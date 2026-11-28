//
//  ProfileViewModel.swift
//  Moist
//
//  Created by Lin Thit Khant on 1/11/2569 BE.
//

import Foundation
import Supabase
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?
    
    private let profileService: ProfileService
    
    init(profileService: ProfileService = ProfileService()) {
        self.profileService = profileService
    }
    

    func loadProfile(userId: UUID? = nil) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = nil

        // A previously viewed external profile must
        // not remain visible while access is checked.
        if userId != nil {
            profile = nil
        }

        defer {
            isLoading = false
        }

        do {
            let loadedProfile: Profile

            if let userId {
                loadedProfile = try await profileService
                    .fetchProfile(userId: userId)
            } else {
                loadedProfile = try await profileService
                    .fetchCurrentProfile()
            }

            try Task.checkCancellation()

            profile = loadedProfile

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(displayName: String, username: String, bio: String) async {
        guard !isSaving else { return }
        
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        
        defer {
            isSaving = false
        }
        
        do {
            profile = try await profileService.updateCurrentProfiel(
                displayName: displayName,
                username: username,
                bio: bio
            )
            
            statusMessage = "Profile updated successfully."
        } catch {
            // 23505: the unique username constraint.
            errorMessage = (error as? PostgrestError)?.code == "23505"
                ? "That username is taken."
                : PublicationErrorMessage.from(error)
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        statusMessage = nil
    }
}
