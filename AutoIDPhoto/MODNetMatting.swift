import Foundation
import CoreML
import CoreGraphics
import CoreVideo

/// Runs the converted Python MODNet weights directly through Core ML, without Vision.
enum MODNetMatting {
    static var modelURL: URL? { Bundle.main.url(forResource: "MODNet", withExtension: "mlmodelc") }
    static var isAvailable: Bool { modelURL != nil }
    static var engineDescription: String {
        isAvailable ? "背景模型：MODNet（Python 同源权重）" : "背景模型：Apple Vision（尚未导入 MODNet）"
    }

    static func mask(for image: CGImage) throws -> PersonMask {
        guard let url = modelURL else {
            throw PhotoError.message("未找到 MODNet 模型，请先运行转换脚本并重新编译。")
        }
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        configuration.computeUnits = .cpuOnly
        #else
        configuration.computeUnits = .all
        #endif
        do {
            let model = try MLModel(contentsOf: url, configuration: configuration)
            let input = try pixelBuffer(for: image)
            let features = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: input)])
            let prediction = try model.prediction(from: features)
            guard let matte = prediction.featureValue(for: "matte")?.multiArrayValue,
                  matte.shape.map(\.intValue) == [1, 1, 512, 512] else {
                throw PhotoError.message("MODNet 返回了非预期的蒙版尺寸。")
            }
            var bytes = [UInt8](repeating: 0, count: 512 * 512)
            let strideY = matte.strides[2].intValue, strideX = matte.strides[3].intValue
            for y in 0..<512 {
                for x in 0..<512 {
                    let index = y * strideY + x * strideX
                    let value: Double
                    switch matte.dataType {
                    case .float32: value = Double(matte.dataPointer.assumingMemoryBound(to: Float.self)[index])
                    case .double: value = matte.dataPointer.assumingMemoryBound(to: Double.self)[index]
                    default: value = matte[[0, 0, NSNumber(value: y), NSNumber(value: x)]].doubleValue
                    }
                    guard value.isFinite else { throw PhotoError.message("MODNet 蒙版包含无效像素。") }
                    bytes[y * 512 + x] = UInt8(clamping: Int((min(1, max(0, value)) * 255).rounded()))
                }
            }
            return PersonMask(width: 512, height: 512, bytesPerRow: 512, bytes: bytes)
        } catch {
            throw PhotoError.message(AppText.format("MODNet 背景处理失败：%@ 可选择原始背景继续排版。", error.localizedDescription))
        }
    }

    private static func pixelBuffer(for image: CGImage) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, 512, 512, kCVPixelFormatType_32BGRA,
                                  attributes, &buffer) == kCVReturnSuccess, let buffer else {
            throw PhotoError.message("无法创建 MODNet 输入图像。")
        }
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
            throw PhotoError.message("无法访问 MODNet 输入图像。")
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: base, width: 512, height: 512, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            throw PhotoError.message("无法准备 MODNet 输入图像。")
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))
        return buffer
    }
}
