//
//  PostRowView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import SwiftUI

struct PostRowView: View {

    let post: Post

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
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}
