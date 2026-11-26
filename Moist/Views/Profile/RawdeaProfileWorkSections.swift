import SwiftUI

struct RawdeaProfileWorkSections<ProjectRow: View, Posts: View, Projects: View>: View {
    let pinnedProjects: [Project]
    @ViewBuilder let projectRow: (Project) -> ProjectRow
    @ViewBuilder let posts: () -> Posts
    @ViewBuilder let projects: () -> Projects

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: Section = .posts

    private enum Section: String, CaseIterable {
        case posts = "Posts"
        case projects = "Projects"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RawdeaSpacing.md) {
            if !pinnedProjects.isEmpty {
                VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {
                    Text("Pinned Projects")
                        .font(RawdeaTypography.sectionTitle)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(pinnedProjects.prefix(2), content: projectRow)

                    if pinnedProjects.count > 2 {
                        DisclosureGroup {
                            VStack(spacing: RawdeaSpacing.sm) {
                                ForEach(pinnedProjects.dropFirst(2), content: projectRow)
                            }
                            .padding(.top, RawdeaSpacing.xs)
                        } label: {
                            Text("More pinned projects")
                                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                        }
                        .font(RawdeaTypography.metadata)
                    }
                }
                .foregroundStyle(RawdeaPalette.primaryText)
            }

            contentSelector

            switch selection {
            case .posts:
                posts()
            case .projects:
                projects()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contentSelector: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: RawdeaSpacing.xxs))
            : AnyLayout(HStackLayout(spacing: RawdeaSpacing.xxs))

        return layout {
            ForEach(Section.allCases, id: \.self) { section in
                Button {
                    selection = section
                } label: {
                    Text(section.rawValue)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(selection == section ? RawdeaPalette.primaryText : RawdeaPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(RawdeaSpacing.xxs)
                        .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget)
                        .background(
                            selection == section ? RawdeaPalette.canvas : .clear,
                            in: RoundedRectangle(cornerRadius: RawdeaSpacing.xs)
                        )
                        .overlay {
                            if selection == section {
                                RoundedRectangle(cornerRadius: RawdeaSpacing.xs)
                                    .strokeBorder(RawdeaPalette.activityOutline)
                                    .allowsHitTesting(false)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(RawdeaSpacing.xxs)
        .background(RawdeaPalette.surface, in: RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Profile content")
    }
}
