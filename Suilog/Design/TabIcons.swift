//
//  TabIcons.swift
//  Suilog
//
//  デザイン仕様 (Suilog Redesign.html TabBar) に合わせたカスタムタブアイコン。
//  SVG 定義を Canvas で忠実に再現する。
//

import SwiftUI

// MARK: - 色パレット

private struct TabIconPalette {
    let stroke: Color
    let fill: Color
    let accent1: Color  // 大きい魚 / メインディテール
    let accent2: Color  // 小さい魚 / サブディテール
    let line: Color

    static func make(active: Bool, theme: Theme) -> TabIconPalette {
        if active {
            return TabIconPalette(
                stroke: theme.primaryColor,
                fill: theme.primaryBg,
                accent1: theme.primaryColor,
                accent2: theme.accent,
                line: theme.primaryLight
            )
        } else {
            return TabIconPalette(
                stroke: Color(hex: "#C0C0CC"),
                fill: .clear,
                accent1: Color(hex: "#C0C0CC"),
                accent2: Color(hex: "#D0D0DA"),
                line: Color(hex: "#D8D8E0")
            )
        }
    }
}

// MARK: - マイ水槽アイコン (26×22)

struct TankTabIcon: View {
    let active: Bool
    let theme: Theme

    var body: some View {
        let p = TabIconPalette.make(active: active, theme: theme)
        Canvas { ctx, size in
            let s = min(size.width / 26, size.height / 22)
            let ox = (size.width - 26 * s) / 2
            let oy = (size.height - 22 * s) / 2
            func x(_ v: CGFloat) -> CGFloat { v * s + ox }
            func y(_ v: CGFloat) -> CGFloat { v * s + oy }

            // tank: rect x=1 y=4 w=24 h=16 rx=4
            let rect = Path(
                roundedRect: CGRect(x: x(1), y: y(4), width: 24 * s, height: 16 * s),
                cornerRadius: 4 * s
            )
            ctx.fill(rect, with: .color(p.fill))
            ctx.stroke(rect, with: .color(p.stroke), lineWidth: 2 * s)

            // water line from (1,8) to (25,8)
            var line = Path()
            line.move(to: CGPoint(x: x(1), y: y(8)))
            line.addLine(to: CGPoint(x: x(25), y: y(8)))
            ctx.stroke(line, with: .color(p.line), lineWidth: 1.5 * s)

            // fish A: ellipse cx=9 cy=12 rx=4 ry=2.5 opacity 0.7
            let fishA = Path(
                ellipseIn: CGRect(x: x(5), y: y(9.5), width: 8 * s, height: 5 * s)
            )
            ctx.fill(fishA, with: .color(p.accent1.opacity(0.7)))

            // fish B: ellipse cx=18 cy=10 rx=3 ry=2 opacity 0.8
            let fishB = Path(
                ellipseIn: CGRect(x: x(15), y: y(8), width: 6 * s, height: 4 * s)
            )
            ctx.fill(fishB, with: .color(p.accent2.opacity(0.8)))
        }
        .frame(width: 26, height: 22)
    }
}

// MARK: - マップアイコン (24×24)

struct MapTabIcon: View {
    let active: Bool
    let theme: Theme

