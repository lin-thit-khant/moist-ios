//
//  MoistApp.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//


import SwiftUI

@main
struct RawdeaApp: App {

    var body: some Scene {
        WindowGroup {
            RawdeaAppearanceRootView()
        }
    }
}

private struct RawdeaAppearanceRootView: View {

    @AppStorage(RawdeaAppearance.storageKey)
    private var selectedAppearance =
        RawdeaAppearance.system.rawValue

    private var activeAppearance: RawdeaAppearance {
        RawdeaAppearance(
            rawValue: selectedAppearance
        ) ?? .system
    }

    var body: some View {
        AuthFlowView()
            .tint(RawdeaPalette.primaryText)
            .preferredColorScheme(
                activeAppearance.preferredColorScheme
            )
    }
}

