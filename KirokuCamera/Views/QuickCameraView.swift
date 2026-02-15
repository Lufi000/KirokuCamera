import SwiftUI

/// 用于 sheet(item:) 的可识别图片包装
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let originalDate: Date?  // 图片的原始拍摄时间（从 EXIF 读取）
}

/// 快速拍照视图：从首页直接拍照，拍完后选择记录项
struct QuickCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore

    /// 预选的记录项（从记录项详情页进入时使用）
    var preselectedSubject: Subject?
    
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: IdentifiableImage?
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingPhotoLibrary = false
    
    // 参考图相关
    @State private var referenceImage: UIImage?      // 参考图
    @State private var showOverlay: Bool = true
    @State private var overlayOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部工具栏
                topToolbar
                
                // 相机预览区域
                cameraPreviewArea
                
                // 底部控制区域
                bottomControls
            }
            
            // 仅在用户已拒绝相机权限时展示说明与「打开设置」入口（不在 notDetermined 时展示，避免在系统权限弹窗前出现带按钮的引导，符合 Guideline 5.1.1）
            if cameraManager.authorizationState == .denied {
                permissionDeniedView
            }
        }
        .onAppear {
            cameraManager.checkPermissionAndSetup()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .task {
            // 异步加载参考图
            await loadReferenceImage()
        }
        .sheet(item: $capturedImage) { captured in
            SubjectPickerView(
                image: captured.image,
                preselectedSubject: preselectedSubject,
                selectedDate: selectedDate,
                onSave: { subject in
                    await savePhoto(captured.image, to: subject, at: selectedDate)
                },
                onDiscard: {
                    capturedImage = nil
                    selectedDate = Date()
                }
            )
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotoLibraryPickerView { image, date in
                showingPhotoLibrary = false
                let dateToUse = date ?? selectedDate
                if let subject = preselectedSubject {
                    Task {
                        await savePhoto(image, to: subject, at: dateToUse)
                    }
                } else {
                    capturedImage = IdentifiableImage(image: image, originalDate: date)
                    if let date = date {
                        selectedDate = date
                    }
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 顶部工具栏
    private var topToolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel(String(localized: "关闭"))
            
            Spacer()
            
            Text(preselectedSubject?.name ?? String(localized: "拍照"))
                .font(.headline)
                .foregroundStyle(.white)
            
            Spacer()
            
            // 切换前后摄像头
            Button {
                cameraManager.switchCamera()
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel(String(localized: "切换摄像头"))
        }
        .background(Color.black.opacity(0.3))
    }
    
    /// 相机预览区域
    private var cameraPreviewArea: some View {
        GeometryReader { geometry in
            ZStack {
                // 相机预览
                CameraPreviewView(cameraManager: cameraManager)
                
                // 加载指示器
                if !cameraManager.isCameraReady && cameraManager.isAuthorized {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("启动相机...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                // 九宫格参考线（iOS 原生相机风格）
                CameraGridOverlay(size: geometry.size)
                    .allowsHitTesting(false)
                
                // 参考图叠加
                if showOverlay, let refImage = referenceImage {
                    Image(uiImage: refImage)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .opacity(overlayOpacity)
                        .allowsHitTesting(false)
                }
                
                // 没有参考图时的提示（仅在有预选记录项时显示）
                if referenceImage == nil && cameraManager.isCameraReady && preselectedSubject != nil {
                    VStack {
                        Spacer()
                        Text("第一张照片")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.kiroku.cardFill)
                            .clipShape(Capsule())
                        Spacer().frame(height: 20)
                    }
                }
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    /// 底部控制区域
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // 透明度调节（仅在有参考图时显示）
            if referenceImage != nil {
                opacityControl
            }
            
            // 日期选择
            Button {
                showingDatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(formattedDate)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
            }
            
            // 拍摄和上传按钮
            HStack(spacing: 40) {
                // 从相册选择
                Button {
                    showingPhotoLibrary = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("相册")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                
                // 拍摄按钮
                Button {
                    capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 60, height: 60)
                    }
                }
                .accessibilityLabel(String(localized: "拍照"))
                .disabled(!cameraManager.isCameraReady)
                .opacity(cameraManager.isCameraReady ? 1 : 0.5)
                
                // 占位（保持对称）
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.bottom, 20)
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
    
    /// 参考图控制
    private var opacityControl: some View {
        HStack(spacing: 12) {
            // 开关按钮
            Button {
                showOverlay.toggle()
            } label: {
                Image(systemName: showOverlay ? "eye.fill" : "eye.slash.fill")
                    .font(.title3)
                    .foregroundStyle(showOverlay ? .white : .gray)
            }
            .accessibilityLabel(showOverlay ? String(localized: "隐藏参考图") : String(localized: "显示参考图"))
            
            Text("参考图")
                .font(.caption)
                .foregroundStyle(.white)
            
            // 透明度滑块
            Slider(value: $overlayOpacity, in: 0.1...0.7)
                .tint(.white)
                .accessibilityLabel(String(localized: "参考图透明度"))
                .disabled(!showOverlay)
            
            Text("\(Int(overlayOpacity * 100))%")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 36)
        }
        .padding(.horizontal)
    }
    
    private var formattedDate: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return String(localized: "今天")
        }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: selectedDate)
    }
    
    /// 日期选择器
    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "选择日期",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("选择照片日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    /// 权限已拒绝时的说明视图：仅告知功能需要相机，并提供前往系统设置的入口（符合审核：在用户已拒绝后再提供链接到 Settings）
    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))

            Text("相机功能需要访问相机")
                .font(.headline)
                .foregroundStyle(.white)

            Text("若您此前已关闭权限，可在「设置」中重新开启。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(String(localized: "Continue")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(Color.kiroku.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 操作
    
    /// 拍照
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            if let image = image {
                capturedImage = IdentifiableImage(image: image, originalDate: nil)
            }
        }
    }
    
    /// 保存照片到指定记录项（写入 DataStore + 文件，无 SwiftData）
    @MainActor
    private func savePhoto(_ image: UIImage, to subject: Subject, at date: Date) async -> Bool {
        guard let fileName = await PhotoStorageService.shared.savePhotoAsync(image) else {
            return false
        }
        let photo = Photo(fileName: fileName, subjectId: subject.id, takenAt: date)
        dataStore.addPhoto(photo)
        capturedImage = nil
        selectedDate = Date()
        dismiss()
        return true
    }

    /// 异步加载参考图（预选记录项时取该记录项最早一张照片）
    private func loadReferenceImage() async {
        guard let subject = preselectedSubject,
              let firstPhoto = dataStore.firstPhoto(for: subject.id) else { return }
        let filePath = firstPhoto.filePath
        let image = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: filePath) else { return nil as UIImage? }
            return UIImage(data: data)
        }.value
        await MainActor.run {
            self.referenceImage = image
        }
    }
}

// MARK: - 九宫格参考线（iOS 原生相机风格）

private struct CameraGridOverlay: View {
    let size: CGSize

    /// 参考线颜色与透明度（与 iOS 原生相机一致）
    private let lineColor = Color.white.opacity(0.6)
    private let lineWidth: CGFloat = 0.5

    var body: some View {
        Canvas { context, _ in
            let w = size.width
            let h = size.height
            let oneThirdW = w / 3
            let oneThirdH = h / 3

            var path = Path()
            // 两条竖线
            path.move(to: CGPoint(x: oneThirdW, y: 0))
            path.addLine(to: CGPoint(x: oneThirdW, y: h))
            path.move(to: CGPoint(x: oneThirdW * 2, y: 0))
            path.addLine(to: CGPoint(x: oneThirdW * 2, y: h))
            // 两条横线
            path.move(to: CGPoint(x: 0, y: oneThirdH))
            path.addLine(to: CGPoint(x: w, y: oneThirdH))
            path.move(to: CGPoint(x: 0, y: oneThirdH * 2))
            path.addLine(to: CGPoint(x: w, y: oneThirdH * 2))

            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }
        .frame(width: size.width, height: size.height)
    }
}

#Preview {
    QuickCameraView()
        .environmentObject(DataStore())
}
