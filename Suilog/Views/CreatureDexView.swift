//
//  CreatureDexView.swift
//  Suilog
//
//  生き物図鑑。全国共通の生き物マスターに対して、ユーザーが「会った」と
//  自己申告した生き物を集めていく。館ごとの飼育リストには依存しない。
//

import SwiftUI
import SwiftData

struct CreatureDexView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var creatureStore: CreatureStore
    @Query private var sightings: [CreatureSighting]

    @State private var searchText = ""
    @State private var selectedCreature: Creature?

    private var theme: Theme { themeManager.currentTheme }

    private var seenIds: Set<String> {
        CreatureCollection.seenIds(from: sightings)
    }

    /// 検索中は名前で絞り込み、未発見でも名前を表示する
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

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        progressHeader
                        searchCard
                        ForEach(filteredGroups, id: \.category) { group in
                            categorySection(group.category, creatures: group.creatures)
                        }
                    }
                    .padding(.horizontal, SuiSpacing.screenHorizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("生き物図鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.primaryColor)
                }
            }
            .sheet(item: $selectedCreature) { creature in
                CreatureDetailSheet(
                    creature: creature,
                    sighting: sightings.first { $0.creatureId == creature.id },
                    theme: theme,
                    onMark: { markSeen(creature) },
                    onUnmark: { unmark(creature) }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        let seenCount = seenIds.count
        let total = creatureStore.totalCount
        let rate = CreatureCollection.completionRate(seenCount: seenCount, totalCount: total)

        return SuiCard(radius: SuiRadius.cardLarge, padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(seenCount)")
                        .font(SuiFont.stat)
                        .foregroundColor(theme.primaryColor)
                    Text("/ \(total) 種 を発見")
                        .font(SuiFont.body)
                        .foregroundColor(SuiColor.midText)
                    Spacer()
                    Text("\(Int(rate * 100))%")
                        .font(SuiFont.bodyMedium)
                        .foregroundColor(theme.primaryColor)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "#EEF4F8"))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [theme.primaryColor, theme.primaryLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(rate))
                    }
                }
                .frame(height: 8)
                Text("水族館でいろんな生き物に会って、図鑑を埋めよう！")
                    .font(SuiFont.caption)
                    .foregroundColor(SuiColor.subText)
            }
        }
    }

    private var searchCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SuiColor.subText)
            TextField("生き物を探す（会った生き物を記録）", text: $searchText)
                .font(SuiFont.body)
                .foregroundColor(SuiColor.heading)
                .autocorrectionDisabled()
            if isSearching {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SuiColor.subText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: SuiRadius.cardSmall, style: .continuous)
                .fill(SuiColor.cardSurface)
        )
        .suiShadow(.card)
    }

    // MARK: - Sections

    private func categorySection(_ category: CreatureCategory, creatures: [Creature]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let seenInCategory = creatures.filter { seenIds.contains($0.id) }.count
            SectionHeader(category.displayName) {
                Text("\(seenInCategory) / \(creatures.count)")
                    .font(SuiFont.label)
                    .foregroundColor(SuiColor.subText)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(creatures) { creature in
                    creatureCell(creature)
                }
            }
        }
    }

    private func creatureCell(_ creature: Creature) -> some View {
        let seen = seenIds.contains(creature.id)
        // 検索中は未発見でも名前を出して探しやすくする
        let revealName = seen || isSearching

        return Button {
            selectedCreature = creature
        } label: {
            VStack(spacing: 6) {
                Text(seen ? creature.emoji : "？")
                    .font(.system(size: 30))
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(seen ? theme.primaryBg : SuiColor.fieldBg)
                    )
                    .opacity(seen ? 1 : 0.6)
                Text(revealName ? creature.name : "？？？")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(seen ? SuiColor.heading : SuiColor.subText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func markSeen(_ creature: Creature) {
        CreatureCollection.markSeen(
            creatureId: creature.id,
            context: modelContext,
            existing: sightings
        )
        try? modelContext.save()
    }

    private func unmark(_ creature: Creature) {
        CreatureCollection.unmark(
            creatureId: creature.id,
            context: modelContext,
            existing: sightings
        )
        try? modelContext.save()
    }
}

// MARK: - 生き物詳細シート

private struct CreatureDetailSheet: View {
    let creature: Creature
    let sighting: CreatureSighting?
    let theme: Theme
    let onMark: () -> Void
    let onUnmark: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var isSeen: Bool { sighting != nil }

    var body: some View {
        ZStack {
            theme.primaryBg.ignoresSafeArea()

            VStack(spacing: 16) {
                Text(creature.emoji)
                    .font(.system(size: 72))
                    .opacity(isSeen ? 1 : 0.5)

                VStack(spacing: 4) {
                    Text(creature.name)
                        .font(SuiFont.screenTitle)
                        .foregroundColor(SuiColor.heading)
                    Text(creature.nameEn)
                        .font(SuiFont.label)
                        .foregroundColor(SuiColor.subText)
                }

                Text(creature.category.displayName)
                    .font(SuiFont.caption)
                    .foregroundColor(theme.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.primaryBg))

                if let sighting {
                    Text("\(formattedDate(sighting.firstSeenDate)) に発見"
                         + (sighting.aquariumName.isEmpty ? "" : "\n（\(sighting.aquariumName)）"))
                        .font(SuiFont.caption)
                        .foregroundColor(SuiColor.midText)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    if isSeen { onUnmark() } else { onMark() }
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSeen ? "checkmark.circle.fill" : "plus.circle")
                        Text(isSeen ? "発見済み（取り消す）" : "会った！ 記録する")
                            .font(SuiFont.bodyMedium)
                    }
                    .foregroundColor(isSeen ? theme.primaryColor : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                            .fill(isSeen ? SuiColor.cardSurface : theme.primaryColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: SuiRadius.button, style: .continuous)
                                    .strokeBorder(isSeen ? theme.primaryLight : Color.clear, lineWidth: 1.5)
                            )
                    )
                }
                .accessibilityIdentifier("creature.toggleSeenButton")
            }
            .padding(20)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}

#Preview {
    CreatureDexView()
        .modelContainer(for: CreatureSighting.self, inMemory: true)
        .environmentObject(ThemeManager())
        .environmentObject(CreatureStore())
}