    var body: some View {
        let p = TabIconPalette.make(active: active, theme: theme)
        Canvas { ctx, size in
            let s = min(size.width / 24, size.height / 24)
            let ox = (size.width - 24 * s) / 2
            let oy = (size.height - 24 * s) / 2
            func x(_ v: CGFloat) -> CGFloat { v * s + ox }
            func y(_ v: CGFloat) -> CGFloat { v * s + oy }

            // teardrop: M12 2 C8.13 2 5 5.13 5 9 c0 5.25 7 13 7 13 s7-7.75 7-13 c0-3.87-3.13-7-7-7 z
            var drop = Path()
            drop.move(to: CGPoint(x: x(12), y: y(2)))
            drop.addCurve(
                to: CGPoint(x: x(5), y: y(9)),
                control1: CGPoint(x: x(8.13), y: y(2)),
                control2: CGPoint(x: x(5), y: y(5.13))
            )
            drop.addCurve(
                to: CGPoint(x: x(12), y: y(22)),
                control1: CGPoint(x: x(5), y: y(14.25)),
                control2: CGPoint(x: x(12), y: y(22))
            )
            drop.addCurve(
                to: CGPoint(x: x(19), y: y(9)),
                control1: CGPoint(x: x(12), y: y(22)),
                control2: CGPoint(x: x(19), y: y(14.25))
            )
            drop.addCurve(
                to: CGPoint(x: x(12), y: y(2)),
                control1: CGPoint(x: x(19), y: y(5.13)),
                control2: CGPoint(x: x(15.87), y: y(2))
            )
            drop.closeSubpath()
            ctx.fill(drop, with: .color(p.fill))
            ctx.stroke(drop, with: .color(p.stroke), lineWidth: 2 * s)

            // circle cx=12 cy=9 r=2.5
            let circle = Path(
                ellipseIn: CGRect(x: x(9.5), y: y(6.5), width: 5 * s, height: 5 * s)
            )
            ctx.fill(circle, with: .color(p.accent1))
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - 記録アイコン (22×24)

struct RecordsTabIcon: View {
    let active: Bool
    let theme: Theme

    var body: some View {
        let p = TabIconPalette.make(active: active, theme: theme)
        let lineColor = active ? p.accent1 : Color(hex: "#C8C8D4")
        Canvas { ctx, size in
            let s = min(size.width / 22, size.height / 24)
            let ox = (size.width - 22 * s) / 2
            let oy = (size.height - 24 * s) / 2
            func x(_ v: CGFloat) -> CGFloat { v * s + ox }
            func y(_ v: CGFloat) -> CGFloat { v * s + oy }

            // book: rect x=2 y=1 w=18 h=22 rx=4
            let rect = Path(
                roundedRect: CGRect(x: x(2), y: y(1), width: 18 * s, height: 22 * s),
                cornerRadius: 4 * s
            )
            ctx.fill(rect, with: .color(p.fill))
            ctx.stroke(rect, with: .color(p.stroke), lineWidth: 2 * s)

            // 3 lines
            func drawLine(from startX: CGFloat, to endX: CGFloat, yCoord: CGFloat) {
                var path = Path()
                path.move(to: CGPoint(x: x(startX), y: y(yCoord)))
                path.addLine(to: CGPoint(x: x(endX), y: y(yCoord)))
                ctx.stroke(
                    path,
                    with: .color(lineColor),
                    style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round)
                )
            }
            drawLine(from: 6, to: 16, yCoord: 8)
            drawLine(from: 6, to: 14, yCoord: 13)
            drawLine(from: 6, to: 11, yCoord: 18)
        }
        .frame(width: 22, height: 24)
    }
}

// MARK: - プロフィールアイコン (24×24)

struct ProfileTabIcon: View {
    let active: Bool
    let theme: Theme

    var body: some View {
        let p = TabIconPalette.make(active: active, theme: theme)
        Canvas { ctx, size in
            let s = min(size.width / 24, size.height / 24)
            let ox = (size.width - 24 * s) / 2
            let oy = (size.height - 24 * s) / 2
            func x(_ v: CGFloat) -> CGFloat { v * s + ox }
            func y(_ v: CGFloat) -> CGFloat { v * s + oy }

            // head: circle cx=12 cy=8 r=4
            let head = Path(
                ellipseIn: CGRect(x: x(8), y: y(4), width: 8 * s, height: 8 * s)
            )
            ctx.fill(head, with: .color(p.fill))
            ctx.stroke(head, with: .color(p.stroke), lineWidth: 2 * s)

            // shoulders: M4 20 c0-4 3.58-7 8-7 s8 3 8 7
            var shoulders = Path()
            shoulders.move(to: CGPoint(x: x(4), y: y(20)))
            shoulders.addCurve(
                to: CGPoint(x: x(12), y: y(13)),
                control1: CGPoint(x: x(4), y: y(16)),
                control2: CGPoint(x: x(7.58), y: y(13))
            )
            shoulders.addCurve(
                to: CGPoint(x: x(20), y: y(20)),
                control1: CGPoint(x: x(16.42), y: y(13)),
                control2: CGPoint(x: x(20), y: y(16))
            )
            ctx.stroke(
                shoulders,
                with: .color(p.stroke),
                style: StrokeStyle(lineWidth: 2 * s, lineCap: .round)
            )
        }
        .frame(width: 24, height: 24)
    }
}
