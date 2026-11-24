import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum PhotoJPEGEncoder {
    static func encode(_ image: CGImage, dpi: Double, verticalDPI: Double? = nil) throws -> Data {
        let dpiY = verticalDPI ?? dpi
        guard dpi.isFinite, dpi > 0, dpiY.isFinite, dpiY > 0 else { throw PhotoError.message("无效的照片分辨率。") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoError.message("无法创建导出文件。")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.98,
                                                       kCGImagePropertyDPIWidth: dpi,
                                                       kCGImagePropertyDPIHeight: dpiY] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.message("导出失败。") }
        return data as Data
    }
}
