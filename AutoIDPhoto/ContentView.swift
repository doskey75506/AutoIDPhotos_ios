import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct ContentView: View {
    @AppStorage(AppLanguage.preferenceKey) private var languageRaw = AppLanguage.systemDefault().rawValue
    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .systemDefault() }
    @StateObject private var model = PhotoModel()
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var selection: PhotosPickerItem?
    @State private var choosingPhoto = false
    @State private var importingPhoto = false
    @State private var wantsCamera = true
    @State private var cameraRotation: CGFloat = 90
    @State private var settings = false
    @State private var sharing = false
    @State private var pendingGenerationSettings: PhotoSettings?

    var body: some View {
        captureView
    }

    private var captureView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sourcePanel
                    sourceActions
                    if model.image != nil && !wantsCamera {
                        Label(AppText.localized(model.framingError ?? "取景范围符合当前规格"),
                              systemImage: model.framingError == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(model.framingError == nil ? Color.green : .red)
                        if let notice = model.detectionNotice {
                            Text(AppText.localized(notice)).font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if let output = model.output, !wantsCamera {
                        Text(AppText.format("打印预览 · %d 张", output.count)).font(.title2.bold())
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                outputImage(output.portrait)
                                outputImage(output.sheet)
                            }
                            HStack(alignment: .top, spacing: 16) {
                                Text(AppText.localized("单张证件照"))
                                    .frame(maxWidth: .infinity)
                                Text(AppText.localized("打印拼版"))
                                    .frame(maxWidth: .infinity)
                            }.font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            // One shared row keeps both menus aligned even when captions wrap.
                            HStack(spacing: 16) {
                                photoShareMenu(portraitOnly: true).frame(maxWidth: .infinity)
                                photoShareMenu(portraitOnly: false).frame(maxWidth: .infinity)
                            }
                        }
                        Text(AppText.format("单张 %d × %d px · 拼版 %d × %d px",
                                            Int(output.portrait.size.width), Int(output.portrait.size.height),
                                            Int(output.sheet.size.width), Int(output.sheet.size.height)))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(AppText.format("单张 %.2f × %.2f mm · 纸张 %.1f × %.1f 英寸",
                                            output.settings.photoWidth, output.settings.photoHeight,
                                            output.settings.paperWidth, output.settings.paperHeight))
                            .font(.caption).foregroundStyle(.secondary)
                        if let warning = output.warning { Text(AppText.localized(warning)).font(.footnote).foregroundStyle(.orange) }
                        Text(AppText.localized("按设定纸张尺寸、100% 实际大小打印；关闭适应页面、填满及无边距放大。优先使用 PDF，打印后用尺核对单张尺寸。"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(AppText.localized("照片仅在本机处理，不上传服务器。")).font(.caption).foregroundStyle(.secondary)
                }.padding(16).disabled(model.busy || model.isSaving || camera.isCapturing || importingPhoto)
            }
            .safeAreaInset(edge: .bottom) {
                Button { camera.stop(); settings = true } label: {
                    Label(AppText.localized("生成照片"), systemImage: "square.grid.3x2")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent)
                    .disabled(model.image == nil || wantsCamera || model.busy || model.isSaving || importingPhoto)
                    .padding(.horizontal, 16).padding(.vertical, 8).background(.bar)
            }
            .navigationTitle("AutoID Photo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        languageRaw = (language == .english ? AppLanguage.simplifiedChinese : .english).rawValue
                    } label: {
                        Label(language == .english ? "中文" : "English", systemImage: "globe")
                            .font(.subheadline)
                    }.accessibilityLabel(Text(AppText.localized(language == .english ? "切换为简体中文" : "切换为英文")))
                }
            }
            .overlay {
                if model.busy || model.isSaving || camera.isCapturing || importingPhoto {
                    ProgressView(AppText.localized(model.isSaving ? "正在保存照片…" : (camera.isCapturing ? "正在拍摄…" : "正在处理照片…")))
                        .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .photosPicker(isPresented: $choosingPhoto, selection: $selection, matching: .images)
            .sheet(isPresented: $settings, onDismiss: {
                if let confirmedSettings = pendingGenerationSettings {
                    pendingGenerationSettings = nil
                    Task { await model.generate(settings: confirmedSettings) }
                } else { resumePreview() }
            }) {
                SettingsView(settings: $model.settings, imageSize: model.image?.size, placement: model.placement, onConfirm: { confirmedSettings in
                    pendingGenerationSettings = confirmedSettings
                }, onRetake: { wantsCamera = true })
            }
            .sheet(isPresented: $sharing, onDismiss: resumePreview) { ShareSheet(items: model.shareFiles) }
            .alert(AppText.localized("提示"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                if model.showPhotoSettingsLink {
                    Button(AppText.localized("打开设置")) {
                        model.message = nil
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url) { accepted in
                                if !accepted { model.message = "无法打开系统设置，请手动前往本 App 的设置检查照片权限。" }
                            }
                        }
                    }
                }
                Button(AppText.localized("知道了"), role: .cancel) { model.message = nil }
            } message: { Text(AppText.localized(model.message ?? "")) }
            .task { await startPreview() }
            .onDisappear { camera.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { resumePreview() } else { camera.stop() }
            }
            .onChange(of: choosingPhoto) { _, showing in
                if !showing && selection == nil { resumePreview() }
            }
            .onChange(of: selection) { _, item in
                guard let item else { return }
                wantsCamera = false
                importingPhoto = true
                camera.stop()
                Task {
                    defer { importingPhoto = false; selection = nil }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoError.message("无法从相册载入照片。") }
                        await model.load(data: data)
                    } catch { model.message = error.localizedDescription }
                }
            }
        }.tint(.teal).environment(\.locale, language.locale)
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppText.localized("实时视频 / 原图")).font(.headline)
                Spacer()
                if wantsCamera && camera.isRunning {
                    Label(AppText.localized("实时"), systemImage: "record.circle.fill").font(.caption).foregroundStyle(.green)
                }
            }
            ZStack {
                Color.black
                if wantsCamera {
                    if camera.isRunning {
                        CameraPreview(session: camera.session, device: camera.device, mirrored: camera.position == .front, rotation: $cameraRotation)
                            .accessibilityLabel(Text(AppText.localized("摄像头实时预览")))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera").font(.system(size: 40))
                            if camera.isStarting { ProgressView().tint(.white) }
                            Text(AppText.localized(camera.displayStatus)).font(.footnote).multilineTextAlignment(.center)
                        }.foregroundStyle(.white).padding(24)
                    }
                } else if let image = model.image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .overlay {
                            HeadSelectionOverlay(placement: $model.placement, imageSize: image.size, settings: model.settings)
                                .id("\(ObjectIdentifier(image))-\(languageRaw)")
                        }
                } else {
                    Text(AppText.localized(model.busy ? "正在载入照片…" : "点击文件夹选择照片，或点击相机开启预览"))
                        .font(.footnote).foregroundStyle(.white).padding(24)
                }
            }.frame(height: 300).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var sourceActions: some View {
        HStack(spacing: 16) {
            iconButton("选择照片", symbol: "folder") { camera.stop(); choosingPhoto = true }
            iconButton("拍摄", symbol: "largecircle.fill.circle", size: 36) {
                Task {
                    if let data = await camera.capture(rotation: cameraRotation) {
                        wantsCamera = false
                        await model.load(data: data)
                    }
                }
            }.disabled(!camera.isRunning || camera.isStarting)
            iconButton("重新拍摄：开启实时视频", symbol: "camera") {
                wantsCamera = true
                Task { await startPreview() }
            }.disabled(camera.isRunning || camera.isStarting)
            if camera.isRunning {
                iconButton("切换前后摄像头", symbol: "arrow.triangle.2.circlepath.camera") {
                    Task { await camera.start(position: camera.position == .back ? .front : .back) }
                }.disabled(camera.isStarting)
            }
        }.frame(maxWidth: .infinity)
    }

    private func outputImage(_ image: UIImage) -> some View {
        Image(uiImage: image).resizable().scaledToFit()
            .frame(height: 180).frame(maxWidth: .infinity)
    }

    private func photoShareMenu(portraitOnly: Bool) -> some View {
        Menu {
            Button { Task { await model.save(portraitOnly: portraitOnly) } } label: {
                Label(AppText.localized("保存到照片"), systemImage: "square.and.arrow.down")
            }
            Button { Task { await model.requestFullPhotoAccess() } } label: {
                Label(AppText.localized("照片访问权限"), systemImage: "photo.badge.checkmark")
            }
            Button { share(portraitOnly: portraitOnly, format: .jpeg) } label: {
                Label(AppText.localized("分享 JPEG"), systemImage: "photo")
            }
            if !portraitOnly {
                Button { share(portraitOnly: false, format: .pdf) } label: {
                    Label(AppText.localized("分享 PDF"), systemImage: "doc")
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up").font(.system(size: 24))
        }.buttonStyle(IconActionStyle())
            .accessibilityLabel(Text(AppText.localized(portraitOnly ? "分享单张证件照" : "分享打印拼版")))
            .help(Text(AppText.localized(portraitOnly ? "分享单张证件照" : "分享打印拼版")))
    }

    private func share(portraitOnly: Bool, format: PhotoModel.ShareFormat) {
        camera.stop()
        model.prepareShare(portraitOnly: portraitOnly, format: format)
        sharing = !model.shareFiles.isEmpty
    }

    private func iconButton(_ title: String, symbol: String, size: CGFloat = 24, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size))
        }.buttonStyle(IconActionStyle()).accessibilityLabel(Text(AppText.localized(title))).help(Text(AppText.localized(title)))
    }

    private func startPreview() async {
        guard wantsCamera, scenePhase == .active, !choosingPhoto, !settings, !sharing,
              !model.busy, !importingPhoto, !camera.isRunning else { return }
        await camera.start()
        if !camera.isRunning && model.image != nil { wantsCamera = false }
    }
    private func resumePreview() { Task { await startPreview() } }
}

