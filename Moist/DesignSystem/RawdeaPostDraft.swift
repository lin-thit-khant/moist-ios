//
//  RawdeaPostDraft.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 22/11/2569 BE.
//


import Foundation

struct RawdeaPostDraft {

    static let characterLimit = 500

    let content: String

    var trimmedContent: String {
        content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var characterCount: Int {
        content.count
    }

    var remainingCharacters: Int {
        Self.characterLimit - characterCount
    }

    var isEmpty: Bool {
        trimmedContent.isEmpty
    }

    var isOverLimit: Bool {
        characterCount > Self.characterLimit
    }

    var isValid: Bool {
        !isEmpty && !isOverLimit
    }

    // Raw comparison is intentional.
    // Even whitespace edits must be protected
    // from accidental dismissal.

    func hasUnsavedChanges(
        comparedTo original: String
    ) -> Bool {
        content != original
    }

    // Editing should enable Save only when
    // the submitted, trimmed text changes.

    func hasSubmittableChanges(
        comparedTo original: String
    ) -> Bool {

        isValid &&
        trimmedContent != original.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}
