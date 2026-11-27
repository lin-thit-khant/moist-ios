//
//  RawdeaTabBar.swift
//  Rawdea
//

import SwiftUI

/// A floating pill of five symbols. Create sits in a tile and
/// never becomes selected.
struct RawdeaTabBar: View {

    let selection: Binding<RawdeaTab>
    let selected: RawdeaTab
    let unreadCount: Int

    private static let items: [(tab: RawdeaTab, title: String, symbol: String, active: String)] = [
        (.home, "Home", "house", "house.fill"),
        (.explore, "Explore", "magnifyingglass", "magnifyingglass"),
        (.create, "Create", "plus", "plus"),
        (.activity, "Activity", "bell", "bell.fill"),
        (.profile, "Profile", "person", "person.fill")
    ]

    var body: some View {

        HStack(spacing: 0) {
            ForEach(Self.items, id: \.title) { item in
                button(item.tab, item.title, item.tab == selected ? item.active : item.symbol)
            }
        }
        .padding(.horizontal, RawdeaSpacing.xs)
        // The shadow belongs to the pill alone, not its symbols.
        .background {
            Capsule()
                .fill(RawdeaPalette.canvas)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
        }
        .overlay {
            Capsule().strokeBorder(RawdeaPalette.activityOutline)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, RawdeaSpacing.md)
        .padding(.top, RawdeaSpacing.xs)
        // Symbols stay a fixed size, as in a system tab bar.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .contain)
    }

    private func button(
        _ tab: RawdeaTab,
        _ title: String,
        _ symbol: String
    ) -> some View {

        let isSelected = tab == selected

        return Button {
            selection.wrappedValue = tab
        } label: {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tab == .create
                    ? RawdeaPalette.primaryText
                    : isSelected
                        ? RawdeaPalette.accent
                        : RawdeaPalette.secondaryText)
                .frame(
                    width: tab == .create ? 54 : nil,
                    height: tab == .create ? 40 : nil
                )
                .background {
                    if tab == .create {
                        RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)
                            .fill(RawdeaPalette.surface)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if tab == .activity, unreadCount > 0, !isSelected {
                        Circle()
                            .fill(RawdeaPalette.accent)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(
            tab == .activity && unreadCount > 0 ? "\(unreadCount) unread" : ""
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: symbol)
        }
    }
}
