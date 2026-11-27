import Foundation
import CoreGraphics
import ImageIO

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    checks += 1
}
let defaults = PhotoSettings()
check(defaults.validationError == nil, "Defaults must be valid")
check(defaults.background == .white, "Fresh and restored defaults must use a white background")
check(defaults.photoWidth == 35 && defaults.photoHeight == 45 && defaults.headMin == 29 && defaults.headMax == 34
      && defaults.headTopMargin == nil && defaults.paperWidth == 6 && defaults.paperHeight == 4
      && defaults.dpi == 300 && defaults.preserveSourceResolution && defaults.gap == 2,
      "Changing the default background must leave all other default parameters unchanged")
check(defaults.layout.count == 8, "6 × 4 inch paper should fit eight 35 × 45 mm photos")
check(defaults.layout.columns == 4 && defaults.layout.rows == 2, "Default layout must be 4 × 2")
for rectangle in defaults.layout.rectangles {
    check(abs(rectangle.width - 35) < 0.00001 && abs(rectangle.height - 45) < 0.00001, "Never resize physical photo dimensions to fill paper")
    check(CGRect(origin: .zero, size: defaults.layout.paper).contains(rectangle), "Photos must remain inside paper")
}
let head = HeadPlacement(top: 0.25, chin: 0.65, centerX: 0.5)
let size = CGSize(width: 1800, height: 2400)
let crop = try head.crop(in: size, settings: defaults)
check(abs(crop.width / crop.height - 35.0 / 45) < 0.00001, "Crop must preserve portrait aspect ratio")
let physicalHead = (head.chin - head.top) * size.height / crop.height * defaults.photoHeight
check(abs(physicalHead - 31.5) < 0.00001, "Crown to chin must print at target head height")
for invalid in [HeadPlacement(top: 0.7, chin: 0.3, centerX: 0.5), HeadPlacement(top: 0, chin: 0.9, centerX: 0.1)] {
    do { _ = try invalid.crop(in: size, settings: defaults); fatalError("Invalid crop accepted") }
    catch { checks += 1 }
}
// Live framing uses the same crop validation as generation, including top padding.
let nearTop = HeadPlacement(top: 0.02, chin: 0.42, centerX: 0.5, width: 0.35)
for background in [PhotoSettings.Background.white, .lightGray, .blue, .red] {
    var solid = defaults
    solid.background = background
    let padded = try nearTop.crop(in: size, settings: solid)
    check(padded.minY < 0, "Solid backgrounds must allow missing space above the source")
    check(nearTop.framingError(in: size, settings: solid) == nil, "Live frame must accept top padding")
    check(abs((nearTop.chin - nearTop.top) * size.height / padded.height * solid.photoHeight - 31.5) < 0.00001,
          "Padding must preserve physical head height")
}
var originalSettings = defaults
originalSettings.background = .original
check(nearTop.framingError(in: size, settings: originalSettings) != nil, "Original background cannot invent missing top space")
check(HeadPlacement(top: 0.60, chin: 0.98, centerX: 0.5).framingError(in: size, settings: defaults) != nil,
      "Solid backgrounds must still reject missing bottom space")
check(HeadPlacement(top: 0.02, chin: 0.42, centerX: 0.1).framingError(in: size, settings: defaults) != nil,
      "Solid backgrounds must still reject missing side space")
let wideHead = HeadPlacement(top: 0.25, chin: 0.65, centerX: 0.5, width: 0.4)
check(wideHead.framingError(in: size, settings: defaults) == nil, "Full selected head should fit default dimensions")
var narrowPhoto = defaults
narrowPhoto.photoWidth = 20
check(wideHead.framingError(in: size, settings: narrowPhoto) != nil, "Changing dimensions must detect head sides being cropped")
var invalidFramingSettings = defaults
invalidFramingSettings.dpi = .nan
check(head.framingError(in: size, settings: invalidFramingSettings) != nil, "Invalid current settings must fail live validation")
check(head.framingError(in: .zero, settings: defaults) != nil, "Zero-sized images must fail validation")
check(HeadPlacement(top: .nan, chin: 0.6, centerX: 0.5).framingError(in: size, settings: defaults) != nil,
      "Invalid coordinates must fail validation")

// Disabled options use precisely the same validation path as generation.
check(originalSettings.generationError(in: size, placement: nearTop)
      == AppText.localized("头顶留白不足。请重新拍摄，在头顶上方多留空白；也可选择单色背景补齐顶部。"),
      "Original-background options must explain insufficient headroom")
check(defaults.generationError(in: size, placement: nearTop) == nil,
      "White backgrounds must stay selectable when only top padding is missing")
check(defaults.generationError(in: size, placement: HeadPlacement(top: 0.02, chin: 0.42, centerX: 0.1))
      == AppText.localized("左侧空间不足。请重新拍摄，将头部居中并在左侧多留空白。"),
      "Unavailable options must explain missing left-side space")
check(defaults.generationError(in: size, placement: HeadPlacement(top: 0.02, chin: 0.42, centerX: 0.9))
      == AppText.localized("右侧空间不足。请重新拍摄，将头部居中并在右侧多留空白。"),
      "Unavailable options must explain missing right-side space")
check(defaults.generationError(in: size, placement: HeadPlacement(top: 0.60, chin: 0.98, centerX: 0.5))
      == AppText.localized("下方空间不足。请重新拍摄，镜头离远一些，保留完整肩部和胸前空间。"),
      "Unavailable options must explain missing shoulder space")
check(narrowPhoto.generationError(in: size, placement: wideHead)
      == AppText.localized("当前规格会裁掉头部两侧。请检查人脸框，或重新拍摄并完整保留头部与双肩。"),
      "Unavailable narrow formats must explain head-edge cropping")
