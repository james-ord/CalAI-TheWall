/// Reads and writes posts. Implementations hide the backend from the rest of the app.
protocol PostRepository: Sendable {
    /// A live sequence of query results, newest first. Cancelling the consuming task stops the
    /// underlying listener.
    /// - Parameter author: A user ID to return only their posts, or `nil` for the whole wall.
    func posts(author: String?, limit: Int) -> any AsyncSequence<PostSnapshot, any Error>

    /// Writes a post using its client-generated ID.
    ///
    /// This stays suspended while offline, and only returns once the server has answered, so
    /// callers must not make the UI wait on it.
    /// - Throws: `PostError` if the write fails.
    func create(_ post: NewPost) async throws

    /// Deletes everything stored locally, so the next account starts with nothing from this
    /// one. Call it after stopping all listeners. This also discards posts still waiting to send.
    func clearLocalData() async throws
}

enum PostError: Error, Equatable {
    /// The server refused the write, for example because of the security rules.
    case rejected
    case unknown
}
