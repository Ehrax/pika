import SwiftUI

struct SettingsCategoryColumn: View {
    let selectedCategory: SettingsCategory
    let hasChanges: Bool
    let onSelect: (SettingsCategory) -> Void

    var body: some View {
        BillbiSecondarySidebarColumn(
            title: "Settings",
            subtitle: hasChanges ? "Unsaved changes" : "Workspace preferences",
            sectionTitle: "Categories",
            wrapsContentInScrollView: false
        ) {
            EmptyView()
        } controls: {
            EmptyView()
        } content: {
            VStack(spacing: 0) {
                Divider()
                categoryList
                    .padding(.top, BillbiSpacing.md)
            }
        }
    }

    private var categoryList: some View {
        List {
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    onSelect(category)
                } label: {
                    SettingsCategoryRow(category: category, isSelected: selectedCategory == category)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: BillbiSpacing.sm, bottom: 1, trailing: BillbiSpacing.sm))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BillbiColor.surface)
    }
}

private struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: category.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(BillbiTypography.body.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)

                Text(category.detail)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)
        }
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: isSelected)
    }
}