private struct IconActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 52, height: 52)
            .foregroundStyle(isEnabled ? Color.teal : Color.secondary)
            .background(Color.teal.opacity(configuration.isPressed ? 0.24 : 0.10), in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct SettingsView: View {
    @Binding var settings: PhotoSettings
    let imageSize: CGSize?
    let placement: HeadPlacement
    var onConfirm: (PhotoSettings) -> Void
    var onRetake: () -> Void
    @AppStorage(AppLanguage.preferenceKey) private var languageRaw = AppLanguage.systemDefault().rawValue
    @State private var draft = PhotoSettings()
    @State private var presetID = PhotoPresetStore.manualID
    @State private var savedPresets: [SavedPhotoPreset] = []
    @State private var customName = ""
    @State private var customMessage: String?
    @State private var customSaveFailed = false
    @State private var selectionIssue: String?
    @Environment(\.dismiss) private var dismiss

    private var builtIn: PhotoPreset? { PhotoPreset(rawValue: presetID) }
    private var effectiveSettings: PhotoSettings { builtIn?.applyingGeometry(to: draft) ?? draft }
    private var isManual: Bool { builtIn == nil }
    private var framingError: String? {
        effectiveSettings.generationError(in: imageSize, placement: placement)
    }
    private var visiblePresets: [PhotoPreset] {
        PhotoPreset.menuPresets(language: AppLanguage(rawValue: languageRaw) ?? .systemDefault(), selectedID: presetID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(AppText.localized("确认规格后生成照片"), systemImage: "person.crop.rectangle")
                        .font(.headline).foregroundStyle(.teal)
                    Text(AppText.localized("1. 选择证件规格与照片背景。"))
                    Text(AppText.localized("2. 核对人脸范围，必要时返回调整。"))
                    Text(AppText.localized("3. 点击确定生成，再分享保存。"))
                } header: { Text(AppText.localized("使用说明")) }

                presetSection

                if isManual {
                    Section(AppText.localized("证件照尺寸（毫米）")) {
                        field("宽度", value: $draft.photoWidth)
                        field("高度", value: $draft.photoHeight)
                    }
                    Section {
                        field("最小头高", value: $draft.headMin)
                        field("最大头高", value: $draft.headMax)
                        Toggle(AppText.localized("指定头顶留白"), isOn: Binding(
                            get: { draft.headTopMargin != nil },
                            set: { draft.headTopMargin = $0 ? 4 : nil }))
                        if draft.headTopMargin != nil {
                            field("头顶留白（毫米）", value: Binding(
                                get: { draft.headTopMargin ?? 0 }, set: { draft.headTopMargin = $0 }))
                        }
                        Text(AppText.format("头顶至下巴；生成时取范围中值。当前目标占照片高度 %.1f%%。", ((draft.headMin + draft.headMax) / 2 / max(1, draft.photoHeight)) * 100))
                            .font(.caption)
                    } header: { Text(AppText.localized("头部占幅（毫米）")) }
                    Section {
                        TextField(AppText.localized("参数名称"), text: $customName)
                        Button(AppText.localized("保存手工参数")) { saveCustomPreset() }
                            .disabled(draft.validationError != nil || customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if let customMessage {
                            Text(AppText.localized(customMessage)).font(.caption)
                                .foregroundStyle(customSaveFailed ? Color.red : .green)
                        }
                    } header: { Text(AppText.localized("存储手工参数")) }
                    footer: { Text(AppText.localized("保存全部照片和打印参数；同名保存将更新已有参数。")) }
                }

                Section(AppText.localized("打印纸张")) {
                    field("宽度（英寸）", value: $draft.paperWidth)
                    field("高度（英寸）", value: $draft.paperHeight)
                    Toggle(AppText.localized("保留原图分辨率"), isOn: $draft.preserveSourceResolution)
                    if draft.preserveSourceResolution {
                        Text(AppText.localized("按头部大小保留裁切区域像素；PDF 保留单张精度。"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        field("分辨率（DPI）", value: $draft.dpi)
                    }
                    if effectiveSettings.validationError == nil {
                        Text(AppText.format("每版 %d 张，%d 列 × %d 行", effectiveSettings.layout.count, effectiveSettings.layout.columns, effectiveSettings.layout.rows))
                    }
                }
                Section(AppText.localized("背景")) {
                    backgroundMenu
                    if builtIn != nil && draft.background != .original {
                        Text(AppText.localized("部分证件申请不接受换背景照片，请先核对官方要求。"))
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                if let error = effectiveSettings.validationError ?? framingError {
                    Section {
                        Text(AppText.localized(error)).foregroundStyle(.red)
                        if effectiveSettings.validationError == nil {
                            Button(AppText.localized("应用规格并调整人脸范围")) {
                                _ = applySettings()
                                dismiss()
                            }
                        }
                        Button(AppText.localized("重新拍摄")) { onRetake(); dismiss() }
                    }
                }
                Section {
                    Button(AppText.localized("恢复默认值")) { restoreDefaults() }
                }
            }
            .navigationTitle(AppText.localized("生成前确认"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppText.localized("取消")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let confirmedSettings = applySettings()
                    onConfirm(confirmedSettings)
                    dismiss()
                } label: {
                    Label(AppText.localized("确定并生成"), systemImage: "checkmark.circle.fill")
                        .font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
                }.buttonStyle(.borderedProminent)
                    .disabled(imageSize == nil || effectiveSettings.validationError != nil || framingError != nil)
                    .padding(16).background(.bar)
            }
        }.onAppear {
            draft = settings
            savedPresets = PhotoPresetStore.load()
            presetID = PhotoPresetStore.selectedID(for: settings)
            customName = savedPresets.first(where: { $0.id.uuidString == presetID })?.name ?? ""
        }
    }

    private struct OptionIssue: Identifiable {
        let id: String
        let title: String
        let reason: String
    }

    private func optionIssue(for candidate: PhotoSettings) -> String? {
        candidate.generationError(in: imageSize, placement: placement)
    }

    private var selectedTitle: String {
        if let builtIn { return AppText.localized(builtIn.title) }
        return savedPresets.first(where: { $0.id.uuidString == presetID })?.name ?? AppText.localized("手工设定")
    }

    private var unavailableOptions: [OptionIssue] {
        var issues: [OptionIssue] = []
        for preset in visiblePresets {
            if let reason = optionIssue(for: preset.applying(to: draft)) {
                issues.append(OptionIssue(id: preset.id, title: AppText.localized(preset.title), reason: reason))
            }
        }
        for preset in savedPresets {
            if let reason = optionIssue(for: preset.settings) {
                issues.append(OptionIssue(id: preset.id.uuidString, title: preset.name, reason: reason))
            }
        }
        for background in PhotoSettings.Background.allCases {
            var candidate = effectiveSettings
            candidate.background = background
            if let reason = optionIssue(for: candidate) {
                issues.append(OptionIssue(id: "background-" + background.rawValue,
                                          title: AppText.localized(background.rawValue), reason: reason))
            }
        }
        return issues
    }

    private var presetSection: some View {
        Section(AppText.localized("证件规格")) {
            Menu {
                ForEach(visiblePresets) { preset in
                    presetButton(id: preset.id, title: AppText.localized(preset.title), candidate: preset.applying(to: draft))
                }
                Button(AppText.localized("手工设定")) { selectPreset(PhotoPresetStore.manualID) }
                if !savedPresets.isEmpty {
                    Section(AppText.localized("已保存的手工参数")) {
                        ForEach(savedPresets) { preset in
                            presetButton(id: preset.id.uuidString, title: preset.name, candidate: preset.settings)
                        }
                    }
                }
            } label: {
                menuLabel("证件类型", value: selectedTitle)
            }
            if let builtIn {
                Text(AppText.localized(builtIn.note)).font(.caption).foregroundStyle(.secondary)
                Link(AppText.localized("查看官方要求"), destination: builtIn.sourceURL).font(.caption)
                Button(AppText.localized("改为手工设定")) { selectPreset(PhotoPresetStore.manualID) }
            }
            if let selectionIssue {
                Text(AppText.localized(selectionIssue)).font(.caption).foregroundStyle(.red)
            }
            let unavailable = unavailableOptions
            if !unavailable.isEmpty {
                DisclosureGroup(AppText.localized("灰色选项：查看原因与重拍建议")) {
                    ForEach(unavailable) { issue in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(issue.title).font(.caption.bold())
                            Text(AppText.localized(issue.reason)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button(AppText.localized("重新拍摄")) { onRetake(); dismiss() }
                }
            }
        }
    }

    private func presetButton(id: String, title: String, candidate: PhotoSettings) -> some View {
        Button { selectPreset(id) } label: {
            if presetID == id {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }.disabled(optionIssue(for: candidate) != nil)
    }

    private var backgroundMenu: some View {
        Menu {
            ForEach(PhotoSettings.Background.allCases, id: \.self) { background in
                let candidate = settings(with: background)
                Button {
                    guard optionIssue(for: candidate) == nil else { return }
                    draft.background = background
                    selectionIssue = nil
                } label: {
                    if draft.background == background {
                        Label(AppText.localized(background.rawValue), systemImage: "checkmark")
                    } else {
                        Text(AppText.localized(background.rawValue))
                    }
                }.disabled(optionIssue(for: candidate) != nil)
            }
        } label: {
            menuLabel("照片背景", value: AppText.localized(draft.background.rawValue))
        }
    }

    private func settings(with background: PhotoSettings.Background) -> PhotoSettings {
        var candidate = effectiveSettings
        candidate.background = background
        return candidate
    }

    private func menuLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(AppText.localized(title)).foregroundStyle(Color.primary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).lineLimit(2)
            Image(systemName: "chevron.up.chevron.down").font(.caption)
        }.foregroundStyle(Color.secondary)
    }

    private func selectPreset(_ id: String) {
        var candidate = draft
        if let preset = PhotoPreset(rawValue: id) {
            candidate = preset.applying(to: draft)
        } else if let preset = savedPresets.first(where: { $0.id.uuidString == id }) {
            candidate = preset.settings
        }
        if id != PhotoPresetStore.manualID, let issue = optionIssue(for: candidate) {
            selectionIssue = issue
            return
        }
        presetID = id
        draft = candidate
        customName = savedPresets.first(where: { $0.id.uuidString == id })?.name ?? ""
        customMessage = nil
        selectionIssue = nil
    }

    private func restoreDefaults() {
        draft = PhotoSettings()
        presetID = PhotoPreset.ukPassport.id
        customName = ""
        customMessage = nil
        selectionIssue = nil
    }

    private func saveCustomPreset() {
        do {
            let preset = try PhotoPresetStore.save(name: customName, settings: draft)
            savedPresets = PhotoPresetStore.load()
            presetID = preset.id.uuidString
            customName = preset.name
            customSaveFailed = false
            customMessage = "手工参数已保存，可在证件类型菜单中再次选择。"
        } catch {
            customSaveFailed = true
            customMessage = error.localizedDescription
        }
    }

    private func applySettings() -> PhotoSettings {
        let confirmedSettings = effectiveSettings
        settings = confirmedSettings
        UserDefaults.standard.set(presetID, forKey: PhotoPresetStore.selectionKey)
        return confirmedSettings
    }

    private func field(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(AppText.localized(title))
            Spacer()
            TextField(AppText.localized(title), value: value, format: .number).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).frame(width: 100)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // Save to Photos is handled by the app menu, where denied access can offer Settings.
        controller.excludedActivityTypes = [.saveToCameraRoll]
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
