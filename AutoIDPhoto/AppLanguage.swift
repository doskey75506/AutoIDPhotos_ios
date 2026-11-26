import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    static let preferenceKey = "appInterfaceLanguage"
    var locale: Locale { Locale(identifier: rawValue) }

    static func systemDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        let primaryLanguage = preferredLanguages.first?
            .replacingOccurrences(of: "_", with: "-").lowercased()
        return primaryLanguage == "zh" || primaryLanguage?.hasPrefix("zh-") == true
            ? .simplifiedChinese : .english
    }

    static func selected(defaults: UserDefaults = .standard,
                         preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        defaults.string(forKey: preferenceKey).flatMap(AppLanguage.init(rawValue:))
            ?? systemDefault(preferredLanguages: preferredLanguages)
    }
}

enum AppText {
    static func localized(_ key: String, language: AppLanguage = .selected(), bundle: Bundle = .main) -> String {
        guard let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else { return key }
        return localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localized(key), locale: AppLanguage.selected().locale, arguments: arguments)
    }
}
