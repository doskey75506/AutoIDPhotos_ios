# App Store copy · 1.0 (build 1)

Prepared: 2026-11-23. Target: AutoIDPhoto; Bundle ID `com.jialishen.AutoIDPhoto`; current display name `ID Photo Maker` / `证件照拼版`. Metadata languages: `en-GB` and `zh-Hans`.

## Status and publication baseline

These are local copy-ready drafts based on the current source and the user's report that testing is satisfactory. No App Store Connect account, app record, live version, price or listing availability was inspected. No metadata was uploaded; no code was changed or pushed.

Working assumption: version 1.0 is the first App Store release, based on the conversation and current project version. User confirmation is pending. There is no Git repository/history in this directory and no confirmed previous published version to compare.

Apple states that What's New is not available for the first version and is required for later versions. Each `whats-new.txt` is therefore intentionally empty (0 bytes), not an overlooked field. Do not paste “initial release” or a fabricated change list into a field that does not exist. If this is an update rather than the first release, first establish the actual published baseline and replace these empty files with verified changes; do not submit the current empty release notes for an update.

## Current limits and exact counts

| Locale | Field | Characters | UTF-8 bytes | Limit |
| --- | --- | ---: | ---: | --- |
| en-GB | Promotional Text | 140 | 140 | 170 characters |
| en-GB | Keywords | 84 | 84 | 100 bytes |
| en-GB | Description | 1522 | 1524 | 4000 characters |
| en-GB | What's New | 0 | 0 | Not available for first release |
| zh-Hans | Promotional Text | 59 | 159 | 170 characters |
| zh-Hans | Keywords | 34 | 90 | 100 bytes |
| zh-Hans | Description | 496 | 1360 | 4000 characters |
| zh-Hans | What's New | 0 | 0 | Not available for first release |

Counts include spaces, punctuation and intentional paragraph breaks. The plain text files have no trailing newline, headings or validation notes. Both Unicode code-point and UTF-16 counts are recorded in `validation.json`; all current text is in the BMP, so those counts agree. Keywords are checked against UTF-8 bytes, not merely Chinese character count. Apple’s product-page marketing guide uses “100 characters”; the App Store Connect reference explicitly uses “100 bytes”, so the stricter byte limit is used here. Current Connect validation remains authoritative.

Run `python3 release/app-store/1.0/validate-copy.py` from the project root to revalidate after editing. It checks length, duplicate/short keyword terms, surrounding whitespace and excluded scenario words, and rewrites only `validation.json`.

## Source-backed feature claims

- `AutoIDPhoto/CameraController.swift`: default front camera, rear/front switching, live camera preview and still capture. Face detection is not performed on the live video stream.
- `AutoIDPhoto/ContentView.swift`, `HeadSelectionOverlay.swift`: photo-library selection, detection after import/capture, draggable/resizable head box, previews and separate single-photo export.
- `AutoIDPhoto/PhotoGeometry.swift`: adjustable width/height, head-height range, paper dimensions, DPI and spacing; default eight 35 × 45 mm photos on 6 × 4 in paper.
- `AutoIDPhoto/PhotoProcessor.swift`, `MODNetMatting.swift`, `BackgroundCompositor.swift`: portrait mask generation/compositing; original, white and light-grey background choices; grey inter-photo spacing. No arbitrary colour picker is advertised.
- `AutoIDPhoto/PhotoModel.swift`, `PhotoJPEGEncoder.swift`: single JPEG, sheet JPEG/PDF, saving sheets to Photos, explicit sharing, temporary export files and DPI metadata.
- `AutoIDPhoto/AppLanguage.swift`: English is the initial app language, Simplified Chinese is available, and the choice is remembered.
- Current Swift sources use local Vision/Core ML processing and contain no processing-upload request, advertising or analytics SDK integration. Copy says only that image processing happens on-device and photos are not uploaded for processing. It does not claim that photos are never stored, that the whole system is always offline, or that no data ever leaves through user-initiated sharing or iCloud Photos.
- `AutoIDPhoto.xcodeproj/project.pbxproj`: version 1.0/build 1, iOS 17 deployment target and iPhone/iPad device families. No runtime/device validation was newly performed in this copy-writing task.

## Editorial constraints

The store text describes general ID-photo creation only. It does not mention specific document/application scenarios, geographic defaults, official approval, acceptance guarantees, identity recognition, pricing, “free”, “no ads”, or unverified ratings/rankings. The UI's default-parameter explanation is intentionally not copied into the store text. Model names and implementation details are omitted from marketing copy.

Keywords avoid the current display name and MobileSoft company wording. If the final App Store name or subtitle contains any keyword terms, revise the keyword list to avoid duplication. The final listing name and its availability have not been checked.

## Official references

Checked on 2026-11-23:

- [Apple: Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) — Promotional Text, Description, Keywords byte limit and first-version What's New behaviour.
- [Apple: Creating Your Product Page](https://developer.apple.com/app-store/product-page/) — plain-language product description and comma-separated keyword guidance.

## Files

Each locale directory contains `promotional-text.txt`, `keywords.txt`, `description.txt`, `whats-new.txt`, and a local `README.md`. `copy-ready.md` collects the same exact text in independent plain-text blocks. Validation data is in `validation.json`.
