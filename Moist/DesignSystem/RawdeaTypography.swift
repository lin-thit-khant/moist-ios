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

    static let postBody: Font = .body

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

    static let cardRadius: CGFloat = 14

    static let buttonRadius: CGFloat = 12

    static let minimumTouchTarget: CGFloat = 44
}
