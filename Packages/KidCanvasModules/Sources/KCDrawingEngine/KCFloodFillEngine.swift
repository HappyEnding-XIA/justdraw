//
//  KCFloodFillEngine.swift
//  KCDrawingEngine
//
//  Created by 小大 on 2026/06/25.
//

import Foundation

/// Flood fill, ported faithfully from `-[KDDrawingCanvasView performFloodFillAtPoint:color:]`.
///
/// Region membership uses the prototype's Manhattan RGBA metric: a pixel belongs
/// to the filled region while the sum of its absolute per-channel deltas from the
/// seed pixel is `<= tolerance * 4` (the boundary is `delta > tolerance * 4`).
/// Expansion is 4-connected BFS with a visited bitmap, so each pixel is visited
/// at most once.
public enum KCFloodFillEngine {
    /// Fills the region seeded at `(startX, startY)` with `fillColor`.
    ///
    /// - Parameters:
    ///   - buffer: The raster to fill in place.
    ///   - startX: Seed x (column).
    ///   - startY: Seed y (row).
    ///   - fillColor: Replacement color.
    ///   - tolerance: Prototype tolerance (default 28). Multiplied by 4 internally.
    /// - Returns: The number of pixels actually changed (0 if the seed already
    ///   matched the fill color or the seed was out of bounds).
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
        // Overflow guards mirrored from the prototype.
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
