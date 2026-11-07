import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

struct FirebaseAuthService: AuthService {
    var authState: any AsyncSequence<AuthUser?, Never> {
        Auth.auth().authStateChanges.map { user in
            user.map { AuthUser(id: $0.uid, name: $0.displayName ?? "", photoURL: $0.photoURL) }
        }
    }

    /// Signs in with Google, then exchanges the Google tokens for a Firebase session. The new
    /// user arrives through `authState`.
    @MainActor func signIn(presenting presenter: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else { throw AuthError.failed }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let googleUser: GIDGoogleUser
        do {
            googleUser = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter).user
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain
            && error.code == GIDSignInError.canceled.rawValue {
            throw AuthError.cancelled
        } catch {
            throw AuthError.failed
        }

        guard let idToken = googleUser.idToken?.tokenString else { throw AuthError.failed }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            throw AuthError.failed
        }
    }

    /// Also signs out of Google, so the next sign-in offers the account picker again.
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}
