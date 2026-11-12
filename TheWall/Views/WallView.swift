import SwiftUI

struct WallView: View {
    @State private var viewModel: WallViewModel
    @State private var draft = ""
    @State private var signOutFailed = false
    @State private var deleteFailed = false
    /// The post waiting for the user to confirm its deletion.
    @State private var postIDToDelete: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: WallViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ComposerView(text: $draft, limit: viewModel.maxPostLength) {
                    if viewModel.post(draft) {
                        draft = ""
                    }
                }
                Picker("Show", selection: filterBinding) {
                    Text("Everyone").tag(PostFilter.allPosts)
                    Text("My posts").tag(PostFilter.myPosts)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                Divider()
                posts
            }
            .navigationTitle("Wall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Log Out", action: signOut)
                }
            }
            .alert("Couldn't log out", isPresented: $signOutFailed) {
                Button("Try Again", action: signOut)
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete this post?", isPresented: isConfirmingDelete, presenting: postIDToDelete) { postID in
                Button("Delete", role: .destructive) { delete(postID: postID) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This can't be undone.")
            }
            // The post is already back in the list by now, since Firestore restores it.
            .alert("Couldn't delete post", isPresented: $deleteFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
        }
        .task {
            viewModel.start()
        }
    }

    private func signOut() {
        Task {
            do {
                try await viewModel.signOut()
            } catch {
                print(error)
                signOutFailed = true
            }
        }
    }

    /// Runs here rather than in the row: the row disappears as soon as the delete starts, so
    /// it can't be the one to show a failure.
    private func delete(postID: String) {
        Task {
            do {
                try await viewModel.delete(postID: postID)
            } catch {
                print(error)
                deleteFailed = true
            }
        }
    }
    /// We use this rather than an `isConfirmingDelete` state var to avoid having to track
    /// that AND the `postIDtoDelete` value
    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { postIDToDelete != nil }, set: { if !$0 { postIDToDelete = nil } })
    }

    private var filterBinding: Binding<PostFilter> {
        Binding(get: { viewModel.filter }, set: { viewModel.updateFilter($0) })
    }

    @ViewBuilder
    private var posts: some View {
        let items = viewModel.items
        if items.isEmpty {
            switch viewModel.status {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't load posts", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("Try Again") { viewModel.reload() }
                }
            case .loaded:
                ContentUnavailableView(
                    viewModel.filter == .myPosts ? "You haven't posted yet" : "No posts yet",
                    systemImage: "text.bubble"
                )
            }
        } else {
            if viewModel.status == .failed {
                refreshFailedBanner
            }
            List(items) { item in
                PostRow(item: item, canDelete: item.post.authorID == viewModel.user.id) {
                    viewModel.retry(postID: item.id)
                } onDelete: {
                    postIDToDelete = item.id
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            // Rows slide in and out as posts arrive, fail or are retried, and fade as they
            // finish sending. Without this, each snapshot would replace the list instantly.
            .animation(reduceMotion ? nil : .default, value: items)
        }
    }

    /// Shown above posts already on screen when the listener fails, so they aren't mistaken for
    /// live ones.
    private var refreshFailedBanner: some View {
        HStack {
            Label("Couldn't refresh posts", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Try Again") { viewModel.reload() }
        }
        .font(.footnote)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
