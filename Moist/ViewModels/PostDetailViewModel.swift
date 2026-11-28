//
//  PostDetailViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class PostDetailViewModel: ObservableObject {

    // MARK: - Data

    @Published private(set) var post: Post?
    @Published private(set) var viewerId: UUID?

    @Published private(set) var likeCount = 0
    @Published private(set) var isLiked = false
    @Published private(set) var comments: [PostComment] = []
    
    // MARK: - Comment Pagination

    @Published private(set) var hasMoreComments = false
    @Published private(set) var isLoadingMoreComments = false

    @Published private(set)
    var commentsPaginationErrorMessage: String?

    private var nextCommentsCursor: RawdeaPageCursor?

    // MARK: - Loading State

    @Published private(set) var isLoading = false
    @Published private(set) var isUpdatingLike = false
    @Published private(set) var isSubmittingComment = false
    @Published private(set) var isEditingComment = false
    @Published private(set) var isDeletingComment = false

    // MARK: - Errors

    @Published private(set) var errorMessage: String?
    @Published private(set) var actionErrorMessage: String?

    @Published private(set) var isChoosingBestReply = false
    @Published private(set) var likedCommentIds: Set<UUID> = []
    @Published private(set) var likingCommentId: UUID?

    private let service: PostEngagementService
    private let postService: PostService

    init(
        service: PostEngagementService =
            PostEngagementService(),
        postService: PostService = PostService()
    ) {
        self.service = service
        self.postService = postService
    }

    /// A chosen answer can be invisible, for example after a block.
    /// The question then reads as open and can be answered again.
    /// With more pages to load, the answer may still be coming.
    nonisolated static func shownBestReply(
        _ best: UUID?,
        loaded: [UUID],
        hasMore: Bool
    ) -> UUID? {
        guard let best, hasMore || loaded.contains(best) else { return nil }
        return best
    }

    var shownBestReplyId: UUID? {
        Self.shownBestReply(
            post?.bestReplyId,
            loaded: comments.map(\.id),
            hasMore: hasMoreComments
        )
    }

    /// The best answer first, when it has been loaded.
    var orderedComments: [PostComment] {
        guard let bestId = post?.bestReplyId,
              let best = comments.first(where: { $0.id == bestId }) else {
            return comments
        }
        return [best] + comments.filter { $0.id != bestId }
    }

    // MARK: - Answer Likes

    func loadCommentLikes() async {
        // Hearts stay empty if this fails; counts still show.
        if let liked = try? await service
            .fetchLikedCommentIds(comments.map(\.id)) {
            likedCommentIds = liked
        }
    }

    // The count moves only after the server accepts the change.
    func toggleCommentLike(_ commentId: UUID) async {

        guard likingCommentId == nil else { return }

        likingCommentId = commentId
        actionErrorMessage = nil
        defer { likingCommentId = nil }

        let liked = !likedCommentIds.contains(commentId)

        do {
            try await service.setCommentLiked(liked, commentId: commentId)

            if liked {
                likedCommentIds.insert(commentId)
            } else {
                likedCommentIds.remove(commentId)
            }

            if let index = comments.firstIndex(where: { $0.id == commentId }) {
                let count = comments[index].likeCount + (liked ? 1 : -1)
                comments[index].likes = [PostCount(count: max(0, count))]
            }
        } catch {
            actionErrorMessage = "Couldn't update that like. Try again."
        }
    }

    // MARK: - Best Answer

    /// Pass nil to reopen the question. Nothing changes on screen
    /// until the server accepts the choice.
    func chooseBestReply(_ commentId: UUID?) async {

        guard let post,
              !isLoading,
              !isChoosingBestReply else {
            return
        }

        isChoosingBestReply = true
        actionErrorMessage = nil

        defer {
            isChoosingBestReply = false
        }

        do {
            // The asker chooses directly; the Project owner
            // goes through the server.
            if viewerId == post.userId {
                try await postService.setBestReply(
                    postId: post.id,
                    commentId: commentId
                )
            } else {
                try await CollaborationService().setBestReplyAsOwner(
                    postId: post.id,
                    commentId: commentId
                )
            }
            self.post?.bestReplyId = commentId

        } catch is CancellationError {
            return

        } catch {
            actionErrorMessage = "Couldn't update the best answer. Try again."
        }
    }

    // MARK: - Load

    func loadPost(postId: UUID) async {

        guard !isLoading,
              !isLoadingMoreComments,
              !isUpdatingLike,
              !isSubmittingComment,
              !isEditingComment,
              !isDeletingComment else {
            return
        }

        isLoading = true
        errorMessage = nil
        actionErrorMessage = nil
        commentsPaginationErrorMessage = nil
        
        
        // Hide previously loaded discussion data while
        // the database checks current visibility.

        post = nil
        viewerId = nil

        comments = []
        likeCount = 0
        isLiked = false

        nextCommentsCursor = nil
        hasMoreComments = false


        defer {
            isLoading = false
        }

        do {
            let snapshot = try await service
                .fetchDiscussion(postId: postId)

            try Task.checkCancellation()

            post = snapshot.post
            viewerId = snapshot.viewerId

            likeCount = snapshot.likeCount
            isLiked = snapshot.isLiked
            comments = snapshot.comments
            nextCommentsCursor = snapshot.commentsCursor
            hasMoreComments = snapshot.hasMoreComments

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            // Do not keep showing an old post
            // if a fresh visibility check fails.

            post = nil
            viewerId = nil
            comments = []
            likeCount = 0
            isLiked = false
            nextCommentsCursor = nil
            hasMoreComments = false
            commentsPaginationErrorMessage = nil

            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Load More Comments

    func loadMoreComments(postId: UUID) async {

        guard post?.id == postId,
              hasMoreComments,
              !isLoading,
              !isLoadingMoreComments,
              !isSubmittingComment,
              !isEditingComment,
              !isDeletingComment,
              let cursor = nextCommentsCursor else {
            return
        }

        isLoadingMoreComments = true
        commentsPaginationErrorMessage = nil

        defer {
            isLoadingMoreComments = false
        }

        do {

            let page = try await service.fetchCommentsPage(
                postId: postId,
                before: cursor
            )

            try Task.checkCancellation()

            // Prevent duplicate comments
            // across pagination boundaries.

            let existingIDs = Set(
                comments.map(\.id)
            )

            comments.append(
                contentsOf: page.items.filter {
                    !existingIDs.contains($0.id)
                }
            )

            nextCommentsCursor = page.nextCursor
            hasMoreComments = page.hasMore

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            commentsPaginationErrorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Like / Unlike

    func toggleLike(postId: UUID) async {

        guard post?.id == postId,
              !isLoading,
              !isUpdatingLike else {
            return
        }

        isUpdatingLike = true
        actionErrorMessage = nil

        defer {
            isUpdatingLike = false
        }

        do {
            let previouslyLiked = isLiked

            if previouslyLiked {
                try await service.unlike(postId: postId)
            } else {
                try await service.like(postId: postId)
            }

            isLiked = !previouslyLiked

            likeCount = max(
                0,
                likeCount + (previouslyLiked ? -1 : 1)
            )

        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Add Comment

    func addComment(
        postId: UUID,
        content: String
    ) async -> Bool {

        guard post?.id == postId,
              !isLoading,
              !isSubmittingComment else {
            return false
        }

        isSubmittingComment = true
        actionErrorMessage = nil

        defer {
            isSubmittingComment = false
        }

        do {
            let comment = try await service.addComment(
                postId: postId,
                content: content
            )

            // New comments appear at the top.
            // Older loaded pages remain intact.

            comments.insert(comment, at: 0)

            return true

        } catch {
            actionErrorMessage = PublicationErrorMessage.from(error)
            return false
        }
    }

    // MARK: - Edit Comment

    func editComment(
        commentId: UUID,
        content: String
    ) async -> Bool {

        guard !isEditingComment,
              !isLoading,
              let viewerId,
              let existing = comments.first(
                where: { $0.id == commentId }
              ),
              existing.userId == viewerId else {
            return false
        }

        isEditingComment = true
        actionErrorMessage = nil

        defer {
            isEditingComment = false
        }

        do {
            let updated = try await service.updateComment(
                commentId: commentId,
                content: content
            )

            if let index = comments.firstIndex(
                where: { $0.id == commentId }
            ) {
                comments[index] = updated
            }

            return true

        } catch {
            actionErrorMessage = PublicationErrorMessage.from(error)
            return false
        }
    }

    // MARK: - Delete Comment

    func deleteComment(commentId: UUID) async {

        guard !isDeletingComment,
              !isLoading,
              let viewerId,
              let existing = comments.first(
                where: { $0.id == commentId }
              ),
              existing.userId == viewerId else {
            return
        }

        isDeletingComment = true
        actionErrorMessage = nil

        defer {
            isDeletingComment = false
        }

        do {
            try await service.deleteComment(
                commentId: commentId
            )

            comments.removeAll {
                $0.id == commentId
            }

            // The database cleared it; the question is open again.
            if post?.bestReplyId == commentId {
                post?.bestReplyId = nil
            }

        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func clearActionError() {
        actionErrorMessage = nil
    }
}
