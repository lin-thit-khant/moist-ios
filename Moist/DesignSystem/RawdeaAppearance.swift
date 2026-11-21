//
//  RawdeaAppearance.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//


import SwiftUI

enum RawdeaAppearance: String, CaseIterable, Identifiable {

    case system
    case light
    case dark

    static let storageKey =
        "rawdea.appearance.preference"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            return "System"

        case .light:
            return "Light"

        case .dark:
            return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system:
            return "iphone"

        case .light:
            return "sun.max"

        case .dark:
            return "moon"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil

        case .light:
            return .light

        case .dark:
            return .dark
        }
    }
}

