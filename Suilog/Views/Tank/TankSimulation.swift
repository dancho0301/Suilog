//
//  TankSimulation.swift
//  Suilog
//
//  マイ水槽の生き物・泡をフレーム単位で動かすシミュレーション。
//  「時刻 → 位置」の固定式ではなく、位置・速度・向きを持つ操舵（ステアリング）型で動かす。
//

import Foundation
import CoreGraphics

// MARK: - 泳ぎ方プロファイル

/// 生き物の動きの種類
enum SwimStyle: Equatable {
    /// 魚・海獣など。目標点へ泳ぎ、壁際で体をひねって反転する
    case swim
    /// クラゲ・クリオネ。拍動で浮き上がり、ゆっくり沈む
    case drift
    /// カニ。海底を横歩きする
    case crawl
    /// チョウ。羽ばたきながら水面近くを漂う
    case flutter
}

/// 生き物ごとの泳ぎ方のパラメータ
struct SwimProfile: Equatable {
    var style: SwimStyle = .swim
    /// 巡航速度（pt/秒、最前面の個体基準）
    var cruiseSpeed: Double = 26
    /// 尾を振って加速している間の速度倍率
    var burstMultiplier: Double = 1.9
    /// 惰性で進んでいる間の速度倍率
    var glideMultiplier: Double = 0.45
    var burstDuration: ClosedRange<Double> = 0.35...0.8
    var glideDuration: ClosedRange<Double> = 0.8...2.2
    /// 尾びれ（拍動・羽ばたき）の基本周波数（Hz）
    var tailFrequency: Double = 2.2
    /// 体のうねりの縦振幅（フレーム高さ比）
    var undulation: Double = 0.05
    /// 尾びれの左右スイープ量（フレーム幅比）。横から見ると尾が伸び縮みして見える
    var tailSweep: Double = 0.04
    /// 体長あたりの波の数
    var wavelength: Double = 0.9
    /// 上下移動時に体を傾ける最大角（ラジアン）
    var maxPitch: Double = 0.3
    /// 反転にかかる秒数
    var turnDuration: Double = 0.7
    /// 泳ぐ高さの範囲（水槽の高さ比）
    var verticalBand: ClosedRange<Double> = 0.12...0.8
    /// 尾の動きに合わせた体全体の上下ゆれ（pt）
    var bob: Double = 0

