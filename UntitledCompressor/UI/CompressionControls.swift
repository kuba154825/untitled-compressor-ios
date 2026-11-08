import SwiftUI

struct CompressionControls: View {
    @Binding var options: CompressionOptions
    let language: String
    @FocusState private var editingSize: Bool
    private func t(_ value: String) -> String { Language.text(value, language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(t("Set your compression"), selection: $options.mode) {
                Text(t("Compression %")).tag(CompressionMode.percent)
                Text(t("Target MB")).tag(CompressionMode.size)
            }.pickerStyle(.segmented).accessibilityIdentifier("compressionMode")
            if options.mode == .percent {
                HStack { Text(t("Reduce file size by")); Spacer(); Text("\(Int(options.percent))%").monospacedDigit().bold() }
                    .font(.system(size: 13))
                Slider(value: $options.percent, in: 1...99, step: 1)
                    .accessibilityLabel(t("Reduce file size by")).accessibilityIdentifier("compressionSlider")
                HStack { Text(t("Higher quality")); Spacer(); Text(t("Smaller file")) }.font(.caption2).foregroundStyle(.secondary)
                Text(language == "pl" ? "Wynik: \(100 - Int(options.percent))% oryginalnego rozmiaru" : "Output: \(100 - Int(options.percent))% of original size")
                    .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("percentExplanation")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Maximum output size · MB")).font(.system(size: 13, weight: .medium))
                    TextField("10", value: $options.targetMB, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                        .focused($editingSize).accessibilityLabel(t("Maximum output size · MB"))
                        .accessibilityIdentifier("targetMB")
                    Text(t("Per video · 1 MB = 1,000,000 bytes")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                ForEach([25, 50, 75, 90], id: \.self) { value in
                    Button("\(value)%") { editingSize = false; options.mode = .percent; options.percent = Double(value) }
                        .buttonStyle(.bordered).tint(options.mode == .percent && Int(options.percent) == value ? .green : .secondary)
                        .font(.caption).accessibilityIdentifier("preset\(value)")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(t("Done")) { editingSize = false } }
        }
    }
}
