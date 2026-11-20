//
//  PublicationErrorMessage.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import Foundation

enum PublicationErrorMessage {

    static func from(_ error: Error) -> String {

        // Supabase may format the PostgREST
        // error differently across versions.
        // Inspect both descriptions for the
        // server's stable error marker.

        let details = """
        \(error.localizedDescription)
        \(String(reflecting: error))
        """.lowercased()

        guard details.contains(
            "rawdea_filter_blocked:"
        ) else {

            return error.localizedDescription
        }

        if details.contains(
            "rawdea_filter_blocked:targeted_threat"
        ) {

            return """
            This text contains language that may be interpreted as a direct threat. Please revise it before publishing.
            """
        }

        if details.contains(
            "rawdea_filter_blocked:self_harm_encouragement"
        ) {

            return """
            Content encouraging another person to harm themselves is not allowed. Please revise your text.
            """
        }

        if details.contains(
            "rawdea_filter_blocked:credential_scam"
        ) {

            return """
            Please remove language requesting passwords or verification codes.
            """
        }

        if details.contains(
            "rawdea_filter_blocked:excessive_links"
        ) {

            return """
            This submission contains too many links. Please reduce the number of links and try again.
            """
        }

        if details.contains(
            "rawdea_filter_blocked:invalid_length"
        ) {

            return """
            This text is too long. Display names must be 80 characters or fewer.
            """
        }

        return """
        This submission needs revision before it can be published. Please review the wording and try again.
        """
    }
}