    /// representativeFish（アセット名 or SF Symbol 名）から泳ぎ方を決める
    static func forCreature(_ name: String) -> SwimProfile {
        var p = SwimProfile()
        switch name {
        // 速く力強く泳ぐ魚
        case "Tuna", "Shark", "salmon", "Hucho", "Piranha":
            p.cruiseSpeed = 38
            p.burstMultiplier = 1.8
            p.tailFrequency = 2.8
            p.turnDuration = 0.55

        // 大型でゆったり泳ぐ魚
        case "Whale Shark", "Mekonggiantcatfish", "Arapaima", "Sturgeon", "Coelacanth", "Arowana":
            p.cruiseSpeed = 15
            p.burstMultiplier = 1.2
            p.glideMultiplier = 0.85
            p.burstDuration = 1.5...3.0
            p.glideDuration = 2.0...4.0
            p.tailFrequency = 0.9
            p.undulation = 0.04
            p.wavelength = 0.7
            p.maxPitch = 0.2
            p.turnDuration = 1.6

        // サンゴ礁の小魚：ちょこまか泳いで止まる
        case "Clownfish", "Coral Fish":
            p.cruiseSpeed = 20
            p.burstMultiplier = 2.2
            p.glideMultiplier = 0.25
            p.burstDuration = 0.25...0.5
            p.glideDuration = 0.6...1.6
            p.tailFrequency = 3.2
            p.turnDuration = 0.45

        // フグ：ホバリングしながら少しずつ進む
        case "Pufferfish":
            p.cruiseSpeed = 11
            p.burstMultiplier = 1.5
            p.glideMultiplier = 0.2
            p.tailFrequency = 4.0
            p.undulation = 0.015
            p.tailSweep = 0.07
            p.maxPitch = 0.15
            p.turnDuration = 0.9

        // 底生の魚
        case "Biwa Catfish", "Deep-sea Fish":
            p.cruiseSpeed = 14
            p.burstMultiplier = 1.6
            p.glideMultiplier = 0.3
            p.tailFrequency = 1.6
            p.maxPitch = 0.2
            p.verticalBand = 0.55...0.86

        // 体全体をくねらせて泳ぐ
        case "Eel":
            p.cruiseSpeed = 18
            p.burstMultiplier = 1.3
            p.glideMultiplier = 0.8
            p.tailFrequency = 1.4
            p.undulation = 0.11
            p.tailSweep = 0
            p.wavelength = 1.6
            p.verticalBand = 0.4...0.86
        case "Giant Salamander":
            p.cruiseSpeed = 10
            p.burstMultiplier = 1.4
            p.glideMultiplier = 0.3
            p.tailFrequency = 1.0
            p.undulation = 0.06
            p.tailSweep = 0
            p.wavelength = 1.2
            p.maxPitch = 0.15
            p.verticalBand = 0.65...0.88

        // 俊敏な海獣・ペンギン：尾びれは上下に動く
        case "Dolphin", "Orca", "Finlessporpoise", "Penguin", "Seal", "SeaLion":
            p.cruiseSpeed = 42
            p.burstMultiplier = 1.9
            p.glideMultiplier = 0.55
            p.burstDuration = 0.6...1.2
            p.glideDuration = 1.0...2.0
            p.tailFrequency = 1.6
            p.undulation = 0.07
            p.tailSweep = 0
            p.wavelength = 0.5
            p.maxPitch = 0.5
            p.turnDuration = 0.55
            p.bob = 1.5

        // ゆったりした海獣
        case "Whale", "Beluga Whale", "Manatee", "Dugong", "Walrus":
            p.cruiseSpeed = 14
            p.burstMultiplier = 1.25
            p.glideMultiplier = 0.8
            p.burstDuration = 1.5...3.0
            p.glideDuration = 2.0...4.0
            p.tailFrequency = 0.7
            p.undulation = 0.06
            p.tailSweep = 0
            p.wavelength = 0.45
            p.maxPitch = 0.22
            p.turnDuration = 1.8
            p.bob = 2.5

        // ウミガメ：ヒレで漕ぐので体はうねらせず、ゆっくり上下させる
        case "Sea Turtle":
            p.cruiseSpeed = 13
            p.burstMultiplier = 1.5
            p.glideMultiplier = 0.6
            p.burstDuration = 0.8...1.4
            p.glideDuration = 1.5...3.0
            p.tailFrequency = 0.6
            p.undulation = 0.01
            p.tailSweep = 0
            p.maxPitch = 0.25
            p.turnDuration = 1.5
            p.bob = 3

        // カモメ：水面近くをぷかぷか
        case "SeaGull":
            p.cruiseSpeed = 12
            p.burstMultiplier = 1.3
            p.glideMultiplier = 0.6
            p.tailFrequency = 1.2
            p.undulation = 0
            p.tailSweep = 0
            p.maxPitch = 0.1
            p.verticalBand = 0.06...0.2
            p.bob = 2.5

        case "Jellyfish", "Clione":
            p.style = .drift
            p.cruiseSpeed = 34      // 拍動 1 回あたりの推進力
            p.tailFrequency = name == "Clione" ? 1.1 : 0.45
            p.undulation = 0
            p.tailSweep = 0
            p.verticalBand = 0.1...0.75

        case "Crab":
            p.style = .crawl
            p.cruiseSpeed = 22
            p.burstDuration = 0.6...1.6
            p.glideDuration = 0.8...2.5
            p.tailFrequency = 5
            p.undulation = 0
            p.tailSweep = 0

        case "Butterfly":
            p.style = .flutter
            p.cruiseSpeed = 16
            p.tailFrequency = 5
            p.undulation = 0
            p.tailSweep = 0
            p.verticalBand = 0.08...0.4
            p.bob = 4

        default:
            break
        }
        return p
    }
}

