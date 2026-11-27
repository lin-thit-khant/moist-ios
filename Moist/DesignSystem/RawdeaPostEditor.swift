//
//  RawdeaPostEditor.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 22/11/2569 BE.
//


import SwiftUI

struct RawdeaPostEditor: View {

    @Binding var content: String

    let placeholder: String
    let isEnabled: Bool
    let autoFocus: Bool
    /// Text on the bare screen, without the field surface.
    let isPlain: Bool

    @FocusState private var isEditorFocused: Bool

    init(
        content: Binding<String>,
        placeholder: String = "What's on your mind?",
        isEnabled: Bool = true,
        autoFocus: Bool = true,
        isPlain: Bool = false
    ) {
        self._content = content
        self.placeholder = placeholder
        self.isEnabled = isEnabled
        self.autoFocus = autoFocus
        self.isPlain = isPlain
    }

    private var draft: RawdeaPostDraft {
        RawdeaPostDraft(content: content)
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.sm
        ) {

            ZStack(alignment: .topLeading) {

                TextEditor(text: $content)
                    .font(RawdeaTypography.postBody)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .scrollContentBackground(.hidden)
                    // A plain editor cancels TextEditor's own
                    // inset so text lines up with the screen.
                    .padding(.horizontal, isPlain ? -5 : RawdeaSpacing.xs)
                    .padding(.vertical, isPlain ? 0 : RawdeaSpacing.xs)
                    .frame(minHeight: isPlain ? 76 : 230)
                    .focused($isEditorFocused)
                    .disabled(!isEnabled)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Post content")
                    .accessibilityHint(
                        "Enter up to 500 characters"
                    )

                if content.isEmpty {

                    Text(placeholder)
                        .font(RawdeaTypography.postBody)
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .padding(
                            .horizontal,
                            isPlain ? 0 : RawdeaSpacing.md
                        )
                        .padding(
                            .top,
                            isPlain ? RawdeaSpacing.xs : RawdeaSpacing.md
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background {

                if !isPlain {

                    fieldShape
                        .fill(RawdeaPalette.surface)
                }
            }
            .overlay {

                if !isPlain {

                    fieldShape
                        .strokeBorder(
                            RawdeaPalette.activityOutline,
                            lineWidth: 1
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

            // MARK: - Character status

            HStack(
                alignment: .firstTextBaseline,
                spacing: RawdeaSpacing.xs
            ) {

                if draft.isOverLimit {

                    Label(
                        "Over the limit by \(-draft.remainingCharacters)",
                        systemImage: "exclamationmark.circle"
                    )
                    .foregroundStyle(
                        RawdeaPalette.danger
                    )

                } else if draft.remainingCharacters == 0 {

                    Text("Character limit reached")
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )

                } else if !isPlain {

                    Text("Share a thought in your own words.")
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                }

                Spacer(minLength: 0)

                Text(
                    "\(draft.characterCount)/\(RawdeaPostDraft.characterLimit)"
                )
                .foregroundStyle(
                    draft.isOverLimit
                    ? RawdeaPalette.danger
                    : RawdeaPalette.secondaryText
                )
                .accessibilityLabel(
                    "\(draft.characterCount) of \(RawdeaPostDraft.characterLimit) characters"
                )
            }
            .font(RawdeaTypography.caption)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }

        // Focus after SwiftUI has presented
        // the editor, not during initialization.
        .task {

            guard autoFocus && isEnabled else {
                return
            }

            await Task.yield()

            isEditorFocused = true
        }
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: RawdeaSpacing.cardRadius,
            style: .continuous
        )
    }
}
