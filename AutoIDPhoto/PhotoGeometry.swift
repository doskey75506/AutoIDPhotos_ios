import Foundation
import CoreGraphics

struct PhotoBackgroundColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(gray: UInt8) { self.init(red: gray, green: gray, blue: gray) }
}

struct PhotoSettings: Codable, Equatable {
    var photoWidth = 35.0
    var photoHeight = 45.0
    var headMin = 29.0
    var headMax = 34.0
    var paperWidth = 6.0
    var paperHeight = 4.0
    var dpi = 300.0
    var preserveSourceResolution = true
    var gap = 2.0
    var background = Background.lightGray
    enum Background: String, Codable, CaseIterable {
        case original = "原始背景", white = "纯白", lightGray = "浅灰", blue = "蓝色", red = "红色"

        // Shared by matting and any padding outside the original photo.
        // Blue/red match https://id-photo.cn/color/ solid-color swatches.
        var replacementColor: PhotoBackgroundColor? {
            switch self {
            case .original: return nil
            case .white: return PhotoBackgroundColor(gray: 255)
            case .lightGray: return PhotoBackgroundColor(gray: 240)
            case .blue: return PhotoBackgroundColor(red: 67, green: 142, blue: 219)
            case .red: return PhotoBackgroundColor(red: 255, green: 0, blue: 0)
            }
        }
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case photoWidth, photoHeight, headMin, headMax, paperWidth, paperHeight
        case dpi, gap, background, preserveSourceResolution
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        photoWidth = try values.decodeIfPresent(Double.self, forKey: .photoWidth) ?? 35
        photoHeight = try values.decodeIfPresent(Double.self, forKey: .photoHeight) ?? 45
        headMin = try values.decodeIfPresent(Double.self, forKey: .headMin) ?? 29
        headMax = try values.decodeIfPresent(Double.self, forKey: .headMax) ?? 34
        paperWidth = try values.decodeIfPresent(Double.self, forKey: .paperWidth) ?? 6
        paperHeight = try values.decodeIfPresent(Double.self, forKey: .paperHeight) ?? 4
        dpi = try values.decodeIfPresent(Double.self, forKey: .dpi) ?? 300
        gap = try values.decodeIfPresent(Double.self, forKey: .gap) ?? 2
        background = try values.decodeIfPresent(Background.self, forKey: .background) ?? .lightGray
        preserveSourceResolution = try values.decodeIfPresent(Bool.self, forKey: .preserveSourceResolution) ?? true
    }

    var validationError: String? {
        let values = [photoWidth, photoHeight, headMin, headMax, paperWidth, paperHeight, dpi, gap]
        guard values.allSatisfy({ $0.isFinite }) else { return "请输入有效数字。" }
        guard photoWidth >= 10, photoHeight >= 10, photoWidth <= 200, photoHeight <= 200,
              headMin >= 5, headMax >= headMin, headMax < photoHeight,
              paperWidth >= 1, paperWidth <= 12, paperHeight >= 1, paperHeight <= 12,
              dpi >= 150, dpi <= 600, gap >= 0, gap <= 10 else {
            return "证件照边长须为 10–200 mm；头高须小于照片高度；纸张须为 1–12 英寸；DPI 须为 150–600；间距须为 0–10 mm。"
        }
        guard layout.count > 0 else { return "打印纸放不下一张证件照，请增大纸张或缩小证件照。" }
        guard preserveSourceResolution || paperWidth * dpi * paperHeight * dpi <= 20_000_000 else { return "输出超过 2000 万像素，请降低 DPI 或纸张尺寸。" }
        return nil
    }
    var layout: SheetLayout {
        SheetLayout(paper: CGSize(width: paperWidth * 25.4, height: paperHeight * 25.4),
                    photo: CGSize(width: photoWidth, height: photoHeight), gap: gap)
    }
}

/// Pixel dimensions and metadata share the same physical sizes as the crop and layout.
struct PhotoResolutionPlan {
    static let maximumSheetPixels = 20_000_000.0
    let portraitSize: CGSize
    let sheetSize: CGSize
    let portraitDPI: CGSize
    let sheetDPI: CGSize
    let sheetWasLimited: Bool

    init(crop: CGRect, settings: PhotoSettings) {
        if settings.preserveSourceResolution {
            portraitSize = CGSize(width: max(1, floor(crop.width)), height: max(1, floor(crop.height)))
            let sourceDPI = min(portraitSize.width / settings.photoWidth,
                                portraitSize.height / settings.photoHeight) * 25.4
            let sheetLimitDPI = sqrt(Self.maximumSheetPixels / (settings.paperWidth * settings.paperHeight))
            let printDPI = min(sourceDPI, sheetLimitDPI)
            sheetSize = CGSize(width: max(1, floor(settings.paperWidth * printDPI)),
                               height: max(1, floor(settings.paperHeight * printDPI)))
            portraitDPI = CGSize(width: portraitSize.width / settings.photoWidth * 25.4,
                                 height: portraitSize.height / settings.photoHeight * 25.4)
            sheetDPI = CGSize(width: sheetSize.width / settings.paperWidth,
                              height: sheetSize.height / settings.paperHeight)
            sheetWasLimited = sourceDPI > sheetLimitDPI
        } else {
            portraitSize = CGSize(width: (settings.photoWidth / 25.4 * settings.dpi).rounded(),
                                  height: (settings.photoHeight / 25.4 * settings.dpi).rounded())
            sheetSize = CGSize(width: (settings.paperWidth * settings.dpi).rounded(),
                               height: (settings.paperHeight * settings.dpi).rounded())
            portraitDPI = CGSize(width: settings.dpi, height: settings.dpi)
            sheetDPI = portraitDPI
            sheetWasLimited = false
        }
    }
}

