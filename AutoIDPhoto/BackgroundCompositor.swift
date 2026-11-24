import Foundation
import CoreGraphics

/// Vision's 8-bit mask: 0 is background, 255 is foreground. Rows start at the image top.
struct PersonMask {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let bytes: [UInt8]

    func validate(head: HeadPlacement) throws {
        guard width > 1, height > 1, bytesPerRow >= width,
              bytes.count >= bytesPerRow * height else {
            throw PhotoError.message("背景分割返回了无效的人物蒙版，请重试或选择原始背景。")
        }
        // A returned pixel buffer is not proof that inference found a person.
        var foreground = 0
        for y in 0..<height {
            for x in 0..<width where bytes[y * bytesPerRow + x] >= 128 { foreground += 1 }
        }
        guard foreground > max(1, width * height / 1000) else { throw invalidMask() }
        let headHeight = head.chin - head.top
        let centerY = (head.top + head.chin) / 2
        var confidence = 0.0
        for row in 0..<5 {
            for column in 0..<5 {
                confidence += alpha(x: head.centerX + Double(column - 2) * headHeight * 0.04,
                                    y: centerY + Double(row - 2) * headHeight * 0.06)
            }
        }
        guard confidence / 25 >= 0.35 else { throw invalidMask() }
    }

    func alpha(x: Double, y: Double) -> Double {
        let px = max(0, min(Double(width - 1), x * Double(width) - 0.5))
        let py = max(0, min(Double(height - 1), y * Double(height) - 0.5))
        let x0 = Int(px), y0 = Int(py)
        let x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
        let dx = px - Double(x0), dy = py - Double(y0)
        let top = Double(bytes[y0 * bytesPerRow + x0]) * (1 - dx) + Double(bytes[y0 * bytesPerRow + x1]) * dx
        let bottom = Double(bytes[y1 * bytesPerRow + x0]) * (1 - dx) + Double(bytes[y1 * bytesPerRow + x1]) * dx
        return (top * (1 - dy) + bottom * dy) / 255
    }

    private func invalidMask() -> PhotoError {
        .message("背景分割未能保留头部，已停止生成，避免输出纯色照片。请检查头部定位、换一张清晰照片，或在规格设置中选择“原始背景”。模拟器抠图请改用真机验证。")
    }
}

enum BackgroundCompositor {
    /// Composite explicitly in sRGB bytes, avoiding simulator Core Image/Metal mask rendering.
    static func composite(_ image: CGImage, mask: PersonMask, head: HeadPlacement,
                          gray: UInt8) throws -> CGImage {
        try composite(image, mask: mask, head: head, color: PhotoBackgroundColor(gray: gray))
    }

    static func composite(_ image: CGImage, mask: PersonMask, head: HeadPlacement,
                          color: PhotoBackgroundColor) throws -> CGImage {
        try mask.validate(head: head)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let base = context.data else { throw PhotoError.message("无法创建背景合成画布。") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        let background = [color.red, color.green, color.blue]
        for y in 0..<image.height {
            for x in 0..<image.width {
                let alpha = mask.alpha(x: (Double(x) + 0.5) / Double(image.width),
                                       y: (Double(y) + 0.5) / Double(image.height))
                let offset = y * context.bytesPerRow + x * 4
                let sourceAlpha = Double(pixels[offset + 3]) / 255
                for channel in 0..<3 {
                    let value = Double(pixels[offset + channel]) * alpha + Double(background[channel]) * (1 - sourceAlpha * alpha)
                    pixels[offset + channel] = UInt8(clamping: Int(value.rounded()))
                }
                pixels[offset + 3] = 255
            }
        }
        guard let result = context.makeImage() else { throw PhotoError.message("背景合成失败。") }
        return result
    }
}
