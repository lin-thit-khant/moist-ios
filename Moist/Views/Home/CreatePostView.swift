//
//  CreatePostView.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//

import SwiftUI

struct CreatePostView: View {
    
    @StateObject private var viewModel = CreatePostViewModel()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var content = ""
    @State private var selectedProject: Project?
    @State private var isShowingProjectPicker = false
    
    let onPostCreated: (Post) -> Void
    
    private let characterLimit = 500
    
    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isFormValid: Bool {
        !trimmedContent.isEmpty && content.count <= characterLimit
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                
                Text("What's happening")
                    .font(.headline)
                
                ZStack(alignment: .topLeading) {
                    
                    if content.isEmpty {
                        Text("Share something with the world...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                }
                
                HStack {
                    Spacer()
                    
                    Text("\(content.count)/\(characterLimit)")
                        .font(.caption)
                        .foregroundStyle(
                            content.count >= characterLimit
                            ? .orange
                            : .secondary
                        )
                }
                
                Button {
                    isShowingProjectPicker = true
                } label: {
                    Label(
                        selectedProject?.name ?? "Add to Project",
                        systemImage: "folder"
                    )
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isPublishing)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.publish(
                                content: trimmedContent,
                                projectId: selectedProject?.id
                            )
                            
                            if success, let post = viewModel.publishedPost {
                                onPostCreated(post)
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isPublishing {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(
                        !isFormValid || viewModel.isPublishing
                    )
                }
            }
        }
        .onChange(of: content) { _, newValue in
            if newValue.count > characterLimit {
                content = String(newValue.prefix(characterLimit))
            }
            
            viewModel.clearError()
        }
        .sheet(isPresented: $isShowingProjectPicker) {
            ProjectPickerView(
                selectedProject: $selectedProject
            )
        }
    }
}
