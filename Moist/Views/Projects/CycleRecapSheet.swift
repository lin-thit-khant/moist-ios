//
//  CycleRecapSheet.swift
//  Rawdea
//

import SwiftUI

/// A finished cycle at a glance.
struct CycleRecapSheet: View {

    let recap: CycleRecap
    let onSeePosts: () -> Void

    @Environment(\.dismiss) private var dismiss

    private func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year())
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: RawdeaSpacing.md) {

                    Text(dates)
                        .font(RawdeaTypography.postBody)
                        .foregroundStyle(RawdeaPalette.primaryText)

                    Text(recap.postCount == 1 ? "1 post" : "\(recap.postCount) posts")
                        .font(RawdeaTypography.postBody)
                        .foregroundStyle(RawdeaPalette.primaryText)

                    if !recap.moves.isEmpty {
                        heading("Stage moves")
                        ForEach(recap.moves) { move in
                            entry(move.marker, date: move.createdAt)
                        }
                    }

                    if !recap.decisions.isEmpty {
                        heading("Decisions")
                        ForEach(recap.decisions) { post in
                            entry(post.content, date: post.createdAt)
                        }
                    }

                    RawdeaPillButton(
                        title: "See all Cycle \(recap.number) posts",
                        isPrimary: true
                    ) {
                        onSeePosts()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, RawdeaSpacing.screenInset)
                .padding(.vertical, RawdeaSpacing.md)
            }
            .background(RawdeaPalette.canvas.ignoresSafeArea())
            .navigationTitle("Cycle \(recap.number) recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var dates: String {
        guard let shipped = recap.shippedAt else {
            return "Started \(day(recap.startedAt))"
        }
        return "\(day(recap.startedAt)) to \(day(shipped))"
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(RawdeaTypography.secondary.weight(.medium))
            .foregroundStyle(RawdeaPalette.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private func entry(_ text: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(RawdeaTypography.postBody)
                .foregroundStyle(RawdeaPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(day(date))
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
