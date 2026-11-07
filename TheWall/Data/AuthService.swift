import UIKit

/// Handles sign-in and reports who is signed in.
protocol AuthService: Sendable {
    /// The current user on subscribing, then every change. `nil` means signed out.
    var authState: any AsyncSequence<AuthUser?, Never> { get }

    /// Runs the interactive sign-in flow. The result arrives through `authState`.
    /// - Parameter presenter: The calling screen's view controller, which the sign-in screen is
    ///   presented from.
    /// - Throws: `AuthError`.
    @MainActor func signIn(presenting presenter: UIViewController) async throws

    func signOut() throws
}

enum AuthError: Error, Equatable {
    /// The user backed out, which the UI shouldn't present as an error.
    case cancelled
    case failed
}
