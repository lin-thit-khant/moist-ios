//
//  PostDetailView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import SwiftUI

struct PostDetailView: View {

    let postId: UUID

    @StateObject private var viewModel =
        PostDetailViewModel()

    @StateObject private var bookmarkViewModel =
        PostBookmarkViewModel()

    @State private var commentDraft = ""

    @State private var editingCommentId: UUID?
    @State private var editDraft = ""

    @State private var pendingDeletionId: UUID?
    @State private var reportTarget: ReportTarget?

    @FocusState private var isCommentFocused: Bool

    @AccessibilityFocusState
    private var focusedCommentId: UUID?

    @Environment(\.scenePhase)
    private var scenePhase

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    // MARK: - Validation

    private var trimmedComment: String {
        commentDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var trimmedEdit: String {
        editDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var canSendComment: Bool {
        !trimmedComment.isEmpty &&
        commentDraft.count <= 500 &&
        !viewModel.isSubmittingComment &&
        !viewModel.isLoading
    }

    // MARK: - Body

    var body: some View {

        Group {

            if let post = viewModel.post {

                ScrollViewReader { proxy in

                    discussionList(post: post)
                        .safeAreaInset(
                            edge: .bottom,
                            spacing: 0
                        ) {

                            commentComposer(
                                scrollProxy: proxy
                            )
                        }
                }

            } else if let error = viewModel.errorMessage {

                VStack(spacing: RawdeaSpacing.md) {

                    RawdeaEmptyState(
                        symbol:
                            "exclamationmark.circle",
                        title: "Post Unavailable",
                        message: error,
                        actionTitle: "Try Again"
                    ) {

                        Task {
                            await viewModel.loadPost(
                                postId: postId
                            )
                        }
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

            } else {

                ProgressView("Loading discussion...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .background(
            RawdeaPalette.canvas.ignoresSafeArea()
        )
        .navigationTitle("Discussion")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Initial loading

        .task(id: postId) {

            await viewModel.loadPost(
                postId: postId
            )
        }

        .task(id: postId) {

            await bookmarkViewModel.load(
                postId: postId
            )
        }

        // Recheck privacy after returning from
        // a child destination such as a profile.
        .onAppear {

            guard viewModel.post != nil else {
                return
            }

            Task {

                await viewModel.loadPost(
                    postId: postId
                )

                await bookmarkViewModel.load(
                    postId: postId
                )
            }
        }

        .onChange(of: scenePhase) { _, phase in

            guard phase == .active else {
                return
            }

            Task {

                await viewModel.loadPost(
                    postId: postId
                )

                await bookmarkViewModel.load(
                    postId: postId
                )
            }
        }

        // MARK: - Reporting

        .sheet(item: $reportTarget) { target in

            ReportContentView(target: target)
        }

        // MARK: - Delete comment confirmation

        .confirmationDialog(
            "Delete this comment?",
            isPresented: Binding(
                get: {
                    pendingDeletionId != nil
                },
                set: { presented in

                    if !presented {
                        pendingDeletionId = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {

            Button(
                "Delete Comment",
                role: .destructive
            ) {

                guard let commentId =
                    pendingDeletionId else {
                    return
                }

                pendingDeletionId = nil

                Task {

                    await viewModel.deleteComment(
                        commentId: commentId
                    )
                }
            }

            Button("Cancel", role: .cancel) {
                pendingDeletionId = nil
            }
        }
    }

    // MARK: - Discussion list

    private func discussionList(
        post: Post
    ) -> some View {

        List {

            // The original post and actions
            // form one continuous reading area.
            VStack(spacing: 0) {

                PostRowView(
                    post: post,
                    currentUserId: viewModel.viewerId,
                    showsDiscussionLink: false
                )

                discussionActions

                if let bookmarkError =
                    bookmarkViewModel.errorMessage {

                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xs
                    ) {

                        RawdeaInlineError(
                            message: bookmarkError
                        )

                        Button("Retry bookmark status") {

                            Task {

                                await bookmarkViewModel.load(
                                    postId: postId
                                )
                            }
                        }
                        .font(RawdeaTypography.metadata)
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }
                    .padding(.horizontal, RawdeaSpacing.md)
                    .padding(.bottom, RawdeaSpacing.sm)
                }

                Divider()
                    .overlay(RawdeaPalette.divider)
                    .padding(.horizontal, RawdeaSpacing.md)
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(RawdeaPalette.canvas)
            .id("original-post")

            Text("Comments")
                .font(RawdeaTypography.sectionTitle)
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .accessibilityAddTraits(.isHeader)
                .padding(.vertical, RawdeaSpacing.xs)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)

            if viewModel.comments.isEmpty {

                Text("No comments yet. Start the discussion.")
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .padding(.vertical, RawdeaSpacing.md)
                    .listRowSeparator(.hidden)
                    .listRowBackground(RawdeaPalette.canvas)

            } else {

                ForEach(viewModel.comments) { comment in

                    commentRow(comment)
                        .id(comment.id)
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading:
                                    RawdeaSpacing.screenInset,
                                bottom: 0,
                                trailing:
                                    RawdeaSpacing.screenInset
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(
                            RawdeaPalette.canvas
                        )
                }
            }

            // MARK: - Pagination error

            if let error =
                viewModel.commentsPaginationErrorMessage {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    RawdeaInlineError(
                        message: "Couldn't load more comments. \(error)"
                    )

                    Button("Retry loading comments") {

                        Task {

                            await viewModel.loadMoreComments(
                                postId: postId
                            )
                        }
                    }
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }
                .padding(.vertical, RawdeaSpacing.sm)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)
            }

            // MARK: - Load more

            if viewModel.hasMoreComments {

                HStack {

                    Spacer(minLength: 0)

                    if viewModel.isLoadingMoreComments {

                        ProgressView(
                            "Loading more comments..."
                        )

                    } else {

                        Button("Load More Comments") {

                            Task {

                                await viewModel.loadMoreComments(
                                    postId: postId
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, RawdeaSpacing.sm)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .scrollDismissesKeyboard(.interactively)

        // Preserve existing privacy revalidation
        // when the user refreshes Discussion.
        .refreshable {

            await viewModel.loadPost(
                postId: postId
            )

            await bookmarkViewModel.load(
                postId: postId
            )
        }
    }

    // MARK: - Quiet Like / Comment / Save actions

    private var discussionActions: some View {

        HStack(spacing: RawdeaSpacing.xs) {

            Button {

                Task {

                    await viewModel.toggleLike(
                        postId: postId
                    )
                }

            } label: {

                HStack(spacing: RawdeaSpacing.xs) {

                    if viewModel.isUpdatingLike {

                        ProgressView()
                            .accessibilityHidden(true)

                    } else {

                        Image(
                            systemName:
                                viewModel.isLiked
                                ? "heart.fill"
                                : "heart"
                        )
                        .foregroundStyle(
                            viewModel.isLiked
                            ? RawdeaPalette.accent
                            : RawdeaPalette.secondaryText
                        )
                    }

                    Text("\(viewModel.likeCount)")
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                }
                .frame(
                    minWidth:
                        RawdeaSpacing.minimumTouchTarget,
                    minHeight:
                        RawdeaSpacing.minimumTouchTarget
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(
                viewModel.isUpdatingLike ||
                viewModel.isLoading
            )
            .accessibilityLabel(
                viewModel.isLiked
                ? "Unlike post"
                : "Like post"
            )
            .accessibilityValue(
                "\(viewModel.likeCount) likes"
            )
            .accessibilityAddTraits(
                viewModel.isLiked ? .isSelected : []
            )

            Button {

                isCommentFocused = true

            } label: {

                Image(systemName: "bubble.left")
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .frame(
                        width:
                            RawdeaSpacing.minimumTouchTarget,
                        height:
                            RawdeaSpacing.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Write a comment")

            Spacer(minLength: 0)

            Button {

                Task {

                    await bookmarkViewModel
                        .toggleBookmark(
                            postId: postId
                        )
                }

            } label: {

                Group {

                    if bookmarkViewModel.isUpdating ||
                       bookmarkViewModel.isLoading {

                        ProgressView()
                            .accessibilityHidden(true)

                    } else {

                        Image(
                            systemName:
                                bookmarkViewModel.isBookmarked
                                ? "bookmark.fill"
                                : "bookmark"
                        )
                        .foregroundStyle(
                            bookmarkViewModel.isBookmarked
                            ? RawdeaPalette.accent
                            : RawdeaPalette.secondaryText
                        )
                    }
                }
                .frame(
                    width:
                        RawdeaSpacing.minimumTouchTarget,
                    height:
                        RawdeaSpacing.minimumTouchTarget
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(
                !bookmarkViewModel.hasLoaded ||
                bookmarkViewModel.isUpdating ||
                bookmarkViewModel.isLoading
            )
            .accessibilityLabel(
                bookmarkViewModel.isBookmarked
                ? "Remove saved post"
                : "Save post"
            )
            .accessibilityAddTraits(
                bookmarkViewModel.isBookmarked
                ? .isSelected : []
            )
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.bottom, RawdeaSpacing.sm)
    }

    // MARK: - Bottom-anchored comment composer

    private func commentComposer(
        scrollProxy: ScrollViewProxy
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            if let error = viewModel.actionErrorMessage {

                RawdeaInlineError(message: error)
            }

            HStack(
                alignment: .bottom,
                spacing: RawdeaSpacing.xs
            ) {

                TextField(
                    "Write a comment...",
                    text: $commentDraft,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .focused($isCommentFocused)
                .disabled(
                    viewModel.isSubmittingComment
                )
                .font(RawdeaTypography.body)
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .padding(.horizontal, RawdeaSpacing.sm)
                .padding(.vertical, RawdeaSpacing.xs)
                .background(
                    RawdeaPalette.surface,
                    in: RoundedRectangle(
                        cornerRadius:
                            RawdeaSpacing.buttonRadius
                    )
                )
                .accessibilityLabel("Comment")
                .accessibilityHint(
                    "Write up to 500 characters"
                )

                Button {

                    Task {

                        await sendComment(
                            scrollProxy: scrollProxy
                        )
                    }

                } label: {

                    Group {

                        if viewModel.isSubmittingComment {

                            ProgressView()
                                .tint(
                                    RawdeaPalette.onAccent
                                )
                                .accessibilityHidden(true)

                        } else {

                            Image(
                                systemName: "arrow.up"
                            )
                            .font(
                                .system(
                                    .body,
                                    weight: .semibold
                                )
                            )
                            .accessibilityHidden(true)
                        }
                    }
                    .frame(
                        width:
                            RawdeaSpacing.minimumTouchTarget,
                        height:
                            RawdeaSpacing.minimumTouchTarget
                    )
                    .foregroundStyle(
                        canSendComment
                        ? RawdeaPalette.onAccent
                        : RawdeaPalette.secondaryText
                    )
                    .background(
                        canSendComment
                        ? RawdeaPalette.accent
                        : RawdeaPalette.divider,
                        in: RoundedRectangle(
                            cornerRadius:
                                RawdeaSpacing.buttonRadius
                        )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSendComment)
                .accessibilityLabel(
                    viewModel.isSubmittingComment
                    ? "Sending comment"
                    : "Send comment"
                )
            }

            HStack {

                Text("\(commentDraft.count)/500")
                    .font(RawdeaTypography.caption)
                    .foregroundStyle(
                        commentDraft.count > 500
                        ? RawdeaPalette.danger
                        : RawdeaPalette.secondaryText
                    )
                    .accessibilityLabel(
                        "\(commentDraft.count) of 500 characters"
                    )

                Spacer(minLength: 0)

                if commentDraft.count > 500 {

                    Text("Comment is too long")
                        .font(
                            RawdeaTypography.caption
                        )
                        .foregroundStyle(
                            RawdeaPalette.danger
                        )
                }
            }
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.top, RawdeaSpacing.sm)
        .padding(.bottom, RawdeaSpacing.xs)
        .background {

            RawdeaPalette.canvas
                .ignoresSafeArea(
                    edges: .bottom
                )
        }
        .overlay(alignment: .top) {

            Rectangle()
                .fill(RawdeaPalette.divider)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .onChange(of: commentDraft) { _, _ in

            if viewModel.actionErrorMessage != nil {
                viewModel.clearActionError()
            }
        }
    }

    // MARK: - Send comment

    @MainActor
    private func sendComment(
        scrollProxy: ScrollViewProxy
    ) async {

        guard canSendComment else {
            return
        }

        let submittedText = commentDraft

        let success = await viewModel.addComment(
            postId: postId,
            content: submittedText
        )

        guard success else {
            // Important: preserve the draft.
            return
        }

        // The backend confirmed the new comment.
        commentDraft = ""

        // Approved keyboard behavior.
        isCommentFocused = false

        guard let newestId =
            viewModel.comments.first?.id else {
            return
        }

        // Let SwiftUI insert the new row before
        // requesting its scroll position.
        await Task.yield()

        if reduceMotion {

            scrollProxy.scrollTo(
                newestId,
                anchor: .center
            )

        } else {

            withAnimation(.easeOut(duration: 0.2)) {

                scrollProxy.scrollTo(
                    newestId,
                    anchor: .center
                )
            }
        }

        // Move screen-reader focus to the
        // new comment's content.
        focusedCommentId = newestId
    }

    // MARK: - Comment row

    private func commentRow(
        _ comment: PostComment
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.sm
        ) {

            HStack(
                alignment: .top,
                spacing: RawdeaSpacing.sm
            ) {

                Image(
                    systemName: "person.crop.circle.fill"
                )
                .font(.system(.title2))
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xxs
                ) {

                    
                    NavigationLink(
                        value: RawdeaPostRoute.author(
                            comment.userId
                        )
                    ) {

                        Text(
                            commentAuthorName(comment)
                        )
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .frame(
                            minWidth:
                                RawdeaSpacing.minimumTouchTarget,
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget,
                            alignment: .leading
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "View profile for \(commentAuthorName(comment))"
                    )


                    Text(
                        comment.createdAt,
                        style: .relative
                    )
                    .font(RawdeaTypography.caption)
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                }

                Spacer(minLength: 0)

                if let viewerId = viewModel.viewerId {

                    if viewerId == comment.userId {

                        ownCommentMenu(comment)

                    } else {

                        reportCommentMenu(comment)
                    }
                }
            }

            // MARK: - Inline editing

            if editingCommentId == comment.id {

                TextField(
                    "Edit comment",
                    text: $editDraft,
                    axis: .vertical
                )
                .lineLimit(2...5)
                .font(RawdeaTypography.body)
                .disabled(
                    viewModel.isEditingComment
                )

                HStack(spacing: RawdeaSpacing.sm) {

                    Button("Cancel") {
                        editingCommentId = nil
                        editDraft = ""
                    }
                    .disabled(
                        viewModel.isEditingComment
                    )

                    Spacer(minLength: 0)

                    Text("\(editDraft.count)/500")
                        .font(
                            RawdeaTypography.caption
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )

                    Button("Save") {

                        Task {

                            let success =
                                await viewModel.editComment(
                                    commentId: comment.id,
                                    content: editDraft
                                )

                            if success {
                                editingCommentId = nil
                                editDraft = ""
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        trimmedEdit.isEmpty ||
                        editDraft.count > 500 ||
                        trimmedEdit == comment.content ||
                        viewModel.isEditingComment
                    )
                }

            } else {

                Text(comment.content)
                    .font(RawdeaTypography.postBody)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .accessibilityFocused(
                        $focusedCommentId,
                        equals: comment.id
                    )
            }

            Divider()
                .overlay(RawdeaPalette.divider)
        }
        .padding(.vertical, RawdeaSpacing.sm)
    }

    // MARK: - Author name

    private func commentAuthorName(
        _ comment: PostComment
    ) -> String {

        let name = comment.author?.displayName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        return name.isEmpty
            ? (comment.author?.username ?? "User")
            : name
    }

    // MARK: - Own comment options

    private func ownCommentMenu(
        _ comment: PostComment
    ) -> some View {

        Menu {

            Button {

                editingCommentId = comment.id
                editDraft = comment.content

            } label: {

                Label(
                    "Edit Comment",
                    systemImage: "pencil"
                )
            }

            Button(role: .destructive) {

                pendingDeletionId = comment.id

            } label: {

                Label(
                    "Delete Comment",
                    systemImage: "trash"
                )
            }

        } label: {

            commentOptionsIcon
        }
        .disabled(
            viewModel.isEditingComment ||
            viewModel.isDeletingComment
        )
        .accessibilityLabel("Comment options")
    }

    // MARK: - Report comment

    private func reportCommentMenu(
        _ comment: PostComment
    ) -> some View {

        Menu {

            Button {

                reportTarget = .comment(
                    comment.id
                )

            } label: {

                Label(
                    "Report Comment",
                    systemImage: "flag"
                )
            }

        } label: {

            commentOptionsIcon
        }
        .accessibilityLabel("Comment options")
    }

    private var commentOptionsIcon: some View {

        Image(systemName: "ellipsis")
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .frame(
                width: RawdeaSpacing.minimumTouchTarget,
                height: RawdeaSpacing.minimumTouchTarget
            )
            .contentShape(Rectangle())
    }
}
