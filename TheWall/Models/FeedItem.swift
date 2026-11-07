/// A post as displayed, combined with how its delivery is going.
struct FeedItem: Sendable, Identifiable, Equatable {
    enum DeliveryStatus: Sendable, Equatable {
        case sending
        case delivered
        case failed
    }

    let post: Post
    let deliveryStatus: DeliveryStatus

    var id: String { post.id }
}
