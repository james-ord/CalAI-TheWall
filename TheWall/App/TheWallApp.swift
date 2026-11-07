import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct TheWallApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Text("The Wall")
                // Google sign-in returns to the app through this URL.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
