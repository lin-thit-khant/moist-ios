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
    let onUnsave: (() -> Void)?
    let isUnsaveDisabled: Bool
    let isUnsaving: Bool
    
    @StateObject private var actions =
        PostRowActionsViewModel()

    @State private var resolvedViewerId: UUID?
    @State private var reportTarget: ReportTarget?
    @State private var isShowingDeleteConfirmation = false
    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let horizontalInset: CGFloat
    private let showsProjectLink: Bool
    
    
    init(
        post: Post,
        currentUserId: UUID? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMove: (() -> Void)? = nil,
        onHide: (() -> Void)? = nil,
        showsDiscussionLink: Bool = true,
        onUnsave: (() -> Void)? = nil,
        isUnsaveDisabled: Bool = false,
        isUnsaving: Bool = false,
        horizontalInset: CGFloat = RawdeaSpacing.screenInset,
        showsProjectLink: Bool = true
    ) {

        self.post = post
        self.currentUserId = currentUserId
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onMove = onMove
        self.onHide = onHide
        self.showsDiscussionLink = showsDiscussionLink

        self.onUnsave = onUnsave
        self.isUnsaveDisabled = isUnsaveDisabled
        self.isUnsaving = isUnsaving
        self.horizontalInset = horizontalInset
        self.showsProjectLink = showsProjectLink
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

    private static let relativeTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var viewerId: UUID? {
        currentUserId ?? resolvedViewerId
    }

    private var hasOwnerActions: Bool {
        onEdit != nil ||
        onDelete != nil ||
        onMove != nil ||
        onHide != nil
    }

    private var displayedBookmarkState: Bool {

        if onUnsave != nil {

            // Saved Posts already knows that this
            // row represents a saved post.

            return true
        }

        return actions.isBookmarked
    }

    private var bookmarkActionIsLoading: Bool {

        if onUnsave != nil {
            return isUnsaving
        }

        return actions.isUpdatingBookmark
    }

    private var bookmarkActionIsDisabled: Bool {

        if onUnsave != nil {

            return isUnsaveDisabled || isUnsaving
        }

        return !actions.hasLoaded ||
               actions.isLoading ||
               actions.isUpdatingBookmark
    }

    private var likeActionIsDisabled: Bool {
        !actions.hasLoaded || actions.isLoading || actions.isUpdatingLike
    }
    // MARK: - Body

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.sm
        ) {

            VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                authorHeader

                postContent
            }

            if showsProjectLink, let project = post.project {
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
        .padding(.horizontal, horizontalInset)
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

            routedPostControl(
                to: .author(post.userId)
            ) {

                AuthorProfileView(
                    userId: post.userId
                )

            } label: {

                HStack(
                    alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
                    spacing: RawdeaSpacing.xs
                ) {

                    RawdeaInitialAvatar(name: authorName)

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

                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            let age = Self.relativeTimeFormatter.localizedString(
                                for: post.createdAt,
                                relativeTo: context.date
                            )
                            Text("\(authorHandle) · \(age)")
                                .font(RawdeaTypography.metadata)
                                .foregroundStyle(RawdeaPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight:
                        RawdeaSpacing.minimumTouchTarget,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .accessibilityLabel(
                "View profile for \(authorName), \(authorHandle)"
            )
            .accessibilityValue(Text(post.createdAt, style: .relative))

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

            routedPostControl(
                to: .discussion(post.id)
            ) {

                PostDetailView(
                    postId: post.id
                )

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

        routedPostControl(
            to: .project(project.id)
        ) {

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
                    loading: actions.isUpdatingLike,
                    disabled: likeActionIsDisabled
                )
            }
            .buttonStyle(.plain)
            .disabled(likeActionIsDisabled)
            .accessibilityLabel(
                actions.isLiked
                ? "Unlike post"
                : "Like post"
            )
            .accessibilityAddTraits(
                actions.isLiked ? .isSelected : []
            )
            .accessibilityValue(actions.isUpdatingLike ? "Updating" : "")

            
            routedPostControl(
                to: .discussion(post.id)
            ) {

                PostDetailView(
                    postId: post.id
                )

            } label: {

                HStack(spacing: RawdeaSpacing.xxs) {
                    Image(systemName: "bubble.left")
                        .font(.body)
                        .accessibilityHidden(true)

                    Text("Discuss")
                        .font(RawdeaTypography.metadata.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
                .foregroundStyle(RawdeaPalette.secondaryText)
                .padding(.horizontal, RawdeaSpacing.xxs)
                .frame(
                    minWidth: RawdeaSpacing.minimumTouchTarget,
                    minHeight: RawdeaSpacing.minimumTouchTarget
                )
                .contentShape(Rectangle())
            }
            .accessibilityLabel(
                "Open discussion and comments"
            )
            .layoutPriority(1)


            Spacer(minLength: 0)

            
            Button {

                if let onUnsave {

                    // Saved Posts owns the removal,
                    // so both removal methods share
                    // the same view model.

                    onUnsave()

                } else {

                    // Normal feed Bookmark behavior.

                    Task {

                        await actions.toggleBookmark(
                            postId: post.id
                        )
                    }
                }

            } label: {

                actionSymbol(
                    displayedBookmarkState
                    ? "bookmark.fill"
                    : "bookmark",
                    selected: displayedBookmarkState,
                    loading: bookmarkActionIsLoading,
                    disabled: bookmarkActionIsDisabled
                )
            }
            .buttonStyle(.plain)
            .disabled(
                bookmarkActionIsDisabled
            )
            .accessibilityLabel(
                displayedBookmarkState
                ? "Remove saved post"
                : "Save post"
            )
            .accessibilityAddTraits(
                displayedBookmarkState
                ? .isSelected
                : []
            )
            .accessibilityValue(bookmarkActionIsLoading ? "Updating" : "")

        }
        .accessibilityElement(children: .contain)
    }

    private func actionSymbol(
        _ name: String,
        selected: Bool,
        loading: Bool,
        disabled: Bool
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
                    .opacity(disabled ? 0.5 : 1)
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
    
    
    // MARK: - Independent routed navigation
    //
    // Within Rawdea's main tabs, use a Button
    // to navigate explicitly.
    //
    // The NavigationLink fallback also lets
    // the row work in other navigation contexts,
    // including standalone previews.

    @ViewBuilder
    private func routedPostControl<
        LabelContent: View,
        Destination: View
    >(
        to route: RawdeaPostRoute,
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {

        if let openPostRoute {

            Button {
                openPostRoute(route)
            } label: {
                label()
            }
            .buttonStyle(.plain)

        } else {

            NavigationLink {
                destination()
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }

}
