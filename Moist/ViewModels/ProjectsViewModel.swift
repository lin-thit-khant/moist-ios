//
//  ProjectsViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 7/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class ProjectsViewModel: ObservableObject {
    
    @Published private(set) var projects: [Project] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isCreating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUpdating = false
    
    private let projectService = ProjectService()
    
    func loadProjects(userId: UUID) async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            projects = try await projectService.fetchProjects(
                userId: userId
            )
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
    
    func creatProject(name: String) async -> Bool {
        guard !isCreating else { return false }
        
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !trimmedName.isEmpty,
              trimmedName.count <= 80 else {
            errorMessage = "Enter a name of up to 80 characters."
            return false
        }
        
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        
        do {
            let project = try await projectService.createProject(
                name: trimmedName
            )
            
            projects.insert(project, at: 0)
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func renameProject(
        projectId: UUID,
        name: String
    ) async -> Bool {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            errorMessage = "Enter a name of up to 80 characters."
            return false
        }
        
        return await applyChange {
            try await projectService.renameProject(
                projectId: projectId,
                name: trimmed
            )
        }
    }
    
    func setArchived(
        projectId: UUID,
        archived: Bool
    ) async -> Bool {
        await applyChange {
            try await projectService.setArchived(
                projectId: projectId,
                archived: archived
            )
        }
    }
    
    func setHidden(
        projectId: UUID,
        hidden: Bool
    ) async -> Bool {
        await applyChange {
            try await projectService.setHidden(
                projectId: projectId,
                hidden: hidden
            )
        }
    }
    
    private func applyChange(
        _ operation: () async throws -> Project
    ) async -> Bool {
        guard !isUpdating else { return false }
        
        isUpdating = true
        errorMessage = nil
        
        defer {
            isUpdating = false
        }
        
        do {
            let updatedProject = try await operation()
            
            if let index = projects.firstIndex(
                where: { $0.id == updatedProject.id }
            ) {
                projects[index] = updatedProject
            }
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
