//
//  ProjectPickerView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 9/11/2569 BE.
//

import SwiftUI
import Supabase

struct ProjectPickerView: View {
    
    @Binding var selectedProject: Project?
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = ProjectsViewModel()
    
    @State private var newProjectName = ""
    @State private var isShowingCreateAlert = false
    @State private var sessionError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Post destination") {
                    
                    Button {
                        selectedProject = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("No Project")
                            Spacer()
                            
                            if selectedProject == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    ForEach(viewModel.projects) { project in
                        Button {
                            selectedProject = project
                            dismiss()
                        } label: {
                            HStack {
                                Text(project.name)
                                Spacer()
                                
                                if selectedProject?.id == project.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    if viewModel.isLoading {
                        ProgressView("Loading Projects...")
                    } else if viewModel.projects.isEmpty &&
                                viewModel.errorMessage == nil {
                        Text("No Projects yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button {
                        newProjectName = ""
                        viewModel.clearError()
                        isShowingCreateAlert = true
                    } label: {
                        Label(
                            "Create new Project",
                            systemImage: "plus"
                        )
                    }
                }
                
                if let error = viewModel.errorMessage ?? sessionError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                
                if viewModel.isCreating {
                    ProgressView("Creating Project...")
                }
            }
            .disabled(viewModel.isCreating)
            .navigationTitle("Choose Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(
                "New Project",
                isPresented: $isShowingCreateAlert
            ) {
                    TextField(
                        "Project name",
                        text: $newProjectName
                    )
                
                Button("Cancel", role: .cancel) {}
                
                Button("Create") {
                    Task {
                        let created = await viewModel.creatProject(
                            name: newProjectName
                        )
                        
                        if created,
                           let newProject = viewModel.projects.first {
                            selectedProject = newProject
                            dismiss()
                        }
                    }
                }
                
            } message: {
                Text("Give your Project a name.")
            }
            .task {
                do {
                    let user = try await SupabaseManager
                        .client.auth.session.user
                    
                    await viewModel.loadProjects(userId: user.id)
                    
                } catch {
                    sessionError = "Please sign in again."
                }
            }
        }
    }
}