check(defaults.generationError(in: nil, placement: head) != nil,
      "No format can be generated without a source photo")
let offCentreHead = HeadPlacement(top: 0.25, chin: 0.65, centerX: 0.32, width: 0.3)
check(PhotoPreset.ukPassport.applying(to: defaults).generationError(in: size, placement: offCentreHead) == nil,
      "Availability checks must retain document formats which fit the current photo")
check(PhotoPreset.usPassport.applying(to: defaults).generationError(in: size, placement: offCentreHead) != nil,
      "Changing to a wider format must disable it if the source lacks side space")
var smallPaperOption = defaults
smallPaperOption.paperWidth = 1
check(smallPaperOption.generationError(in: size, placement: head) == smallPaperOption.validationError,
      "A paper size that cannot contain one photo must be unavailable")

var settings = defaults
settings.paperWidth = 1
check(settings.validationError != nil, "Reject paper that cannot fit one photo")
settings = defaults
settings.headMax = 50
check(settings.validationError != nil, "Reject head larger than portrait")
settings = defaults
settings.dpi = .nan
check(settings.validationError != nil, "Reject nonfinite settings")
settings = defaults
settings.paperWidth = 12
settings.paperHeight = 12
settings.dpi = 600
settings.preserveSourceResolution = false
check(settings.validationError != nil, "Bound output memory")
for width in [4.0, 5, 6, 8, 10] {
    for height in [4.0, 6, 8] {
        settings = defaults
        settings.paperWidth = width
        settings.paperHeight = height
        check(settings.validationError == nil, "Reasonable paper sizes should work")
        for rect in settings.layout.rectangles {
            check(CGRect(origin: .zero, size: settings.layout.paper).contains(rect), "Custom layout must fit")
            check(rect.size == CGSize(width: 35, height: 45), "Custom layout must keep exact dimensions")
        }
    }
}
let encoded = try JSONEncoder().encode(defaults)
let decoded = try JSONDecoder().decode(PhotoSettings.self, from: encoded)
check(decoded == defaults, "Settings should persist")


// Source-resolution mode preserves crop pixels; print raster is separately bounded.
check(defaults.preserveSourceResolution, "Original resolution must be the default")
let nativePlan = PhotoResolutionPlan(crop: crop, settings: defaults)
check(nativePlan.portraitSize == CGSize(width: floor(crop.width), height: floor(crop.height)),
      "Native portrait must preserve all whole pixels in the source crop")
check(nativePlan.portraitSize.width <= crop.width && nativePlan.portraitSize.height <= crop.height,
      "Native mode must never upscale to invent detail")
check(abs(nativePlan.portraitSize.width / nativePlan.portraitDPI.width * 25.4 - defaults.photoWidth) < 0.000001,
      "Native horizontal metadata must preserve physical photo width")
check(abs(nativePlan.portraitSize.height / nativePlan.portraitDPI.height * 25.4 - defaults.photoHeight) < 0.000001,
      "Native vertical metadata must preserve physical photo height")
let largerCrop = try head.crop(in: CGSize(width: 3600, height: 4800), settings: defaults)
let largerPlan = PhotoResolutionPlan(crop: largerCrop, settings: defaults)
check(largerPlan.portraitSize.width >= nativePlan.portraitSize.width * 2,
      "A higher-resolution source must yield a more detailed portrait")
check(largerPlan.sheetWasLimited && largerPlan.sheetSize.width * largerPlan.sheetSize.height <= PhotoResolutionPlan.maximumSheetPixels,
      "Large native portraits must not allocate an unbounded print raster")
check(largerPlan.portraitSize.width == floor(largerCrop.width), "Print limits must never reduce the single photo")
let lowDetailPlan = PhotoResolutionPlan(crop: CGRect(x: 0, y: 0, width: 350, height: 450), settings: defaults)
check(!lowDetailPlan.sheetWasLimited, "Small sources need no print-raster limit")
check(lowDetailPlan.portraitSize == CGSize(width: 350, height: 450), "Low-detail sources must not be upscaled in native mode")
var fixedSettings = defaults
fixedSettings.preserveSourceResolution = false
let fixedPlan = PhotoResolutionPlan(crop: crop, settings: fixedSettings)
check(fixedPlan.portraitSize == CGSize(width: 413, height: 531), "Fixed 300 DPI must retain the previous single-photo dimensions")
check(fixedPlan.sheetSize == CGSize(width: 1800, height: 1200), "Fixed 300 DPI must retain the previous print dimensions")
let restoredFixedSettings = try JSONDecoder().decode(PhotoSettings.self, from: JSONEncoder().encode(fixedSettings))
check(restoredFixedSettings == fixedSettings,
      "An explicit fixed-DPI choice must persist")
var savedBeforeResolutionMode = try JSONSerialization.jsonObject(with: JSONEncoder().encode(defaults)) as! [String: Any]
savedBeforeResolutionMode.removeValue(forKey: "preserveSourceResolution")
savedBeforeResolutionMode["gap"] = 3.0
savedBeforeResolutionMode["dpi"] = 450.0
let migratedResolution = try JSONDecoder().decode(PhotoSettings.self, from: JSONSerialization.data(withJSONObject: savedBeforeResolutionMode))
check(migratedResolution.preserveSourceResolution && migratedResolution.gap == 3 && migratedResolution.dpi == 450,
      "Old settings must default to native resolution while retaining existing values")

