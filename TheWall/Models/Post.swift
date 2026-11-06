import Foundation

/// A post as read back from the data layer.
struct Post: Sendable, Identifiable, Equatable {
    let id: String
    let authorID: String
    let authorName: String
    let authorPhotoURL: URL?
    let text: String
    /// The server's timestamp, or a local estimate while `isPending` is true.
    let createdAt: Date
    /// True until the server has confirmed the write.
    let isPending: Bool
}

/// One complete query result. Each snapshot replaces the previous one rather than patching it.
struct PostSnapshot: Sendable, Equatable {
    let posts: [Post]
    /// True when this result hasn't been confirmed by the server.
    let isFromCache: Bool
}
