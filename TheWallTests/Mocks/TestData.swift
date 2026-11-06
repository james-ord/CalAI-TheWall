import Foundation
@testable import TheWall

enum TestData {
    static let maya = AuthUser(id: "maya-id", name: "Maya", photoURL: nil)
    static let jordan = AuthUser(id: "jordan-id", name: "Jordan", photoURL: nil)

    static func post(
        id: String = UUID().uuidString,
        author: AuthUser = maya,
        text: String = "Hello",
        createdAt: Date = Date(timeIntervalSince1970: 1_000),
        isPending: Bool = false
    ) -> Post {
        Post(
            id: id,
            authorID: author.id,
            authorName: author.name,
            authorPhotoURL: author.photoURL,
            text: text,
            createdAt: createdAt,
            isPending: isPending
        )
    }
}