// Regression: a valid-looking segmentation buffer can contain no foreground.
let testHead = HeadPlacement(top: 0.05, chin: 0.45, centerX: 0.5)
var sourcePixels = [UInt8]()
for index in 0..<16 {
    let red = UInt8(40 + index * 4)
    let green = UInt8(80 + index)
    let blue = UInt8(150 - index)
    sourcePixels.append(contentsOf: [red, green, blue, 255])
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let provider = CGDataProvider(data: Data(sourcePixels) as CFData)!
let source = CGImage(width: 4, height: 4, bitsPerComponent: 8, bitsPerPixel: 32,
                     bytesPerRow: 16, space: space,
                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                     provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
func readPixels(_ image: CGImage) -> [UInt8] {
    let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8,
                            bytesPerRow: 16, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: 4, height: 4))
    return Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: 64))
}
// Asymmetric mask and padded rows verify orientation, stride, and foreground preservation.
let mask = PersonMask(width: 4, height: 4, bytesPerRow: 8,
                      bytes: [255,255,255,255,17,17,17,17, 255,255,255,255,17,17,17,17,
                              0,0,0,0,17,17,17,17, 0,0,0,0,17,17,17,17])
let composite = try BackgroundCompositor.composite(source, mask: mask, head: testHead, gray: 240)
let result = readPixels(composite)
for index in 0..<16 {
    let offset = index * 4
    if index < 8 {
        check(Array(result[offset..<offset+4]) == Array(sourcePixels[offset..<offset+4]), "Foreground must retain original color and top/bottom orientation")
    } else {
        check(Array(result[offset..<offset+4]) == [240,240,240,255], "Only background should become gray")
    }
}
// Settings choose the photo background independently from print-sheet separators.
check(PhotoSettings.Background.original.replacementColor == nil, "Original mode must not replace the background")
check(PhotoSettings.Background.white.replacementColor == PhotoBackgroundColor(gray: 255), "White must be pure white")
check(PhotoSettings.Background.lightGray.replacementColor == PhotoBackgroundColor(gray: 240), "Light gray must retain the requested 240 shade")
check(SheetLayout.spacerGray == 127, "Print separators must remain medium gray")
for background in [PhotoSettings.Background.white, .lightGray, .blue, .red] {
    let color = background.replacementColor!
    let selectedResult = readPixels(try BackgroundCompositor.composite(source, mask: mask, head: testHead, color: color))
    for index in 0..<16 {
        let offset = index * 4
        if index < 8 {
            check(Array(selectedResult[offset..<offset+4]) == Array(sourcePixels[offset..<offset+4]),
                  "Changing background must preserve foreground pixels")
        } else {
            check(Array(selectedResult[offset..<offset+4]) == [color.red,color.green,color.blue,255],
                  "Background pixels must match the selected photo background")
        }
    }
}
check(PhotoSettings.Background.blue.replacementColor == PhotoBackgroundColor(red: 67, green: 142, blue: 219),
      "Blue must match the reference site's solid blue swatch")
check(PhotoSettings.Background.red.replacementColor == PhotoBackgroundColor(red: 255, green: 0, blue: 0),
      "Red must match the reference site's solid red swatch")
for background in [PhotoSettings.Background.blue, .red] {
    var coloredSettings = defaults
    coloredSettings.background = background
    let restored = try JSONDecoder().decode(PhotoSettings.self, from: JSONEncoder().encode(coloredSettings))
    check(restored == coloredSettings, "New background choices must persist")
    let color = background.replacementColor!
    let blend = readPixels(try BackgroundCompositor.composite(source,
        mask: PersonMask(width: 2, height: 2, bytesPerRow: 2, bytes: [128,128,128,128]),
        head: testHead, color: color))
    for (channel, component) in [color.red, color.green, color.blue].enumerated() {
        let expected = (Double(sourcePixels[channel]) * 128 + Double(component) * 127) / 255
        check(abs(Double(blend[channel]) - expected) <= 1, "Soft edges must blend each RGB channel independently")
    }
}
let opaque = PersonMask(width: 2, height: 2, bytesPerRow: 2, bytes: [255,255,255,255])
let unchanged = try BackgroundCompositor.composite(source, mask: opaque, head: testHead, gray: 255)
check(readPixels(unchanged) == sourcePixels, "Low-resolution foreground mask must preserve all source pixels")
let soft = PersonMask(width: 2, height: 2, bytesPerRow: 2, bytes: [128,128,128,128])
let softResult = readPixels(try BackgroundCompositor.composite(source, mask: soft, head: testHead, gray: 240))
check(abs(Int(softResult[0]) - 140) <= 1, "Soft mask edges should blend, rather than erase the person")
let badMasks = [
    PersonMask(width: 4, height: 4, bytesPerRow: 4, bytes: Array(repeating: 0, count: 16)),
    PersonMask(width: 4, height: 4, bytesPerRow: 4, bytes: Array(repeating: 0, count: 8) + Array(repeating: 255, count: 8)),
    PersonMask(width: 4, height: 4, bytesPerRow: 2, bytes: [255,255]),
    PersonMask(width: 0, height: 0, bytesPerRow: 0, bytes: [])
]
for badMask in badMasks {
    do {
        _ = try BackgroundCompositor.composite(source, mask: badMask, head: testHead, gray: 240)
        fatalError("Reject blank, misplaced or malformed masks before producing a gray photo")
    } catch { checks += 1 }
}


// Previously saved cleaning-method choices must not prevent settings from loading.
for previousMethod in ["纯色背景（头部辅助）", "人像模型（MODNet / Vision）"] {
    var legacyObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(defaults)) as! [String: Any]
    legacyObject["mattingMethod"] = previousMethod
    legacyObject["background"] = PhotoSettings.Background.lightGray.rawValue
    legacyObject["gap"] = 3.0
    let migrated = try JSONDecoder().decode(PhotoSettings.self, from: JSONSerialization.data(withJSONObject: legacyObject))
    check(migrated.gap == 3 && migrated.photoWidth == 35 && migrated.background == .lightGray,
          "Ignore removed cleaning method while preserving saved photo settings")
}


