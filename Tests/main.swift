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

// Language preference starts in English, survives reads and does not mutate photo settings.
let languageSuite = "AutoIDPhoto.LanguageTests." + UUID().uuidString
let languageDefaults = UserDefaults(suiteName: languageSuite)!
defer { languageDefaults.removePersistentDomain(forName: languageSuite) }
check(AppLanguage.selected(defaults: languageDefaults) == .english, "A fresh install must default to English")
languageDefaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: AppLanguage.preferenceKey)
check(AppLanguage.selected(defaults: languageDefaults) == .simplifiedChinese, "Chinese selection must be remembered")
languageDefaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.preferenceKey)
check(AppLanguage.selected(defaults: languageDefaults) == .english, "Switching back to English must be remembered")
languageDefaults.set("invalid-language", forKey: AppLanguage.preferenceKey)
check(AppLanguage.selected(defaults: languageDefaults) == .english, "Unknown stored languages must fall back to English")
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
for guideKey in ["1. 确认证件照尺寸与背景。", "2. 拍摄或选择清晰正面照。", "3. 方框对齐头顶与下巴，调至绿色。", "4. 点击生成，通过分享保存或导出。"] {
    let sentence = englishTable[guideKey]!
    check(sentence.split(whereSeparator: { $0.isWhitespace }).count <= 10, "Each English guide step must use at most ten words, including its number")
    check(sentence.filter { $0 == "." }.count == 2, "Each step must have one sentence after its numbered prefix")
}
print("Passed \(checks) geometry, image export, head-box and bilingual localization checks")
