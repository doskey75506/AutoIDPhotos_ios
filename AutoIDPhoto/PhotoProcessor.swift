import UIKit
import Vision
import CoreML
import ImageIO
import UniformTypeIdentifiers

struct PhotoOutput {
    let portrait: UIImage
    let sheet: UIImage
    let portraitJPEG: Data
    let jpeg: Data
    let pdf: Data
    let count: Int
    let warning: String?
}

final class PhotoProcessor {
    private func perform(_ request: VNRequest, on image: CGImage, stage: String) throws {
        do {
            #if targetEnvironment(simulator)
            // Simulator inference may choose an unavailable accelerator. Select only
            // CPUs advertised by this particular request and compute stage.
            for (computeStage, devices) in try request.supportedComputeStageDevices {
                if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                    request.setComputeDevice(cpu, for: computeStage)
                }
            }
            #endif
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            throw VisionProcessingError(stage: stage, underlying: error)
        }
    }

    func normalize(_ input: UIImage) throws -> UIImage {
        if input.imageOrientation == .up, let cg = input.cgImage { return UIImage(cgImage: cg) }
        let size = CGSize(width: input.size.width * input.scale, height: input.size.height * input.scale)
        guard size.width > 0, size.height > 0 else { throw PhotoError.message("无法读取照片。") }
        return render(size: size) { input.draw(in: CGRect(origin: .zero, size: size)) }
    }

    func detect(_ image: UIImage) throws -> HeadPlacement {
        guard let cg = image.cgImage else { throw PhotoError.message("无法读取照片。") }
        let request = VNDetectFaceRectanglesRequest()
        try perform(request, on: cg, stage: "人脸检测")
        let faces = request.results ?? []
        guard faces.count == 1, let face = faces.first else {
            throw PhotoError.message(faces.isEmpty ? "未检测到正面人脸。请选择清晰、正面且包含完整头部的照片。" : "检测到多张人脸，请选择只有一人的照片。")
        }
        let box = face.boundingBox
        // Match the Python approximation, then let the user correct crown/chin.
        return HeadPlacement(top: max(0, 1 - box.maxY - box.height / 6), chin: 1 - box.minY, centerX: box.midX, width: box.width)
    }

    func generate(_ image: UIImage, placement: HeadPlacement, settings: PhotoSettings) throws -> PhotoOutput {
        if let error = settings.validationError { throw PhotoError.message(error) }
        let crop = try placement.crop(in: image.size, settings: settings)
        let cleaned = try removeBackground(image, mode: settings.background, head: placement)
        let resolution = PhotoResolutionPlan(crop: crop, settings: settings)
        let portraitSize = resolution.portraitSize
        let portrait = render(size: portraitSize) {
            // Fill before drawing: the crop may extend above the source for a solid background.
            let color = settings.background.replacementColor ?? PhotoBackgroundColor(gray: 255)
            UIColor(red: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255,
                    blue: CGFloat(color.blue) / 255, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: portraitSize))
            cleaned.draw(in: CGRect(x: -crop.minX / crop.width * portraitSize.width,
                                   y: -crop.minY / crop.height * portraitSize.height,
                                   width: image.size.width / crop.width * portraitSize.width,
                                   height: image.size.height / crop.height * portraitSize.height))
        }
        let layout = settings.layout
        let sheetSize = resolution.sheetSize
        let sheet = render(size: sheetSize) {
            drawSheet(portrait, layout: layout, size: sheetSize)
        }
        let pdfSize = CGSize(width: settings.paperWidth * 72, height: settings.paperHeight * 72)
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pdfSize)).pdfData { renderer in
            renderer.beginPage()
            drawSheet(portrait, layout: layout, size: pdfSize)
        }
        guard let portraitCG = portrait.cgImage, let sheetCG = sheet.cgImage else {
            throw PhotoError.message("无法读取生成的照片。")
        }
        let portraitJPEG = try PhotoJPEGEncoder.encode(portraitCG, dpi: resolution.portraitDPI.width, verticalDPI: resolution.portraitDPI.height)
        let sheetJPEG = try PhotoJPEGEncoder.encode(sheetCG, dpi: resolution.sheetDPI.width, verticalDPI: resolution.sheetDPI.height)
        let warning: String?
        if resolution.sheetWasLimited {
            warning = "单张证件照保留原图裁切精度；打印 JPEG 已限制为 2000 万像素。需要完整精度的拼版请分享 PDF。"
        } else if !settings.preserveSourceResolution && (crop.width < portraitSize.width || crop.height < portraitSize.height) {
            warning = "原图裁切区域分辨率不足，已放大输出；建议使用更清晰的原图。"
        } else {
            warning = nil
        }
        return PhotoOutput(portrait: portrait, sheet: sheet, portraitJPEG: portraitJPEG, jpeg: sheetJPEG, pdf: pdf, count: layout.count, warning: warning)
    }

    private func removeBackground(_ image: UIImage, mode: PhotoSettings.Background, head: HeadPlacement) throws -> UIImage {
        guard let color = mode.replacementColor else { return image }
        guard let cg = image.cgImage else { throw PhotoError.message("无法读取照片。") }
        if MODNetMatting.isAvailable {
            let mask = try MODNetMatting.mask(for: cg)
            let output = try BackgroundCompositor.composite(cg, mask: mask, head: head,
                                                            color: color)
            return UIImage(cgImage: output)
        }
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try perform(request, on: cg, stage: "背景分割")
        guard let buffer = request.results?.first?.pixelBuffer else {
            throw PhotoError.message("未能分离人物和背景，请换图或选择原始背景。")
        }
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else {
            throw PhotoError.message("无法读取人物蒙版，请重试或选择原始背景。")
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw PhotoError.message("人物蒙版为空，请重试或选择原始背景。")
        }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let mask = PersonMask(width: CVPixelBufferGetWidth(buffer), height: height, bytesPerRow: stride,
                              bytes: Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: stride * height)))
        let output = try BackgroundCompositor.composite(cg, mask: mask, head: head,
                                                        color: color)
        return UIImage(cgImage: output)
    }

    private func render(size: CGSize, draw: () -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            draw()
        }
    }

    private func drawSheet(_ portrait: UIImage, layout: SheetLayout, size: CGSize) {
        // Match Python's 127/255 gray spacer so light photo backgrounds have
        // a visible cutting boundary. Fill outside the exact photo rectangles.
        UIColor(white: CGFloat(SheetLayout.spacerGray) / 255, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        for rect in layout.rectangles {
            let target = CGRect(x: rect.minX / layout.paper.width * size.width,
                                y: rect.minY / layout.paper.height * size.height,
                                width: rect.width / layout.paper.width * size.width,
                                height: rect.height / layout.paper.height * size.height)
            portrait.draw(in: target)
            // Fine outside cutting guides; never draw a border over the photo.
            if layout.gap >= 1 {
                let path = UIBezierPath()
                let length = min(layout.gap / 3, 1) * size.width / layout.paper.width
                for x in [target.minX, target.maxX] {
                    for y in [target.minY, target.maxY] {
                        let dx: CGFloat = x == target.minX ? -1 : 1
                        let dy: CGFloat = y == target.minY ? -1 : 1
                        path.move(to: CGPoint(x: x + dx * length * 0.3, y: y))
                        path.addLine(to: CGPoint(x: x + dx * length, y: y))
                        path.move(to: CGPoint(x: x, y: y + dy * length * 0.3))
                        path.addLine(to: CGPoint(x: x, y: y + dy * length))
                    }
                }
                UIColor.lightGray.setStroke()
                path.lineWidth = max(0.2, size.width / layout.paper.width * 0.08)
                path.stroke()
            }
        }
    }
}

struct VisionProcessingError: LocalizedError {
    let stage: String
    let underlying: Error
    var errorDescription: String? {
        let error = underlying as NSError
        var text = AppText.format("%@失败：%@（%@ / %d）。", AppText.localized(stage), error.localizedDescription, error.domain, error.code)
        #if targetEnvironment(simulator)
        text += AppText.localized("模拟器可能无法运行此 Vision 模型。")
        if stage == "背景分割" {
            text += AppText.localized("可在规格设置中选择“原始背景”继续测试裁切和拼版；背景清理请在真机验证。")
        }
        #endif
        return text
    }
}
