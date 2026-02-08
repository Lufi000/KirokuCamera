import SwiftUI
import AVFoundation

/// 相机预览视图：将 AVCaptureSession 的预览显示在 SwiftUI 中
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = cameraManager.session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // 当相机准备好或切换摄像头时，刷新预览层
        if cameraManager.isCameraReady {
            uiView.refreshPreviewLayer()
        }
    }
}

/// UIKit 相机预览视图
final class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var session: AVCaptureSession? {
        didSet {
            guard session !== oldValue else { return }
            setupPreviewLayer()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    /// 刷新预览层（当相机状态变化时调用）
    func refreshPreviewLayer() {
        // 确保预览层存在且帧正确
        if previewLayer == nil {
            setupPreviewLayer()
        }
        previewLayer?.frame = bounds
    }
    
    private func setupPreviewLayer() {
        // 移除旧的预览层
        previewLayer?.removeFromSuperlayer()
        
        guard let session = session else { return }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        
        self.layer.addSublayer(layer)
        self.previewLayer = layer
    }
}

#Preview {
    CameraPreviewView(cameraManager: CameraManager())
        .frame(width: 300, height: 400)
}
