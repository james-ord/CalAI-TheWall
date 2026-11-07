import SwiftUI

/// Shows sign-in or the Wall, following the signed-in user.
struct RootView: View {
    let dependencies: AppDependencies

    @State private var user: AuthUser?
    @State private var hasCheckedAuth = false

    var body: some View {
        Group {
            if !hasCheckedAuth {
                ProgressView()
            } else if let user {
                WallView(viewModel: WallViewModel(
                    user: user,
                    repository: dependencies.repository,
                    auth: dependencies.auth,
                    config: dependencies.config
                ))
                // A different user gets a new view model, so nothing carries over.
                .id(user.id)
            } else {
                SignInView(auth: dependencies.auth)
            }
        }
        .task {
            for await user in dependencies.auth.authState {
                self.user = user
                hasCheckedAuth = true
            }
        }
    }
}
