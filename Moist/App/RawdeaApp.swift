//
//  MoistApp.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//


import SwiftUI

@main
struct RawdeaApp: App {

    init() {
        // `rawdeaRefreshable` draws the cell instead of this spinner.
        if #available(iOS 18.0, *) {
            UIRefreshControl.appearance().tintColor = .clear
        }
    }

    var body: some Scene {
        WindowGroup {
            RawdeaAppearanceRootView()
        }
    }
}

private struct RawdeaAppearanceRootView: View {

    var body: some View {
        AuthFlowView()
            .tint(RawdeaPalette.primaryText)
    }
}
