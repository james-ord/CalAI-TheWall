enum FeedStatus: Equatable {
    case loading
    case loaded
    /// The listener ended with an error. `reload()` starts a new one.
    case failed
}
