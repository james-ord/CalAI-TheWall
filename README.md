# The Wall

A real-time social wall in SwiftUI and Firebase. Sign in with Google, post a message, and see everyone's posts, or just your own, updated live.

## Running the App

Requries a minimum of Xcode 26.0 and iOS 18.0. Open `TheWall.xcodeproj`. The project uses two schemes: `TheWall` and `TheWallTests`. Swift packages will resolve on first build. Run `TheWall` to build the app to device or simulator.

## Tests

Testing uses the Swift Testing library and no third-party dependencies. Use the `TheWallTests` to run unit tests.

**NOTE**
Firebase is pinned to 12.x because 13.x needs Xcode 26.2 and this Macbook is restricted to 26.0. I tested on two iOS simulators because the test phone couldn't verify the developer profile.

## Key decisions and Trade-offs

- **Live post limit updates:** Use an `AsyncStream` for the `max_post_length` value. It seemed overkill at first for fetching a single `Int` value, but updating the value for the client side would require an app restart or log out/login. Fetches are also throttled by default and `fetchAndActivate` would return a cached value within the time limit. Using an `AsyncStream` allowed for live limit updates at the cost of a long-lived task and simplicity.
- **Firestore owns delivery and ordering:** I deferred to Firestore for post ordering and sending updates. This is included in the SDK and attempting to control it in the app would be repeating functionality, with the risk being dependency on the SDK behaving as expected. Local posts also appear on the feed before Firestore has confirmed the server received it in order to match pending post behavior expectations. The post query is updated with `includeMetadataChanges` in order for posts to be updated when the server has received them.
- **Sign-out clears everything:** This includes posts that have are still pending if the user logs out before the post is received by the server. This also means a logout/login cycle starts from cold rather than the previous cache. The benefit is simplicity (not having to track previous user/trusing the cache) of logout and a stronger guarantee against stale data showing up across users.

## What I'd do with more time

- **Paging and a "New posts" button:** the wall listens to the newest 100 posts, so older ones can't be reached. I'd keep one live listener for the newest page and fetch older pages with Firestore cursors (`start(afterDocument:)` and `limit`). While you're scrolled down, new posts would wait behind a "New posts" button. The fiddly part is the moving boundary between the live page and older pages.
- **Offline Status:** Display to the user when the app is offline/Firestore is unreachable
- **Edge-cases:**
  - Warn before logging out with unsent posts since they'll be cleared with the cache
  - Post failure reasons and delete instead of retry when the post will never work. An account with no display name, for example, is rejected on every retry.

## AI notes

I used Claude Code to plan and implement this. The build plan was to do underlying structure first (protocols/models followed by data and logic). Each step was manually reviewed with the AI restricted from creating commits/commit messages.

The most egregious mistake the AI made was when building mocks for unit tests. The initial implementation created a mock server with its own predefined behaviors such as author verification, default userID, and separate 'everyone' and 'myPosts' streams. The AI even created unit tests for the mock itself. I re-routed it to have tests drive mock behaviors rather than mocks defining themselves, and certainly avoid making mocks so heavy that they need their own unit tests.
