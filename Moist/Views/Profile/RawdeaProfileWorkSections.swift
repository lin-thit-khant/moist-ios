
import SwiftUI

/// A profile's Projects as chips, then its posts and replies.
struct RawdeaProfileWorkSections<Chips: View, Posts: View>: View {
    let userId: UUID
    @ViewBuilder let chips: () -> Chips
    @ViewBuilder let posts: () -> Posts

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: Section = .posts

    private enum Section: String, CaseIterable {
        case posts = "Posts"
        case replies = "Replies"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RawdeaSpacing.md) {
            VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                Text("Projects")
                    .font(RawdeaTypography.secondary.weight(.medium))
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RawdeaSpacing.xs, content: chips)
                }
            }

            contentSelector

            switch selection {
            case .posts:
                posts()
            case .replies:
                ProfileRepliesView(userId: userId)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contentSelector: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))

        return layout {
            ForEach(Section.allCases, id: \.self) { section in
                let isSelected = selection == section

                Button {
                    selection = section
                } label: {
                    Text(section.rawValue)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(isSelected ? RawdeaPalette.primaryText : RawdeaPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, RawdeaSpacing.xxs)
                        .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelected ? RawdeaPalette.accent : RawdeaPalette.divider)
                                .frame(height: isSelected ? 2 : 0.5)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Profile content")
    }
}

/// A Project on a profile: "Kiln Log · Early".
struct RawdeaProjectChip: View {
    let project: Project

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    private var status: String {
        if project.isArchived { return "Archived" }
        if project.isHidden { return "Hidden" }
        return project.stage.title
    }

    var body: some View {
        RawdeaChip(
            title: "\(project.name) · \(status)",
            symbol: project.isPinned ? "pin.fill" : nil,
            isSelected: false
        ) {
            openPostRoute?(.project(project.id))
        }
        .accessibilityHint("Opens Project")
    }
}

// MARK: - Replies

private struct ProfileRepliesView: View {
    let userId: UUID

    @State private var replies: [ProfileReply]?
    @State private var hasError = false

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasError {
                RawdeaInlineError(message: "Couldn't load replies.")
                Button("Try Again") {
                    Task { await load() }
                }
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            } else if let replies {
                if replies.isEmpty {
                    Text("No replies yet.")
                        .font(RawdeaTypography.secondary)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                }
                ForEach(replies) { reply in
                    Button {
                        openPostRoute?(.discussion(reply.postId))
                    } label: {
                        VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                            Text("On: \(reply.post.content)")
                                .font(RawdeaTypography.metadata)
                                .foregroundStyle(RawdeaPalette.secondaryText)
                                .lineLimit(1)
                            Text(reply.content)
                                .font(RawdeaTypography.body)
                                .foregroundStyle(RawdeaPalette.primaryText)
                            Text(PostRowView.relativeAge(of: reply.createdAt, at: .now))
                                .font(RawdeaTypography.caption)
                                .foregroundStyle(RawdeaPalette.secondaryText)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget, alignment: .leading)
                        .padding(.vertical, RawdeaSpacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens Discussion")

                    Divider()
                        .overlay(RawdeaPalette.divider)
                }
            } else {
                RawdeaLoadingIndicator("Loading replies...")
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: userId) { await load() }
    }

    private func load() async {
        hasError = false
        do {
            replies = try await PostEngagementService().fetchReplies(userId: userId)
        } catch is CancellationError {
            return
        } catch {
            replies = nil
            hasError = true
        }
    }
}
