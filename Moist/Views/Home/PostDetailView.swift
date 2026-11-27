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

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.rawdeaOpenPostRoute)
    private var openPostRoute

    @State private var likePop = 0

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

    private var commentCharacterCount: Int {

        RawdeaTextLength.count(commentDraft)
    }

    private var editCharacterCount: Int {

        RawdeaTextLength.count(editDraft)
    }
    
    private var canSendComment: Bool {

        !trimmedComment.isEmpty &&
        commentCharacterCount <= 500 &&
        !viewModel.isSubmittingComment &&
        !viewModel.isLoading
    }

    // MARK: - Body

    var body: some View {

        Group {

            if let post = viewModel.post {

                ScrollViewReader { proxy in

                    // A question has its answer field in the page.
                    discussionList(post: post, scrollProxy: proxy)
                        .safeAreaInset(
                            edge: .bottom,
                            spacing: 0
                        ) {

                            if post.kind != .question {
                                commentComposer(
                                    scrollProxy: proxy
                                )
                            }
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

                RawdeaLoadingIndicator("Loading discussion...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .background(
            RawdeaPalette.canvas.ignoresSafeArea()
        )
        .navigationTitle(viewModel.post?.kind == .question ? "Question" : "Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let post = viewModel.post,
               post.kind == .question,
               let viewerId = viewModel.viewerId,
               viewerId != post.userId {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report Post", systemImage: "flag") {
                            reportTarget = .post(post.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Post options")
                }
            }
        }

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
        post: Post,
        scrollProxy: ScrollViewProxy
    ) -> some View {

        List {

            // The original post and actions
            // form one continuous reading area.
            VStack(spacing: 0) {

                if post.kind == .question {

                    questionHeader(post)

                    questionStatus(post)
                        .padding(.horizontal, RawdeaSpacing.screenInset)
                        .padding(.bottom, RawdeaSpacing.sm)

                    Divider()
                        .overlay(RawdeaPalette.divider)
                        .padding(.horizontal, RawdeaSpacing.md)

                } else {

                    PostRowView(
                        post: post,
                        currentUserId: viewModel.viewerId,
                        showsDiscussionLink: false
                    )
                }

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

                if post.kind == .question {
                    commentComposer(scrollProxy: scrollProxy)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(RawdeaPalette.canvas)
            .id("original-post")

            Text(post.kind == .question ? "Answers" : "Comments")
                .font(RawdeaTypography.sectionTitle)
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .accessibilityAddTraits(.isHeader)
                .padding(.vertical, RawdeaSpacing.xs)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)

            if viewModel.comments.isEmpty {

                Text(post.kind == .question
                     ? "No answers yet."
                     : "No comments yet. Start the discussion.")
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .padding(.vertical, RawdeaSpacing.md)
                    .listRowSeparator(.hidden)
                    .listRowBackground(RawdeaPalette.canvas)

            } else {

                ForEach(viewModel.orderedComments) { comment in

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

                        RawdeaLoadingIndicator(
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
        .rawdeaRefreshable {

            // Loading removes this List, which would cancel
            // the refresh and leave the spinner forever. An
            // unstructured task is allowed to finish.
            await Task {

                await viewModel.loadPost(
                    postId: postId
                )

                await bookmarkViewModel.load(
                    postId: postId
                )
            }.value
        }
    }

    // MARK: - Quiet Like / Comment / Save actions

    private var discussionActions: some View {

        HStack(spacing: RawdeaSpacing.xs) {

            Button {

                Task {

                    let wasLiked = viewModel.isLiked

                    await viewModel.toggleLike(
                        postId: postId
                    )

                    // Celebrate only a like the server accepted.
                    if !wasLiked,
                       viewModel.isLiked,
                       viewModel.actionErrorMessage == nil {
                        likePop += 1
                    }
                }

            } label: {

                HStack(spacing: RawdeaSpacing.xs) {

                    ZStack {

                        // Stays in place while loading so the
                        // like bounce has a view to animate.
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
                        .font(.body)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .symbolEffect(.bounce, value: likePop)
                        .symbolEffectsRemoved(reduceMotion)
                        .opacity(viewModel.isUpdatingLike ? 0 : 1)
                        .animation(
                            reduceMotion ? .easeInOut(duration: 0.2) : nil,
                            value: viewModel.isUpdatingLike
                        )

                        if viewModel.isUpdatingLike {

                            ProgressView()
                                .accessibilityHidden(true)
                        }
                    }

                    // A zero count adds noise, so it only
                    // appears once someone has liked the post.
                    if viewModel.likeCount > 0 {
                        Text("\(viewModel.likeCount)")
                            .font(
                                RawdeaTypography.metadata
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                    }
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
                viewModel.likeCount == 1
                ? "1 like"
                : "\(viewModel.likeCount) likes"
            )
            .accessibilityAddTraits(
                viewModel.isLiked ? .isSelected : []
            )
            .sensoryFeedback(.impact(weight: .light), trigger: likePop)

            Button {

                isCommentFocused = true

            } label: {

                Image(systemName: "bubble.left")
                    .font(.body)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
            .accessibilityLabel(viewModel.post?.kind == .question ? "Add an answer" : "Write a comment")

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
                        .font(.body)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(
                            bookmarkViewModel.isBookmarked
                            ? RawdeaPalette.primaryText
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
        // Line the outer symbols up with the post text.
        .padding(.horizontal, RawdeaSpacing.screenInset - RawdeaSpacing.sm)
        .padding(.bottom, RawdeaSpacing.xxs)
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
                    viewModel.post?.kind == .question
                        ? "Add an answer..."
                        : "Write a comment...",
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
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                .background(
                    RawdeaPalette.surface,
                    in: RoundedRectangle(
                        cornerRadius:
                            RawdeaSpacing.lg
                    )
                )
                // The padding around the text focuses it too.
                .contentShape(Rectangle())
                .onTapGesture {
                    isCommentFocused = true
                }
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
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
                        ? RawdeaPalette.onPrimaryFill
                        : RawdeaPalette.secondaryText
                    )
                    .background(
                        canSendComment
                        ? RawdeaPalette.primaryFill
                        : RawdeaPalette.divider,
                        in: Circle()
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

            RawdeaCharacterLimitText(
                count: commentCharacterCount,
                limit: 500,
                threshold: 50
            )
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

    // Comments hang from one line, like replies in a thread.
    private func commentRow(
        _ comment: PostComment
    ) -> some View {

        let usesColumn = !dynamicTypeSize.isAccessibilitySize
        let continuesThread = usesColumn &&
            viewModel.post?.kind != .question &&
            comment.id != viewModel.orderedComments.last?.id

        return VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xxs
        ) {

            HStack(
                alignment: .top,
                spacing: RawdeaSpacing.sm
            ) {

                // A second way into the profile with a full-size
                // target. A tap gesture keeps it out of VoiceOver.
                RawdeaInitialAvatar(
                    name: commentAuthorName(comment),
                    size: RawdeaSpacing.avatarColumn
                )
                .frame(
                    width: RawdeaSpacing.minimumTouchTarget,
                    height: RawdeaSpacing.minimumTouchTarget
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    openPostRoute?(.author(comment.userId))
                }
                .padding(-(RawdeaSpacing.minimumTouchTarget - RawdeaSpacing.avatarColumn) / 2)
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xxs
                ) {

                    commentHeader(comment)

                    if usesColumn {
                        commentBody(comment)
                    }
                }
            }

            // Large text needs the width beside the avatar too.
            if !usesColumn {
                commentBody(comment)
            }

            bestAnswerControl(comment)
                .padding(.leading, usesColumn
                    ? RawdeaSpacing.avatarColumn + RawdeaSpacing.sm
                    : 0)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: RawdeaSpacing.avatarColumn,
            alignment: .topLeading
        )
        .padding(.vertical, RawdeaSpacing.sm)
        .overlay(alignment: .topLeading) {

            if continuesThread {

                Rectangle()
                    .fill(RawdeaPalette.activityOutline)
                    .frame(width: 2)
                    .padding(
                        .top,
                        RawdeaSpacing.sm + RawdeaSpacing.avatarColumn + RawdeaSpacing.xxs
                    )
                    .padding(.leading, RawdeaSpacing.avatarColumn / 2 - 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Question

    private func questionHeader(_ post: Post) -> some View {

        let name = post.project?.name ?? "Project"
        let author = post.author?.username ?? "unknown"
        let date = post.createdAt.formatted(.dateTime.day().month(.abbreviated))
        let stage = post.project?.stage?.title

        return VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {

            Button {
                if let projectId = post.projectId {
                    openPostRoute?(.project(projectId))
                }
            } label: {
                HStack(spacing: RawdeaSpacing.sm) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        RawdeaProjectAvatar(name: name)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name)
                            .font(RawdeaTypography.authorName)
                            .foregroundStyle(RawdeaPalette.primaryText)
                        Text([author, stage, date].compactMap { $0 }.joined(separator: " · "))
                            .font(RawdeaTypography.secondary)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens Project")

            Text(post.content)
                .font(.body)
                .foregroundStyle(RawdeaPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.top, RawdeaSpacing.sm)
        .padding(.bottom, RawdeaSpacing.sm)
    }

    private func questionStatus(_ post: Post) -> some View {

        let isAnswered = post.bestReplyId != nil
        let count = max(post.replyCount, viewModel.comments.count)
        let counted = count == 1 ? "1 answer" : "\(count) answers"
        let isAuthor = viewModel.viewerId == post.userId
        let author = post.author?.username ?? "the author"
        let note = isAnswered
            ? "Best answer chosen by \(isAuthor ? "you" : author)"
            : isAuthor ? "Pick the best answer" : "Waiting for \(author) to pick one"

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.xxs))
            : AnyLayout(HStackLayout(spacing: RawdeaSpacing.xs))

        return layout {
            HStack(spacing: RawdeaSpacing.xs) {
                if isAnswered {
                    Image(systemName: "checkmark")
                } else {
                    Circle()
                        .fill(RawdeaPalette.accent)
                        .frame(width: RawdeaSpacing.xs, height: RawdeaSpacing.xs)
                }
                Text("\(isAnswered ? "Answered" : "Open") · \(counted)")
            }
            .font(RawdeaTypography.authorName)
            .foregroundStyle(RawdeaPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(note)
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
        }
        .padding(RawdeaSpacing.sm)
        .background(
            RawdeaPalette.surface,
            in: RoundedRectangle(cornerRadius: RawdeaSpacing.cardRadius)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func bestAnswerControl(_ comment: PostComment) -> some View {

        if let post = viewModel.post, post.kind == .question {

            let isBest = post.bestReplyId == comment.id
            let isAuthor = viewModel.viewerId == post.userId

            if isBest {
                Text("\(Image(systemName: "checkmark")) Best answer")
                    .font(RawdeaTypography.metadata.weight(.semibold))
                    .foregroundStyle(RawdeaPalette.primaryText)
            }

            if isAuthor && (isBest || post.bestReplyId == nil) {
                Button {
                    Task {
                        await viewModel.chooseBestReply(isBest ? nil : comment.id)
                    }
                } label: {
                    Text(isBest ? "Remove choice" : "Mark as best")
                        .font(isBest
                            ? RawdeaTypography.metadata
                            : RawdeaTypography.secondary.weight(.semibold))
                        .foregroundStyle(isBest
                            ? RawdeaPalette.secondaryText
                            : RawdeaPalette.onAccent)
                        .padding(.horizontal, isBest ? 0 : RawdeaSpacing.sm)
                        .padding(.vertical, RawdeaSpacing.xs)
                        .background(
                            isBest ? Color.clear : RawdeaPalette.accent,
                            in: RoundedRectangle(cornerRadius: RawdeaSpacing.xs)
                        )
                        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isChoosingBestReply)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func commentHeader(
        _ comment: PostComment
    ) -> some View {

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xs))

        return HStack(alignment: .top, spacing: RawdeaSpacing.xs) {

            authorControl(comment.userId) {

                layout {

                    Text(commentAuthorName(comment))
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.primaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(PostRowView.relativeAge(of: comment.createdAt, at: context.date))
                            .font(RawdeaTypography.metadata)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                }
                .padding(.top, RawdeaSpacing.sm)
                .contentShape(Rectangle())
                .padding(.top, -RawdeaSpacing.sm)
            }
            .accessibilityLabel(
                "View profile for \(commentAuthorName(comment))"
            )
            .accessibilityValue(Text(comment.createdAt, style: .relative))
            .frame(maxWidth: .infinity, alignment: .leading)

            if let viewerId = viewModel.viewerId {

                // Keeps a 44 pt target without making
                // the name row taller.
                Group {

                    if viewerId == comment.userId {

                        ownCommentMenu(comment)

                    } else {

                        reportCommentMenu(comment)
                    }
                }
                .padding(.vertical, -RawdeaSpacing.sm)
                .padding(.trailing, -RawdeaSpacing.sm)
            }
        }
    }

    // A button rather than a List link, which would add a chevron
    // and make the whole row open the profile.
    @ViewBuilder
    private func authorControl<LabelContent: View>(
        _ userId: UUID,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {

        if let openPostRoute {

            Button {
                openPostRoute(.author(userId))
            } label: {
                label()
            }
            .buttonStyle(.plain)

        } else {

            NavigationLink(value: RawdeaPostRoute.author(userId)) {
                label()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func commentBody(
        _ comment: PostComment
    ) -> some View {

        // MARK: Inline editing

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
                .buttonStyle(.borderless)
                .disabled(
                    viewModel.isEditingComment
                )

                Spacer(minLength: 0)

                RawdeaCharacterLimitText(
                    count: editCharacterCount,
                    limit: 500,
                    threshold: 50
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
                    editCharacterCount > 500 ||
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
            .font(.body)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
