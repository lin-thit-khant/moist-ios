//
//  ProfileViewModel.swift
//  Moist
//
//  Created by Lin Thit Khant on 1/11/2569 BE.
//

import Foundation
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
    
    func loadProfile() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            profile = try await profileService.fetchCurrentProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateProfile(displayName: String, bio: String) async {
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
                bio: bio
            )
            
            statusMessage = "Profile updated successfully."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        statusMessage = nil
    }
}
