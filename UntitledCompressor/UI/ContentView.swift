import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct ContentView: View {
    @StateObject private var store = CompressorStore()
    @AppStorage("language") private var language = "en"
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showImporter = false
    @State private var showSettings = false
    @State private var filter = "All"
    @State private var preview: PreviewItem?
    private func t(_ value: String) -> String { Language.text(value, language) }
    private var visible: [CompressionJob] {
        store.jobs.filter { filter == "All" || (filter == "Completed" ? $0.state == .done : [.reading, .ready, .running].contains($0.state)) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 22) { settingsPanel.frame(maxWidth: 440); queuePanel }
                    } else { settingsPanel; queuePanel }
                    HStack { Text("Untitled Compressor"); Spacer(); Text("MP4 · iOS") }
                        .font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 2)
                }.padding(20).frame(maxWidth: 1100).frame(maxWidth: .infinity)
            }
            .background(Palette.canvas(scheme)).scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.mpeg4Movie], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): Task { await store.add(urls) }
                case .failure(let error): store.message = CompressorStore.errorMessage(error)
                }
            }
            .sheet(isPresented: $showSettings) { settingsSheet }
            .sheet(item: $preview) { item in VideoPlayer(player: AVPlayer(url: item.url)).ignoresSafeArea() }
            .alert("Untitled Compressor", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button(t("Done")) { store.message = nil }
            } message: { Text(t(store.message ?? "")) }
        }
        .tint(scheme == .dark ? Palette.accent : Color(red: 0.26, green: 0.43, blue: 0.17))
        .preferredColorScheme(appearance == "system" ? nil : appearance == "light" ? .light : .dark)
        .onChange(of: store.options) { _, _ in store.applyOptions() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                .frame(width: 32, height: 34).background(Palette.accent, in: RoundedRectangle(cornerRadius: 10))
            Text("Untitled Compressor").font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                ForEach(["en", "pl"], id: \.self) { code in
                    Button(code == "en" ? "ENG" : "PL") { language = code }
                        .font(.system(size: 10, weight: language == code ? .bold : .regular))
                        .padding(.horizontal, 7).frame(minHeight: 34)
                        .background(language == code ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityIdentifier(code == "en" ? "languageEN" : "languagePL")
                }
            }.padding(2).overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.rail(scheme)))
            Button { showSettings = true } label: { Image(systemName: "gearshape").frame(width: 32, height: 36) }
                .accessibilityLabel(t("Settings"))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Palette.canvas(scheme)).overlay(alignment: .bottom) { Rectangle().fill(Palette.rail(scheme)).frame(height: 1) }
    }
    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("SMALLER FILES. SAME MOMENTS.")).font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
            Text(t("Make room for more.")).font(.system(size: 29, weight: .semibold)).tracking(-0.8)
            Text(t("Compress your MP4 videos. Keep what matters.")).font(.system(size: 13)).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
    }
    private var settingsPanel: some View {
        Panel {
            sectionTitle("NEW COMPRESSION", "Add your files")
            step("01", "Choose local files")
            Button { showImporter = true } label: {
                Label(t(store.importing ? "Adding files…" : "Choose MP4 files"), systemImage: "folder")
                    .font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.bordered).disabled(store.importing).accessibilityIdentifier("addFiles")
            Text(t("MP4 videos from Files")).font(.caption2).foregroundStyle(.secondary)
            Divider()
            step("02", "Set your compression")
            CompressionControls(options: $store.options, language: language)
            Button(t("Save defaults")) { store.saveDefaults(); store.message = "Defaults saved" }.font(.caption)
            Divider()
            Button { store.start() } label: {
                HStack { Image(systemName: "arrow.down.right.and.arrow.up.left"); Text(t("Compress files")); Spacer(); Image(systemName: "arrow.right") }
            }.buttonStyle(AccentButton()).disabled(store.readyCount == 0 || store.running || store.importing)
                .opacity(store.readyCount == 0 || store.running || store.importing ? 0.5 : 1).accessibilityIdentifier("compress")
            if store.running {
                Button(t("Cancel"), role: .destructive) { store.cancel() }.frame(maxWidth: .infinity).accessibilityIdentifier("cancel")
                Text(t("Keep this app open while compressing.")).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    private var queuePanel: some View {
        Panel {
            HStack(alignment: .top) {
                sectionTitle("EVERYTHING IN ONE PLACE", "Your compressions")
                Spacer()
                Text("\(store.jobs.count)").font(.caption.monospacedDigit()).padding(7).background(Color.primary.opacity(0.05), in: Capsule())
                if store.jobs.contains(where: { $0.state == .done }) {
                    Button(t("Clear")) { store.clearCompleted() }.font(.caption).disabled(store.running)
                }
            }
            HStack(spacing: 22) {
                ForEach(["All", "Active", "Completed"], id: \.self) { value in
                    Button(t(value)) { filter = value }.font(.system(size: 12, weight: filter == value ? .semibold : .regular))
                        .foregroundStyle(filter == value ? (scheme == .dark ? Palette.accent : .green) : .secondary)
                        .padding(.bottom, 10).overlay(alignment: .bottom) { if filter == value { Rectangle().frame(height: 2) } }
                }
            }
            Divider()
            if store.jobs.isEmpty { emptyQueue }
            else if visible.isEmpty { Text(t("No files in this view.")).font(.caption).foregroundStyle(.secondary).padding(.vertical, 30) }
            else {
                ForEach(visible) { job in
                    JobCard(job: job, store: store, language: language) { preview = PreviewItem(url: store.output(job)) }
                }
            }
        }
    }
    private var emptyQueue: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.stack").font(.system(size: 57, weight: .ultraLight)).foregroundStyle(.secondary).padding(.bottom, 6)
            Text(t("Your files will appear here")).font(.system(size: 18, weight: .semibold))
            Text(t("Add MP4 files and choose your target size.")).font(.caption).foregroundStyle(.secondary)
            Text(t("Everything stays on your device.")).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 60).multilineTextAlignment(.center)
    }
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Picker(t("Appearance"), selection: $appearance) {
                    Text(t("Dark")).tag("dark"); Text(t("Light")).tag("light"); Text(t("System")).tag("system")
                }
                Text(t("Everything stays on your device.")).font(.caption).foregroundStyle(.secondary)
            }.navigationTitle(t("Settings")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(t("Done")) { showSettings = false } } }
        }.presentationDetents([.medium])
    }
    private func sectionTitle(_ eyebrow: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t(eyebrow)).font(.system(size: 8, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
            Text(t(title)).font(.system(size: 20, weight: .semibold)).tracking(-0.4)
        }
    }
    private func step(_ value: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 28, height: 28).overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.rail(scheme)))
            Text(t(title)).font(.system(size: 13, weight: .semibold))
        }
    }
}

