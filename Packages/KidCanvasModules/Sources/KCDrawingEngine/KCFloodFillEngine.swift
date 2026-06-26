//
//  KCFloodFillEngine.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation

/// 泛洪填充，忠实移植自 `-[KDDrawingCanvasView performFloodFillAtPoint:color:]`。
///
/// 区域归属判定使用原型的曼哈顿 RGBA 度量：当某像素与种子像素的各通道差值绝对值之和
/// `<= tolerance * 4` 时，该像素属于填充区域（边界条件为 `delta > tolerance * 4`）。
/// 扩展采用 4 连通 BFS 并配合已访问位图，因此每个像素最多被访问一次。
public enum KCFloodFillEngine {
    /// 以 `fillColor` 填充以 `(startX, startY)` 为起点的区域。
    ///
    /// - Parameters:
    ///   - buffer: 原地填充的光栅。
    ///   - startX: 种子 x（列）。
    ///   - startY: 种子 y（行）。
    ///   - fillColor: 替换颜色。
    ///   - tolerance: 原型容差（默认 28），内部会乘以 4。
    /// - Returns: 实际改变的像素数量（若种子颜色已与填充色一致，或种子越界，则为 0）。
    @discardableResult
    public static func fill(
        buffer: KCBitmapBuffer,
        startX: Int,
        startY: Int,
        fillColor: KCRGBA8,
        tolerance: Double = 28.0
    ) -> Int {
        let width = buffer.width
        let height = buffer.height
        guard width > 0,
              height > 0,
              startX >= 0, startX < width,
              startY >= 0, startY < height else { return 0 }

        let pixelCount = width * height
        // 与原型保持一致的溢出保护。
        guard width <= Int.max / height else { return 0 }
        guard pixelCount <= Int.max / 4 else { return 0 }

        let seedColor = buffer.pixel(x: startX, y: startY)
        let threshold = tolerance * 4.0

        var visited = [Bool](repeating: false, count: pixelCount)
        var queue = [Int]()
        queue.reserveCapacity(min(pixelCount, 4_096))
        var head = 0

        var changedPixels = 0
        let startIndex = startY * width + startX
        visited[startIndex] = true
        queue.append(startIndex)

        while head < queue.count {
            let current = queue[head]
            head += 1
            let x = current % width
            let y = current / width

            let color = buffer.pixel(x: x, y: y)
            if Double(color.delta(from: seedColor)) > threshold {
                continue
            }

            if color != fillColor {
                buffer.setPixel(fillColor, x: x, y: y)
                changedPixels += 1
            }

            if x + 1 < width { enqueue(current + 1) }
            if x > 0 { enqueue(current - 1) }
            if y + 1 < height { enqueue(current + width) }
            if y > 0 { enqueue(current - width) }
        }

        return changedPixels

        @inline(__always) func enqueue(_ index: Int) {
            if !visited[index] {
                visited[index] = true
                queue.append(index)
            }
        }
    }
}
