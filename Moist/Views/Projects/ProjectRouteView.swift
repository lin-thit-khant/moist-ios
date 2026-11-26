//
//  ProjectRouteView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 9/11/2569 BE.
//


import SwiftUI
import Supabase

struct ProjectRouteView: View {

    let projectId: UUID

    @State private var project: Project?
    @State private var ownerProjects: [Project] = []

    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @Environment(\.scenePhase) private var scenePhase

    private let projectService = ProjectService()

    // MARK: - Body

    var body: some View {

        Group {

            if isLoading && project == nil {

                ProgressView("Opening Project...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

            } else if let errorMessage {

                RawdeaEmptyState(
                    symbol: "folder",
                    title: "Project unavailable",
                    message: errorMessage,
                    actionTitle: "Try Again"
                ) {
                    Task {
                        await loadProject(clearingContent: true)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

            } else if let project {

                ProjectDetailView(
                    project: project,
                    projects: ownerProjects
                )

            } else {

                ProgressView("Opening Project...")
            }
        }

        // Initial load and project ID changes.

        .task(id: projectId) {

            await loadProject(clearingContent: true)
        }

        // Revalidate an already-open route when
        // returning from another screen. The open
        // Project stays on screen while it checks,
        // so scroll position and loaded posts survive.

        .onAppear {

            Task {
                await loadProject()
            }
        }
        
        
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await loadProject()
            }
        }

    }

    // MARK: - Load Project

    @MainActor
    private func loadProject(clearingContent: Bool = false) async {

        guard !isLoading else {
            return
        }

        isLoading = true

        // A new route clears old content before
        // verifying access. Revalidation keeps it.

        if clearingContent || project == nil {
            project = nil
            ownerProjects = []
        }

        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let loadedProject = try await projectService
                .fetchProject(id: projectId)

            try Task.checkCancellation()

            var loadedOwnerProjects: [Project] = []

            if let user = try? await SupabaseManager
                .client.auth.session.user,
               user.id == loadedProject.userId {

                loadedOwnerProjects = (
                    try? await projectService.fetchProjects(
                        userId: user.id
                    )
                ) ?? []
            }

            try Task.checkCancellation()

            project = loadedProject
            ownerProjects = loadedOwnerProjects

        } catch is CancellationError {
            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            project = nil
            ownerProjects = []

            errorMessage =
                "This Project is no longer available."
        }
    }
}
