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
    @State private var confirmedSetup = false

    var body: some View {
        Group {
            if confirmedSetup {
                captureView
            } else {
                SettingsView(settings: $model.settings, isInitial: true) { confirmedSetup = true }
            }
        }.tint(.teal).environment(\.locale, language.locale)
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
                        if let warning = output.warning { Text(AppText.localized(warning)).font(.footnote).foregroundStyle(.orange) }
                        Text(AppText.localized("按设定纸张尺寸、100% 实际大小打印；关闭适应页面、填满及无边距放大。优先使用 PDF，打印后用尺核对单张尺寸。"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(AppText.localized("照片仅在本机处理，不上传服务器。")).font(.caption).foregroundStyle(.secondary)
                }.padding(16).disabled(model.busy || model.isSaving || camera.isCapturing || importingPhoto)
            }
            .safeAreaInset(edge: .bottom) {
                if model.image != nil && !wantsCamera {
                    Button { Task { await model.generate() } } label: {
                        Label(AppText.localized("生成证件照与拼版"), systemImage: "square.grid.3x2")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent)
                        .disabled(model.framingError != nil || model.busy || model.isSaving || importingPhoto)
                        .padding(.horizontal, 16).padding(.vertical, 8).background(.bar)
                }
            }
            .navigationTitle("AutoID Photo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { camera.stop(); settings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }.accessibilityLabel(Text(AppText.localized("证件照与打印规格")))
                }
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
            .sheet(isPresented: $settings, onDismiss: resumePreview) { SettingsView(settings: $model.settings) }
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
        guard confirmedSetup, wantsCamera, scenePhase == .active, !choosingPhoto, !settings, !sharing,
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
    var isInitial = false
    var onConfirm: (() -> Void)? = nil
    @AppStorage(AppLanguage.preferenceKey) private var languageRaw = AppLanguage.systemDefault().rawValue
    @State private var draft = PhotoSettings()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                if isInitial {
                    Section {
                        Label(AppText.localized("四步制作证件照"), systemImage: "person.crop.rectangle")
                            .font(.headline).foregroundStyle(.teal)
                        Text(AppText.localized("1. 确认证件照尺寸与背景。"))
                        Text(AppText.localized("2. 拍摄或选择清晰正面照。"))
                        Text(AppText.localized("3. 方框对齐头顶与下巴，调至绿色。"))
                        Text(AppText.localized("4. 点击生成，通过分享保存或导出。"))
                    } header: { Text(AppText.localized("使用说明")) }
                }
                Section(AppText.localized("证件照尺寸（毫米）")) {
                    field("宽度", value: $draft.photoWidth)
                    field("高度", value: $draft.photoHeight)
                }
                Section {
                    field("最小头高", value: $draft.headMin)
                    field("最大头高", value: $draft.headMax)
                    Text(AppText.format("头顶至下巴；生成时取范围中值。当前目标占照片高度 %.1f%%。", ((draft.headMin + draft.headMax) / 2 / max(1, draft.photoHeight)) * 100))
                        .font(.caption)
                } header: { Text(AppText.localized("头部占幅（毫米）")) }
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
                    field("照片间距（毫米）", value: $draft.gap)
                    if draft.validationError == nil { Text(AppText.format("每版 %d 张，%d 列 × %d 行", draft.layout.count, draft.layout.columns, draft.layout.rows)) }
                }
                Section(AppText.localized("背景")) {
                    Picker(AppText.localized("照片背景"), selection: $draft.background) {
                        ForEach(PhotoSettings.Background.allCases, id: \.self) { Text(AppText.localized($0.rawValue)).tag($0) }
                    }
                }
                if let error = draft.validationError { Section { Text(AppText.localized(error)).foregroundStyle(.red) } }
                Section {
                    Button(AppText.localized("载入默认参数")) { draft = PhotoSettings() }
                } footer: {
                    Text(AppText.localized("默认参数参考英国护照照片要求：35 × 45 mm、头顶至下巴 29–34 mm；打印纸为 6 × 4 英寸。可按需修改。"))
                }
            }.navigationTitle(AppText.localized("规格设置"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if isInitial {
                            Button {
                                languageRaw = languageRaw == AppLanguage.english.rawValue
                                    ? AppLanguage.simplifiedChinese.rawValue : AppLanguage.english.rawValue
                            } label: {
                                Label(languageRaw == AppLanguage.english.rawValue ? "中文" : "English", systemImage: "globe")
                            }
                        } else {
                            Button(AppText.localized("取消")) { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppText.localized(isInitial ? "确定" : "保存")) {
                            settings = draft
                            if isInitial { onConfirm?() } else { dismiss() }
                        }.disabled(draft.validationError != nil)
                    }
                }
        }.onAppear { draft = settings }
    }
    private func field(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(AppText.localized(title))
            Spacer()
            TextField(AppText.localized(title), value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
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
