import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    let limit: Int
    let onSubmit: () -> Void

    private var count: Int {
        PostRules.normalized(text).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Write something here...", text: $text, axis: .vertical)
                .lineLimit(1...5)
            HStack {
                Button("Add to the wall", action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!PostRules.canPost(text, limit: limit))
                Spacer()
                Text("\(count)/\(limit)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(count > limit ? .red : .secondary)
            }
        }
        .padding()
    }
}