// MARK: - 生き物

/// 水槽に入れる生き物 1 匹分の入力（訪問記録から作る）
struct TankCreatureSpec: Equatable, Identifiable {
    let id: UUID
    let creatureName: String
    let sizeLevel: Int
    let isLocationCheckIn: Bool
    let colorIndex: Int

    /// アセット画像か（"." を含むものは SF Symbol 名）
    var isCustomAsset: Bool { !creatureName.contains(".") }

    /// fishIconSize（1〜5）に対応する基準サイズ
    var baseSize: Double {
        switch sizeLevel {
        case 1: return 24
        case 2: return 30
        case 3: return 36
        case 4: return 44
        case 5: return 56
        default: return 36
        }
    }
}

/// 水槽内の生き物 1 匹の状態
struct TankCreature: Identifiable {
    var spec: TankCreatureSpec
    var profile: SwimProfile
    /// 奥行き（0 = 手前、1 = 奥）
    let depth: Double

    var id: UUID { spec.id }

    var isActive = false
    var spawnDelay: Double
    var fadeIn: Double = 0

    var x: Double = 0
    var y: Double = 0
    var vx: Double = 0
    var vy: Double = 0
    /// 体の向き（0 = 右向き、π = 左向き。途中は体をひねっている最中）
    var yaw: Double = 0
    var desiredYaw: Double = 0
    /// 進行方向の上下の傾き（ラジアン、負 = 頭が上）
    var pitch: Double = 0
    var speed: Double = 0

    var target: CGPoint = .zero
    var retargetTimer: Double = 0
    var isBursting = false
    var phaseTimer: Double = 0

    /// 尾びれ（拍動・羽ばたき）の位相
    var tailPhase: Double = Double.random(in: 0...(2 * .pi))
    /// 尾の振りの強さ（0〜1）
    var tailPower: Double = 0.5
    /// ゆっくりした揺れ用の位相
    var swayPhase: Double = Double.random(in: 0...(2 * .pi))

    init(spec: TankCreatureSpec, depth: Double, spawnDelay: Double) {
        self.spec = spec
        self.profile = SwimProfile.forCreature(spec.creatureName)
        self.depth = depth
        self.spawnDelay = spawnDelay
    }

    // MARK: 奥行き表現

    /// 手前ほど大きく、奥ほど小さい
    var depthScale: Double { 1.15 - 0.5 * depth }
    /// 奥ほどゆっくり動く（視差）
    var depthSpeed: Double { 1 - 0.35 * depth }
    /// 描画サイズ（pt）
    var renderSize: Double { spec.baseSize * depthScale }
    var halfLength: Double { renderSize * 0.5 }

    var opacity: Double { fadeIn * (1 - 0.3 * depth) }
    var blurRadius: Double { depth > 0.6 ? (depth - 0.6) * 2.5 : 0 }
    var saturation: Double { 1 - 0.35 * depth }
    /// 奥ほど青みがかる乗算色（RGB）
    var tint: (red: Double, green: Double, blue: Double) {
        (1 - 0.35 * depth, 1 - 0.18 * depth, 1 - 0.04 * depth)
    }

    // MARK: 描画パラメータ

    /// シェーダーに渡すうねりの振幅
    var undulationAmount: Double {
        guard profile.style == .swim else { return 0 }
        return profile.undulation * (0.35 + 0.65 * tailPower)
    }

    var tailSweepAmount: Double {
        guard profile.style == .swim else { return 0 }
        return profile.tailSweep * (0.3 + 0.7 * tailPower)
    }

    /// 描画時の回転（ラジアン）
    var renderRotation: Double {
        switch profile.style {
        case .swim: return pitch
        case .drift: return sin(swayPhase) * 0.07
        case .crawl: return abs(vx) > 1 ? sin(tailPhase) * 0.05 : 0
        case .flutter: return sin(swayPhase) * 0.12
        }
    }

