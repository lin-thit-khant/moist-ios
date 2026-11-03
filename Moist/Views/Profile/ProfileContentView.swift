//
//  ProfileContentView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//

import SwiftUI

struct ProfileContentView: View {
    let profile: Profile

    var body: some View {
        VStack(spacing: 20) {

            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(
                    profile.displayname.isEmpty
                    ? profile.username
                    : profile.displayname
                )
                .font(.title2)
                .fontWeight(.bold)

                Text("@\(profile.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(
                profile.bio.isEmpty
                ? "No bio yet"
                : profile.bio
            )
            .font(.body)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }
}
