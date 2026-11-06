@testable import TheWall

/// A `ConfigService` that delivers whatever stream each test supplies.
struct MockConfigService: ConfigService {
    let maxPostLength: AsyncStream<Int>
}
