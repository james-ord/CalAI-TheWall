import Foundation

/// What counts as a postable message.
enum PostRules {
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canPost(_ text: String, limit: Int) -> Bool {
        let normalized = normalized(text)
        return !normalized.isEmpty && normalized.count <= limit
    }
}
