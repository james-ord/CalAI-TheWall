import Testing
@testable import TheWall

@Suite struct PostRulesTests {
    @Test(arguments: [
        ("Hello", 280, true),
        ("  Hello  ", 5, true),
        ("Hello!", 5, false),
        ("Hello", 5, true),
        ("", 280, false),
        ("   \n  ", 280, false),
        ("👍🏽👍🏽", 2, true),
    ])
    func canPost(text: String, limit: Int, expected: Bool) {
        #expect(PostRules.canPost(text, limit: limit) == expected)
    }

    @Test func normalizedTrimsSurroundingWhitespaceOnly() {
        #expect(PostRules.normalized("  a\nb \n") == "a\nb")
    }
}
