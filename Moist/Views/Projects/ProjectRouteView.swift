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
    @State private var errorMessage: String?
    
    private let projectService = ProjectService()
    
    var body: some View {
        Group {
            if let project {
                ProjectDetailView(
                    project: project,
                    projects: ownerProjects
                )
                
            } else if let errorMessage {
                ContentUnavailableView(
                    "Project unavailable",
                    systemImage: "folder",
                    description: Text(errorMessage)
                )
                
            } else {
                ProgressView("Opening Project...")
            }
        }
        .task(id: projectId) {
            do {
                let loadedProject = try await projectService
                    .fetchProject(id: projectId)
            
                project = loadedProject
                
                if let user = try? await SupabaseManager.client.auth.session.user,
                   user.id == loadedProject.userId {
                    
                    ownerProjects = (
                        try? await projectService.fetchProjects(
                            userId: user.id
                        )
                    ) ?? []
                }
                
            } catch is CancellationError {
                return
                
            } catch {
                guard !Task.isCancelled else { return }
                
                errorMessage = "This Project is not available."
            }
        }
    }
}
