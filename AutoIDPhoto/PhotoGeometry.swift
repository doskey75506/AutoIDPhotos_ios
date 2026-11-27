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
    var headTopMargin: Double? = nil
    var paperWidth = 6.0
    var paperHeight = 4.0
    var dpi = 300.0
    var preserveSourceResolution = true
    var gap = 2.0
    var background = Background.white
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
        case dpi, gap, background, preserveSourceResolution, headTopMargin
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        photoWidth = try values.decodeIfPresent(Double.self, forKey: .photoWidth) ?? 35
        photoHeight = try values.decodeIfPresent(Double.self, forKey: .photoHeight) ?? 45
        headMin = try values.decodeIfPresent(Double.self, forKey: .headMin) ?? 29
        headMax = try values.decodeIfPresent(Double.self, forKey: .headMax) ?? 34
        headTopMargin = try values.decodeIfPresent(Double.self, forKey: .headTopMargin)
        paperWidth = try values.decodeIfPresent(Double.self, forKey: .paperWidth) ?? 6
        paperHeight = try values.decodeIfPresent(Double.self, forKey: .paperHeight) ?? 4
        dpi = try values.decodeIfPresent(Double.self, forKey: .dpi) ?? 300
        let storedGap = try values.decodeIfPresent(Double.self, forKey: .gap) ?? 2
        gap = storedGap.isFinite ? max(SheetLayout.minimumGap, storedGap) : storedGap
        background = try values.decodeIfPresent(Background.self, forKey: .background) ?? .white
        preserveSourceResolution = try values.decodeIfPresent(Bool.self, forKey: .preserveSourceResolution) ?? true
    }

    var validationError: String? {
        let values = [photoWidth, photoHeight, headMin, headMax, paperWidth, paperHeight, dpi, gap]
        guard values.allSatisfy({ $0.isFinite }) else { return "请输入有效数字。" }
        if let margin = headTopMargin {
            guard margin.isFinite, margin >= 0, margin + headMax < photoHeight else {
                return "头顶留白须为非负数，且留白与最大头高之和须小于照片高度。"
            }
        }
        guard photoWidth >= 10, photoHeight >= 10, photoWidth <= 200, photoHeight <= 200,
              headMin >= 5, headMax >= headMin, headMax < photoHeight,
              paperWidth >= 1, paperWidth <= 12, paperHeight >= 1, paperHeight <= 12,
              dpi >= 150, dpi <= 600, gap >= SheetLayout.minimumGap, gap <= 10 else {
            return "证件照边长须为 10–200 mm；头高须小于照片高度；纸张须为 1–12 英寸；DPI 须为 150–600；最小间距须为 0.5–10 mm。"
        }
        guard layout.count > 0 else { return "打印纸放不下一张证件照，请增大纸张或缩小证件照。" }
        guard preserveSourceResolution || paperWidth * dpi * paperHeight * dpi <= 20_000_000 else { return "输出超过 2000 万像素，请降低 DPI 或纸张尺寸。" }
        return nil
    }
    var layout: SheetLayout {
        SheetLayout(paper: CGSize(width: paperWidth * 25.4, height: paperHeight * 25.4),
                    photo: CGSize(width: photoWidth, height: photoHeight), gap: gap)
    }

    /// Shared by disabled options, the confirm button and the actual crop path.
    func generationError(in imageSize: CGSize?, placement: HeadPlacement) -> String? {
        if let validationError { return validationError }
        guard let imageSize else { return "请先拍摄或选择一张照片。" }
        return placement.framingError(in: imageSize, settings: self)
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
    static let minimumGap = 0.5
    let paper: CGSize
    let photo: CGSize
    /// Minimum gap, not fixed spacing. Remaining paper is shared evenly.
    let gap: Double

    init(paper: CGSize, photo: CGSize, gap: Double) {
        self.paper = paper
        self.photo = photo
        self.gap = gap.isFinite ? max(Self.minimumGap, gap) : gap
    }
    // Inch-to-mm conversion can put an exact fit a few floating-point bits below
    // an integer (e.g. three 50.8 mm photos on 6 inches). Tolerance is in mm.
    private func capacity(paper: Double, photo: Double) -> Int {
        guard paper.isFinite, photo.isFinite, gap.isFinite, paper > 0, photo > 0, gap >= 0 else { return 0 }
        return max(0, Int(floor((paper + gap + 0.0000001) / (photo + gap))))
    }
    var columns: Int { capacity(paper: paper.width, photo: photo.width) }
    var rows: Int { capacity(paper: paper.height, photo: photo.height) }
    var count: Int { columns * rows }
    private func spacing(paper: Double, photo: Double, count: Int) -> (margin: Double, between: Double) {
        guard count > 0 else { return (0, 0) }
        let spare = max(0, paper - Double(count) * photo)
        guard count > 1 else { return (spare / 2, 0) }
        // Prefer the same space at the edges and between photos. On a tight
        // fit, preserve the minimum internal gap and reduce only outer margins.
        let between = max(gap, spare / Double(count + 1))
        return (max(0, (spare - Double(count - 1) * between) / 2), between)
    }
    var horizontalSpacing: Double { spacing(paper: paper.width, photo: photo.width, count: columns).between }
    var verticalSpacing: Double { spacing(paper: paper.height, photo: photo.height, count: rows).between }
    var horizontalMargin: Double { spacing(paper: paper.width, photo: photo.width, count: columns).margin }
    var verticalMargin: Double { spacing(paper: paper.height, photo: photo.height, count: rows).margin }
    var cutMarkClearance: Double {
        min(horizontalMargin, verticalMargin,
            columns > 1 ? horizontalSpacing / 2 : .infinity,
            rows > 1 ? verticalSpacing / 2 : .infinity)
    }
    var rectangles: [CGRect] {
        guard count > 0 else { return [] }
        return (0..<rows).flatMap { y in (0..<columns).map { x in
            CGRect(x: horizontalMargin + Double(x) * (photo.width + horizontalSpacing),
                   y: verticalMargin + Double(y) * (photo.height + verticalSpacing), width: photo.width, height: photo.height)
        } }
    }

    /// Used by both JPEG and PDF; all placements derive from physical millimetres.
    func rectangles(in outputSize: CGSize) -> [CGRect] {
        guard paper.width > 0, paper.height > 0 else { return [] }
        return rectangles.map { rect in
            CGRect(x: rect.minX / paper.width * outputSize.width,
                   y: rect.minY / paper.height * outputSize.height,
                   width: rect.width / paper.width * outputSize.width,
                   height: rect.height / paper.height * outputSize.height)
        }
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
        let cropTop = settings.headTopMargin.map { top * size.height - $0 / settings.photoHeight * height }
            ?? ((top + chin) / 2 * size.height - height / 2)
        let rect = CGRect(x: centerX * size.width - width / 2,
                          y: cropTop, width: width, height: height)
        // Solid backgrounds can supply missing space above the source image.
        // Missing sides or bottom may cut off shoulders and must still be rejected.
        if settings.background == .original && rect.minY < 0 {
            throw PhotoError.message("头顶留白不足。请重新拍摄，在头顶上方多留空白；也可选择单色背景补齐顶部。")
        }
        if rect.minX < 0 {
            throw PhotoError.message("左侧空间不足。请重新拍摄，将头部居中并在左侧多留空白。")
        }
        if rect.maxX > size.width {
            throw PhotoError.message("右侧空间不足。请重新拍摄，将头部居中并在右侧多留空白。")
        }
        if rect.maxY > size.height {
            throw PhotoError.message("下方空间不足。请重新拍摄，镜头离远一些，保留完整肩部和胸前空间。")
        }
        if let headWidth = self.width {
            guard headWidth.isFinite, headWidth > 0,
                  (centerX - headWidth / 2) * size.width >= rect.minX,
                  (centerX + headWidth / 2) * size.width <= rect.maxX else {
                throw PhotoError.message("当前规格会裁掉头部两侧。请检查人脸框，或重新拍摄并完整保留头部与双肩。")
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
    /// Expand the initial detected head vertically, without moving its centre horizontally.
    /// Clip at image edges rather than shifting the opposite edge to compensate.
    func expandedForInitialDetection() -> HeadPlacement {
        let height = chin - top
        guard height.isFinite, height > 0 else { return self }
        var result = self
        result.top = max(0, top - height * 0.20)
        result.chin = min(1, chin + height * 0.10)
        return result
    }

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
