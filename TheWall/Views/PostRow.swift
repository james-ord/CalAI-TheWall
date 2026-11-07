import SwiftUI

struct PostRow: View {
    let item: FeedItem
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: item.post.authorPhotoURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.post.authorName).bold()
                    Spacer()
                    Text(item.post.createdAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(item.post.text)
                deliveryStatus
            }
        }
        .opacity(item.deliveryStatus == .sending ? 0.6 : 1)
    }

    @ViewBuilder
    private var deliveryStatus: some View {
        switch item.deliveryStatus {
        case .sending:
            Text("Sending…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            HStack {
                Text("Not sent").foregroundStyle(.red)
                Button("Retry", action: onRetry)
                    // Keeps the tap on the button rather than the whole row.
                    .buttonStyle(.borderless)
            }
            .font(.caption)
        case .delivered:
            EmptyView()
        }
    }
}
