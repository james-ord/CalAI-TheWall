import Foundation

/// The signed-in user, free of any Firebase types.
struct AuthUser: Sendable, Equatable {
    let id: String
    let name: String
    let photoURL: URL?
}