struct SheetLayout {
    static let spacerGray: UInt8 = 127
    let paper: CGSize
    let photo: CGSize
    let gap: Double
    var columns: Int { max(0, Int((paper.width + gap) / (photo.width + gap))) }
    var rows: Int { max(0, Int((paper.height + gap) / (photo.height + gap))) }
    var count: Int { columns * rows }
    var rectangles: [CGRect] {
        guard count > 0 else { return [] }
        let startX = (paper.width - Double(columns) * photo.width - Double(columns - 1) * gap) / 2
        let startY = (paper.height - Double(rows) * photo.height - Double(rows - 1) * gap) / 2
        return (0..<rows).flatMap { y in (0..<columns).map { x in
            CGRect(x: startX + Double(x) * (photo.width + gap),
                   y: startY + Double(y) * (photo.height + gap), width: photo.width, height: photo.height)
        } }
    }
}

struct HeadPlacement: Equatable {
    // Coordinates are fractions of the upright image, measured from its top left.
    var top: Double
    var chin: Double
    var centerX: Double
    var width: Double? = nil
    func crop(in size: CGSize, settings: PhotoSettings) throws -> CGRect {
        if let error = settings.validationError { throw PhotoError.message(error) }
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              top.isFinite, chin.isFinite, centerX.isFinite,
              top >= 0, chin <= 1, chin > top + 0.02, centerX >= 0, centerX <= 1 else {
            throw PhotoError.message("头顶必须高于下巴，请调整头部方框。")
        }
        let headPixels = (chin - top) * size.height
        let height = headPixels * settings.photoHeight / ((settings.headMin + settings.headMax) / 2)
        let width = height * settings.photoWidth / settings.photoHeight
        let rect = CGRect(x: centerX * size.width - width / 2,
                          y: (top + chin) / 2 * size.height - height / 2, width: width, height: height)
        // Solid backgrounds can supply missing space above the source image.
        // Missing sides or bottom may cut off shoulders and must still be rejected.
        guard rect.minX >= 0, rect.maxX <= size.width, rect.maxY <= size.height,
              settings.background != .original || rect.minY >= 0 else {
            throw PhotoError.message("原图四周空间不足，无法满足当前头高和尺寸要求。请换一张拍摄更远、留白更多的照片，或调整定位及规格。")
        }
        if let headWidth = self.width {
            guard headWidth.isFinite, headWidth > 0,
                  (centerX - headWidth / 2) * size.width >= rect.minX,
                  (centerX + headWidth / 2) * size.width <= rect.maxX else {
                throw PhotoError.message("当前规格会裁掉头部左右边缘，请调整头部方框或证件照尺寸。")
            }
        }
        return rect
    }

    func framingError(in size: CGSize, settings: PhotoSettings) -> String? {
        do { _ = try crop(in: size, settings: settings); return nil }
        catch { return error.localizedDescription }
    }
}

enum PhotoError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return AppText.localized(text) }; return nil }
}

/// Normalized image coordinates; editing is independent of preview scale and letterboxing.
enum HeadBoxGeometry {
    enum Corner: CaseIterable, Hashable { case topLeft, topRight, bottomLeft, bottomRight }

    static func clamped(_ rect: CGRect, minimum: CGSize = CGSize(width: 0.04, height: 0.04)) -> CGRect {
        let width = min(1, max(minimum.width, rect.width))
        let height = min(1, max(minimum.height, rect.height))
        return CGRect(x: min(1 - width, max(0, rect.minX)),
                      y: min(1 - height, max(0, rect.minY)), width: width, height: height)
    }

    static func moved(_ rect: CGRect, by delta: CGSize) -> CGRect {
        clamped(rect.offsetBy(dx: delta.width, dy: delta.height))
    }

    static func resized(_ rect: CGRect, corner: Corner, by delta: CGSize,
                        minimum: CGSize = CGSize(width: 0.04, height: 0.04)) -> CGRect {
        var left = rect.minX, right = rect.maxX, top = rect.minY, bottom = rect.maxY
        switch corner {
        case .topLeft, .bottomLeft: left = max(0, min(right - minimum.width, left + delta.width))
        case .topRight, .bottomRight: right = min(1, max(left + minimum.width, right + delta.width))
        }
        switch corner {
        case .topLeft, .topRight: top = max(0, min(bottom - minimum.height, top + delta.height))
        case .bottomLeft, .bottomRight: bottom = min(1, max(top + minimum.height, bottom + delta.height))
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}

extension HeadPlacement {
    func selection(in imageSize: CGSize) -> CGRect {
        let boxWidth = width ?? (chin - top) * imageSize.height / max(1, imageSize.width) * 0.75
        return HeadBoxGeometry.clamped(CGRect(x: centerX - boxWidth / 2, y: top,
                                             width: boxWidth, height: chin - top))
    }

    func replacingSelection(_ rectangle: CGRect) -> HeadPlacement {
        let box = HeadBoxGeometry.clamped(rectangle)
        return HeadPlacement(top: box.minY, chin: box.maxY, centerX: box.midX, width: box.width)
    }
}
