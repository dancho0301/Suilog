//
//  WidgetSnapshotBuilderTests.swift
//  SuilogTests
//
//  訪問記録からウィジェット用のスナップショットを作る処理のテスト。
//

import Testing
import SwiftData
import Foundation
@testable import Suilog

@Suite(.serialized)
struct WidgetSnapshotBuilderTests {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Aquarium.self, VisitRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    private func makeAquarium(_ name: String, in context: ModelContext) -> Aquarium {
        let aquarium = Aquarium(name: name, latitude: 35.0, longitude: 139.0, description: "", region: "関東")
        context.insert(aquarium)
        return aquarium
    }

    @MainActor
    private func makeVisit(
        _ aquarium: Aquarium?,
        daysAgo: Int,
        type: CheckInType = .manual,
        id: UUID = UUID(),
        in context: ModelContext
    ) -> VisitRecord {
        let date = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(TimeInterval(-daysAgo * 86_400))
        let visit = VisitRecord(id: id, visitDate: date, checkInType: type, aquarium: aquarium)
        context.insert(visit)
        return visit
    }

    private let now = Date(timeIntervalSince1970: 1_700_100_000)

    @Test("訪問が 0 件でも作れる（件数 0・最近の訪問は空）")
    @MainActor
    func testEmpty() {
        let snapshot = WidgetSnapshot(visits: [], theme: .defaultTheme, isPro: true, now: now)
        #expect(snapshot.visitedAquariumCount == 0)
        #expect(snapshot.visitCount == 0)
        #expect(snapshot.recentVisits.isEmpty)
        #expect(snapshot.updatedAt == now)
    }

    @Test("訪問館数は重複しない水族館の数、訪問回数は記録の数")
    @MainActor
    func testCounts() throws {
        let context = try makeContext()
        let kaiyukan = makeAquarium("海遊館", in: context)
        let sunshine = makeAquarium("サンシャイン水族館", in: context)
        let visits = [
            makeVisit(kaiyukan, daysAgo: 1, in: context),
            makeVisit(kaiyukan, daysAgo: 2, in: context),
            makeVisit(sunshine, daysAgo: 3, in: context)
        ]

        let snapshot = WidgetSnapshot(visits: visits, theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.visitedAquariumCount == 2)
        #expect(snapshot.visitCount == 3)
    }

    @Test("最近の訪問は新しい順に最大3件")
    @MainActor
    func testRecentVisitsAreNewestFirstAndLimited() throws {
        let context = try makeContext()
        let names = ["A館", "B館", "C館", "D館", "E館"]
        // daysAgo が小さいほど新しい。わざと順不同で渡す
        let order = [3, 0, 4, 1, 2]
        let visits = order.map { index in
            makeVisit(makeAquarium(names[index], in: context), daysAgo: index, in: context)
        }

        let snapshot = WidgetSnapshot(visits: visits, theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.recentVisits.map(\.aquariumName) == ["A館", "B館", "C館"])
    }

    @Test("チェックインの種類（ゴールド/シルバー）が引き継がれる")
    @MainActor
    func testCheckInType() throws {
        let context = try makeContext()
        let aquarium = makeAquarium("海遊館", in: context)
        let visits = [
            makeVisit(aquarium, daysAgo: 0, type: .location, in: context),
            makeVisit(aquarium, daysAgo: 1, type: .manual, in: context)
        ]

        let snapshot = WidgetSnapshot(visits: visits, theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.recentVisits.map(\.isLocationCheckIn) == [true, false])
    }

    @Test("水族館が消えた記録は名前を「水族館」にし、訪問館数には数えない")
    @MainActor
    func testVisitWithoutAquarium() throws {
        let context = try makeContext()
        let visit = makeVisit(nil, daysAgo: 0, in: context)

        let snapshot = WidgetSnapshot(visits: [visit], theme: .defaultTheme, isPro: true, now: now)

        #expect(snapshot.visitCount == 1)
        #expect(snapshot.visitedAquariumCount == 0)
        #expect(snapshot.recentVisits.map(\.aquariumName) == ["水族館"])
    }

    @Test("同じ日時の記録でも並びが毎回同じ")
    @MainActor
    func testTieBreakIsDeterministic() throws {
        let context = try makeContext()
        let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let a = makeVisit(makeAquarium("A館", in: context), daysAgo: 0, id: idA, in: context)
        let b = makeVisit(makeAquarium("B館", in: context), daysAgo: 0, id: idB, in: context)

        let forward = WidgetSnapshot(visits: [a, b], theme: .defaultTheme, isPro: true, now: now)
        let backward = WidgetSnapshot(visits: [b, a], theme: .defaultTheme, isPro: true, now: now)

        #expect(forward.recentVisits == backward.recentVisits)
    }

    @Test("Pro の有無と、テーマの色が反映される")
    @MainActor
    func testProAndThemeColors() {
        let withPro = WidgetSnapshot(visits: [], theme: .sixteenBit, isPro: true, now: now)
        let withoutPro = WidgetSnapshot(visits: [], theme: .sixteenBit, isPro: false, now: now)

        #expect(withPro.isPro == true)
        #expect(withoutPro.isPro == false)
        #expect(withPro.primaryHex == Theme.sixteenBit.primaryColorHex)
        #expect(withPro.tankTopHex == Theme.sixteenBit.tankTopHex ?? Theme.sixteenBit.primaryColorHex)
        #expect(withPro.tankBottomHex == Theme.sixteenBit.tankBottomHex ?? Theme.sixteenBit.primaryColorHex)
    }
}
