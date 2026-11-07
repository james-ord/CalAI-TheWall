import FirebaseRemoteConfig

struct FirebaseConfigService: ConfigService {
    private static let maxPostLengthKey = "max_post_length"

    /// The activated value at launch, then each live update from the Firebase console.
    var maxPostLength: AsyncStream<Int> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            // `RemoteConfig` isn't `Sendable`, so it's looked up inside the task rather than
            // captured from outside it.
            let task = Task {
                let config = RemoteConfig.remoteConfig()
                config.setDefaults([Self.maxPostLengthKey: NSNumber(value: ConfigDefaults.maxPostLength)])
                continuation.yield(limit(from: config))

                _ = try? await config.fetchAndActivate()
                continuation.yield(limit(from: config))

                // Updates only take effect once activated. If the update stream fails, the last
                // limit stays in place until the next launch.
                for try await _ in config.configUpdates {
                    _ = try await config.activate()
                    continuation.yield(limit(from: config))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func limit(from config: RemoteConfig) -> Int {
        let value = config.configValue(forKey: Self.maxPostLengthKey).numberValue.intValue
        return value > 0 ? value : ConfigDefaults.maxPostLength
    }
}
