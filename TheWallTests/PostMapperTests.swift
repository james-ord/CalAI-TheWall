import FirebaseFirestore
import Foundation
import Testing
@testable import TheWall

@Suite struct PostMapperTests {
    private let createdAt = Date(timeIntervalSince1970: 1_000)

    private func validData() -> [String: Any] {
        [
            "authorId": "maya-id",
            "authorName": "Maya",
            "authorPhotoURL": "https://example.com/maya.png",
            "text": "Hello",
            "createdAt": Timestamp(date: createdAt),
        ]
    }

    @Test func readsAValidDocument() {
        let post = PostMapper.post(id: "1", data: validData(), isPending: true)

        #expect(post == Post(
            id: "1",
            authorID: "maya-id",
            authorName: "Maya",
            authorPhotoURL: URL(string: "https://example.com/maya.png"),
            text: "Hello",
            createdAt: createdAt,
            isPending: true
        ))
    }

    @Test func nullPhotoReadsAsNil() {
        var data = validData()
        data["authorPhotoURL"] = NSNull()

        #expect(PostMapper.post(id: "1", data: data, isPending: false)?.authorPhotoURL == nil)
    }

    @Test(arguments: ["authorId", "authorName", "text", "createdAt"])
    func missingRequiredFieldIsSkipped(field: String) {
        var data = validData()
        data[field] = nil

        #expect(PostMapper.post(id: "1", data: data, isPending: false) == nil)
    }

    @Test func wrongTypeIsSkipped() {
        var data = validData()
        data["createdAt"] = "yesterday"

        #expect(PostMapper.post(id: "1", data: data, isPending: false) == nil)
    }

    @Test func writesExactlyTheFieldsTheRulesExpect() {
        let data = PostMapper.data(for: NewPost(author: TestData.maya, text: "Hello"))

        #expect(Set(data.keys) == ["authorId", "authorName", "authorPhotoURL", "text", "createdAt"])
        #expect(data["authorId"] as? String == TestData.maya.id)
        #expect(data["authorName"] as? String == TestData.maya.name)
        #expect(data["text"] as? String == "Hello")
        #expect(data["createdAt"] is FieldValue)
    }

    @Test func missingPhotoIsWrittenAsNull() {
        let data = PostMapper.data(for: NewPost(author: TestData.maya, text: "Hello"))
        #expect(data["authorPhotoURL"] is NSNull)
    }

    @Test func photoIsWrittenAsAString() {
        let author = AuthUser(id: "id", name: "Name", photoURL: URL(string: "https://example.com/p.png"))
        let data = PostMapper.data(for: NewPost(author: author, text: "Hello"))
        #expect(data["authorPhotoURL"] as? String == "https://example.com/p.png")
    }
}
