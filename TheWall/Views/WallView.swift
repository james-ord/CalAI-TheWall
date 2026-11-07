import SwiftUI

struct WallView: View {
    @State private var viewModel: WallViewModel
    @State private var draft = ""

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
                    Button("Log Out") {
                        Task { try? await viewModel.signOut() }
                    }
                }
            }
        }
        .task {
            viewModel.start()
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
            List(items) { item in
                PostRow(item: item) {
                    viewModel.retry(postID: item.id)
                }
            }
            .listStyle(.plain)
        }
    }
}
