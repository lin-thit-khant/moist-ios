//
//  EditProfileView.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//

import SwiftUI

struct EditProfileView: View {
    
    @ObservedObject var viewModel: ProfileViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String
    @State private var bio: String
    
    let profile: Profile
    
    init(viewModel: ProfileViewModel, profile: Profile) {
        self.viewModel = viewModel
        self.profile = profile
        
        _displayName = State(initialValue: profile.displayname)
        _bio = State(initialValue: profile.bio)
    }
    
    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isFormValid: Bool {
        bio.count <= 160
    }
    
    var body: some View {
        Form {
            Section("Display Name") {
                TextField("Your display name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            
            Section {
                TextEditor(text: $bio)
                    .frame(minHeight: 120)
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 160 {
                            bio = String(newValue.prefix(160))
                        }
                    }
                
                HStack {
                    Spacer()
                    
                    Text("\(bio.count)/160")
                        .font(.caption)
                        .foregroundStyle(
                            bio.count >= 160 ? .orange : .secondary
                        )
                }
            } header: {
                Text("Bio")
            } footer: {
                Text("Tell people a littel about yourself.")
            }
            
            if let errorMessage = viewModel.errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
            
            if let statusMessage = viewModel.statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            
            Section {
                Button {
                    Task {
                        await viewModel.updateProfile(
                            displayName: trimmedDisplayName,
                            bio: bio
                        )
                        
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        
                        if viewModel.isSaving {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        
                        Text(
                            viewModel.isSaving
                            ? "Saving..."
                            : "Save Changes"
                        )
                        
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving || !isFormValid)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.clearMessages()
                    dismiss()
                }
                .disabled(viewModel.isSaving)
            }
        }
    }
}