// Direct manipulation uses image fractions, so preview scale never changes output geometry.
let detectedHead = HeadPlacement(top: 0.25, chin: 0.65, centerX: 0.5, width: 0.30)
let selection = detectedHead.selection(in: size)
check(abs(selection.width - 0.3) < 0.000001, "Selection must use the detector's actual face width")
let movedBox = HeadBoxGeometry.moved(selection, by: CGSize(width: 0.1, height: -0.05))
let movedHead = detectedHead.replacingSelection(movedBox)
check(abs(movedHead.centerX - 0.6) < 0.000001 && abs(movedHead.top - 0.2) < 0.000001,
      "Moving the box must update both horizontal center and head position")
check(abs(movedHead.chin - movedHead.top - 0.4) < 0.000001, "Moving must preserve the head height")
let edgeMove = HeadBoxGeometry.moved(selection, by: CGSize(width: 100, height: -100))
check(abs(edgeMove.maxX - 1) < 0.000001 && edgeMove.minY == 0 && edgeMove.size == selection.size,
      "Dragging beyond the image must clamp position, without shrinking the head")
for corner in HeadBoxGeometry.Corner.allCases {
    for translation in [CGSize(width: 0.03, height: -0.02), CGSize(width: 100, height: 100), CGSize(width: -100, height: -100)] {
        let resized = HeadBoxGeometry.resized(selection, corner: corner, by: translation)
        check(resized.minX >= 0 && resized.minY >= 0 && resized.maxX <= 1 && resized.maxY <= 1,
              "All corner drags must remain inside the image")
        check(resized.width >= 0.04 - 0.000001 && resized.height >= 0.04 - 0.000001,
              "Corners must never cross or collapse to zero")
        let oldOpposite: CGPoint
        let newOpposite: CGPoint
        switch corner {
        case .topLeft: oldOpposite = CGPoint(x: selection.maxX, y: selection.maxY); newOpposite = CGPoint(x: resized.maxX, y: resized.maxY)
        case .topRight: oldOpposite = CGPoint(x: selection.minX, y: selection.maxY); newOpposite = CGPoint(x: resized.minX, y: resized.maxY)
        case .bottomLeft: oldOpposite = CGPoint(x: selection.maxX, y: selection.minY); newOpposite = CGPoint(x: resized.maxX, y: resized.minY)
        case .bottomRight: oldOpposite = CGPoint(x: selection.minX, y: selection.minY); newOpposite = CGPoint(x: resized.minX, y: resized.minY)
        }
        check(abs(oldOpposite.x - newOpposite.x) < 0.000001 && abs(oldOpposite.y - newOpposite.y) < 0.000001,
              "Resizing one corner must keep the opposite corner anchored")
    }
}
let resizedBox = HeadBoxGeometry.resized(selection, corner: .bottomRight, by: CGSize(width: 0.05, height: 0.03))
let resizedHead = detectedHead.replacingSelection(resizedBox)
let editedCrop = try resizedHead.crop(in: size, settings: defaults)
let editedHeadMM = (resizedHead.chin - resizedHead.top) * size.height / editedCrop.height * defaults.photoHeight
check(abs(editedHeadMM - 31.5) < 0.000001, "Edited head height must drive the physical print crop")
check(abs(editedCrop.width / editedCrop.height - 35.0 / 45) < 0.000001, "Box editing must preserve the passport photo aspect ratio")


// Single-photo export must carry its own pixel dimensions and requested print DPI.
for dpi in [150.0, 300.0, 600.0] {
    let jpeg = try PhotoJPEGEncoder.encode(source, dpi: dpi)
    let decoded = CGImageSourceCreateWithData(jpeg as CFData, nil)!
    let properties = CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil)! as NSDictionary
    check(properties[kCGImagePropertyPixelWidth] as? Int == source.width && properties[kCGImagePropertyPixelHeight] as? Int == source.height,
          "JPEG export must preserve single-image dimensions")
    check(abs((properties[kCGImagePropertyDPIWidth] as! NSNumber).doubleValue - dpi) < 1,
          "JPEG must include horizontal DPI")
    check(abs((properties[kCGImagePropertyDPIHeight] as! NSNumber).doubleValue - dpi) < 1,
          "JPEG must include vertical DPI")
    check(CGImageSourceCreateImageAtIndex(decoded, 0, nil) != nil, "Exported JPEG must decode as an image")
}


// Native pixel rounding can require different horizontal and vertical DPI.
let nativeJPEG = try PhotoJPEGEncoder.encode(source, dpi: 305.25, verticalDPI: 307.75)
let nativeJPEGSource = CGImageSourceCreateWithData(nativeJPEG as CFData, nil)!
let nativeJPEGProperties = CGImageSourceCopyPropertiesAtIndex(nativeJPEGSource, 0, nil)! as NSDictionary
check(abs((nativeJPEGProperties[kCGImagePropertyDPIWidth] as! NSNumber).doubleValue - 305.25) < 1,
      "JPEG must retain native horizontal density")
check(abs((nativeJPEGProperties[kCGImagePropertyDPIHeight] as! NSNumber).doubleValue - 307.75) < 1,
      "JPEG must retain native vertical density")

