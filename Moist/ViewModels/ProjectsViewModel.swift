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
    
    func clearError() {
        errorMessage = nil
    }
}
