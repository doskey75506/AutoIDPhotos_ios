import AVFoundation
import Combine
import SwiftUI
import UIKit

/// Session configuration, device changes, capture, and start/stop all share one queue.
private final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.autoidphoto.camera")
    private let output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var captureContinuation: CheckedContinuation<Data, Error>?
    private var captureID: Int64?
    private var capturedData: Data?
    private var captureError: Error?

    func start(position: AVCaptureDevice.Position) async throws -> AVCaptureDevice {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AVCaptureDevice, Error>) in
            queue.async {
                do {
                    try self.configure(position: position)
                    if !self.session.isRunning { self.session.startRunning() }
                    guard self.session.isRunning else { throw PhotoError.message("摄像头未能启动，请重试。") }
                    guard let device = self.input?.device else { throw PhotoError.message("摄像头未能启动，请重试。") }
                    continuation.resume(returning: device)
                } catch {
                    if self.session.isRunning { self.session.stopRunning() }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            if let continuation = self.captureContinuation {
                self.captureContinuation = nil
                self.captureID = nil
                self.capturedData = nil
                self.captureError = nil
                continuation.resume(throwing: PhotoError.message("拍摄已取消，请重试。"))
            }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        if input?.device.position != position {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                throw PhotoError.message(position == .front ? "没有可用的前置摄像头。" : "没有可用的后置摄像头。")
            }
            let replacement = try AVCaptureDeviceInput(device: device)
            let previous = input
            if let previous { session.removeInput(previous) }
            guard session.canAddInput(replacement) else {
                if let previous, session.canAddInput(previous) { session.addInput(previous) }
                throw PhotoError.message("无法连接摄像头，请重试。")
            }
            session.addInput(replacement)
            input = replacement
        }
        if !session.outputs.contains(output) {
            guard session.canAddOutput(output) else { throw PhotoError.message("无法启用拍照功能。") }
            session.addOutput(output)
            output.maxPhotoQualityPrioritization = .quality
        }
        if let dimensions = input?.device.activeFormat.supportedMaxPhotoDimensions.max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }) {
            output.maxPhotoDimensions = dimensions
        }
    }

    func capture(rotation: CGFloat) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning, self.captureContinuation == nil else {
                    continuation.resume(throwing: PhotoError.message("请等待摄像头就绪后拍照。"))
                    return
                }
                guard let connection = self.output.connection(with: .video) else {
                    continuation.resume(throwing: PhotoError.message("拍照连接不可用，请重启摄像头。"))
                    return
                }
                if connection.isVideoRotationAngleSupported(rotation) { connection.videoRotationAngle = rotation }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = self.input?.device.position == .front
                }
                self.captureContinuation = continuation
                self.capturedData = nil
                self.captureError = nil
                let settings = AVCapturePhotoSettings()
                settings.maxPhotoDimensions = self.output.maxPhotoDimensions
                settings.photoQualityPrioritization = .quality
                self.captureID = settings.uniqueID
                self.output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        let identifier = photo.resolvedSettings.uniqueID
        queue.async {
            guard self.captureID == identifier else { return }
            self.capturedData = data
            self.captureError = error
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        queue.async {
            guard self.captureID == resolvedSettings.uniqueID,
                  let continuation = self.captureContinuation else { return }
            self.captureContinuation = nil
            self.captureID = nil
            defer { self.capturedData = nil; self.captureError = nil }
            if let error = error ?? self.captureError { continuation.resume(throwing: error) }
            else if let data = self.capturedData { continuation.resume(returning: data) }
            else { continuation.resume(throwing: PhotoError.message("未能读取拍摄照片，请重试。")) }
        }
    }
}

@MainActor
final class CameraController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var isCapturing = false
    @Published private(set) var position = AVCaptureDevice.Position.front
    @Published private(set) var device: AVCaptureDevice?
    @Published private(set) var status = "正在连接摄像头…" { didSet { statusError = nil } }
    @Published private(set) var statusError: Error?
    var displayStatus: String {
        if let statusError { return AppText.format(status, statusError.localizedDescription) }
        return AppText.localized(status)
    }
    private let camera = CameraSession()
    private var requestID = 0
    private var observers = Set<AnyCancellable>()
    var session: AVCaptureSession { camera.session }

    init() {
        NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification, object: camera.session)
            .merge(with: NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification, object: camera.session))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.stop()
                self.status = "摄像头连接已中断，请点击相机图标重试。"
            }.store(in: &observers)
    }

    func start(position requestedPosition: AVCaptureDevice.Position? = nil) async {
        guard !isStarting, !isCapturing else { return }
        requestID += 1
        let ticket = requestID
        isStarting = true
        status = "正在连接摄像头…"
        defer { if ticket == requestID { isStarting = false } }
        #if targetEnvironment(simulator)
        status = "模拟器没有可用摄像头，请点击文件夹图标选择照片。"
        return
        #else
        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = permission == .authorized ? true : (permission == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : false)
        guard ticket == requestID else { return }
        guard allowed else { status = "相机权限未开启，请在系统设置中允许访问，或从相册选择照片。"; return }
        let target = requestedPosition ?? position
        do {
            let activeDevice = try await camera.start(position: target)
            guard ticket == requestID else { return }
            device = activeDevice
            position = target
            isRunning = true
            status = "实时视频：请保持正面，点击快门拍摄。"
        } catch {
            guard ticket == requestID else { return }
            isRunning = false
            status = "无法启动摄像头：%@"
            statusError = error
        }
        #endif
    }

    func stop() {
        requestID += 1
        isStarting = false
        isRunning = false
        camera.stop()
    }

    func capture(rotation: CGFloat) async -> Data? {
        guard isRunning, !isStarting, !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let data = try await camera.capture(rotation: rotation)
            stop()
            status = "已拍摄；可调整定位，或点击相机图标重新拍摄。"
            return data
        } catch {
            status = "拍照失败：%@"
            statusError = error
            return nil
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let device: AVCaptureDevice?
    let mirrored: Bool
    @Binding var rotation: CGFloat

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspect
        view.previewLayer.session = session
        view.onRotation = { angle in
            DispatchQueue.main.async { if rotation != angle { rotation = angle } }
        }
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {
        view.mirrored = mirrored
        view.configureRotation(device: device)
        view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.configureRotation(device: nil)
        view.onRotation = nil
        view.previewLayer.session = nil
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var mirrored = false
        var onRotation: ((CGFloat) -> Void)?
        private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
        private var previewRotationObservation: NSKeyValueObservation?
        private var captureRotationObservation: NSKeyValueObservation?

        func configureRotation(device: AVCaptureDevice?) {
            guard rotationCoordinator?.device !== device else {
                applyRotation()
                return
            }
            previewRotationObservation = nil
            captureRotationObservation = nil
            rotationCoordinator = nil
            guard let device else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            rotationCoordinator = coordinator
            // AVFoundation delivers rotation KVO on the main queue. Keep preview
            // and capture angles separate: sensor orientation varies by camera.
            previewRotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, _ in
                self?.applyRotation()
            }
            captureRotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, _ in
                self?.applyRotation()
            }
            applyRotation()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyRotation()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            applyRotation()
        }

        private func applyRotation() {
            guard window != nil, let coordinator = rotationCoordinator else { return }
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            if let connection = previewLayer.connection {
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = mirrored
                }
            }
            onRotation?(coordinator.videoRotationAngleForHorizonLevelCapture)
        }
    }
}
