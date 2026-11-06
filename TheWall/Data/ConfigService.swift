/// Provides remotely configured values.
protocol ConfigService: Sendable {
    /// The post length limit: the current value, then each live update. Falls back to
    /// `ConfigDefaults.maxPostLength` if the configured value isn't usable.
    var maxPostLength: AsyncStream<Int> { get }
}

enum ConfigDefaults {
    static let maxPostLength = 280
}
