//
//  SafetyInformationView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import SwiftUI

// MARK: - Configure Before App Store Submission

enum RawdeaPublicContact {

    // Replace with your real, monitored email.
    static let email = ""

    // Replace with working HTTPS pages.
    static let supportURL = ""
    static let privacyPolicyURL = ""
}

// MARK: - Public Safety Information

struct SafetyInformationView: View {

    var body: some View {

        List {

            Section("About Rawdea") {

                Text(
                    """
                    Rawdea is a space for sharing ideas, thoughts, and creative work.

                    Everyone should be able to participate without harassment, intimidation, or unwanted abuse.
                    """
                )
            }

            Section("Community Guidelines") {

                guideline(
                    "Respect other people",
                    "Do not harass, bully, threaten, stalk, or intimidate other users."
                )

                guideline(
                    "No hateful or discriminatory attacks",
                    "Do not attack or dehumanize people based on protected characteristics."
                )

                guideline(
                    "No dangerous encouragement",
                    "Do not promote violence or encourage others to harm themselves."
                )

                guideline(
                    "Respect privacy",
                    "Do not publish someone else's private information without permission."
                )

                guideline(
                    "No explicit sexual exploitation",
                    "Do not share sexually exploitative material or nonconsensual intimate content."
                )

                guideline(
                    "No spam or scams",
                    "Do not impersonate others, run scams, solicit passwords, or repeatedly publish unwanted promotions."
                )

                guideline(
                    "Respect intellectual property",
                    "Share content you have the right to publish. Do not deliberately infringe another person's rights."
                )
            }

            Section("Reporting and Moderation") {

                Text(
                    """
                    You can report posts, comments, and accounts through the available Report actions.

                    You can also block abusive users. We review reports and may hide content or suspend accounts that violate these guidelines.

                    Reports are private, and submitting a report does not automatically prove a violation.
                    """
                )
            }

            Section("Appeals") {

                Text(
                    """
                    If you believe a moderation decision was incorrect, you can submit an appeal from Safety & Support in your profile.

                    Suspended accounts can still sign in and submit an appeal.
                    """
                )
            }

            Section("Contact the Developer") {

                if !RawdeaPublicContact.email.isEmpty,
                   let url = URL(
                    string:
                        "mailto:\(RawdeaPublicContact.email)"
                   ) {

                    Link(
                        "Email Rawdea Support",
                        destination: url
                    )

                    Text(RawdeaPublicContact.email)
                        .font(.caption)
                        .textSelection(.enabled)

                } else {

                    Text(
                        "Developer email must be configured before release."
                    )
                    .foregroundStyle(.secondary)
                }

                if let url = URL(
                    string: RawdeaPublicContact.supportURL
                ),
                   url.scheme == "https" {

                    Link(
                        "Support Website",
                        destination: url
                    )
                }
            }

            Section("Privacy") {

                if let url = URL(
                    string: RawdeaPublicContact.privacyPolicyURL
                ),
                   url.scheme == "https" {

                    Link(
                        "Read Privacy Policy",
                        destination: url
                    )

                } else {

                    Text(
                        "Privacy policy URL must be configured before release."
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Community & Safety")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideline(
        _ title: String,
        _ explanation: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 5) {

            Text(title)
                .fontWeight(.semibold)

            Text(explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
