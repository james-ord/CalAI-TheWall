import SwiftUI
import UIKit

/// Holds the view controller behind a SwiftUI view, for UIKit APIs that need one to present
/// from, such as Google sign-in.
@MainActor
final class PresenterReference {
    weak var controller: UIViewController?
}

/// Place in a view's `.background` to capture that view's own controller in `reference`. It's
/// added to the view's controller hierarchy, so presenting from it presents over that screen.
struct PresenterReader: UIViewControllerRepresentable {
    let reference: PresenterReference

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        reference.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
