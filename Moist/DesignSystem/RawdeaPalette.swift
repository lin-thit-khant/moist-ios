//
//  RawdeaPalette.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//


import SwiftUI
import UIKit

enum RawdeaPalette {

    // MARK: - Main surfaces

    static let canvas = adaptive(
        light: 0xFFFFFF,
        dark: 0x101010
    )

    static let surface = adaptive(
        light: 0xF2F2F2,
        dark: 0x1E1E1E
    )

    // MARK: - Typography

    static let primaryText = adaptive(
        light: 0x000000,
        dark: 0xF3F5F7
    )

    static let secondaryText = adaptive(
        light: 0x6C6C70,
        dark: 0x8E8E93,
        increasedLight: 0x48484A,
        increasedDark: 0xD2D7DC
    )

    // MARK: - Brand

    static let accent = adaptive(
        light: 0xB2394B,
        dark: 0xC4505F
    )

    // Use on top of the accent fill.
    // Light: white on Fresh Cut Red.
    // Dark: charcoal on Soft Rose.

    static let onAccent = adaptive(
        light: 0xFFFFFF,
        dark: 0xFFFFFF
    )

    static let softBlush = adaptive(
        light: 0xF4DEDF,
        dark: 0x30262B
    )

    // MARK: - Monochrome fill

    // Primary actions are charcoal in Light Mode and
    // near-white in Dark Mode. The brand accent is kept
    // for Projects and likes.

    static let primaryFill = adaptive(
        light: 0x000000,
        dark: 0xF3F5F7
    )

    // Use on top of primaryFill.

    static let onPrimaryFill = adaptive(
        light: 0xFFFFFF,
        dark: 0x101010
    )

    // MARK: - Dividers and borders

    static let divider = adaptive(
        light: 0xE5E5EA,
        dark: 0x2C2C2C
    )

    // Quiet Outline Activity:
    // subtle normally, stronger with Increase Contrast.

    static let activityOutline = adaptive(
        light: 0xE5E5EA,
        dark: 0x2C2C2C,
        increasedLight: 0x858D95,
        increasedDark: 0x7D858E
    )

    // Soft Surface Projects:
    // no visible outline normally;
    // accessible outline with Increase Contrast.

    static let projectOutline = Color(
        uiColor: UIColor { traits in

            guard traits.accessibilityContrast == .high else {
                return UIColor.clear
            }

            let hex: UInt32 =
                traits.userInterfaceStyle == .dark
                ? 0x7D858E
                : 0x858D95

            return makeUIColor(hex)
        }
    )

    // MARK: - Stage track

    // The current stage stays white in both appearances.
    static let stageCurrent = Color.white

    static let stageOutline = adaptive(
        light: 0xCFCFD4,
        dark: 0xCFCFD4,
        increasedLight: 0x48484A,
        increasedDark: 0xCFCFD4
    )

    // MARK: - Semantic status

    // Status colors remain distinct from branding.
    // Never communicate errors by color alone.

    static let danger = Color(uiColor: .systemRed)
    static let warning = Color(uiColor: .systemOrange)
    static let success = Color(uiColor: .systemGreen)

    // MARK: - Adaptive color factory

    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        increasedLight: UInt32? = nil,
        increasedDark: UInt32? = nil
    ) -> Color {

        Color(
            uiColor: UIColor { traits in

                let isDark =
                    traits.userInterfaceStyle == .dark

                let increased =
                    traits.accessibilityContrast == .high

                let hex: UInt32

                if isDark {
                    hex = increased
                        ? (increasedDark ?? dark)
                        : dark
                } else {
                    hex = increased
                        ? (increasedLight ?? light)
                        : light
                }

                return makeUIColor(hex)
            }
        )
    }

    private static func makeUIColor(
        _ hex: UInt32
    ) -> UIColor {

        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
