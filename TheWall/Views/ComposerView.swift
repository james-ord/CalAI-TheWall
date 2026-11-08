import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    let limit: Int
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var count: Int {
        PostRules.normalized(text).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Write something here...", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .focused($isFocused)
            HStack {
                Button("Add to the wall") {
                    isFocused = false
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .disabled(!PostRules.canPost(text, limit: limit))
                Spacer()
                Text("\(count)/\(limit)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(count > limit ? .red : .secondary)
                    .accessibilityLabel("\(count) of \(limit) characters")
            }
        }
        .padding()
    }
}
