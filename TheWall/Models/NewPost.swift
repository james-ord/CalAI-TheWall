import Foundation

/// A post on its way to the server.
///
/// It has no `createdAt` because the server assigns that, and no pending state because
/// that only describes a stored document. See `Post` for the read side.
///
/// The client generates `id`. Retrying resends the same value, so a retry can't create a
/// second post.
struct NewPost: Sendable, Equatable {
    let id: String
    let authorID: String
    let authorName: String
    let authorPhotoURL: URL?
    let text: String

    init(id: String = UUID().uuidString, author: AuthUser, text: String) {
        self.id = id
        self.authorID = author.id
        self.authorName = author.name
        self.authorPhotoURL = author.photoURL
        self.text = text
    }
}
