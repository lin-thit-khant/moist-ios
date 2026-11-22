//
//  PostRowView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import Supabase
import SwiftUI

struct PostRowView: View {

    let post: Post
    let currentUserId: UUID?

    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onMove: (() -> Void)?
    let onHide: (() -> Void)?

    let showsDiscussionLink: Bool

    @StateObject private var actions =
        PostRowActionsViewModel()

    @State private var resolvedViewerId: UUID?
    @State private var reportTarget: ReportTarget?
    @State private var isShowingDeleteConfirmation = false

    init(
        post: Post,
        currentUserId: UUID? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMove: (() -> Void)? = nil,
        onHide: (() -> Void)? = nil,
        showsDiscussionLink: Bool = true
    ) {
        self.post = post
        self.currentUserId = currentUserId
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onMove = onMove
        self.onHide = onHide
        self.showsDiscussionLink = showsDiscussionLink
    }

    // MARK: - Display values

    private var authorName: String {

        let name = post.author?.displayName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        return name.isEmpty
            ? (post.author?.username ?? "Rawdea User")
            : name
    }

    private var authorHandle: String {

        guard let username = post.author?.username else {
            return "@unknown"
        }

        return "@\(username)"
    }

    private var viewerId: UUID? {
        currentUserId ?? resolvedViewerId
    }

    private var hasOwnerActions: Bool {
        onEdit != nil ||
        onDelete != nil ||
        onMove != nil ||
        onHide != nil
    }

