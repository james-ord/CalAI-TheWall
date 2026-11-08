import SwiftUI

struct WallView: View {
    @State private var viewModel: WallViewModel
    @State private var draft = ""
    @State private var signOutFailed = false
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
                PostRow(item: item) {
                    viewModel.retry(postID: item.id)
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
