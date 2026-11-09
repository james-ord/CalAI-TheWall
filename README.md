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

- **Older posts and "New posts" button:** The query for posts is currently limited to the 100 newest posts. Getting older posts would mean fetching further pages while keeping the listener for new incoming posts. The main tricks are prefetching ahead of reaching the bottom of the list (to keep scrolling smooth), and changing the listener to grow when new posts arrive. When a new post loads the oldest live post would drop from the list unless the listener is fixed to a post rather than a count. When scrolling, new posts would have to be held out of the list until the button is pressed to avoid shifting the list.
- **Offline Status:** Display to the user when the app is offline/Firestore is unreachable
- **Edge-cases:**
  - Warn before logging out with unsent posts since they'll be cleared with the cache
  - Post failure reasons and delete instead of retry when the post will never work. An account with no display name, for example, is rejected on every retry.

## AI notes

I used Claude Code to plan and implement this. The build plan was to do underlying structure first (protocols/models followed by data and logic). Each step was manually reviewed with the AI restricted from creating commits/commit messages.

The most egregious mistake the AI made was when building mocks for unit tests. The initial implementation created a mock server with its own predefined behaviors such as author verification, default userID, and separate 'everyone' and 'myPosts' streams. The AI even created unit tests for the mock itself. I re-routed it to have tests drive mock behaviors rather than mocks defining themselves, and certainly avoid making mocks so heavy that they need their own unit tests.
