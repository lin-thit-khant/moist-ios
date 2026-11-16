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

    private var trimmedDraft: String {
        commentDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var trimmedEditDraft: String {
        editDraft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var body: some View {

        Group {

            if let post = viewModel.post {

                discussionContent(post: post)

            } else if let error = viewModel.errorMessage {

                VStack(spacing: 16) {

                    ContentUnavailableView(
                        "Post Unavailable",
                        systemImage: "exclamationmark.circle",
                        description: Text(error)
                    )

                    Button("Try Again") {
                        Task {
                            await viewModel.loadPost(
                                postId: postId
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

            } else {

                ProgressView("Loading discussion...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .navigationTitle("Discussion")
        .navigationBarTitleDisplayMode(.inline)

        .task(id: postId) {
            await viewModel.loadPost(postId: postId)
        }
        .task(id: postId) {
            await bookmarkViewModel.load(
                postId: postId
            )
        }

        // MARK: - Action Error

        .alert(
            "Couldn't complete action",
            isPresented: Binding(
                get: {
                    viewModel.actionErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearActionError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {
                viewModel.clearActionError()
            }

        } message: {

            Text(
                viewModel.actionErrorMessage ?? ""
            )
        }

        // MARK: - Comment Deletion Confirmation

        .confirmationDialog(
            "Delete this comment?",
            isPresented: Binding(
                get: {
                    pendingDeletionId != nil
                },
                set: { isPresented in
                    if !isPresented {
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

                guard let commentId = pendingDeletionId else {
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

    // MARK: - Discussion Content

    private func discussionContent(
        post: Post
    ) -> some View {

        List {

            // Existing post rendering.

            Section {

                PostRowView(
                    post: post,
                    currentUserId: viewModel.viewerId,
                    showsDiscussionLink: false
                )
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 0
                    )
                )
            }
            
            // MARK: - Likes and Bookmarks

            Section {

                HStack(spacing: 12) {

                    // Existing Like / Unlike

                    Button {

                        Task {
                            await viewModel.toggleLike(
                                postId: postId
                            )
                        }

                    } label: {

                        HStack(spacing: 6) {

                            if viewModel.isUpdatingLike {

                                ProgressView()

                            } else {

                                Image(
                                    systemName: viewModel.isLiked
                                    ? "heart.fill"
                                    : "heart"
                                )
                            }

                            Text(
                                viewModel.isLiked
                                ? "Unlike"
                                : "Like"
                            )
                        }
                        .foregroundStyle(
                            viewModel.isLiked
                            ? Color.red
                            : Color.primary
                        )
                    }
                    .buttonStyle(.borderless)
                    .disabled(
                        viewModel.isUpdatingLike ||
                        viewModel.isLoading
                    )

                    Text("\(viewModel.likeCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 4)

                    // New Save / Unsave

                    Button {

                        Task {

                            await bookmarkViewModel
                                .toggleBookmark(
                                    postId: postId
                                )
                        }

                    } label: {

                        HStack(spacing: 6) {

                            if bookmarkViewModel.isUpdating ||
                               bookmarkViewModel.isLoading {

                                ProgressView()

                            } else {

                                Image(
                                    systemName:
                                        bookmarkViewModel.isBookmarked
                                        ? "bookmark.fill"
                                        : "bookmark"
                                )
                            }

                            Text(
                                bookmarkViewModel.isBookmarked
                                ? "Saved"
                                : "Save"
                            )
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .disabled(
                        !bookmarkViewModel.hasLoaded ||
                        bookmarkViewModel.isLoading ||
                        bookmarkViewModel.isUpdating
                    )
                }
            }

            // Show errors without replacing the existing
            // like/comment alerts.

            if let bookmarkError = bookmarkViewModel.errorMessage {

                Section {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text(bookmarkError)
                            .font(.caption)
                            .foregroundStyle(.red)

                        Button("Retry Bookmark") {

                            Task {

                                await bookmarkViewModel.load(
                                    postId: postId
                                )
                            }
                        }
                        .font(.caption)
                    }
                }
            }


            // MARK: - Comment Composer

            Section("Write a Comment") {

                TextField(
                    "Share your thoughts...",
                    text: $commentDraft,
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(viewModel.isSubmittingComment)

                HStack {

                    Text("\(commentDraft.count)/500")
                        .font(.caption)
                        .foregroundStyle(
                            commentDraft.count > 500
                            ? Color.red
                            : Color.secondary
                        )

                    Spacer()

                    Button {

                        Task {

                            let success = await viewModel
                                .addComment(
                                    postId: postId,
                                    content: commentDraft
                                )

                            if success {
                                commentDraft = ""
                            }
                        }

                    } label: {

                        HStack(spacing: 6) {

                            if viewModel.isSubmittingComment {
                                ProgressView()
                            }

                            Text(
                                viewModel.isSubmittingComment
                                ? "Posting..."
                                : "Post Comment"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        trimmedDraft.isEmpty ||
                        commentDraft.count > 500 ||
                        viewModel.isSubmittingComment ||
                        viewModel.isLoading
                    )
                }
            }

            // MARK: - Comments

            Section("Comments") {

                if viewModel.comments.isEmpty {

                    Text("No comments yet. Start the discussion!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                } else {

                    ForEach(viewModel.comments) { comment in

                        commentRow(comment)
                    }
                    
                    
                    // MARK: - Comment Pagination Error

                    if let error =
                        viewModel.commentsPaginationErrorMessage {

                        VStack(alignment: .leading, spacing: 8) {

                            Label(
                                "Couldn't load more comments",
                                systemImage: "exclamationmark.circle"
                            )
                            .font(.subheadline)

                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    // MARK: - Load More Comments

                    if viewModel.hasMoreComments {

                        HStack {

                            Spacer()

                            if viewModel.isLoadingMoreComments {

                                ProgressView("Loading more comments...")

                            } else {

                                Button("Load More Comments") {

                                    Task {

                                        await viewModel.loadMoreComments(
                                            postId: postId
                                        )
                                    }
                                }
                                .buttonStyle(.bordered)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }

                    
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadPost(
                postId: postId
            )
        }
    }

    // MARK: - Individual Comment

    private func commentRow(
        _ comment: PostComment
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack(alignment: .top, spacing: 10) {

                Image(
                    systemName: "person.crop.circle.fill"
                )
                .font(.title2)
                .foregroundStyle(.secondary)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    NavigationLink {

                        AuthorProfileView(
                            userId: comment.userId
                        )

                    } label: {

                        Text(
                            comment.author?.displayName.isEmpty == false
                            ? (comment.author?.displayName ?? "")
                            : (comment.author?.username ?? "User")
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)

                    Text(
                        comment.createdAt,
                        style: .relative
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Only the comment author
                // sees the edit/delete menu.

                if let viewerId = viewModel.viewerId,
                   viewerId == comment.userId {

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

                        Image(systemName: "ellipsis")
                            .padding(8)
                    }
                }
            }

            // MARK: - Inline Editing

            if editingCommentId == comment.id {

                TextField(
                    "Edit comment",
                    text: $editDraft,
                    axis: .vertical
                )
                .lineLimit(2...5)
                .disabled(viewModel.isEditingComment)

                HStack(spacing: 12) {

                    Button("Cancel") {
                        editingCommentId = nil
                        editDraft = ""
                    }
                    .disabled(viewModel.isEditingComment)

                    Spacer()

                    Text("\(editDraft.count)/500")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Save") {

                        Task {

                            let success = await viewModel
                                .editComment(
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
                        trimmedEditDraft.isEmpty ||
                        editDraft.count > 500 ||
                        trimmedEditDraft == comment.content ||
                        viewModel.isEditingComment
                    )
                }

            } else {

                Text(comment.content)
                    .font(.body)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
        .padding(.vertical, 8)
    }
}
