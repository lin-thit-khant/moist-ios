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
    @State private var isShowingOptions = false
    @State private var pendingOption: PostOption?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let horizontalInset: CGFloat
    private let showsProjectLink: Bool
    private let isReader: Bool
    private let isTimeline: Bool


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
        isReader: Bool = false,
        isTimeline: Bool = false
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
        self.isReader = isReader
        self.isTimeline = isTimeline
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

    /// The feed's short age: "2h", "3d", "5w".
    static func shortAge(of date: Date, at now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3_600))h"
        case ..<604_800: return "\(Int(seconds / 86_400))d"
        default: return "\(Int(seconds / 604_800))w"
        }
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

        Group {
            if isTimeline {
                timelineLayout
            } else {
                threadLayout
            }
        }
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

        // The chosen action runs once the sheet has closed,
        // so it can present its own sheet or confirmation.
        .sheet(
            isPresented: $isShowingOptions,
            onDismiss: {
                pendingOption?.action()
                pendingOption = nil
            }
        ) {
            PostOptionsSheet(options: postOptions) { option in
                pendingOption = option
                isShowingOptions = false
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
    
    // MARK: - Layouts

    /// Avatar column, then everything else beside it. Large text
    /// drops the avatar to keep the width.
    private var threadLayout: some View {

        HStack(alignment: .top, spacing: RawdeaSpacing.sm) {

            if !dynamicTypeSize.isAccessibilitySize {
                threadAvatar
            }

            VStack(alignment: .leading, spacing: 0) {

                threadHeader

                RawdeaKindLabel(post: post)
                    .padding(.top, RawdeaSpacing.xxs)

                postContent

                hiddenLabel

                if showsDiscussionLink {

                    postActions

                    actionError
                }
            }
        }
        .padding(.horizontal, horizontalInset)
        .padding(.top, RawdeaSpacing.sm)
        .padding(.bottom, RawdeaSpacing.xxs)
    }

    // Inside a Project timeline the date and rail are drawn by the
    // Project screen. Counts are text; actions are in the menu.
    private var timelineLayout: some View {

        VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {

            RawdeaKindLabel(post: post)

            postContent

            hiddenLabel

            Text("\(counted(post.likeCount, "like"))   \(counted(post.replyCount, post.kind == .question ? "answer" : "reply"))")
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
                .padding(.bottom, RawdeaSpacing.sm)
        }
        .contentShape(Rectangle())
        .contextMenu {
            if showsOptions {
                ForEach(postOptions) { option in
                    Button(
                        option.title,
                        systemImage: option.symbol,
                        role: option.isDestructive ? .destructive : nil,
                        action: option.action
                    )
                }
            }
        }
        .accessibilityActions {
            if showsOptions {
                ForEach(postOptions) { option in
                    Button(option.title, action: option.action)
                }
            }
        }
    }

    private func counted(_ count: Int, _ noun: String) -> String {
        if count == 1 { return "1 \(noun)" }
        return noun == "reply" ? "\(count) replies" : "\(count) \(noun)s"
    }

    private var showsOptions: Bool {
        guard let viewerId else { return false }
        return viewerId != post.userId || hasOwnerActions
    }

    private var linkedProject: PostProject? {
        showsProjectLink ? post.project : nil
    }

    // A tap gesture keeps the avatar out of VoiceOver, which
    // uses the names beside it.
    private var threadAvatar: some View {

        Group {
            if let project = linkedProject {
                RawdeaProjectAvatar(name: project.name)
            } else {
                RawdeaInitialAvatar(name: authorName)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let project = linkedProject {
                openPostRoute?(.project(project.id))
            } else {
                openPostRoute?(.author(post.userId))
            }
        }
        .accessibilityHidden(true)
    }

    // "Project · Stage  author  time" on one line where it fits.
    private var threadHeader: some View {

        HStack(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xxs) {

            // Narrow rows put the person under the Project.
            ViewThatFits(in: .horizontal) {

                HStack(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xxs) {
                    projectPart
                    authorPart
                }

                VStack(alignment: .leading, spacing: 0) {
                    projectPart
                    HStack(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xxs) {
                        authorPart
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    projectPart
                    authorPart
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsOptions {
                optionsButton
                    .padding(.vertical, -RawdeaSpacing.sm)
                    .padding(.trailing, -RawdeaSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private var projectPart: some View {

        if let project = linkedProject {

            routedPostControl(
                to: .project(project.id)
            ) {

                ProjectRouteView(projectId: project.id)

            } label: {

                // Large text puts the stage under the name.
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xxs))

                layout {

                    Text(project.name)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.primaryText)

                    if let stage = project.stage {
                        Text(dynamicTypeSize.isAccessibilitySize ? stage.title : "· \(stage.title)")
                            .font(RawdeaTypography.secondary)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                    }
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .multilineTextAlignment(.leading)
                // The avatar is the full-size way in.
                .padding(.vertical, RawdeaSpacing.xxs)
                .contentShape(Rectangle())
                .padding(.vertical, -RawdeaSpacing.xxs)
            }
            .accessibilityLabel("Open Project \(project.name)")
        }
    }

    @ViewBuilder
    private var authorPart: some View {

        routedPostControl(
            to: .author(post.userId)
        ) {

            AuthorProfileView(userId: post.userId)

        } label: {

            Text(post.author?.username ?? authorName)
                .font(linkedProject == nil
                    ? RawdeaTypography.authorName
                    : RawdeaTypography.secondary)
                .foregroundStyle(linkedProject == nil
                    ? RawdeaPalette.primaryText
                    : RawdeaPalette.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .padding(.vertical, RawdeaSpacing.xxs)
                .contentShape(Rectangle())
                .padding(.vertical, -RawdeaSpacing.xxs)
        }
        .accessibilityLabel(
            "View profile for \(authorName), \(authorHandle)"
        )

        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(Self.shortAge(of: post.createdAt, at: context.date))
                .font(RawdeaTypography.secondary)
                .foregroundStyle(RawdeaPalette.secondaryText)
                .lineLimit(1)
                .accessibilityLabel(Self.relativeAge(of: post.createdAt, at: context.date))
        }
    }

    @ViewBuilder
    private var hiddenLabel: some View {

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
    }

    @ViewBuilder
    private var actionError: some View {

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
                    .multilineTextAlignment(.leading)
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



    // MARK: - Independent post actions

    private var postActions: some View {

        HStack(spacing: RawdeaSpacing.xxs) {

            HStack(spacing: -RawdeaSpacing.xs) {
                likeButton
                countText(shownLikeCount)
            }

            discussionButton

            bookmarkButton

            Spacer(minLength: 0)
        }
        // Line the first symbol up with the post text.
        .padding(.leading, -RawdeaSpacing.sm)
        .accessibilityElement(children: .contain)
    }

    private func countText(_ count: Int) -> some View {
        Text(count.formatted())
            .font(RawdeaTypography.metadata)
            .foregroundStyle(actions.isLiked
                ? RawdeaPalette.accent
                : RawdeaPalette.secondaryText)
            .padding(.trailing, RawdeaSpacing.xs)
            .accessibilityLabel(count == 1 ? "1 like" : "\(count) likes")
    }

    // The fetched count, moved by a change made on this row.
    private var shownLikeCount: Int {
        guard let initial = actions.initiallyLiked else {
            return post.likeCount
        }
        return post.likeCount
            + (actions.isLiked ? 1 : 0)
            - (initial ? 1 : 0)
    }

    private var likeButton: some View {

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
    }

    private var discussionButton: some View {

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
                    .dynamicTypeSize(...Self.largestSymbolSize)
                    .accessibilityHidden(true)
                Text(post.kind == .question
                    ? counted(post.replyCount, "answer")
                    : post.replyCount.formatted())
                    .font(RawdeaTypography.metadata)
            }
                .foregroundStyle(RawdeaPalette.secondaryText)
                .padding(.horizontal, RawdeaSpacing.xs)
                .frame(
                    minWidth: RawdeaSpacing.minimumTouchTarget,
                    minHeight: RawdeaSpacing.minimumTouchTarget
                )
                .contentShape(Rectangle())
        }
        .accessibilityLabel(
            "Open discussion and comments, \(counted(post.replyCount, post.kind == .question ? "answer" : "reply"))"
        )
    }

    private var bookmarkButton: some View {

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

    // MARK: - Post options

    private var optionsButton: some View {

        Button {
            isShowingOptions = true
        } label: {
            optionsSymbol
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Post options")
    }

    private var ownerOptions: [PostOption] {

        var options: [PostOption] = []

        if let onEdit {
            options.append(PostOption(
                title: "Edit Post",
                symbol: "pencil",
                action: onEdit
            ))
        }

        if let onMove {
            options.append(PostOption(
                title: "Move to Project",
                symbol: "folder",
                action: onMove
            ))
        }

        if let onHide {
            options.append(PostOption(
                title: post.isHidden ? "Unhide Post" : "Hide Post",
                symbol: post.isHidden ? "eye" : "eye.slash",
                action: onHide
            ))
        }

        if onDelete != nil {
            options.append(PostOption(
                title: "Delete Post",
                symbol: "trash",
                isDestructive: true,
                action: { isShowingDeleteConfirmation = true }
            ))
        }

        return options
    }

    private var postOptions: [PostOption] {

        if viewerId == post.userId {
            return ownerOptions
        }

        return [
            PostOption(
                title: "Report Post",
                symbol: "flag",
                isDestructive: true,
                action: { reportTarget = .post(post.id) }
            )
        ]
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
