import FirebaseFirestore
import Foundation

/// Converts between Firestore documents and our models. Field names match `firestore.rules`.
enum PostMapper {
    enum Field {
        static let authorID = "authorId"
        static let authorName = "authorName"
        static let authorPhotoURL = "authorPhotoURL"
        static let text = "text"
        static let createdAt = "createdAt"
    }

    /// The document to write for a new post. The rules require every field, so a missing photo
    /// is written as `null`, and `createdAt` is left for the server to fill in.
    static func data(for post: NewPost) -> [String: Any] {
        [
            Field.authorID: post.authorID,
            Field.authorName: post.authorName,
            Field.authorPhotoURL: post.authorPhotoURL?.absoluteString ?? NSNull(),
            Field.text: post.text,
            Field.createdAt: FieldValue.serverTimestamp(),
        ]
    }

    /// Reads a document's data, fetched with `serverTimestampBehavior: .estimate` so that a
    /// pending post already has a time.
    /// - Returns: `nil` for a malformed document, so one bad post can't break the list.
    static func post(id: String, data: [String: Any], isPending: Bool) -> Post? {
        guard
            let authorID = data[Field.authorID] as? String,
            let authorName = data[Field.authorName] as? String,
            let text = data[Field.text] as? String,
            let createdAt = data[Field.createdAt] as? Timestamp
        else {
            return nil
        }
        return Post(
            id: id,
            authorID: authorID,
            authorName: authorName,
            authorPhotoURL: (data[Field.authorPhotoURL] as? String).flatMap(URL.init(string:)),
            text: text,
            createdAt: createdAt.dateValue(),
            isPending: isPending
        )
    }
}
