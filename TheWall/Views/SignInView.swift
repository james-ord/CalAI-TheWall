import SwiftUI

struct SignInView: View {
    let auth: any AuthService

    @State private var presenter = PresenterReference()
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Button("Sign In With Google", action: signIn)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(isSigningIn)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Wall")
            .navigationBarTitleDisplayMode(.inline)
            .background(PresenterReader(reference: presenter))
        }
    }

    private func signIn() {
        guard let controller = presenter.controller else { return }
        isSigningIn = true
        errorMessage = nil
        Task {
            defer { isSigningIn = false }
            do {
                try await auth.signIn(presenting: controller)
            } catch AuthError.cancelled {
                // Backing out isn't an error.
            } catch {
                print(error)
                errorMessage = "Couldn't sign in. Please try again."
            }
        }
    }
}
