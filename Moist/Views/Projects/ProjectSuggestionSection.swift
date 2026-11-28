//
//  ProjectSuggestionSection.swift
//  Rawdea
//

import SwiftUI

/// The Project header's way into suggestions: followers send and
/// track them, the owner opens the ones waiting.
struct ProjectSuggestionSection: View {

    let project: Project
    let isOwner: Bool
    let isFollowing: Bool

    @State private var count = 0
    @State private var isSuggesting = false

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    private var canSuggest: Bool {
        !isOwner && isFollowing && project.takesSuggestions
    }

    var body: some View {

        VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

            if canSuggest {
                RawdeaPillButton(title: "Suggest an update") {
                    isSuggesting = true
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("project-suggest-action")
            }

            if count > 0 {
                Button {
                    openPostRoute?(isOwner
                        ? .suggestions(project.id)
                        : .mySuggestions(project.id))
                } label: {
                    HStack(spacing: RawdeaSpacing.xs) {
                        if isOwner {
                            Circle()
                                .fill(RawdeaPalette.accent)
                                .frame(width: RawdeaSpacing.xs, height: RawdeaSpacing.xs)
                                .accessibilityHidden(true)
                        }
                        Text(label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.right")
                            .accessibilityHidden(true)
                    }
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isSuggesting) {
            SuggestUpdateSheet(project: project) {
                await load()
            }
        }
        // Reloads after answering, and when the stage moves.
        .onAppear { Task { await load() } }
        .onChange(of: project.stage) { _, _ in
            Task { await load() }
        }
        .onChange(of: isOwner) { _, _ in
            Task { await load() }
        }
    }

    private var label: String {
        if isOwner {
            return count == 1 ? "1 suggestion waiting" : "\(count) suggestions waiting"
        }
        return "Your suggestions (\(count))"
    }

    // A failed check only hides the shortcut.
    private func load() async {
        let service = SuggestionService()
        if isOwner {
            count = (try? await service.fetchWaiting(projectId: project.id).count) ?? 0
        } else {
            count = (try? await service.fetchMine(projectId: project.id).count) ?? 0
        }
    }
}
