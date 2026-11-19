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

            if isLoading {

                ProgressView("Opening Project...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

            } else if let errorMessage {

                VStack(spacing: 16) {

                    ContentUnavailableView(
                        "Project Unavailable",
                        systemImage: "folder",
                        description: Text(errorMessage)
                    )

                    Button("Try Again") {

                        Task {
                            await loadProject()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

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

            await loadProject()
        }

        // Revalidate an already-open route when
        // returning from another screen.

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
    private func loadProject() async {

        guard !isLoading else {
            return
        }

        isLoading = true

        // Clear old content before verifying access.

        project = nil
        ownerProjects = []
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
