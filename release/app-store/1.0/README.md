# App Store copy · 1.0 (build 1)

Updated: 2026-11-24. Localized listing text: `en-GB` and `zh-Hans`. Prepared for the first 1.0 release, based on the current publishing task. The App Store Connect record, accepted listing name, price and publication state have not been inspected. No metadata was submitted, no business code changed, and no commit/push performed.

## Suggested app-record values

- Platform: iOS; recommended primary metadata language: English (United Kingdom), matching `en-GB`.
- Bundle ID: `com.jialishen.AutoIDPhoto` (matches the project).
- Suggested SKU: `AutoIDPhoto-iOS`. It is an internal identifier; uniqueness in this account has not been checked. Apple does not allow changing it after creating the app record.
- Suggested listing names retain current localized display names: `ID Photo Maker` / `证件照拼版`. They are proposals; availability and final Connect values are unconfirmed.
- Suggested subtitles: `Portrait cutout & print sheets` / `人像抠图换背景，自定尺寸与单张导出`. No app name, subtitle or bundle setting was changed in the project.
- Version/build: `1.0` / `1`; iPhone and iPad, minimum iOS 17.

## First-release baseline

This package contains all currently implemented features for the first release, not a fabricated change list from a published baseline. There is no Git repository/history in this directory. Apple's What's New field is unavailable for the first version; both `whats-new.txt` files are intentionally empty (0 bytes). If the release becomes an update, establish the actual published baseline before writing release notes.

## Limits and exact counts

| Locale | Field | Characters | UTF-8 bytes | Limit |
| --- | --- | ---: | ---: | --- |
| en-GB | name | 14 | 14 | 30 characters |
| en-GB | subtitle | 30 | 30 | 30 characters |
| en-GB | promotional-text | 165 | 165 | 170 characters |
| en-GB | keywords | 77 | 77 | 100 UTF-8 bytes |
| en-GB | description | 2389 | 2391 | 4000 characters |
| en-GB | whats-new | 0 | 0 | Not applicable to first release |
| zh-Hans | name | 5 | 15 | 30 characters |
| zh-Hans | subtitle | 17 | 51 | 30 characters |
| zh-Hans | promotional-text | 70 | 180 | 170 characters |
| zh-Hans | keywords | 29 | 77 | 100 UTF-8 bytes |
| zh-Hans | description | 846 | 2320 | 4000 characters |
| zh-Hans | whats-new | 0 | 0 | Not applicable to first release |

Counts include spaces, punctuation and paragraph breaks. Field `.txt` files have no heading or trailing newline. The only byte-based field here is Keywords: Chinese keywords must fit 100 UTF-8 bytes, not 100 Chinese characters. Other fields use character limits; current text has identical Unicode code-point and UTF-16 lengths, both recorded in `validation.json`. Name minimum: 2 characters. All fields pass.

Run `python3 release/app-store/1.0/validate-copy.py` from the project root. It validates six fields in each locale, lengths, short/duplicate keyword terms, surrounding whitespace, excluded scenario words and empty first-release notes. It rewrites only `validation.json`.

## Source-backed claims and editorial decisions

- `ContentView.swift`: every app launch starts in specification settings with a four-step guide; confirmation precedes camera startup. Language switching is available during setup and capture. Photo menus offer single/sheet saving, JPEG sharing, sheet PDF sharing and photo-access actions; system settings are offered when needed.
- `CameraController.swift`: live preview, default front lens and front/rear switching. The camera stream has no live face tracking. `PhotoModel.swift` detects a face after import/capture. `HeadSelectionOverlay.swift` and `PhotoGeometry.swift` recheck the framing as the head box or settings change. Red/green describes crop space only, not background quality or official acceptance. The store text preserves this distinction.
- `PhotoGeometry.swift`: configurable photo/head-height/paper/spacing settings; default eight 35 × 45 mm photos on 6 × 4 in paper. Head height uses the midpoint of the selected range. Changing settings clears the existing output; users generate it again.
- Backgrounds are exactly original, white RGB(255,255,255), light grey RGB(240,240,240), blue #438EDB and red #FF0000. `PhotoProcessor.swift`/`BackgroundCompositor.swift` perform portrait cutout and composition. For replacement backgrounds, an otherwise valid crop may extend above the image and be filled with that colour; missing head edges, side or bottom content is not reconstructed. No arbitrary colour picker or missing-body generation is claimed. Exact RGB/hex values are kept here rather than adding technical colour codes to marketing copy.
- `PhotoGeometry.swift`/`PhotoProcessor.swift`: source-crop pixel preservation is enabled by default; fixed DPI is optional. Single JPEG has its own resolution; sheet JPEG is capped at 20 million pixels. PDF places the generated single photo directly, retaining its resolution independently of that sheet cap. This is not a promise of lossless export, unlimited resolution or extra detail beyond the source. `PhotoJPEGEncoder.swift` writes physical-size DPI metadata. Previews report pixel dimensions.
- Sheet grey spacing and external cutting marks are conditional on available spacing. A zero gap does not promise visible separators.
- `AppLanguage.swift`: English initially, Simplified Chinese available, preference persisted.
- `PhotoModel.swift`: Photo-library import via the system picker; saving can request Photos access; files are written to temporary export directories. Current processing uses on-device Vision/Core ML, with no processing-upload request in the Swift implementation. No claim of never storing images, always being offline, free pricing or absence of ads was added. User-initiated sharing/iCloud system behaviour is not covered by the narrow processing statement.
- `AutoIDPhoto.xcodeproj/project.pbxproj`: version/build, bundle ID, deployment target and supported device families. This docs task did not perform new runtime, camera or export testing.

All public fields use general “ID photo / 证件照” wording. They omit specific document/application scenarios, geographic defaults, model implementation names, official approval, acceptance guarantees, price, rankings and unrelated brands. Keywords avoid the proposed name/subtitle; recheck after final metadata changes.

## Official rules checked on 2026-11-24

- [Apple: App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) — name 2–30 characters, subtitle at most 30; bundle ID matching and SKU syntax/immutability.
- [Apple: Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) — Promotional Text 170 characters; plain-text Description 4000; Keywords 100 bytes with terms longer than two characters; What's New 4000 for later versions and unavailable for the first version. Avoid app/company names and unrelated brands in keywords.

## Files, preservation and remaining checks

Each locale has `name.txt`, `subtitle.txt`, `promotional-text.txt`, `keywords.txt`, `description.txt`, `whats-new.txt`, and a local README. [copy-ready.md](copy-ready.md) provides each field in its own plain-text block. Prior copy is preserved in `archive/before-2026-11-24/` before this update; it is historical, not the current submission text.

Remaining outside this copy task: confirm the name/SKU availability and final metadata in Connect, complete support/privacy URLs and listing configuration, and provide current matching screenshots. No URL availability, licensing status, pricing or review readiness is asserted by this document.
