//
//  MovePostToProjectView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 7/11/2569 BE.
//

import SwiftUI

struct MovePostToProjectView: View {
    
    let post: Post
    let projects: [Project]
    let onMoved: () async -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private let postService = PostService()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Choose a destination") {
                    
                    Button {
                        Task {
                            await move(to: nil)
                        }
                    } label: {
                        HStack {
                            Text("No Project")
                            Spacer()
                            
                            if post.projectId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    ForEach(projects) { project in
                        Button {
                            Task {
                                await move(to: project.id)
                            }
                        } label: {
                            HStack {
                                Text(project.name)
                                Spacer()
                                
                                if post.projectId == project.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle("Move to Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    @MainActor
    private func move(to projectId: UUID?) async {
        guard !isSaving else { return }
        
        if projectId == post.projectId {
            dismiss()
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        defer {
            isSaving = false
        }
        
        do {
            try await postService.movePost(
                postId: post.id,
                to: projectId
            )
            
            await onMoved()
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
