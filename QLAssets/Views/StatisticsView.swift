
import SwiftUI

// StatisticsView.swift
// 饼图引线重构版：
// 1. 引线第一段始终沿扇区半径方向向外
// 2. 折点强制位于饼图外侧安全区域
// 3. 第二段水平向左右延伸
// 4. 标签跟随线末端，不参与折线反推

struct CalloutLayout {
    let start: CGPoint
    let bend: CGPoint
    let end: CGPoint
    let side: Side

    enum Side {
        case left
        case right
    }
}

func makeOutsideCallout(
    start: CGPoint,
    center: CGPoint,
    radius: CGFloat,
    side: CalloutLayout.Side,
    labelY: CGFloat
) -> CalloutLayout {

    let dx = start.x - center.x
    let dy = start.y - center.y

    let length = max(
        sqrt(dx * dx + dy * dy),
        0.001
    )

    let ux = dx / length
    let uy = dy / length

    let safeRadius = radius + 35

    var outerPoint = CGPoint(
        x: center.x + ux * safeRadius,
        y: center.y + uy * safeRadius
    )

    // 保证折点在标签高度线上，同时不回到圆内
    let currentDistance = sqrt(
        pow(outerPoint.x - center.x, 2) +
        pow(outerPoint.y - center.y, 2)
    )

    if currentDistance < safeRadius {
        outerPoint = CGPoint(
            x: center.x + ux * safeRadius,
            y: center.y + uy * safeRadius
        )
    }

    let bend = CGPoint(
        x: outerPoint.x,
        y: labelY
    )

    let horizontalLength: CGFloat = 90

    let end = CGPoint(
        x: side == .left
            ? bend.x - horizontalLength
            : bend.x + horizontalLength,
        y: labelY
    )

    return CalloutLayout(
        start: start,
        bend: bend,
        end: end,
        side: side
    )
}


struct OutsideCalloutShape: Shape {

    let layout: CalloutLayout

    func path(in rect: CGRect) -> Path {

        var path = Path()

        path.move(to: layout.start)

        // 第一段：斜向远离饼图
        path.addLine(to: layout.bend)

        // 第二段：水平向外
        path.addLine(to: layout.end)

        return path
    }
}


// 标签不要固定宽度
// 使用：
// .padding(.horizontal, 8)
// .padding(.vertical, 4)
// 让文字自动撑开
