@testable import TheWall

/// An `AuthService` whose behaviour is set by each test. It supports one `authState` consumer,
/// which is all the app has.
final class MockAuthService: AuthService {
    typealias SignOutHandler = @Sendable () throws -> Void

    let authState: AsyncStream<AuthUser?>
    private let continuation: AsyncStream<AuthUser?>.Continuation
    private let signInResult: Result<AuthUser, AuthError>
    private let signOutHandler: SignOutHandler

    init(
        initialUser: AuthUser?,
        signInResult: Result<AuthUser, AuthError>,
        signOut: @escaping SignOutHandler
    ) {
        (authState, continuation) = AsyncStream.makeStream()
        self.signInResult = signInResult
        self.signOutHandler = signOut
        continuation.yield(initialUser)
    }

    @MainActor func signIn() async throws {
        continuation.yield(try signInResult.get())
    }

    func signOut() throws {
        try signOutHandler()
        continuation.yield(nil)
    }
}