// Initial detection padding is relative to the original detected height.
let initialDetectedHead = HeadPlacement(top: 0.3, chin: 0.7, centerX: 0.47, width: 0.22)
let paddedHead = initialDetectedHead.expandedForInitialDetection()
check(abs(paddedHead.top - 0.22) < 0.000001, "Initial head box must extend upward by 20% of detected height")
check(abs(paddedHead.chin - 0.74) < 0.000001, "Initial head box must extend downward by 10% of detected height")
check(paddedHead.width == initialDetectedHead.width && paddedHead.centerX == initialDetectedHead.centerX,
      "Initial vertical expansion must preserve horizontal framing")
let edgeHead = HeadPlacement(top: 0.01, chin: 0.99, centerX: 0.5, width: 0.3).expandedForInitialDetection()
check(edgeHead.top == 0 && edgeHead.chin == 1, "Detection padding must clip to the source image")
let editedHead = paddedHead.replacingSelection(CGRect(x: 0.3, y: 0.2, width: 0.25, height: 0.5))
check(abs(editedHead.top - 0.2) < 0.000001 && abs(editedHead.chin - 0.7) < 0.000001,
      "Manual edits must use exact user bounds without reapplying detection padding")
check(HeadPlacement(top: 0.7, chin: 0.3, centerX: 0.5).expandedForInitialDetection().top == 0.7,
      "Invalid detection bounds must not be expanded")

// Template geometry is applied without overwriting the user's print setup.
var customPaper = PhotoSettings()
customPaper.paperWidth = 8
customPaper.paperHeight = 6
customPaper.gap = 3
customPaper.dpi = 450
customPaper.preserveSourceResolution = false
let referenceHead = HeadPlacement(top: 0.3, chin: 0.55, centerX: 0.5, width: 0.18)
let referenceSize = CGSize(width: 3600, height: 4800)
for preset in PhotoPreset.allCases {
    let settings = preset.applying(to: customPaper)
    check(settings.validationError == nil, "Every built-in preset must have valid printable geometry")
    check(preset.matches(settings), "Applied presets must be recognised without numeric editing")
    check(settings.paperWidth == 8 && settings.paperHeight == 6 && settings.gap == 3
          && settings.dpi == 450 && !settings.preserveSourceResolution,
          "Choosing a document preset must preserve paper and resolution choices")
    check(settings.background == customPaper.background, "Preset selection must preserve the chosen background")
    let crop = try referenceHead.crop(in: referenceSize, settings: settings)
    let printedHead = (referenceHead.chin - referenceHead.top) * referenceSize.height / crop.height * settings.photoHeight
    check(abs(printedHead - (settings.headMin + settings.headMax) / 2) < 0.000001,
          "Preset head height must be represented in printed millimetres")
    if let margin = settings.headTopMargin {
        let printedMargin = (referenceHead.top * referenceSize.height - crop.minY) / crop.height * settings.photoHeight
        check(abs(printedMargin - margin) < 0.000001, "Presets with top margins must position the head accordingly")
    }
    check(preset.sourceURL.scheme == "https", "Each preset must link to its official reference")
}
let usPreset = PhotoPreset.usVisa.applying(to: PhotoSettings())
check(usPreset.photoWidth == 50.8 && usPreset.photoHeight == 50.8,
      "US print size must retain exact two-inch dimensions")
check(usPreset.headMin == 25.4 && usPreset.headMax == 34.925,
      "US head-height bounds must retain the official inch specification")
// The menu label determines geometry at confirmation, even if the draft still
// contains previous UK dimensions. Paper, resolution and explicit colour survive.
var previousUKDraft = PhotoSettings()
previousUKDraft.background = .blue
let confirmedUS = PhotoPreset.usPassport.applyingGeometry(to: previousUKDraft)
check(confirmedUS.photoWidth == 50.8 && confirmedUS.photoHeight == 50.8,
      "US confirmation must override previous rectangular UK dimensions")
check(confirmedUS.background == .blue && confirmedUS.paperWidth == 6 && confirmedUS.paperHeight == 4,
      "Resolving the selected preset must retain user background and paper settings")
check(confirmedUS.layout.count == 2 && confirmedUS.layout.columns == 2 && confirmedUS.layout.rows == 1,
      "Two-inch squares with 2 mm gaps fit two across a 6 by 4 inch sheet, not eight rectangles")
for rectangle in confirmedUS.layout.rectangles {
    check(rectangle.width == 50.8 && rectangle.height == 50.8, "US sheet cells must remain exact two-inch squares")
}
var minimumGapUS = confirmedUS
minimumGapUS.gap = 0.5
check(minimumGapUS.layout.columns == 2 && minimumGapUS.layout.rows == 1 && minimumGapUS.layout.count == 2,
      "The minimum half-millimetre gap prevents edge-to-edge packing of two-inch squares")
