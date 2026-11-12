import Foundation
import Testing
@testable import TheWall

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WallViewModelTests {
    // MARK: - Setup

    typealias Listener = (author: String?, continuation: AsyncThrowingStream<PostSnapshot, any Error>.Continuation)

    /// Every listener the view model has started, in order, so a test can feed the current one.
    /// It also records sign-out steps, to check their order.
    @MainActor
    final class Log {
        var listeners: [Listener] = []
        var current: Listener { listeners[listeners.count - 1] }
        var signOutSteps: [String] = []
    }

    @MainActor
    final class Harness {
        let log = Log()
        let limits = AsyncStream.makeStream(of: Int.self)
        let repository: MockPostRepository
        let auth: MockAuthService
        let viewModel: WallViewModel

        init(createBehavior: MockPostRepository.CreateBehavior) {
            let log = log
            repository = MockPostRepository(
                createBehavior: createBehavior,
                posts: { author, _ in
                    let (stream, continuation) = AsyncThrowingStream.makeStream(of: PostSnapshot.self)
                    MainActor.assumeIsolated { log.listeners.append((author, continuation)) }
                    return stream
                },
                clearLocalData: {
                    await MainActor.run {
                        let listenerEnded = isTerminated(log.current.continuation)
                        log.signOutSteps.append(listenerEnded ? "clear after listener ended" : "clear while listening")
                    }
                }
            )
            auth = MockAuthService(
                initialUser: TestData.maya,
                signInResult: .success(TestData.maya),
                signOut: {
                    MainActor.assumeIsolated { log.signOutSteps.append("sign out") }
                }
            )
            viewModel = WallViewModel(
                user: TestData.maya,
                repository: repository,
                auth: auth,
                config: MockConfigService(maxPostLength: limits.stream)
            )
        }

        /// Starts the view model and waits for its first listener.
        func start() async {
            viewModel.start()
            await waitUntil { self.log.listeners.count == 1 }
        }

        func send(_ posts: [Post], isFromCache: Bool = false) {
            log.current.continuation.yield(PostSnapshot(posts: posts, isFromCache: isFromCache))
        }

        var ids: [String] { viewModel.items.map(\.id) }
        var statuses: [FeedItem.DeliveryStatus] { viewModel.items.map(\.deliveryStatus) }

        /// Posts `text` and returns its ID once it has reached the repository.
        func postAndWait(_ text: String = "Hello") async -> String {
            let countBefore = await repository.createdPosts.count
            #expect(viewModel.post(text))
            await waitUntil { await self.repository.createdPosts.count == countBefore + 1 }
            return await repository.createdPosts.last!.id
        }
    }

    // MARK: - Listing

    @Test func showsTheQueryResultInItsOrder() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()

        harness.send([TestData.post(id: "new"), TestData.post(id: "old")])

        await waitUntil { harness.ids == ["new", "old"] }
        #expect(harness.viewModel.status == .loaded)
    }

    @Test func pendingToConfirmedKeepsTheRowAndUsesTheServerTime() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()
        let serverTime = Date(timeIntervalSince1970: 2_000)

        harness.send([TestData.post(id: "mine", isPending: true), TestData.post(id: "other")])
        await waitUntil { harness.statuses == [.sending, .delivered] }

        harness.send([TestData.post(id: "mine", createdAt: serverTime), TestData.post(id: "other")])

        await waitUntil { harness.statuses == [.delivered, .delivered] }
        #expect(harness.ids == ["mine", "other"])
        #expect(harness.viewModel.items.first?.post.createdAt == serverTime)
    }

    @Test func emptyCacheIsStillLoadingButEmptyServerResultIsLoaded() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()

        harness.send([], isFromCache: true)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(harness.viewModel.status == .loading)

        harness.send([], isFromCache: false)
        await waitUntil { harness.viewModel.status == .loaded }
    }

    // MARK: - Posting

    @Test func validTextIsSentAndInvalidTextIsNot() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()

        #expect(!harness.viewModel.post("   "))
        let id = await harness.postAndWait("  Hello  ")

        let sent = await harness.repository.createdPosts
        #expect(sent.map(\.id) == [id])
        #expect(sent.first?.text == "Hello")
        #expect(sent.first?.authorID == TestData.maya.id)
    }

    @Test func limitFollowsTheConfigStream() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()
        #expect(harness.viewModel.maxPostLength == ConfigDefaults.maxPostLength)

        harness.limits.continuation.yield(5)
        await waitUntil { harness.viewModel.maxPostLength == 5 }

        #expect(!harness.viewModel.post("Too long"))
        #expect(harness.viewModel.post("Short"))
    }

    // MARK: - Failure and retry

    @Test func rejectedPostShowsAsFailedAboveTheList() async {
        let harness = Harness(createBehavior: .fail(.rejected))
        await harness.start()
        harness.send([TestData.post(id: "other")])

        let id = await harness.postAndWait()

        await waitUntil { harness.ids == [id, "other"] }
        #expect(harness.statuses == [.failed, .delivered])
    }

    @Test func rejectedPostStaysFailedWhileItsPendingDocumentIsStillListed() async {
        let harness = Harness(createBehavior: .fail(.rejected))
        await harness.start()
        let id = await harness.postAndWait()
        await waitUntil { harness.statuses == [.failed] }

        harness.send([TestData.post(id: id, isPending: true)])
        await waitUntil { harness.viewModel.status == .loaded }

        #expect(harness.ids == [id])
        #expect(harness.statuses == [.failed])
    }

    @Test func retryResendsTheSameIDWithoutADuplicate() async {
        let harness = Harness(createBehavior: .fail(.rejected))
        await harness.start()
        let id = await harness.postAndWait()
        await waitUntil { harness.statuses == [.failed] }

        await harness.repository.setCreateBehavior(.succeed)
        harness.viewModel.retry(postID: id)

        #expect(harness.ids.isEmpty)
        await waitUntil { await harness.repository.createdPosts.count == 2 }
        #expect(await harness.repository.createdPosts.map(\.id) == [id, id])

        harness.send([TestData.post(id: id)])
        await waitUntil { harness.ids == [id] }
        #expect(harness.statuses == [.delivered])
    }

    @Test func retryIsIgnoredUnlessThePostFailed() async {
        let harness = Harness(createBehavior: .suspend)
        await harness.start()
        let id = await harness.postAndWait()

        harness.viewModel.retry(postID: id)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(await harness.repository.createdPosts.count == 1)
    }

    @Test func failedPostsShowUnderBothFilters() async {
        let harness = Harness(createBehavior: .fail(.rejected))
        await harness.start()
        let id = await harness.postAndWait()
        await waitUntil { harness.ids == [id] }

        harness.viewModel.updateFilter(.myPosts)

        #expect(harness.ids == [id])
        #expect(harness.statuses == [.failed])
    }

    // MARK: - Filtering

    @Test func switchingFilterReplacesTheListener() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()
        harness.send([TestData.post(id: "theirs", author: TestData.jordan)])
        await waitUntil { harness.ids == ["theirs"] }
        let wall = harness.log.current

        harness.viewModel.updateFilter(.myPosts)

        #expect(harness.viewModel.filter == .myPosts)
        #expect(harness.viewModel.status == .loading)
        #expect(harness.ids.isEmpty)
        await waitUntil { harness.log.listeners.count == 2 }
        #expect(harness.log.listeners.map(\.author) == [nil, TestData.maya.id])
        await waitUntil { isTerminated(wall.continuation) }

        harness.send([TestData.post(id: "ours")])
        await waitUntil { harness.ids == ["ours"] }
    }

    @Test func selectingTheCurrentFilterDoesNothing() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()

        harness.viewModel.updateFilter(.allPosts)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(harness.log.listeners.count == 1)
    }

    @Test func aSnapshotFromTheOldListenerIsNotApplied() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()
        harness.send([TestData.post(id: "first")])
        await waitUntil { harness.ids == ["first"] }

        // Already on its way to the view model when the filter changes.
        harness.send([TestData.post(id: "late", author: TestData.jordan)])
        harness.viewModel.updateFilter(.myPosts)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(harness.ids.isEmpty)
    }

    // MARK: - Listener errors

    @Test func listenerErrorReportsFailedAndReloadStartsANewListener() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()
        harness.log.current.continuation.finish(throwing: PostError.unknown)
        await waitUntil { harness.viewModel.status == .failed }

        harness.viewModel.reload()

        #expect(harness.viewModel.status == .loading)
        await waitUntil { harness.log.listeners.count == 2 }
        harness.send([TestData.post(id: "w")])
        await waitUntil { harness.ids == ["w"] }
        #expect(harness.viewModel.status == .loaded)
    }

    // MARK: - Deleting

    @Test func deleteSendsThePostIDToTheRepository() async throws {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()

        try await harness.viewModel.delete(postID: "p1")

        #expect(await harness.repository.deletedPostIDs == ["p1"])
    }

    @Test func rejectedDeleteIsThrownToTheCaller() async {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()
        await harness.repository.setDeleteError(.rejected)

        await #expect(throws: PostError.rejected) {
            try await harness.viewModel.delete(postID: "p1")
        }
    }

    @Test func deletingAFailedPostRemovesItWithoutTheRepository() async throws {
        let harness = Harness(createBehavior: .fail(.rejected))
        await harness.start()
        let id = await harness.postAndWait()
        await waitUntil { harness.statuses == [.failed] }

        try await harness.viewModel.delete(postID: id)

        #expect(harness.ids.isEmpty)
        #expect(await harness.repository.deletedPostIDs.isEmpty)
    }

    @Test func nothingIsDeletedAfterSignOut() async throws {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()
        try await harness.viewModel.signOut()

        try await harness.viewModel.delete(postID: "p1")

        #expect(await harness.repository.deletedPostIDs.isEmpty)
    }

    // MARK: - Signing out

    @Test func signOutEndsTheListenerThenClearsLocalDataThenSignsOut() async throws {
        let harness = Harness(createBehavior: .succeed)
        await harness.start()

        try await harness.viewModel.signOut()

        #expect(harness.log.signOutSteps == ["clear after listener ended", "sign out"])
    }

    @Test func signOutTerminatesTheListenerAndClearsEverything() async throws {
        let harness = Harness(createBehavior: .fail(.rejected))
        await harness.start()
        harness.send([TestData.post(id: "w")])
        _ = await harness.postAndWait()
        await waitUntil { harness.ids.count == 2 }

        try await harness.viewModel.signOut()

        #expect(harness.ids.isEmpty)
        #expect(isTerminated(harness.log.current.continuation))
    }

    @Test func nothingIsAppliedOrSentAfterSignOut() async throws {
        let harness = Harness(createBehavior: .suspend)
        await harness.start()
        let id = await harness.postAndWait()
        harness.send([TestData.post(id: "first")])
        await waitUntil { harness.ids == ["first"] }

        // Already on its way to the view model when sign-out starts.
        harness.send([TestData.post(id: "late")])
        try await harness.viewModel.signOut()
        await harness.repository.finishSuspendedCreate(id: id, with: .failure(.rejected))
        try? await Task.sleep(for: .milliseconds(50))

        #expect(harness.ids.isEmpty)
        #expect(!harness.viewModel.post("After stop"))
        harness.viewModel.updateFilter(.myPosts)
        harness.viewModel.reload()
        #expect(harness.log.listeners.count == 1)
    }
}

/// Whether the consumer of this stream has gone away.
@MainActor
private func isTerminated(_ continuation: AsyncThrowingStream<PostSnapshot, any Error>.Continuation) -> Bool {
    if case .terminated = continuation.yield(PostSnapshot(posts: [], isFromCache: true)) {
        return true
    }
    return false
}

/// Waits for asynchronous delivery into the view model, failing the test if it never happens.
@MainActor
private func waitUntil(
    _ condition: @MainActor () async -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    for _ in 0..<400 {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Condition was never met", sourceLocation: sourceLocation)
}
