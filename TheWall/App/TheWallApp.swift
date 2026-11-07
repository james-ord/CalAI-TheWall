import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct TheWallApp: App {
    private let dependencies: AppDependencies

    init() {
        FirebaseApp.configure()
        dependencies = AppDependencies(
            repository: FirebasePostRepository(),
            auth: FirebaseAuthService(),
            config: FirebaseConfigService()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                // Google sign-in returns to the app through this URL.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
