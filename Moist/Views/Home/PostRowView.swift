//
//  PostRowView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//

import SwiftUI

struct PostRowView: View {
    
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading) {
                    
                    Text("Moist User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(post.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text(post.content)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
