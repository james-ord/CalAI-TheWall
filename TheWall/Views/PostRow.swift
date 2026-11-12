import SwiftUI

struct PostRow: View {
    let item: FeedItem
    /// Whether to offer Delete, which only the post's author can do.
    let canDelete: Bool
    let onRetry: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var scaledAvatarSize = 36
    /// Grows with the text, but stops before it takes the width the text needs.
    private var avatarSize: CGFloat { min(scaledAvatarSize, 56) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: item.post.authorPhotoURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                header
                Text(item.post.text)
                    .font(.subheadline)
                deliveryStatus
            }
        }
        .swipeActions(edge: .trailing) {
            if canDelete {
                // Red, but not the destructive role: that role makes the list remove the row
                // straight away, before the user has confirmed.
                Button("Delete", systemImage: "trash", action: onDelete)
                    .tint(.red)
            }
        }
        .opacity(item.deliveryStatus == .sending ? 0.6 : 1)
        // VoiceOver reads the row as one item rather than stopping on each piece.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityActions {
            if item.deliveryStatus == .failed {
                Button("Retry", action: onRetry)
            }
            if canDelete {
                Button("Delete", action: onDelete)
            }
        }
    }

    /// Name and time share a line, except at accessibility text sizes, where there's no room
    /// and the time would break mid-word.
    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            authorName
            time
        } else {
            HStack {
                authorName
                Spacer()
                time
            }
        }
    }

    private var authorName: some View {
        Text(item.post.authorName)
            .font(.subheadline.bold())
    }

    private var time: some View {
        Text(item.post.createdAt, format: .dateTime.hour().minute())
            .font(.caption)
            .foregroundStyle(.secondary)
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

    private var accessibilityText: String {
        var parts = [
            item.post.authorName,
            item.post.text,
            item.post.createdAt.formatted(.dateTime.hour().minute()),
        ]
        switch item.deliveryStatus {
        case .sending: parts.append("Sending")
        case .failed: parts.append("Not sent")
        case .delivered: break
        }
        return parts.joined(separator: ", ")
    }
}
