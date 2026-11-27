import Foundation

/// Print/crop references, not a promise of acceptance or digital-upload compliance.
enum PhotoPreset: String, CaseIterable, Identifiable {
    case ukPassport = "uk-passport"
    case ukVisa = "uk-visa-paper-reference"
    case usVisa = "us-visa"
    case usPassport = "us-passport"
    case germanVisa = "german-visa"
    case canadianVisa = "canadian-visa"
    case japaneseVisa = "japanese-visa"
    case chinesePassport = "chinese-passport"
    case chineseID = "chinese-id-reference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ukPassport: return "英国护照"
        case .ukVisa: return "英国签证（纸质参考）"
        case .usVisa: return "美国签证"
        case .usPassport: return "美国护照"
        case .germanVisa: return "德国签证"
        case .canadianVisa: return "加拿大签证"
        case .japaneseVisa: return "日本签证（纸质参考）"
        case .chinesePassport: return "中国护照"
        case .chineseID: return "身份证照片（尺寸参考）"
        }
    }

    var note: String {
        switch self {
        case .ukVisa:
            return "纸质尺寸参考，按英国护照比例裁切；电子申请请以签证页面为准。"
        case .usVisa:
            return "头顶需包含头发，眼睛位置与电子尺寸请核对官方要求。"
        case .chineseID:
            return "头高按照片约三分之二作裁切参考；不提供身份证采集回执。"
        default:
            return "预设仅用于裁切参考；电子文件、拍摄及受理要求请核对官方说明。"
        }
    }

    var sourceURL: URL {
        let address: String
        switch self {
        case .ukPassport: address = "https://www.gov.uk/photos-for-passports/photo-requirements"
        case .ukVisa: address = "https://www.gov.uk/guidance/how-to-take-a-photo-for-a-visa-application-or-permission"
        case .usVisa: address = "https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/photo-composition-template.html"
        case .usPassport: address = "https://travel.state.gov/en/passports/apply/help/photos.html"
        case .germanVisa: address = "https://uk.diplo.de/uk-en/02/visa/visa-faq/2442852"
        case .canadianVisa: address = "https://www.canada.ca/en/immigration-refugees-citizenship/services/application/application-forms-guides/temporary-resident-visa-application-photograph-specifications.html"
        case .japaneseVisa: address = "https://www.ng.emb-japan.go.jp/files/100806447.pdf"
        case .chinesePassport: address = "https://to.china-embassy.gov.cn/chn/lsfw/zjbl/lsqw_133413/202506/t20250612_11646385.htm"
        case .chineseID: address = "https://www.beijing.gov.cn/fuwu/bmfw/bmzt/sfz/rdgz/201809/t20180917_1857547.html"
        }
        return URL(string: address)!
    }

    func applying(to settings: PhotoSettings) -> PhotoSettings {
        // Keep explicit print/background choices; fresh and restored defaults use white.
        applyingGeometry(to: settings)
    }

    /// Re-resolve the chosen document at confirmation without resetting print or background choices.
    func applyingGeometry(to settings: PhotoSettings) -> PhotoSettings {
        var result = settings
        let dimensions: (Double, Double, Double, Double, Double?)
        switch self {
        case .ukPassport, .ukVisa: dimensions = (35, 45, 29, 34, nil)
        case .usVisa, .usPassport: dimensions = (50.8, 50.8, 25.4, 34.925, nil)
        case .germanVisa: dimensions = (35, 45, 32, 36, nil)
        case .canadianVisa: dimensions = (35, 45, 31, 36, nil)
        case .japaneseVisa: dimensions = (35, 45, 25, 29, 7)
        case .chinesePassport: dimensions = (33, 48, 28, 33, 4)
        // The linked public guidance describes an approximate 2/3 head ratio,
        // not a universal numeric crown/chin tolerance or digital receipt format.
        case .chineseID: dimensions = (26, 32, 32 * 2 / 3, 32 * 2 / 3, nil)
        }
        (result.photoWidth, result.photoHeight, result.headMin, result.headMax, result.headTopMargin) = dimensions
        return result
    }

    static func menuPresets(language: AppLanguage, selectedID: String) -> [PhotoPreset] {
        if language == .simplifiedChinese {
            return [.chineseID] + allCases.filter { $0 != .chineseID }
        }
        return allCases.filter { $0 != .chineseID || $0.id == selectedID }
    }

    func matches(_ settings: PhotoSettings) -> Bool {
        let reference = applying(to: settings)
        return reference.photoWidth == settings.photoWidth && reference.photoHeight == settings.photoHeight
            && reference.headMin == settings.headMin && reference.headMax == settings.headMax
            && reference.headTopMargin == settings.headTopMargin
    }
}

struct SavedPhotoPreset: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var settings: PhotoSettings
}

enum PhotoPresetStore {
    static let storageKey = "savedPhotoPresets"
    static let selectionKey = "selectedPhotoPreset"
    static let manualID = "manual"

    static func load(defaults: UserDefaults = .standard) -> [SavedPhotoPreset] {
        guard let data = defaults.data(forKey: storageKey),
              let values = try? JSONDecoder().decode([SavedPhotoPreset].self, from: data) else { return [] }
        var seen = Set<UUID>()
        return values.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.settings.validationError == nil && seen.insert($0.id).inserted
        }
    }

    /// Reusing a name updates that saved preset rather than accumulating duplicates.
    @discardableResult
    static func save(name: String, settings: PhotoSettings,
                     defaults: UserDefaults = .standard) throws -> SavedPhotoPreset {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else {
            throw PhotoError.message("请输入不超过 40 个字符的参数名称。")
        }
        if let error = settings.validationError { throw PhotoError.message(error) }
        var values = load(defaults: defaults)
        let index = values.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        let preset = SavedPhotoPreset(id: index.map { values[$0].id } ?? UUID(), name: name, settings: settings)
        if let index { values[index] = preset } else { values.append(preset) }
        defaults.set(try JSONEncoder().encode(values), forKey: storageKey)
        return preset
    }

    static func selectedID(for settings: PhotoSettings, defaults: UserDefaults = .standard) -> String {
        let savedID = defaults.string(forKey: selectionKey)
        if savedID == manualID { return manualID }
        if let savedID, let preset = PhotoPreset(rawValue: savedID), preset.matches(settings) { return savedID }
        if let value = load(defaults: defaults).first(where: { $0.id.uuidString == savedID && $0.settings == settings }) {
            return value.id.uuidString
        }
        return PhotoPreset.allCases.first(where: { $0.matches(settings) })?.id ?? manualID
    }
}