for rectangle in minimumGapUS.layout.rectangles(in: CGSize(width: 1800, height: 1200)) {
    check(abs(rectangle.width - 600) < 0.000001 && abs(rectangle.height - 600) < 0.000001,
          "US print JPEG cells must be square at 300 DPI")
}
for rectangle in minimumGapUS.layout.rectangles(in: CGSize(width: 432, height: 288)) {
    check(abs(rectangle.width - 144) < 0.000001 && abs(rectangle.height - 144) < 0.000001,
          "PDF cell size must be 144 by 144 points, exactly two inches")
}
var largerUSSheet = minimumGapUS
largerUSSheet.paperWidth = 8
largerUSSheet.paperHeight = 6
check(largerUSSheet.layout.count == 6, "Changing paper size must recalculate row and column counts")
let barelyTooSmall = SheetLayout(paper: CGSize(width: 150.999, height: 101), photo: CGSize(width: 50, height: 50), gap: 0.5)
check(barelyTooSmall.columns == 2, "Float tolerance must not squeeze genuinely oversized photos onto paper")
for preset in PhotoPreset.allCases {
    let settings = preset.applying(to: PhotoSettings())
    let plan = settings.layout
    let pdfSize = CGSize(width: settings.paperWidth * 72, height: settings.paperHeight * 72)
    for rectangle in plan.rectangles(in: pdfSize) {
        check(abs(rectangle.width / 72 * 25.4 - settings.photoWidth) < 0.000001
              && abs(rectangle.height / 72 * 25.4 - settings.photoHeight) < 0.000001,
              "Every document preset must preserve its required physical dimensions in PDF")
        check(rectangle.minX >= -0.000001 && rectangle.minY >= -0.000001
              && rectangle.maxX <= pdfSize.width + 0.000001 && rectangle.maxY <= pdfSize.height + 0.000001,
              "All dynamically arranged photos must stay inside the paper")
    }
}
// Distribute spare paper evenly instead of clustering a fixed-gap grid.
let evenlySpaced = PhotoSettings().layout
let evenRects = evenlySpaced.rectangles
check(abs(evenRects[0].minX - 2.48) < 0.000001,
      "Default print grid must spread its horizontal spare space across all five gaps")
check(abs(evenRects[0].minY - 11.6 / 3) < 0.000001,
      "Default print grid must spread vertical spare space across all three gaps")
check(abs(evenRects[1].minX - evenRects[0].maxX - evenRects[0].minX) < 0.000001,
      "When space permits, outer and internal horizontal gaps must be equal")
check(abs(evenlySpaced.paper.width - evenRects[3].maxX - evenRects[0].minX) < 0.000001,
      "Left and right margins must match")
let tightLayout = SheetLayout(paper: CGSize(width: 100.5, height: 30), photo: CGSize(width: 50, height: 20), gap: 0)
check(tightLayout.gap == 0.5 && tightLayout.count == 2,
      "Direct layout callers cannot disable the half-millimetre minimum")
check(abs(tightLayout.rectangles[1].minX - tightLayout.rectangles[0].maxX - 0.5) < 0.000001,
      "A tight fit must preserve the minimum internal gap without scaling photos")
check(tightLayout.cutMarkClearance == 0, "Cut marks must not extend beyond a sheet with no outer margin")
let exactInchFit = SheetLayout(paper: CGSize(width: 6 * 25.4, height: 60),
                              photo: CGSize(width: (152.4 - 1) / 3, height: 50), gap: 0.5)
check(exactInchFit.columns == 3, "Exact fits including mandatory gaps must tolerate inch-conversion rounding")
let singleLayout = SheetLayout(paper: CGSize(width: 60, height: 60), photo: CGSize(width: 50, height: 50), gap: 0.5)
check(singleLayout.count == 1 && singleLayout.rectangles[0].origin == CGPoint(x: 5, y: 5),
      "A single photo must be centred on the page")
var invalidGapSettings = PhotoSettings()
invalidGapSettings.gap = 0.49
check(invalidGapSettings.validationError != nil, "New manual settings must reject gaps under 0.5 mm")
let migratedZeroGap = try JSONDecoder().decode(PhotoSettings.self, from: Data("{\"gap\":0}".utf8))
check(migratedZeroGap.gap == 0.5 && migratedZeroGap.validationError == nil,
      "Old zero-gap settings must migrate to the half-millimetre minimum")
for preset in PhotoPreset.allCases {
    for minGap in [0.5, 2.0, 5.0] {
        for paper in [CGSize(width: 152.4, height: 101.6), CGSize(width: 101.6, height: 152.4), CGSize(width: 203.2, height: 152.4)] {
            let presetSettings = preset.applying(to: PhotoSettings())
            let layout = SheetLayout(paper: paper, photo: CGSize(width: presetSettings.photoWidth, height: presetSettings.photoHeight), gap: minGap)
            let cells = layout.rectangles
            check(cells.count == layout.count && cells.count > 0, "Distributed layouts must retain the dynamically computed photo count")
            for row in 0..<layout.rows {
                for column in 0..<layout.columns {
                    let cell = cells[row * layout.columns + column]
                    check(cell.size == layout.photo, "Even distribution must never resize the photos")
                    check(cell.minX >= -0.000001 && cell.minY >= -0.000001
                          && cell.maxX <= paper.width + 0.000001 && cell.maxY <= paper.height + 0.000001,
                          "Distributed photos must remain inside their print sheet")
                    if column > 0 {
                        let actualGap = cell.minX - cells[row * layout.columns + column - 1].maxX
                        check(actualGap >= minGap - 0.000001 && abs(actualGap - layout.horizontalSpacing) < 0.000001,
                              "Every horizontal gap must be uniform and no smaller than the requested minimum")
                    }
                    if row > 0 {
                        let actualGap = cell.minY - cells[(row - 1) * layout.columns + column].maxY
                        check(actualGap >= minGap - 0.000001 && abs(actualGap - layout.verticalSpacing) < 0.000001,
                              "Every vertical gap must be uniform and no smaller than the requested minimum")
                    }
                }
            }
        }
    }
}

let chineseMenu = PhotoPreset.menuPresets(language: .simplifiedChinese, selectedID: PhotoPreset.ukPassport.id)
check(chineseMenu.first == .chineseID && Set(chineseMenu).count == PhotoPreset.allCases.count,
      "Chinese menus must put the ID-card preset first without duplicating entries")
check(!PhotoPreset.menuPresets(language: .english, selectedID: PhotoPreset.ukPassport.id).contains(.chineseID),
      "The extra ID-card reference is initially offered in Chinese")
