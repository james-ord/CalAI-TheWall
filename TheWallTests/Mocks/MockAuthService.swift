@testable import TheWall

/// An `AuthService` whose behaviour is set by each test. It supports one `authState` consumer,
/// which is all the app has.
final class MockAuthService: AuthService {
    let authState: AsyncStream<AuthUser?>
    private let continuation: AsyncStream<AuthUser?>.Continuation
    private let signInResult: Result<AuthUser, AuthError>

    init(initialUser: AuthUser?, signInResult: Result<AuthUser, AuthError>) {
        (authState, continuation) = AsyncStream.makeStream()
        self.signInResult = signInResult
        continuation.yield(initialUser)
    }

    @MainActor func signIn() async throws {
        continuation.yield(try signInResult.get())
    }

    func signOut() throws {
        continuation.yield(nil)
    }
}
