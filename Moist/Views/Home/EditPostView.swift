//
//  EditPostView.swift
//  Moist
//
//  Created by Lin Thit Khant on 4/11/2569 BE.
//

import SwiftUI

struct EditPostView: View {
    
    let post: Post
    
    @ObservedObject var viewModel: FeedViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var content: String
    
    init(post: Post, viewModel: FeedViewModel) {
        self.post = post
        self.viewModel = viewModel
        _content = State(initialValue: post.content)
    }
    
    private var trimmedContent: String {
        content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
    
    private var isSaving: Bool {
        viewModel.editingPostId == post.id
    }
    
    private var canSave: Bool {
        !trimmedContent.isEmpty &&
        content.count <= 500 &&
        trimmedContent != post.content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                
                Text("Post")
                    .font(.headline)
                
                TextEditor(text: $content)
                    .frame(height: 200)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .disabled(isSaving)
                
                HStack {
                    
                    Spacer()
                    
                    Text("\(content.count)/500")
                        .font(.caption)
                        .foregroundStyle(
                            content.count > 500
                            ? Color.red
                            : Color.secondary
                        )
                }
                
                if trimmedContent.isEmpty {
                    Text("Post Content cannot be empty.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                if let errorMessage = viewModel.editErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task {
                            let didSave = await viewModel.updatePost(
                                postId: post.id,
                                content: content
                            )
                            
                            if didSave {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isSaving {
                                ProgressView()
                            }
                            
                            Text(isSaving ? "Saving..." : "Save")
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                viewModel.clearEditError()
            }
            .onChange(of: content) { _, _ in
                viewModel.clearEditError()
            }
        }
    }
}
