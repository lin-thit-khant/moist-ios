//
//  PostRowView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import SwiftUI

struct PostRowView: View {

    let post: Post
    let currentUserId: UUID?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onMove: (() -> Void)?
    
    @State private var isShowingDeleteConfirmation = false

    init(
        post: Post,
        currentUserId: UUID? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMove: (() -> Void)? = nil
    ) {
        self.post = post
        self.currentUserId = currentUserId
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onMove = onMove
    }
    
    private var authorDisplayName: String {
        let name = post.author?.displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""

        return name.isEmpty
            ? (post.author?.username ?? "Moist User")
            : name
    }

    private var authorUsername: String {
        if let username = post.author?.username {
            return "@\(username)"
        }

        return "@unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 10) {

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {

                    NavigationLink {
                        AuthorProfileView(userId: post.userId)
                    } label: {

                        VStack(alignment: .leading, spacing: 3) {

                            Text(authorDisplayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(authorUsername)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Text(post.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                
                if let currentUserId,
                   currentUserId == post.userId,
                   (onEdit != nil || onDelete != nil || onMove != nil) {
                    
                    Menu {
                        if let onEdit {
                            Button {
                                onEdit()
                            } label: {
                                Label("Edit Post", systemImage: "pencil")
                            }
                        }
                        
                        if onDelete != nil {
                            Button(role: .destructive) {
                                isShowingDeleteConfirmation = true
                            } label: {
                                Label("Delete Post", systemImage: "trash")
                            }
                        }
                        
                        if let onMove {
                            Button {
                                onMove()
                            } label: {
                                Label("Move to Project", systemImage: "folder")
                            }
                        }
                        
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                    .accessibilityLabel("Post options")
                }
            }

            Text(post.content)
                .font(.body)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            if let project = post.project {
                NavigationLink {
                    ProjectRouteView(projectId: project.id)
                } label: {
                    Label(project.name, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            .thinMaterial,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .confirmationDialog(
            "Delete this post?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            
            Button("Cancel", role: .cancel) {
                
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}
