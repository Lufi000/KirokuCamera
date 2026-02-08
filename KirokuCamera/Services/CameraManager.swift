import AVFoundation
import UIKit
import Combine

/// 相机管理器：处理相机会话和拍照
final class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isCameraReady = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // MARK: - 权限检查
    
    /// 检查权限并设置相机
    func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }
    
    // MARK: - 相机设置
    
    /// 设置相机
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    /// 配置相机会话
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // 添加视频输入
        guard let device = getCamera(for: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }
        
        // 添加照片输出
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        session.startRunning()
        
        DispatchQueue.main.async { [weak self] in
            self?.isCameraReady = true
        }
    }
    
    /// 获取摄像头设备
    private func getCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        )
    }
    
    // MARK: - 相机控制
    
    /// 切换前后摄像头
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            
            guard let device = self.getCamera(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: device) else {
                return
            }
            
            self.session.beginConfiguration()
            
            // 移除旧输入
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            // 添加新输入
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
                
                DispatchQueue.main.async {
                    self.currentPosition = newPosition
                }
            }
            
            self.session.commitConfiguration()
        }
    }
    
    /// 停止相机会话
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    // MARK: - 拍照
    
    /// 拍摄照片
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCaptureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { [weak self] in
                self?.photoCaptureCompletion?(nil)
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var finalImage = image
            // 如果是前置摄像头，需要镜像翻转
            if self.currentPosition == .front {
                finalImage = image.withHorizontallyFlippedOrientation()
            }
            
            self.photoCaptureCompletion?(finalImage)
        }
    }
}