    /// 描画時の拡大率（拍動・羽ばたき）
    var renderScale: (x: Double, y: Double) {
        switch profile.style {
        case .swim, .crawl:
            return (1, 1)
        case .drift:
            let pulse = max(0, sin(tailPhase))
            return (1 + 0.08 * pulse, 1 - 0.1 * pulse)
        case .flutter:
            return (0.3 + 0.7 * abs(cos(tailPhase)), 1)
        }
    }

    /// 描画時の上下オフセット（pt）
    var renderOffsetY: Double {
        switch profile.style {
        case .swim: return profile.bob * sin(tailPhase + .pi) * tailPower
        case .drift: return 0
        case .crawl: return abs(vx) > 1 ? -abs(sin(tailPhase)) * 1.5 : 0
        case .flutter: return profile.bob * sin(swayPhase * 2)
        }
    }
}

// MARK: - 泡

struct TankBubbleParticle {
    var baseX: Double
    var y: Double
    var vy: Double
    var size: Double
    var wobblePhase: Double
    var wobbleAmplitude: Double

    /// 左右にゆらゆら揺れながら昇る
    var x: Double { baseX + sin(wobblePhase) * wobbleAmplitude }
}

private struct BubbleEmitter {
    var fraction: Double
    var timer: Double
    var pending: Int = 0
    var gap: Double = 0
}

// MARK: - シミュレーション

final class TankSimulation {
    private(set) var creatures: [TankCreature] = []
    private(set) var bubbles: [TankBubbleParticle] = []
    /// シミュレーション開始からの経過秒（シェーダーや浮遊物に使う）
    private(set) var time: Double = 0

    private var lastDate: Date?
    private var size: CGSize = .zero
    private var lastSpecs: [TankCreatureSpec] = []
    private var hasSynced = false
    private var emitters: [BubbleEmitter] = [
        BubbleEmitter(fraction: Double.random(in: 0.1...0.3), timer: Double.random(in: 0.5...2)),
        BubbleEmitter(fraction: Double.random(in: 0.7...0.9), timer: Double.random(in: 2...4))
    ]
    private var ambientBubbleTimer: Double = 1

    /// 1 フレームで進める最大秒数（バックグラウンド復帰時などのワープ防止）
    static let maxStep: Double = 1.0 / 15.0

    /// 訪問記録の変化を反映し、date まで時間を進める
    func update(specs: [TankCreatureSpec], date: Date, size: CGSize) {
        sync(specs)
        step(to: date, size: size)
    }

    // MARK: 同期

