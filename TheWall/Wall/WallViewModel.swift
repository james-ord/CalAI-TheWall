import Foundation
import Observation

/// The Wall screen for one signed-in user: a live list for the selected filter, plus any posts
/// the server rejected. The view owns it, and a new user gets a new one.
@MainActor
@Observable
final class WallViewModel {
    private static let listenerLimit = 100

    let user: AuthUser
    private(set) var filter = PostFilter.allPosts
    private(set) var status = FeedStatus.loading
    private(set) var maxPostLength = ConfigDefaults.maxPostLength

    /// The latest query result. Firestore includes our own unsent posts, marked pending.
    private var posts: [Post] = []
    /// Posts the server rejected. They drop out of the query, so they're kept here for retry.
    private var failedPosts: [Post] = []

    private let repository: any PostRepository
    private let auth: any AuthService
    private let config: any ConfigService
    @ObservationIgnored private var listenerTask: Task<Void, Never>?
    @ObservationIgnored private var configTask: Task<Void, Never>?
    @ObservationIgnored private var isSignedOut = false

    init(
        user: AuthUser,
        repository: any PostRepository,
        auth: any AuthService,
        config: any ConfigService
    ) {
        self.user = user
        self.repository = repository
        self.auth = auth
        self.config = config
    }

    /// Failed posts first, then the query's posts in the order it returned them.
    var items: [FeedItem] {
        let failedIDs = Set(failedPosts.map(\.id))
        let failed = failedPosts.map { FeedItem(post: $0, deliveryStatus: .failed) }
        let listed = posts
            .filter { !failedIDs.contains($0.id) }
            .map { FeedItem(post: $0, deliveryStatus: $0.isPending ? .sending : .delivered) }
        return failed + listed
    }

    // MARK: - Lifecycle

    func start() {
        guard !isSignedOut, listenerTask == nil else { return }
        listen()
        configTask = Task { [weak self, config] in
            for await limit in config.maxPostLength {
                self?.maxPostLength = limit
            }
        }
    }

    /// Signs out in the order Firestore needs: stop listening, clear the local cache so the next
    /// account starts with nothing from this one, then sign out. Clearing refuses to run while a
    /// listener is active, and a listener left running would hit permission errors once signed
    /// out. Clearing also discards posts still waiting to send.
    func signOut() async throws {
        isSignedOut = true
        listenerTask?.cancel()
        configTask?.cancel()
        posts = []
        failedPosts = []

        // A failed clear shouldn't stop the user signing out. The cache only holds posts any
        // signed-in user can read.
        try? await repository.clearLocalData()
        try auth.signOut()
    }

    // MARK: - Reading

    func updateFilter(_ filter: PostFilter) {
        guard !isSignedOut, filter != self.filter else { return }
        self.filter = filter
        listen()
    }

    /// Starts a new listener, for example after one has failed.
    func reload() {
        guard !isSignedOut else { return }
        listen()
    }

    private func listen() {
        listenerTask?.cancel()
        posts = []
        status = .loading

        let author = filter == .myPosts ? user.id : nil
        listenerTask = Task { [weak self, repository] in
            do {
                for try await snapshot in repository.posts(author: author, limit: Self.listenerLimit) {
                    // A snapshot can already be on its way when the listener is replaced or stopped.
                    guard !Task.isCancelled else { return }
                    self?.posts = snapshot.posts
                    // An empty result from the cache only means nothing is cached yet.
                    if !snapshot.isFromCache || !snapshot.posts.isEmpty {
                        self?.status = .loaded
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.status = .failed
            }
        }
    }

    // MARK: - Posting

    /// Sends `text` if it's postable. The post appears through the listener straight away, so
    /// this doesn't wait for the server, which can take indefinitely while offline.
    /// - Returns: Whether the text was accepted, so the composer knows to clear.
    @discardableResult
    func post(_ text: String) -> Bool {
        guard !isSignedOut, PostRules.canPost(text, limit: maxPostLength) else { return false }
        send(NewPost(author: user, text: PostRules.normalized(text)), sentAt: Date())
        return true
    }

    /// Resends a rejected post with the same ID, so it can't create a duplicate. A rejected
    /// write never stored the document, so the retry is a fresh create.
    func retry(postID: String) {
        guard !isSignedOut, let failed = failedPosts.first(where: { $0.id == postID }) else { return }
        failedPosts.removeAll { $0.id == postID }
        send(NewPost(id: failed.id, author: user, text: failed.text), sentAt: failed.createdAt)
    }

    private func send(_ post: NewPost, sentAt: Date) {
        Task { [weak self, repository] in
            do {
                try await repository.create(post)
            } catch {
                guard let self, !self.isSignedOut else { return }
                let failed = Post(
                    id: post.id,
                    authorID: post.authorID,
                    authorName: post.authorName,
                    authorPhotoURL: post.authorPhotoURL,
                    text: post.text,
                    createdAt: sentAt,
                    isPending: true
                )
                self.failedPosts.insert(failed, at: 0)
            }
        }
    }
}
