//
//  RawdeaTextLength.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 25/11/2569 BE.
//

import Foundation

enum RawdeaTextLength {

    // Match PostgreSQL char_length for
    // valid UTF-8 text.

    nonisolated static func count(
        _ text: String
    ) -> Int {

        text.unicodeScalars.count
    }
}

