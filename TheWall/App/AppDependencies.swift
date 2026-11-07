/// The services the app runs on. The app passes in the Firebase versions, and tests use mocks.
struct AppDependencies {
    let repository: any PostRepository
    let auth: any AuthService
    let config: any ConfigService
}
