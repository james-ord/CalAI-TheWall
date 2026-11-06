@testable import TheWall

/// A `PostRepository` with no behaviour of its own: each test supplies what the backend does.
actor MockPostRepository: PostRepository {
    typealias PostsHandler = @Sendable (_ author: String?, _ limit: Int) -> any AsyncSequence<PostSnapshot, any Error>

    enum CreateBehavior: Sendable {
        case succeed
        case fail(PostError)
        /// Stays suspended like an offline write, until `finishSuspendedCreate` is called.
        case suspend
    }

    private let postsHandler: PostsHandler
    private var createBehavior: CreateBehavior
    private var suspendedCreates: [String: CheckedContinuation<Void, any Error>] = [:]
    private(set) var createdPosts: [NewPost] = []

    init(createBehavior: CreateBehavior, posts: @escaping PostsHandler) {
        self.createBehavior = createBehavior
        self.postsHandler = posts
    }

    nonisolated func posts(author: String?, limit: Int) -> any AsyncSequence<PostSnapshot, any Error> {
        postsHandler(author, limit)
    }

    func create(_ post: NewPost) async throws {
        createdPosts.append(post)
        switch createBehavior {
        case .succeed:
            return
        case .fail(let error):
            throw error
        case .suspend:
            try await withCheckedThrowingContinuation { continuation in
                suspendedCreates[post.id] = continuation
            }
        }
    }

    func setCreateBehavior(_ behavior: CreateBehavior) {
        createBehavior = behavior
    }

    /// Answers a suspended `create`, as the server eventually would.
    func finishSuspendedCreate(id: String, with result: Result<Void, PostError>) {
        suspendedCreates
            .removeValue(forKey: id)?
            .resume(with: result.mapError { $0 as any Error })
    }
}
