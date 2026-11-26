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
    @State private var likePop = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let horizontalInset: CGFloat
    private let showsProjectLink: Bool
    private let continuesThread: Bool


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
        showsProjectLink: Bool = true,
        continuesThread: Bool = false
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
        self.continuesThread = continuesThread
    }


    // Row symbols stop growing here so they stay inside
    // their 44 pt targets.
    private static let largestSymbolSize = DynamicTypeSize.accessibility1

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

    /// Under a minute old, or slightly in the future because the server
    /// clock is ahead of the device, reads as "now" instead of "in 0 sec".
    static func relativeAge(of date: Date, at now: Date) -> String {
        if now.timeIntervalSince(date) < 60 {
            return "now"
        }
        return relativeTimeFormatter.localizedString(for: date, relativeTo: now)
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

    /// Feed rows put everything beside the avatar. Discussion and
    /// accessibility text sizes give the post the full width.
    private var usesAvatarColumn: Bool {
        showsDiscussionLink && !dynamicTypeSize.isAccessibilitySize
    }
    // MARK: - Body

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .top, spacing: RawdeaSpacing.sm) {

                avatarLink

                VStack(alignment: .leading, spacing: 0) {

                    authorHeader

                    if usesAvatarColumn {
                        postDetails
                    }
                }
            }

            // Large text needs the width beside the avatar too.
            if dynamicTypeSize.isAccessibilitySize {
                projectLine
            }

            if !usesAvatarColumn {
                postDetails
            }
        }
        .padding(.horizontal, horizontalInset)
        .padding(.top, RawdeaSpacing.sm)
        .padding(.bottom, RawdeaSpacing.xxs)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .overlay(alignment: .topLeading) {
            if continuesThread && usesAvatarColumn {
                threadLine
            }
        }
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
    
    // MARK: - Thread line

    // Runs down the avatar column to the next post.
    private var threadLine: some View {

        Rectangle()
            .fill(RawdeaPalette.activityOutline)
            .frame(width: 2)
            .padding(.top, RawdeaSpacing.sm + RawdeaSpacing.avatarColumn + RawdeaSpacing.xxs)
            .padding(.leading, horizontalInset + RawdeaSpacing.avatarColumn / 2 - 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Author header

    // A second way into the profile with a full-size target.
    // VoiceOver uses the name instead.
    private var avatarLink: some View {

        routedPostControl(
            to: .author(post.userId)
        ) {

            AuthorProfileView(
                userId: post.userId
            )

        } label: {

            RawdeaInitialAvatar(
                name: authorName,
                size: RawdeaSpacing.avatarColumn,
                tintSeed: post.userId
            )
            .frame(
                width: RawdeaSpacing.minimumTouchTarget,
                height: RawdeaSpacing.minimumTouchTarget
            )
            .contentShape(Rectangle())
        }
        .padding(-(RawdeaSpacing.minimumTouchTarget - RawdeaSpacing.avatarColumn) / 2)
        .accessibilityHidden(true)
    }

    private var authorHeader: some View {

        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .top, spacing: RawdeaSpacing.xs) {

                authorLink
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let viewerId {

                    // Keeps a 44 pt target without making
                    // the name row taller.
                    Group {

                        if viewerId == post.userId {

                            if hasOwnerActions {
                                ownerOptions
                            }

                        } else {

                            reportingOptions
                        }
                    }
                    .padding(.vertical, -RawdeaSpacing.sm)
                    .padding(.trailing, -RawdeaSpacing.sm)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {

                // The 44 pt target reaches up into the name row
                // so the two lines still read as one block.
                projectLine
                    .padding(.top, -10)
                    .zIndex(1)
            }
        }
    }

    @ViewBuilder
    private var projectLine: some View {

        if showsProjectLink, let project = post.project {
            projectLink(project)
        }
    }

    private var authorLink: some View {

        routedPostControl(
            to: .author(post.userId)
        ) {

            AuthorProfileView(
                userId: post.userId
            )

        } label: {

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.xxs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xs))

            layout {

                Text(authorName)
                    .font(RawdeaTypography.authorName)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(Self.relativeAge(of: post.createdAt, at: context.date))
                        .font(RawdeaTypography.metadata)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                        .lineLimit(1)
                }
                .layoutPriority(1)
            }
            .padding(.vertical, RawdeaSpacing.sm)
            .contentShape(Rectangle())
            .padding(.vertical, -RawdeaSpacing.sm)
        }
        .accessibilityLabel(
            "View profile for \(authorName), \(authorHandle)"
        )
        .accessibilityValue(Text(post.createdAt, style: .relative))
    }

    // MARK: - Post details

    private var postDetails: some View {

        VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {

            postContent

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
                        .font(RawdeaTypography.metadata.weight(.semibold))
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }
                }
            }
        }
        .padding(.top, post.project == nil || !showsProjectLink ? RawdeaSpacing.xxs : 0)
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
                        alignment: .topLeading
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

            HStack(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xxs) {

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
                RawdeaPalette.accent
            )
            .padding(.vertical, RawdeaSpacing.sm)
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

        HStack(spacing: RawdeaSpacing.xxs) {

            Button {

                Task {
                    let wasLiked = actions.isLiked
                    await actions.toggleLike(
                        postId: post.id
                    )
                    // Celebrate only a like the server accepted.
                    if !wasLiked, actions.isLiked {
                        likePop += 1
                    }
                }

            } label: {

                actionSymbol(
                    actions.isLiked
                    ? "heart.fill"
                    : "heart",
                    selected: actions.isLiked,
                    selectedColor: RawdeaPalette.accent,
                    loading: actions.isUpdatingLike,
                    disabled: likeActionIsDisabled,
                    popTrigger: likePop
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
            .sensoryFeedback(.impact(weight: .light), trigger: likePop)

            
            routedPostControl(
                to: .discussion(post.id)
            ) {

                PostDetailView(
                    postId: post.id
                )

            } label: {

                Image(systemName: "bubble.left")
                    .font(.body)
                    .dynamicTypeSize(...Self.largestSymbolSize)
                    .accessibilityHidden(true)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .frame(
                        minWidth: RawdeaSpacing.minimumTouchTarget,
                        minHeight: RawdeaSpacing.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(
                "Open discussion and comments"
            )


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
                    selectedColor: RawdeaPalette.primaryText,
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
        // Line the outer symbols up with the post text.
        .padding(.horizontal, -RawdeaSpacing.sm)
        .accessibilityElement(children: .contain)
    }

    private func actionSymbol(
        _ name: String,
        selected: Bool,
        selectedColor: Color,
        loading: Bool,
        disabled: Bool,
        popTrigger: Int = 0
    ) -> some View {

        ZStack {

            // The symbol stays in place while loading so the
            // like bounce has a view to animate.
            Image(systemName: name)
                .font(.system(.body, weight: .regular))
                .dynamicTypeSize(...Self.largestSymbolSize)
                .foregroundStyle(
                    selected
                    ? selectedColor
                    : RawdeaPalette.secondaryText
                )
                .symbolEffect(.bounce, value: popTrigger)
                .symbolEffectsRemoved(reduceMotion)
                .opacity(loading ? 0 : (disabled ? 0.5 : 1))
                .animation(
                    reduceMotion ? .easeInOut(duration: 0.2) : nil,
                    value: loading
                )
                .accessibilityHidden(true)

            if loading {

                ProgressView()
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
            .dynamicTypeSize(...Self.largestSymbolSize)
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
