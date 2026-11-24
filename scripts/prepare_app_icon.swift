import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else { fatalError("Usage: prepare_app_icon input.png output.png") }
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width == image.height,
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                              bytesPerRow: 1024 * 4, space: space,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
    fatalError("A square input image is required")
}
context.interpolationQuality = .high
context.setFillColor(CGColor(red: 0, green: 0.3, blue: 0.3, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Cannot create icon")
}
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot save icon") }
print("Prepared opaque 1024 × 1024 app icon: \(outputURL.path)")
