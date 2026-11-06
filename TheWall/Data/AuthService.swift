/// Handles sign-in and reports who is signed in.
protocol AuthService: Sendable {
    /// The current user on subscribing, then every change. `nil` means signed out.
    var authState: AsyncStream<AuthUser?> { get }

    /// Runs the interactive sign-in flow. The result arrives through `authState`.
    /// - Throws: `AuthError`.
    @MainActor func signIn() async throws

    func signOut() throws
}

enum AuthError: Error, Equatable {
    /// The user backed out, which the UI shouldn't present as an error.
    case cancelled
    case failed
}
