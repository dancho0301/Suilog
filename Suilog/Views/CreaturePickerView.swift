//
//  CreaturePickerView.swift
//  Suilog
//
//  「会った生き物」を複数選択するピッカー。チェックイン記録時に使う。
//

import SwiftUI

struct CreaturePickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var creatureStore: CreatureStore
    @Environment(\.dismiss) private var dismiss

    /// 選択中の生き物ID（呼び出し元とバインド）
    @Binding var selectedIds: Set<String>

    @State private var searchText = ""

    private var theme: Theme { themeManager.currentTheme }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func matches(_ creature: Creature) -> Bool {
        guard isSearching else { return true }
        return creature.name.localizedCaseInsensitiveContains(searchText)
            || creature.nameEn.localizedCaseInsensitiveContains(searchText)
    }

    private var filteredGroups: [(category: CreatureCategory, creatures: [Creature])] {
        creatureStore.groupedByCategory
            .map { (category: $0.category, creatures: $0.creatures.filter(matches)) }
            .filter { !$0.creatures.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.category) { group in
                    Section(group.category.displayName) {
                        ForEach(group.creatures) { creature in
                            row(creature)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "生き物を探す")
            .navigationTitle("会った生き物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primaryColor)
                }
            }
        }
    }

    private func row(_ creature: Creature) -> some View {
        let selected = selectedIds.contains(creature.id)
        return Button {
            if selected {
                selectedIds.remove(creature.id)
            } else {
                selectedIds.insert(creature.id)
            }
        } label: {
            HStack(spacing: 12) {
                Text(creature.emoji)
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(creature.name)
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(SuiColor.heading)
                    Text(creature.nameEn)
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.subText)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? theme.primaryColor : SuiColor.subText)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreaturePickerView(selectedIds: .constant([]))
        .environmentObject(ThemeManager())
        .environmentObject(CreatureStore())
}
