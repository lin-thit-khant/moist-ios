//
//  RawdeaTypography.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//


import SwiftUI

// MARK: - Typography

enum RawdeaTypography {

    static let screenTitle: Font = .system(
        .title2,
        design: .default,
        weight: .bold
    )

    // Rawdea's name at the top of Home.
    static let wordmark: Font = .system(
        .title3,
        design: .default,
        weight: .heavy
    )

    static let sectionTitle: Font = .system(
        .headline,
        design: .default,
        weight: .semibold
    )

    static let authorName: Font = .system(
        .subheadline,
        design: .default,
        weight: .semibold
    )

    static let postBody: Font = .subheadline

    static let body: Font = .body

    static let secondary: Font = .subheadline

    static let metadata: Font = .footnote

    static let caption: Font = .caption

    static let button: Font = .system(
        .headline,
        design: .default,
        weight: .semibold
    )
}

// MARK: - Layout

enum RawdeaSpacing {

    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32

    static let screenInset: CGFloat = 16

    static let cardPadding: CGFloat = 16

    // How far a two-line header name's target reaches past its text.
    static let readerNameReach: CGFloat = 24

    static let cardRadius: CGFloat = 14

    static let buttonRadius: CGFloat = 12

    // Welcome and sign-in screens.
    static let authInset: CGFloat = 24
    static let authButtonHeight: CGFloat = 52

    static let minimumTouchTarget: CGFloat = 44

    // Avatar column beside a post in a feed.
    static let avatarColumn: CGFloat = 40

    // Where a feed divider starts: inset, avatar and gap.
    static let feedDividerInset: CGFloat = 68
}
