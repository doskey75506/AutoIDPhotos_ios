import Foundation
import SwiftUI
import Photos
import ImageIO

@MainActor
final class PhotoModel: ObservableObject {
    @Published var settings: PhotoSettings {
        didSet {
            output = nil
            if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: "photoSettings") }
        }
    }
    @Published var detectionNotice: String?
    @Published var image: UIImage?
    @Published var placement = HeadPlacement(top: 0.2, chin: 0.65, centerX: 0.5) { didSet { output = nil } }
    @Published var output: PhotoOutput?
    @Published var busy = false
    @Published var message: String? {
        didSet { if message == nil { showPhotoSettingsLink = false } }
    }
    @Published private(set) var showPhotoSettingsLink = false
    @Published private(set) var isSaving = false
    enum ShareFormat { case jpeg, pdf }
    @Published var shareFiles: [URL] = []
    init() {
        settings = UserDefaults.standard.data(forKey: "photoSettings")
            .flatMap { try? JSONDecoder().decode(PhotoSettings.self, from: $0) } ?? PhotoSettings()
    }
    func load(data: Data) async {
        busy = true
        defer { busy = false }
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(width.intValue, height.intValue)
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: thumbnail)
        }.value
        guard let decoded else { message = "无法读取照片格式。"; return }
        await load(image: decoded)
    }
    func load(image: UIImage) async {
        busy = true
        output = nil
        self.image = nil
        detectionNotice = nil
        defer { busy = false }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let processor = PhotoProcessor()
                let normalized = try processor.normalize(image)
                do {
                    return (normalized, try processor.detect(normalized), Optional<String>.none)
                } catch let error as VisionProcessingError {
                    #if targetEnvironment(simulator)
                    let notice = "模拟器自动检测不可用，已切换为手动定位。请拖动方框，使上边对齐头顶、下边对齐下巴，左右围住头部；当前方框不是检测结果。"
                    return (normalized, HeadPlacement(top: 0.25, chin: 0.65, centerX: 0.5),
                            Optional(notice))
                    #else
                    throw error
                    #endif
                }
            }.value
            self.image = result.0
            // Apply exactly once per loaded photo, including the simulator's
            // initial manual fallback. Later drag/resize edits are left alone.
            placement = result.1.expandedForInitialDetection()
            detectionNotice = result.2
        } catch { message = error.localizedDescription }
    }
    var framingError: String? {
        guard let image else { return nil }
        return placement.framingError(in: image.size, settings: settings)
    }

    func generate(settings requestedSettings: PhotoSettings) async {
        guard let image, !busy else { return }
        busy = true
        output = nil
        let settings = requestedSettings
        let placement = placement
        defer { busy = false }
        do {
            output = try await Task.detached(priority: .userInitiated) {
                try PhotoProcessor().generate(image, placement: placement, settings: settings)
            }.value
        } catch { message = error.localizedDescription }
    }
    func prepareShare(portraitOnly: Bool, format: ShareFormat) {
        shareFiles = []
        guard let output else { return }
        do {
            let fileManager = FileManager()
            let directory = fileManager.temporaryDirectory.appendingPathComponent("AutoIDPhoto-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let file: URL
            let data: Data
            switch (portraitOnly, format) {
            case (true, .jpeg):
                file = directory.appendingPathComponent("ID-Photo.jpg")
                data = output.portraitJPEG
            case (false, .jpeg):
                file = directory.appendingPathComponent("ID-Photo-Print.jpg")
                data = output.jpeg
            case (false, .pdf):
                file = directory.appendingPathComponent("ID-Photo-Print.pdf")
                data = output.pdf
            case (true, .pdf):
                throw PhotoError.message("单张证件照请使用 JPEG 格式。")
            }
            try data.write(to: file, options: .atomic)
            shareFiles = [file]
        } catch { message = AppText.format("导出失败：%@", error.localizedDescription) }
    }
    func save(portraitOnly: Bool) async {
        guard let output, !isSaving else { return }
        // Snapshot the selected image before awaiting a permission prompt.
        let data = portraitOnly ? output.portraitJPEG : output.jpeg
        isSaving = true
        showPhotoSettingsLink = false
        defer { isSaving = false }
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let status = current == .notDetermined ? await PHPhotoLibrary.requestAuthorization(for: .readWrite) : current
        guard status == .authorized || status == .limited else {
            showPhotoPermissionMessage(status)
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            if status == .limited {
                showPhotoSettingsLink = true
                message = "照片已保存。当前为有限访问；如需完全访问，请打开本 App 的设置，在“照片”中选择“完全访问”。"
            } else {
                message = portraitOnly ? "单张证件照已保存到照片。" : "打印拼版已保存到照片。"
            }
        } catch {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .denied || status == .restricted {
                showPhotoPermissionMessage(status)
            } else {
                message = AppText.format("保存失败：%@", error.localizedDescription)
            }
        }
    }

    func requestFullPhotoAccess() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let status = current == .notDetermined
            ? await PHPhotoLibrary.requestAuthorization(for: .readWrite) : current
        switch status {
        case .authorized:
            message = "已允许完全访问照片。"
        case .limited:
            showPhotoSettingsLink = true
            message = "当前为有限访问，仍可选择和保存照片。如需完全访问，请打开本 App 的设置，在“照片”中选择“完全访问”。"
        default:
            showPhotoPermissionMessage(status)
        }
    }

    private func showPhotoPermissionMessage(_ status: PHAuthorizationStatus) {
        showPhotoSettingsLink = true
        message = status == .restricted
            ? "系统限制了添加照片的权限。请打开本 App 的设置，检查照片权限及系统访问限制；也可以分享为文件。"
            : "尚未获准访问照片。请打开本 App 的设置，在“照片”中选择有限访问或完全访问，然后返回重试；也可以分享为文件。"
    }
}