    // MARK: - Body

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.sm
        ) {

            authorHeader

            postContent

            if let project = post.project {
                projectLink(project)
            }

            if post.isHidden,
               viewerId == post.userId {

                Label(
                    "Hidden",
                    systemImage: "eye.slash"
                )
                .font(RawdeaTypography.metadata)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .accessibilityLabel("Hidden post")
            }

            if showsDiscussionLink {

                postActions

                if let error = actions.errorMessage {

                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xs
                    ) {

                        RawdeaInlineError(
                            message: error
                        )

                        Button("Retry post actions") {

                            Task {
                                await actions.load(
                                    postId: post.id
                                )
                            }
                        }
                        .font(RawdeaTypography.metadata)
                        .foregroundStyle(
                            RawdeaPalette.accent
                        )
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }
                }
            }
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.vertical, RawdeaSpacing.md)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(RawdeaPalette.canvas)

        // Load lightweight action state for
        // feed rows, not for the Discussion
        // screen's already-loaded post.
        .task(id: post.id) {

            guard showsDiscussionLink else {
                return
            }

            await actions.load(postId: post.id)
        }

        // Recheck after returning from a
        // Discussion screen so Like and Save
        // states reflect changes made there.
        .onAppear {

            guard showsDiscussionLink,
                  actions.hasLoaded else {
                return
            }

            Task {
                await actions.load(postId: post.id)
            }
        }

        // Resolve the viewer where the caller
        // has not supplied an authenticated ID.
        .task {

            guard currentUserId == nil,
                  resolvedViewerId == nil else {
                return
            }

            if let user = try? await SupabaseManager
                .client
                .auth
                .session
                .user {

                resolvedViewerId = user.id
            }
        }

        .sheet(item: $reportTarget) { target in

            ReportContentView(target: target)
        }

        .confirmationDialog(
            "Delete this post?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Delete",
                role: .destructive
            ) {
                onDelete?()
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            Text("This cannot be undone.")
        }
    }

    // MARK: - Author header

    private var authorHeader: some View {

        HStack(
            alignment: .top,
            spacing: RawdeaSpacing.xs
        ) {

            NavigationLink {

                AuthorProfileView(
                    userId: post.userId
                )

            } label: {

                HStack(
                    alignment: .top,
                    spacing: RawdeaSpacing.sm
                ) {

                    Image(
                        systemName: "person.crop.circle.fill"
                    )
                    .font(.system(size: 40))
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .accessibilityHidden(true)

                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xxs
                    ) {

                        Text(authorName)
                            .font(
                                RawdeaTypography.authorName
                            )
                            .foregroundStyle(
                                RawdeaPalette.primaryText
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                        Text(authorHandle)
                            .font(
                                RawdeaTypography.metadata
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )

                        Text(
                            post.createdAt,
                            style: .relative
                        )
                        .font(RawdeaTypography.caption)
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: RawdeaSpacing.minimumTouchTarget,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "View profile for \(authorName), \(authorHandle)"
            )

            if let viewerId {

                if viewerId == post.userId {

                    if hasOwnerActions {
                        ownerOptions
                    }

                } else {

                    reportingOptions
                }
            }
        }
    }

    // MARK: - Post content

    @ViewBuilder
    private var postContent: some View {

        if showsDiscussionLink {

            NavigationLink {

                PostDetailView(postId: post.id)

            } label: {

                Text(post.content)
                    .font(RawdeaTypography.postBody)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget,
                        alignment: .leading
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Post by \(authorName). \(post.content)"
            )
            .accessibilityHint("Opens Discussion")

        } else {

            Text(post.content)
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
        }
    }

    // MARK: - Project navigation

    private func projectLink(
        _ project: PostProject
    ) -> some View {

        NavigationLink {

            ProjectRouteView(
                projectId: project.id
            )

        } label: {

            HStack(spacing: RawdeaSpacing.xs) {

                Image(systemName: "folder")
                    .accessibilityHidden(true)

                Text(project.name)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
            .font(RawdeaTypography.metadata)
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Open Project \(project.name)"
        )
    }

    // MARK: - Independent post actions

    private var postActions: some View {

        HStack(spacing: RawdeaSpacing.xs) {

            Button {

                Task {
                    await actions.toggleLike(
                        postId: post.id
                    )
                }

            } label: {

                actionSymbol(
                    actions.isLiked
                    ? "heart.fill"
                    : "heart",
                    selected: actions.isLiked,
                    loading: actions.isUpdatingLike
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !actions.hasLoaded ||
                actions.isLoading ||
                actions.isUpdatingLike
            )
            .accessibilityLabel(
                actions.isLiked
                ? "Unlike post"
                : "Like post"
            )
            .accessibilityAddTraits(
                actions.isLiked ? .isSelected : []
            )

            NavigationLink {

                PostDetailView(postId: post.id)

            } label: {

                actionSymbol(
                    "bubble.left",
                    selected: false,
                    loading: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Open discussion and comments"
            )

            Spacer(minLength: 0)

            Button {

                Task {
                    await actions.toggleBookmark(
                        postId: post.id
                    )
                }

            } label: {

                actionSymbol(
                    actions.isBookmarked
                    ? "bookmark.fill"
                    : "bookmark",
                    selected: actions.isBookmarked,
                    loading: actions.isUpdatingBookmark
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !actions.hasLoaded ||
                actions.isLoading ||
                actions.isUpdatingBookmark
            )
            .accessibilityLabel(
                actions.isBookmarked
                ? "Remove saved post"
                : "Save post"
            )
            .accessibilityAddTraits(
                actions.isBookmarked ? .isSelected : []
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func actionSymbol(
        _ name: String,
        selected: Bool,
        loading: Bool
    ) -> some View {

        Group {

            if loading {

                ProgressView()
                    .accessibilityHidden(true)

            } else {

                Image(systemName: name)
                    .font(.system(.body, weight: .regular))
                    .foregroundStyle(
                        selected
                        ? RawdeaPalette.accent
                        : RawdeaPalette.secondaryText
                    )
                    .accessibilityHidden(true)
            }
        }
        .frame(
            minWidth: RawdeaSpacing.minimumTouchTarget,
            minHeight: RawdeaSpacing.minimumTouchTarget
        )
        .contentShape(Rectangle())
    }

    // MARK: - Owner menu

    private var ownerOptions: some View {

        Menu {

            if let onEdit {

                Button(
                    "Edit Post",
                    systemImage: "pencil",
                    action: onEdit
                )
            }

            if onDelete != nil {

                Button(
                    "Delete Post",
                    systemImage: "trash",
                    role: .destructive
                ) {
                    isShowingDeleteConfirmation = true
                }
            }

            if let onMove {

                Button(
                    "Move to Project",
                    systemImage: "folder",
                    action: onMove
                )
            }

            if let onHide {

                Button(
                    post.isHidden
                    ? "Unhide Post"
                    : "Hide Post",
                    systemImage:
                        post.isHidden
                        ? "eye"
                        : "eye.slash",
                    action: onHide
                )
            }

        } label: {

            optionsSymbol
        }
        .accessibilityLabel("Post options")
    }

    // MARK: - Report menu

    private var reportingOptions: some View {

        Menu {

            Button {

                reportTarget = .post(post.id)

            } label: {

                Label(
                    "Report Post",
                    systemImage: "flag"
                )
            }

        } label: {

            optionsSymbol
        }
        .accessibilityLabel("Post options")
    }

    private var optionsSymbol: some View {

        Image(systemName: "ellipsis")
            .font(.system(.body))
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