    func sync(_ specs: [TankCreatureSpec]) {
        guard !hasSynced || specs != lastSpecs else { return }
        let isInitial = !hasSynced
        hasSynced = true
        lastSpecs = specs

        let existing = Dictionary(creatures.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // 初回は 1 匹ずつ順に泳いで登場させる（最大 8 秒程度）
        let stride = min(0.6, 8.0 / Double(max(specs.count, 1)))

        var next: [TankCreature] = []
        next.reserveCapacity(specs.count)
        for (index, spec) in specs.enumerated() {
            if var creature = existing[spec.id] {
                if creature.spec.creatureName != spec.creatureName {
                    creature.profile = SwimProfile.forCreature(spec.creatureName)
                }
                creature.spec = spec
                next.append(creature)
            } else {
                let delay = isInitial
                    ? Double(index) * stride + Double.random(in: 0...stride)
                    : 0.2
                next.append(TankCreature(spec: spec, depth: Double.random(in: 0...1), spawnDelay: delay))
            }
        }
        // 奥の個体から描画する
        creatures = next.sorted { $0.depth > $1.depth }
    }

    // MARK: ステップ

    func step(to date: Date, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let dt: Double
        if let lastDate {
            dt = min(max(date.timeIntervalSince(lastDate), 0), Self.maxStep)
        } else {
            dt = 0
        }
        lastDate = date
        self.size = size
        guard dt > 0 else { return }
        advance(by: dt)
    }

    /// 経過時間を直接指定して進める（テスト用にも使う）
    func advance(by dt: Double, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        self.size = size
        advance(by: min(max(dt, 0), Self.maxStep))
    }

    private func advance(by dt: Double) {
        time += dt
        for index in creatures.indices {
            update(&creatures[index], dt: dt)
        }
        updateBubbles(dt: dt)
    }

    // MARK: 生き物の更新

    private var width: Double { Double(size.width) }
    private var height: Double { Double(size.height) }

    private func update(_ c: inout TankCreature, dt: Double) {
        if !c.isActive {
            c.spawnDelay -= dt
            guard c.spawnDelay <= 0 else { return }
            activate(&c)
        }
        c.fadeIn = min(1, c.fadeIn + dt / 0.6)
        c.swayPhase += dt * 0.9

        switch c.profile.style {
        case .swim: updateSwim(&c, dt: dt)
        case .drift: updateDrift(&c, dt: dt)
        case .crawl: updateCrawl(&c, dt: dt)
        case .flutter: updateFlutter(&c, dt: dt)
        }
    }

    private func activate(_ c: inout TankCreature) {
        c.isActive = true
        let fromLeft = Bool.random()
        let half = c.halfLength
        switch c.profile.style {
        case .swim, .flutter:
            // 画面外から泳いで入ってくる
            c.x = fromLeft ? -half * 1.2 : width + half * 1.2
            c.y = randomY(for: c)
            c.yaw = (fromLeft || c.profile.style == .flutter) ? 0 : .pi
            c.desiredYaw = c.yaw
            c.speed = c.profile.cruiseSpeed * c.depthSpeed
            c.target = CGPoint(
                x: fromLeft ? random(width * 0.35, width * 0.8) : random(width * 0.2, width * 0.65),
                y: randomY(for: c)
            )
            c.retargetTimer = random(6, 12)
            c.isBursting = true
            c.phaseTimer = random(c.profile.burstDuration)
        case .drift:
            // その場でふわっと現れる
            c.fadeIn = 0
            c.x = random(half, width - half)
            c.y = randomY(for: c)
            c.vx = random(-5, 5)
            c.retargetTimer = random(4, 9)
        case .crawl:
            c.x = fromLeft ? -half : width + half
            c.y = crawlY(for: c)
            c.target = CGPoint(x: random(width * 0.2, width * 0.8), y: c.y)
            c.isBursting = true
            c.phaseTimer = random(c.profile.burstDuration)
        }
    }

    private func updateSwim(_ c: inout TankCreature, dt: Double) {
        let p = c.profile
        let half = c.halfLength

        var dx = Double(c.target.x) - c.x
        var dy = Double(c.target.y) - c.y
        var distance = hypot(dx, dy)

        c.retargetTimer -= dt
        if distance < max(12, half * 0.6) || c.retargetTimer <= 0 {
            c.target = randomSwimTarget(for: c)
            c.retargetTimer = random(6, 14)
            dx = Double(c.target.x) - c.x
            dy = Double(c.target.y) - c.y
            distance = hypot(dx, dy)
        }

        // 目標が背後に回ったら反転（小さなズレでは振り向かない）
        if abs(dx) > half * 0.5 {
            c.desiredYaw = dx >= 0 ? 0 : .pi
        }
        c.yaw = approach(c.yaw, c.desiredYaw, maxDelta: .pi / p.turnDuration * dt)
        let facing = cos(c.yaw)
        let isTurning = abs(facing) < 0.95

        // 尾を振って加速 → 惰性で滑る、を繰り返す
        c.phaseTimer -= dt
        if c.phaseTimer <= 0 {
            c.isBursting.toggle()
            c.phaseTimer = random(c.isBursting ? p.burstDuration : p.glideDuration)
        }
        var targetSpeed = p.cruiseSpeed * c.depthSpeed * (c.isBursting ? p.burstMultiplier : p.glideMultiplier)
        // 目標に近づいたら減速
        targetSpeed *= max(0.35, min(1, distance / (half * 3 + 20)))
        // 反転中は速度を落とす
        if isTurning { targetSpeed *= 0.5 }
        let response = c.isBursting ? 2.5 : 0.7
        c.speed += (targetSpeed - c.speed) * min(1, response * dt)

        // 上下に移動するときは頭をそちらへ傾ける
        let desiredPitch = clamp(atan2(dy, max(abs(dx), 1)), -p.maxPitch, p.maxPitch) * abs(facing)
        c.pitch += (desiredPitch - c.pitch) * min(1, 2 * dt)

        c.vx = c.speed * facing * cos(c.pitch)
        c.vy = c.speed * sin(c.pitch)
        c.x += c.vx * dt
        c.y = clamp(c.y + c.vy * dt, half * 0.4, height - half * 0.4)

        // 尾の振り：加速中・反転中は強く速く
        let tailTarget = (c.isBursting || isTurning) ? 1.0 : 0.25
        c.tailPower += (tailTarget - c.tailPower) * min(1, 4 * dt)
        let frequency = p.tailFrequency * (0.5 + 0.7 * c.tailPower)
        c.tailPhase = wrapPhase(c.tailPhase + 2 * .pi * frequency * dt)
    }

    private func updateDrift(_ c: inout TankCreature, dt: Double) {
        let p = c.profile
        let half = c.halfLength
        let band = yRange(for: c)

        c.tailPhase = wrapPhase(c.tailPhase + 2 * .pi * p.tailFrequency * dt)
        let pulse = max(0, sin(c.tailPhase))
        // 上限に近いほど拍動を弱める
        let headroom = clamp((c.y - band.lowerBound) / 40, 0, 1)
        c.vy -= pulse * p.cruiseSpeed * c.depthSpeed * headroom * dt * 2
        c.vy += 7 * dt                          // ゆっくり沈む
        c.vy *= max(0, 1 - 1.4 * dt)            // 水の抵抗

        c.retargetTimer -= dt
        if c.retargetTimer <= 0 {
            c.vx = random(-6, 6) * c.depthSpeed
            c.retargetTimer = random(4, 9)
        }
        if c.x < half { c.vx = abs(c.vx) }
        if c.x > width - half { c.vx = -abs(c.vx) }

        c.x += c.vx * dt
        c.y += c.vy * dt
        if c.y > band.upperBound { c.vy = min(c.vy, 0); c.y = band.upperBound }
        if c.y < band.lowerBound { c.vy = max(c.vy, 0); c.y = band.lowerBound }
    }

    private func updateCrawl(_ c: inout TankCreature, dt: Double) {
        let p = c.profile
        c.y = crawlY(for: c)

        c.phaseTimer -= dt
        if c.phaseTimer <= 0 {
            c.isBursting.toggle()
            c.phaseTimer = random(c.isBursting ? p.burstDuration : p.glideDuration)
            if c.isBursting {
                c.target = CGPoint(x: random(c.halfLength, width - c.halfLength), y: c.y)
            }
        }
        let dx = Double(c.target.x) - c.x
        let targetVx = (c.isBursting && abs(dx) > 4)
            ? (dx > 0 ? 1 : -1) * p.cruiseSpeed * c.depthSpeed
            : 0
        c.vx += (targetVx - c.vx) * min(1, 6 * dt)
        c.x += c.vx * dt
        if abs(c.vx) > 1 {
            c.tailPhase = wrapPhase(c.tailPhase + 2 * .pi * p.tailFrequency * dt)
        }
    }

    private func updateFlutter(_ c: inout TankCreature, dt: Double) {
        let p = c.profile
        let dx = Double(c.target.x) - c.x
        let dy = Double(c.target.y) - c.y
        let distance = hypot(dx, dy)

        c.retargetTimer -= dt
        if distance < 10 || c.retargetTimer <= 0 {
            c.target = CGPoint(x: random(c.halfLength, width - c.halfLength), y: randomY(for: c))
            c.retargetTimer = random(4, 8)
        }
        let speed = p.cruiseSpeed * c.depthSpeed
        let desiredVx = distance > 0 ? dx / distance * speed : 0
        let desiredVy = distance > 0 ? dy / distance * speed : 0
        c.vx += (desiredVx - c.vx) * min(1, 1.5 * dt)
        c.vy += (desiredVy - c.vy) * min(1, 1.5 * dt)
        c.x += c.vx * dt
        c.y = clamp(c.y + c.vy * dt, c.halfLength * 0.5, height - c.halfLength * 0.5)
        c.tailPhase = wrapPhase(c.tailPhase + 2 * .pi * p.tailFrequency * dt)
    }

    // MARK: 目標点

    private func yRange(for c: TankCreature) -> ClosedRange<Double> {
        let half = c.halfLength
        let top = max(half * 0.6, height * c.profile.verticalBand.lowerBound)
        let bottom = min(height - half * 0.6 - 8, height * c.profile.verticalBand.upperBound)
        return top <= bottom ? top...bottom : (height / 2)...(height / 2)
    }

    private func randomY(for c: TankCreature) -> Double {
        let range = yRange(for: c)
        return random(range.lowerBound, range.upperBound)
    }

    private func crawlY(for c: TankCreature) -> Double {
        height - c.halfLength * 0.55 - 6
    }

    private func randomSwimTarget(for c: TankCreature) -> CGPoint {
        let margin = c.halfLength * 0.8
        let minX = margin
        let maxX = max(minX, width - margin)
        var x = random(minX, maxX)
        // 近すぎる目標は選ばず、水槽を横切るように泳がせる
        if abs(x - c.x) < width * 0.25 {
            x = c.x < width / 2
                ? random(max(minX, width * 0.55), maxX)
                : random(minX, min(maxX, width * 0.45))
        }
        return CGPoint(x: x, y: randomY(for: c))
    }

    // MARK: 泡の更新

    private func updateBubbles(dt: Double) {
        // 2 か所のエアストーンから数個ずつまとめて出る
        for index in emitters.indices {
            emitters[index].timer -= dt
            if emitters[index].pending > 0 {
                emitters[index].gap -= dt
                if emitters[index].gap <= 0 {
                    emitBubble(x: width * emitters[index].fraction + random(-4, 4), size: random(4, 9))
                    emitters[index].pending -= 1
                    emitters[index].gap = random(0.08, 0.22)
                }
            } else if emitters[index].timer <= 0 {
                emitters[index].pending = Int.random(in: 3...7)
                emitters[index].timer = random(2.5, 5.5)
            }
        }
        // ときどき単発の泡
        ambientBubbleTimer -= dt
        if ambientBubbleTimer <= 0 {
            emitBubble(x: random(10, width - 10), size: random(3, 7))
            ambientBubbleTimer = random(1.2, 3)
        }

        for index in bubbles.indices {
            // 浮力で加速し、大きい泡ほど速く昇る（終端速度あり）
            let terminal = 22 + bubbles[index].size * 4
            bubbles[index].vy = min(bubbles[index].vy + 40 * dt, terminal)
            bubbles[index].y -= bubbles[index].vy * dt
            bubbles[index].wobblePhase += dt * (3 + 8 / bubbles[index].size)
            // 水圧が下がって少しずつ膨らむ
            bubbles[index].size *= 1 + 0.04 * dt
        }
        bubbles.removeAll { $0.y < -$0.size }
    }

    private func emitBubble(x: Double, size: Double) {
        guard bubbles.count < 80 else { return }
        bubbles.append(TankBubbleParticle(
            baseX: x,
            y: height + size,
            vy: random(4, 10),
            size: size,
            wobblePhase: random(0, 2 * .pi),
            wobbleAmplitude: 1 + size * 0.35
        ))
    }

    // MARK: ユーティリティ

    private func random(_ a: Double, _ b: Double) -> Double {
        a + (b - a) * Double.random(in: 0...1)
    }

    private func random(_ range: ClosedRange<Double>) -> Double {
        random(range.lowerBound, range.upperBound)
    }
}

private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
    min(max(value, lower), upper)
}

private func approach(_ value: Double, _ target: Double, maxDelta: Double) -> Double {
    if value < target { return min(value + maxDelta, target) }
    return max(value - maxDelta, target)
}

private func wrapPhase(_ phase: Double) -> Double {
    phase.truncatingRemainder(dividingBy: 2 * .pi * 64)
}
