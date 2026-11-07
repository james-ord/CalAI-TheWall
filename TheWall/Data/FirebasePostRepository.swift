import FirebaseFirestore
import Foundation

struct FirebasePostRepository: PostRepository {
    /// Looked up on every call rather than stored, because `clearLocalData()` shuts the current
    /// Firestore instance down and the next call needs a fresh one.
    private var collection: CollectionReference {
        Firestore.firestore().collection("posts")
    }

    func posts(author: String?, limit: Int) -> any AsyncSequence<PostSnapshot, any Error> {
        var query: Query = collection
        if let author {
            query = query.whereField(PostMapper.Field.authorID, isEqualTo: author)
        }
        return query
            .order(by: PostMapper.Field.createdAt, descending: true)
            .limit(to: limit)
            // Metadata changes are needed to hear when a pending post is confirmed.
            .snapshots(includeMetadataChanges: true)
            .map { snapshot in
                PostSnapshot(
                    posts: snapshot.documents.compactMap { document in
                        PostMapper.post(
                            id: document.documentID,
                            data: document.data(with: .estimate),
                            isPending: document.metadata.hasPendingWrites
                        )
                    },
                    isFromCache: snapshot.metadata.isFromCache
                )
            }
    }

    func create(_ post: NewPost) async throws {
        do {
            try await collection.document(post.id).setData(PostMapper.data(for: post))
        } catch {
            throw postError(for: error)
        }
    }

    /// Shuts Firestore down, then deletes its local cache and any unsent writes. Clearing only
    /// works on an instance that isn't running.
    func clearLocalData() async throws {
        let firestore = Firestore.firestore()
        try await firestore.terminate()
        try await firestore.clearPersistence()
    }

    private func postError(for error: any Error) -> PostError {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else { return .unknown }
        switch FirestoreErrorCode.Code(rawValue: nsError.code) {
        case .permissionDenied, .invalidArgument:
            return .rejected
        default:
            return .unknown
        }
    }
}