private struct PreviewItem: Identifiable { let id = UUID(); let url: URL }

private struct JobCard: View {
    let job: CompressionJob
    @ObservedObject var store: CompressorStore
    let language: String
    let preview: () -> Void
    @State private var expanded = false
    @Environment(\.colorScheme) private var scheme
    private func t(_ value: String) -> String { Language.text(value, language) }
    private var canEdit: Bool { [.ready, .failed, .cancelled].contains(job.state) && job.media != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "film").font(.title2).foregroundStyle(.secondary).frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name).font(.system(size: 13, weight: .semibold)).lineLimit(2).textSelection(.enabled)
                    Text(fileBytes(job.size)).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if canEdit { Button { expanded.toggle() } label: { Image(systemName: expanded ? "minus" : "plus").frame(width: 30, height: 36) }.accessibilityLabel(t("Options")) }
                if job.state != .running && job.state != .reading { Button { store.remove(job.id) } label: { Image(systemName: "xmark").frame(width: 28, height: 36) }.accessibilityLabel(t("Remove")) }
            }
            HStack {
                if let result = job.resultSize { Text("\(fileBytes(job.size)) → \(fileBytes(result))") }
                else if let target = store.estimate(job) { Text("\(t("Output target")): \(fileBytes(target))") }
                else { Text("MP4") }
                Spacer()
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if job.state == .running {
                ProgressView(value: job.progress)
                HStack {
                    Text(t(job.attempt > 1 ? "Adjusting size…" : "Compressing…"))
                    Spacer(); Text("\(Int(job.progress * 100))%").monospacedDigit()
                }.font(.caption)
            } else if job.state == .done {
                HStack {
                    Label(t("Complete"), systemImage: "checkmark.circle").font(.caption)
                    Spacer()
                    Button(t("Preview"), action: preview).font(.caption)
                    ShareLink(item: store.output(job)) { Label(t("Share / Save"), systemImage: "square.and.arrow.up").font(.caption) }
                }
            } else {
                Text(t(job.state == .reading ? "Reading…" : job.state == .ready ? "Ready" : job.state == .cancelled ? "Cancelled" : "Failed"))
                    .font(.caption).foregroundStyle(job.state == .failed ? .orange : .secondary)
            }
            if let error = job.error { Text(t(error)).font(.caption).foregroundStyle(.orange) }
            if expanded && canEdit {
                Divider()
                CompressionControls(options: Binding(get: { job.options }, set: { store.setOptions($0, for: job.id) }), language: language)
            }
        }
        .padding(14).background(Palette.canvas(scheme), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.rail(scheme)))
    }
}
