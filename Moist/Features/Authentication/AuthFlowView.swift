//
//  AuthFlowView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import Foundation
import SwiftUI

struct AuthFlowView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ProgressView("Loading Moist...")
            case .signedOut:
                WelcomeView()
            case .signedIn:
                HomeView()
            }
        }
    }
}
