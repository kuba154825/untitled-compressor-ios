import SwiftUI
import UIKit

enum JobState: String, Codable { case reading, ready, running, done, failed, cancelled }

struct CompressionJob: Identifiable, Codable {
    var id: UUID
    var name: String
    var size: Int64 = 0
    var media: MediaInfo?
    var options: CompressionOptions
    var state: JobState = .reading
    var progress: Double = 0
    var attempt: Int = 1
    var resultSize: Int64?
    var error: String?
}

@MainActor
final class CompressorStore: ObservableObject {
    @Published var jobs: [CompressionJob] = []
    @Published var options = CompressionOptions()
    @Published var importing = false
    @Published var running = false
    @Published var message: String?
    let root: URL
    private var engine: MediaEngine?
    private var task: Task<Void, Never>?
    private var backgroundID: UIBackgroundTaskIdentifier = .invalid
    private let defaults: UserDefaults

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        defaults = testing ? UserDefaults(suiteName: "UntitledCompressor.UITests")! : .standard
        if testing { defaults.removePersistentDomain(forName: "UntitledCompressor.UITests") }
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(testing ? "UITestJobs" : "Jobs", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = defaults.data(forKey: "compressionOptions"), let saved = try? JSONDecoder().decode(CompressionOptions.self, from: data) { options = saved }
        if !testing, let data = try? Data(contentsOf: root.appendingPathComponent("jobs.json")), let saved = try? JSONDecoder().decode([CompressionJob].self, from: data) {
            jobs = saved.map { job in
                var value = job
                if [.running, .reading].contains(value.state) { value.state = value.media == nil ? .failed : .ready; value.progress = 0 }
                if value.state == .done && !FileManager.default.fileExists(atPath: output(value).path) { value.state = .failed; value.error = "The output file is no longer available." }
                return value
            }
        }
        var resource = URLResourceValues(); resource.isExcludedFromBackup = true
        var directory = root; try? directory.setResourceValues(resource)
    }

    var readyCount: Int { jobs.filter { [.ready, .failed, .cancelled].contains($0.state) && $0.media != nil }.count }
    func directory(_ job: CompressionJob) -> URL { root.appendingPathComponent(job.id.uuidString, isDirectory: true) }
    func input(_ job: CompressionJob) -> URL { directory(job).appendingPathComponent("source.mp4") }
    func output(_ job: CompressionJob) -> URL {
        let base = (job.name as NSString).deletingPathExtension
        let safe = String(base.filter { !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) && $0 != "/" && $0 != ":" }.prefix(120))
        return directory(job).appendingPathComponent("\(safe.isEmpty ? "video" : safe)-compressed.mp4")
    }

    func saveDefaults() {
        if let data = try? JSONEncoder().encode(options) { defaults.set(data, forKey: "compressionOptions") }
    }
    func applyOptions() {
        saveDefaults()
        for index in jobs.indices where [.ready, .failed, .cancelled].contains(jobs[index].state) {
            jobs[index].options = options
        }
        persist()
    }
    func setOptions(_ options: CompressionOptions, for id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }), jobs[index].state != .running else { return }
        jobs[index].options = options; persist()
    }
    func estimate(_ job: CompressionJob) -> Int64? {
        guard let meta = job.media else { return nil }
        return try? CompressionPlan.make(size: job.size, media: meta, options: job.options).targetBytes
    }

    func add(_ urls: [URL]) async {
        guard !importing else { return }
        importing = true
        defer { importing = false }
        for source in urls {
            let job = CompressionJob(id: UUID(), name: source.lastPathComponent, options: options)
            jobs.append(job)
            let folder = directory(job), destination = input(job)
            do {
                guard source.pathExtension.lowercased() == "mp4" else { throw CompressorError.mp4Only }
                try await Task.detached(priority: .userInitiated) {
                    let scoped = source.startAccessingSecurityScopedResource()
                    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: source, to: destination)
                }.value
                let size = try MediaEngine.fileSize(destination)
                let reader = MediaEngine()
                let meta = try await reader.probe(destination)
                update(job.id) { $0.size = size; $0.media = meta; $0.state = .ready }
            } catch {
                update(job.id) { $0.state = .failed; $0.error = Self.errorMessage(error) }
                try? FileManager.default.removeItem(at: folder)
            }
            persist()
        }
    }

    func start() {
        guard !running, !importing, readyCount > 0 else { return }
        running = true
        let ids = jobs.filter { [.ready, .failed, .cancelled].contains($0.state) && $0.media != nil }.map(\.id)
        task = Task { [weak self] in
            guard let self else { return }
            backgroundID = UIApplication.shared.beginBackgroundTask(withName: "Finish compression") { [weak self] in
                Task { @MainActor in self?.cancel() }
            }
            defer {
                engine = nil; running = false; task = nil
                if backgroundID != .invalid { UIApplication.shared.endBackgroundTask(backgroundID); backgroundID = .invalid }
                persist()
            }
            for id in ids {
                if Task.isCancelled { break }
                guard let job = jobs.first(where: { $0.id == id }), let meta = job.media else { continue }
                let worker = MediaEngine(); engine = worker
                update(id) { $0.state = .running; $0.progress = 0; $0.attempt = 1; $0.error = nil }
                persist()
                do {
                    let size = try await worker.compress(input: input(job), output: output(job), size: job.size, media: meta, options: job.options) { [weak self] fraction, attempt in
                        Task { @MainActor in self?.update(id) { value in
                            guard value.state == .running else { return }
                            value.progress = fraction; value.attempt = attempt
                        } }
                    }
                    try Task.checkCancellation()
                    update(id) { $0.state = .done; $0.progress = 1; $0.resultSize = size }
                } catch {
                    let cancelled = Task.isCancelled || (error as? CompressorError) == .cancelled
                    update(id) { $0.state = cancelled ? .cancelled : .failed; $0.error = cancelled ? nil : Self.errorMessage(error) }
                    try? FileManager.default.removeItem(at: output(job))
                }
                engine = nil; persist()
                // Do not start another video while iOS is suspending the application.
                if UIApplication.shared.applicationState == .background { break }
            }
        }
    }
    func cancel() { task?.cancel(); engine?.cancel() }
    func remove(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }), job.state != .running, job.state != .reading else { return }
        try? FileManager.default.removeItem(at: directory(job)); jobs.removeAll { $0.id == id }; persist()
    }
    func clearCompleted() {
        let ids = jobs.filter { $0.state == .done }.map(\.id)
        for id in ids { remove(id) }
    }
    private func update(_ id: UUID, _ body: (inout CompressionJob) -> Void) {
        if let index = jobs.firstIndex(where: { $0.id == id }) { body(&jobs[index]) }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(jobs) { try? data.write(to: root.appendingPathComponent("jobs.json"), options: .atomic) }
    }
    static func errorMessage(_ error: Error) -> String {
        if error is CancellationError { return "Cancelled" }
        if let own = error as? CompressorError { return own.localizedDescription }
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError { return "Not enough free space on this device." }
        return "This file could not be processed. Try downloading it to Files first."
    }
}

extension CompressorError: Equatable { }