check(PhotoPreset.menuPresets(language: .english, selectedID: PhotoPreset.chineseID.id).contains(.chineseID),
      "Switching to English must keep an already-selected Chinese ID preset usable")

let idPreset = PhotoPreset.chineseID.applying(to: PhotoSettings())
check(idPreset.photoWidth == 26 && idPreset.photoHeight == 32,
      "Chinese ID reference must use 26 by 32 mm")
check(abs(idPreset.headMin / idPreset.photoHeight - 2.0 / 3) < 0.000001,
      "Chinese ID approximate head ratio must not invent an official min/max tolerance")
var badMargin = PhotoSettings()
for margin in [-1.0, Double.nan, Double.infinity, 11.0] {
    badMargin.headTopMargin = margin
    check(badMargin.validationError != nil, "Invalid or overflowing top margins must be rejected")
}
let marginRoundTrip = try JSONDecoder().decode(PhotoSettings.self, from: JSONEncoder().encode(PhotoPreset.chinesePassport.applying(to: PhotoSettings())))
check(marginRoundTrip.headTopMargin == 4, "Preset top margins must survive settings persistence")
let legacySettings = try JSONDecoder().decode(PhotoSettings.self, from: Data("{}".utf8))
check(legacySettings.headTopMargin == nil && legacySettings == PhotoSettings(),
      "Existing settings must retain centred placement without a top-margin field")

// Explicit top margins obey the same source-boundary rules as centred crops.
let nearTopHead = HeadPlacement(top: 0.005, chin: 0.105, centerX: 0.5, width: 0.10)
var topMarginSettings = PhotoPreset.chinesePassport.applying(to: PhotoSettings())
topMarginSettings.background = .original
check(nearTopHead.framingError(in: referenceSize, settings: topMarginSettings) != nil,
      "Original backgrounds cannot supply missing top margin beyond the source")
topMarginSettings.background = .white
check(nearTopHead.framingError(in: referenceSize, settings: topMarginSettings) == nil,
      "Replacement backgrounds can supply missing top margin for document presets")

// Saved manual presets persist complete settings, update by name, and reject invalid input.
let presetSuite = "AutoIDPhoto.PresetTests." + UUID().uuidString
let presetDefaults = UserDefaults(suiteName: presetSuite)!
defer { presetDefaults.removePersistentDomain(forName: presetSuite) }
check(PhotoPresetStore.load(defaults: presetDefaults).isEmpty, "A fresh library must contain no saved custom presets")
check(PhotoPresetStore.selectedID(for: PhotoSettings(), defaults: presetDefaults) == PhotoPreset.ukPassport.id,
      "Existing default geometry must resolve to the UK passport reference")
var savedSettings = PhotoPreset.chinesePassport.applying(to: customPaper)
savedSettings.background = .blue
let savedPreset = try PhotoPresetStore.save(name: "  My portrait  ", settings: savedSettings, defaults: presetDefaults)
check(savedPreset.name == "My portrait", "Custom preset names must be trimmed")
check(PhotoPresetStore.load(defaults: presetDefaults) == [savedPreset], "All custom settings must persist exactly")
presetDefaults.set(savedPreset.id.uuidString, forKey: PhotoPresetStore.selectionKey)
check(PhotoPresetStore.selectedID(for: savedSettings, defaults: presetDefaults) == savedPreset.id.uuidString,
      "Selected custom presets must survive reopening the confirmation sheet")
savedSettings.background = .red
let updatedPreset = try PhotoPresetStore.save(name: "my PORTRAIT", settings: savedSettings, defaults: presetDefaults)
check(updatedPreset.id == savedPreset.id && PhotoPresetStore.load(defaults: presetDefaults).count == 1,
      "Saving an existing name must update it without creating a duplicate")
let secondPreset = try PhotoPresetStore.save(name: "证件照", settings: idPreset, defaults: presetDefaults)
check(secondPreset.id != savedPreset.id && PhotoPresetStore.load(defaults: presetDefaults).count == 2,
      "Differently named presets must be independently reusable")
let beforeInvalidSave = presetDefaults.data(forKey: PhotoPresetStore.storageKey)
for name in ["  ", String(repeating: "x", count: 41)] {
    do {
        try PhotoPresetStore.save(name: name, settings: savedSettings, defaults: presetDefaults)
        fatalError("Invalid preset name was accepted")
    } catch { check(true, "Invalid names must be rejected") }
}
do {
    try PhotoPresetStore.save(name: "Bad settings", settings: badMargin, defaults: presetDefaults)
    fatalError("Invalid preset settings were accepted")
} catch { check(true, "Invalid custom settings must be rejected") }
check(presetDefaults.data(forKey: PhotoPresetStore.storageKey) == beforeInvalidSave,
      "Failed saves must leave existing custom presets intact")
presetDefaults.set(PhotoPresetStore.manualID, forKey: PhotoPresetStore.selectionKey)
check(PhotoPresetStore.selectedID(for: PhotoSettings(), defaults: presetDefaults) == PhotoPresetStore.manualID,
      "An explicit manual choice must not be replaced by a matching built-in preset")
presetDefaults.set(PhotoPreset.ukVisa.id, forKey: PhotoPresetStore.selectionKey)
check(PhotoPresetStore.selectedID(for: PhotoSettings(), defaults: presetDefaults) == PhotoPreset.ukVisa.id,
      "Presets with identical geometry must preserve the chosen document label")
presetDefaults.set(Data("broken-json".utf8), forKey: PhotoPresetStore.storageKey)
check(PhotoPresetStore.load(defaults: presetDefaults).isEmpty, "Corrupt libraries must not crash app startup")

