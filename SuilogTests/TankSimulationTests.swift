//
//  TankSimulationTests.swift
//  SuilogTests
//
//  マイ水槽の生き物シミュレーションのテスト
//

import Testing
import Foundation
import CoreGraphics
@testable import Suilog

@MainActor
@Suite
struct TankSimulationTests {

    private let tankSize = CGSize(width: 360, height: 280)

    private func makeSpec(_ name: String, sizeLevel: Int = 3, index: Int = 0) -> TankCreatureSpec {
        TankCreatureSpec(
            id: UUID(),
            creatureName: name,
            sizeLevel: sizeLevel,
            isLocationCheckIn: true,
            colorIndex: index
        )
    }

    /// 指定秒数ぶん 60fps で進める
    private func run(_ simulation: TankSimulation, seconds: Double) {
        let frames = Int(seconds * 60)
        for _ in 0..<frames {
            simulation.advance(by: 1.0 / 60.0, size: tankSize)
        }
    }

    // MARK: - プロファイル

    @Test("生き物の種類に応じて動きのスタイルが決まる")
    func testProfileStyle() {
        #expect(SwimProfile.forCreature("Jellyfish").style == .drift)
        #expect(SwimProfile.forCreature("Clione").style == .drift)
        #expect(SwimProfile.forCreature("Crab").style == .crawl)
        #expect(SwimProfile.forCreature("Butterfly").style == .flutter)
        #expect(SwimProfile.forCreature("Shark").style == .swim)
        #expect(SwimProfile.forCreature("fish.fill").style == .swim)
        #expect(SwimProfile.forCreature("未知の生き物").style == .swim)
    }

    @Test("大型の生き物は小魚よりゆっくり泳ぐ")
    func testLargeCreaturesAreSlower() {
        #expect(SwimProfile.forCreature("Whale Shark").cruiseSpeed < SwimProfile.forCreature("Tuna").cruiseSpeed)
        #expect(SwimProfile.forCreature("Whale").turnDuration > SwimProfile.forCreature("Clownfish").turnDuration)
    }

    @Test("すべてのプロファイルの範囲が妥当")
    func testProfilesAreValid() {
        let names = [
            "Arapaima", "Arowana", "Beluga Whale", "Biwa Catfish", "Butterfly", "Clione", "Clownfish",
            "Coelacanth", "Coral Fish", "Crab", "Deep-sea Fish", "Dolphin", "Dugong", "Eel",
            "Finlessporpoise", "Freshwater Fish", "Giant Salamander", "Hucho", "Jellyfish", "Manatee",
            "Mekonggiantcatfish", "Orca", "Penguin", "Piranha", "Pufferfish", "Sea Turtle", "SeaGull",
            "SeaLion", "Seal", "Shark", "Sturgeon", "Tuna", "Walrus", "Whale Shark", "Whale", "salmon"
        ]
        for name in names {
            let p = SwimProfile.forCreature(name)
            #expect(p.cruiseSpeed > 0, "\(name)")
            #expect(p.turnDuration > 0, "\(name)")
            #expect(p.tailFrequency > 0, "\(name)")
            #expect(p.verticalBand.lowerBound >= 0 && p.verticalBand.upperBound <= 1, "\(name)")
        }
    }

    // MARK: - 同期

    @Test("訪問記録を追加しても既存の生き物の状態は保たれる")
    func testSyncKeepsExistingState() {
        let simulation = TankSimulation()
        let first = makeSpec("Shark")
        simulation.sync([first])
        run(simulation, seconds: 3)

        let before = simulation.creatures.first { $0.id == first.id }
        #expect(before?.isActive == true)

        simulation.sync([first, makeSpec("Tuna", index: 1)])
        let after = simulation.creatures.first { $0.id == first.id }
        #expect(simulation.creatures.count == 2)
        #expect(after?.x == before?.x)
        #expect(after?.y == before?.y)
        #expect(after?.depth == before?.depth)
    }

    @Test("訪問記録を削除すると生き物も消える")
    func testSyncRemovesCreature() {
        let simulation = TankSimulation()
        let a = makeSpec("Shark")
        let b = makeSpec("Tuna", index: 1)
        simulation.sync([a, b])
        simulation.sync([b])
        #expect(simulation.creatures.map(\.id) == [b.id])
    }

    @Test("奥の個体から順に描画される")
    func testCreaturesSortedByDepth() {
        let simulation = TankSimulation()
        simulation.sync((0..<20).map { makeSpec("Freshwater Fish", index: $0) })
        let depths = simulation.creatures.map(\.depth)
        #expect(depths == depths.sorted(by: >))
    }

    // MARK: - 動き

    @Test("長時間動かしても生き物は水槽からはみ出さない")
    func testCreaturesStayInsideTank() {
        let simulation = TankSimulation()
        let names = ["Shark", "Whale Shark", "Clownfish", "Pufferfish", "Eel", "Dolphin",
                     "Sea Turtle", "Jellyfish", "Crab", "Butterfly", "SeaGull", "fish.fill"]
        simulation.sync(names.enumerated().map { makeSpec($0.element, sizeLevel: 5, index: $0.offset) })

        // 全員が入場しきるまで待つ
        run(simulation, seconds: 20)
        #expect(simulation.creatures.allSatisfy { $0.isActive })

        for _ in 0..<(60 * 60) {
            simulation.advance(by: 1.0 / 60.0, size: tankSize)
            for c in simulation.creatures {
                let margin = c.halfLength * 1.3
                #expect(c.x >= -margin && c.x <= tankSize.width + margin, "\(c.spec.creatureName) x=\(c.x)")
                #expect(c.y >= 0 && c.y <= tankSize.height, "\(c.spec.creatureName) y=\(c.y)")
                #expect(c.x.isFinite && c.y.isFinite)
            }
        }
    }

    @Test("泳ぐ生き物は左右両方に向きを変える")
    func testSwimmersTurnAround() {
        let simulation = TankSimulation()
        let spec = makeSpec("Clownfish")
        simulation.sync([spec])

        var sawRight = false
        var sawLeft = false
        for _ in 0..<(60 * 90) {
            simulation.advance(by: 1.0 / 60.0, size: tankSize)
            guard let c = simulation.creatures.first, c.isActive else { continue }
            if c.yaw < 0.01 { sawRight = true }
            if c.yaw > .pi - 0.01 { sawLeft = true }
        }
        #expect(sawRight && sawLeft)
    }

    @Test("復帰直後などで時間が大きく飛んでもワープしない")
    func testLargeTimeJumpIsClamped() {
        let simulation = TankSimulation()
        let start = Date()
        simulation.sync([makeSpec("Tuna")])
        simulation.step(to: start, size: tankSize)
        simulation.step(to: start.addingTimeInterval(600), size: tankSize)
        #expect(simulation.time <= TankSimulation.maxStep + 1e-9)
    }

    // MARK: - 泡

    @Test("泡が発生し、水面より上に残らない")
    func testBubblesRiseAndDisappear() {
        let simulation = TankSimulation()
        simulation.sync([])
        run(simulation, seconds: 10)
        #expect(!simulation.bubbles.isEmpty)
        #expect(simulation.bubbles.allSatisfy { $0.y >= -$0.size })
        #expect(simulation.bubbles.count <= 80)
    }
}