// Follow the primary iOS language until the user explicitly chooses a language.
let languageSuite = "AutoIDPhoto.LanguageTests." + UUID().uuidString
let languageDefaults = UserDefaults(suiteName: languageSuite)!
defer { languageDefaults.removePersistentDomain(forName: languageSuite) }
for identifier in ["zh", "zh-Hans", "zh-Hans-CN", "zh-Hant-TW", "zh-HK", "ZH_Hant"] {
    check(AppLanguage.selected(defaults: languageDefaults, preferredLanguages: [identifier]) == .simplifiedChinese,
          "Chinese system language \(identifier) must default to Simplified Chinese")
}
for languages in [["en-GB"], ["fr-FR", "zh-Hans"], ["ja-JP"], [String](), [""]] {
    check(AppLanguage.selected(defaults: languageDefaults, preferredLanguages: languages) == .english,
          "Non-Chinese primary languages and missing system preferences must default to English")
}
check(languageDefaults.object(forKey: AppLanguage.preferenceKey) == nil,
      "Reading the system default must not save a manual language override")
languageDefaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: AppLanguage.preferenceKey)
check(AppLanguage.selected(defaults: languageDefaults, preferredLanguages: ["en-GB"]) == .simplifiedChinese,
      "Manual Chinese selection must override an English system")
languageDefaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.preferenceKey)
check(AppLanguage.selected(defaults: languageDefaults, preferredLanguages: ["zh-Hans"]) == .english,
      "Manual English selection must override a Chinese system")
languageDefaults.set("invalid-language", forKey: AppLanguage.preferenceKey)
check(AppLanguage.selected(defaults: languageDefaults, preferredLanguages: ["zh-Hant"]) == .simplifiedChinese,
      "Unknown stored languages must fall back to the system language")
check(AppLanguage.selected(defaults: languageDefaults, preferredLanguages: ["de-DE"]) == .english,
      "Unknown stored languages must fall back to English on other systems")
let localizationDirectory = FileManager().temporaryDirectory.appendingPathComponent("AutoIDPhoto-Localization-" + UUID().uuidString + ".bundle")
defer { try? FileManager().removeItem(at: localizationDirectory) }
let bundleContents = localizationDirectory.appendingPathComponent("Contents")
let bundleResources = bundleContents.appendingPathComponent("Resources")
try FileManager().createDirectory(at: bundleResources, withIntermediateDirectories: true)
let bundleInfo = ["CFBundleIdentifier": "com.autoidphoto.localization.tests", "CFBundleDevelopmentRegion": "en"]
try PropertyListSerialization.data(fromPropertyList: bundleInfo, format: .xml, options: 0).write(to: bundleContents.appendingPathComponent("Info.plist"))
let appSource = URL(fileURLWithPath: FileManager().currentDirectoryPath).appendingPathComponent("AutoIDPhoto")
var languageTables = [AppLanguage: [String: String]]()
for language in AppLanguage.allCases {
    let folder = appSource.appendingPathComponent(language.rawValue + ".lproj")
    try FileManager().copyItem(at: folder, to: bundleResources.appendingPathComponent(language.rawValue + ".lproj"))
    let bytes = try Data(contentsOf: folder.appendingPathComponent("Localizable.strings"))
    languageTables[language] = try PropertyListSerialization.propertyList(from: bytes, options: [], format: nil) as? [String: String]
}
let localizedTestBundle = Bundle(url: localizationDirectory)!
let englishTable = languageTables[.english]!
let chineseTable = languageTables[.simplifiedChinese]!
check(Set(englishTable.keys) == Set(chineseTable.keys), "Both languages must cover exactly the same keys")
let placeholderPattern = try NSRegularExpression(pattern: "%(?:[0-9]+\\$)?[-+0 #]*(?:[0-9]+)?(?:\\.[0-9]+)?(?:l{1,2}|z)?[@dfg]")
for (key, english) in englishTable {
    check(!english.isEmpty && !chineseTable[key]!.isEmpty, "Translations must not be empty")
    let sourceTokens = placeholderPattern.matches(in: key, range: NSRange(key.startIndex..., in: key)).map { (key as NSString).substring(with: $0.range) }
    let translatedTokens = placeholderPattern.matches(in: english, range: NSRange(english.startIndex..., in: english)).map { (english as NSString).substring(with: $0.range) }
    check(sourceTokens == translatedTokens, "Formatting arguments must be preserved in translation")
    check(AppText.localized(key, language: .english, bundle: localizedTestBundle) == english, "English resources must resolve through the real bundle lookup")
    check(AppText.localized(key, language: .simplifiedChinese, bundle: localizedTestBundle) == chineseTable[key], "Chinese resources must resolve through the real bundle lookup")
}
check(AppText.localized("载入默认参数", language: .english, bundle: localizedTestBundle) == "Load Default Settings", "Default settings action must be English")
check(PhotoSettings.Background.lightGray.rawValue == "浅灰", "Localization must not change persisted background identifiers")
for guideKey in ["1. 选择证件规格与照片背景。", "2. 核对人脸范围，必要时返回调整。", "3. 点击确定生成，再分享保存。", "1. 确认证件照尺寸与背景。", "2. 拍摄或选择清晰正面照。", "3. 方框对齐头顶与下巴，调至绿色。", "4. 点击生成，通过分享保存或导出。"] {
    let sentence = englishTable[guideKey]!
    check(sentence.split(whereSeparator: { $0.isWhitespace }).count <= 10, "Each English guide step must use at most ten words, including its number")
    check(sentence.filter { $0 == "." }.count == 2, "Each step must have one sentence after its numbered prefix")
}
print("Passed \(checks) geometry, image export, head-box and bilingual localization checks")
