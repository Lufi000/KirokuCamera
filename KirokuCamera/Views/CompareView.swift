import SwiftUI

/// 用于 sheet(item:) 的预览图包装
private struct IdentifiableUIImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 对比视图：选择两张照片进行对比（独立 push 页面，支持缩放/旋转/平移、时间信息开关、预览保存）
struct CompareView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [Photo]
    
    @State private var leftPhoto: Photo?
    @State private var rightPhoto: Photo?
    @State private var selectingForSide: Side?
    @State private var isSavingCompare = false
    @State private var saveCompareAlert: SaveCompareResult?

    // 对比图：缩放、旋转、平移（左右独立）
    @State private var leftScale: CGFloat = 1.0
    @State private var leftAngle: Double = 0
    @State private var leftOffset: CGSize = .zero
    @State private var rightScale: CGFloat = 1.0
    @State private var rightAngle: Double = 0
    @State private var rightOffset: CGSize = .zero

    // 时间信息：保存对比图时是否显示日期（默认显示）
    @State private var showDateLabels: Bool = true

    // 预览再保存
    @State private var previewImage: UIImage?
    
    enum Side {
        case left, right
    }
    
    enum SaveCompareResult: Identifiable {
        case success
        case failure(String)
        var id: String {
            switch self {
            case .success: return "success"
            case .failure(let msg): return "failure-\(msg)"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.kiroku.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                compareArea
                photoSelector
            }
        }
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width > 80 { dismiss() }
                        }
                )
        }
        .navigationTitle("对比")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(SwipeBackEnabler())
        .toolbarBackground(.regularMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.kiroku.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    generateAndShowPreview()
                }
                .foregroundStyle(canSaveCompare ? Color.kiroku.primary : Color.gray)
                .disabled(!canSaveCompare || isSavingCompare)
            }
        }
        .alert(item: $saveCompareAlert) { result in
            Alert(
                title: Text("保存对比图"),
                message: saveCompareMessage(result),
                dismissButton: .default(Text("确定")) { saveCompareAlert = nil }
            )
        }
        .sheet(item: Binding(get: { previewImage.map { IdentifiableUIImage(image: $0) } }, set: { previewImage = $0?.image })) { wrapper in
            comparePreviewSheet(image: wrapper.image)
        }
        .tint(Color.kiroku.primary)
    }
    
    // MARK: - 子视图
    
    /// 对比区域
    private var compareArea: some View {
        HStack(spacing: 2) {
            // 左侧照片
            comparePhotoView(
                photo: leftPhoto,
                side: .left,
                label: "Before"
            )
            
            // 右侧照片
            comparePhotoView(
                photo: rightPhoto,
                side: .right,
                label: "After"
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    /// 单个对比照片视图（支持双指缩放、旋转、平移；点击选中要更换的一侧）
    private func comparePhotoView(photo: Photo?, side: Side, label: String) -> some View {
        VStack(spacing: 8) {
            if let photo = photo {
                let scale = side == .left ? $leftScale : $rightScale
                let angle = side == .left ? $leftAngle : $rightAngle
                let offset = side == .left ? $leftOffset : $rightOffset
                ZStack {
                    EditableCompareImageView(fileName: photo.fileName, scale: scale, angle: angle, offset: offset)
                        .aspectRatio(3/4, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectingForSide == side ? Color.kiroku.primary : Color.clear,
                                    lineWidth: 3
                                )
                        )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectingForSide = side
                }
                
                Text(photo.formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.kiroku.textSecondary)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.kiroku.cardFill)
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(Color.kiroku.primary.opacity(0.5))
                            Text("Select \(label)")
                                .font(.caption)
                                .foregroundStyle(Color.kiroku.textSecondary)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectingForSide == side ? Color.kiroku.primary : Color.clear,
                                lineWidth: 3
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectingForSide = side }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// 照片选择器：一排显示，放不下则两排，上下滚动
    private var photoSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectingForSide != nil {
                Text("选择一张照片")
                    .font(.headline)
                    .foregroundStyle(Color.kiroku.textPrimary)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80), spacing: 12)
                ], spacing: 12) {
                    ForEach(photos) { photo in
                        photoSelectorItem(photo: photo)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: 300)
        .background(Color.kiroku.cardFill)
    }
    
    /// 照片选择器单项
    private func photoSelectorItem(photo: Photo) -> some View {
        VStack(spacing: 6) {
            AsyncPhotoImage.thumbnail(fileName: photo.fileName, size: 200)
                .frame(width: 80, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(photoItemBorderColor(for: photo), lineWidth: 2)
                )
                .shadow(color: Color.kiroku.shadow, radius: 4, x: 0, y: 2)
            
            Text(photo.formattedDate)
                .font(.caption2)
                .foregroundStyle(Color.kiroku.textSecondary)
        }
        .onTapGesture {
            selectPhoto(photo)
        }
    }
    
    /// 照片边框颜色
    private func photoItemBorderColor(for photo: Photo) -> Color {
        if photo.id == leftPhoto?.id || photo.id == rightPhoto?.id {
            return Color.kiroku.primary
        }
        return .clear
    }
    
    private var canSaveCompare: Bool {
        leftPhoto != nil && rightPhoto != nil
    }

    private func saveCompareMessage(_ result: SaveCompareResult) -> Text? {
        switch result {
        case .success:
            return Text("已保存到相册")
        case .failure(let msg):
            return Text(msg)
        }
    }

    /// 生成预览图并弹出预览 sheet（应用缩放/旋转/平移、时间显示）
    private func generateAndShowPreview() {
        guard let left = leftPhoto, let right = rightPhoto else { return }
        isSavingCompare = true
        Task {
            let leftImage = left.loadImage()
            let rightImage = right.loadImage()
            await MainActor.run {
                isSavingCompare = false
                guard let l = leftImage, let r = rightImage else {
                    saveCompareAlert = .failure("无法加载照片")
                    return
                }
                let leftTransformed = CompareImageService.transformImage(l, scale: leftScale, angleDegrees: leftAngle, offset: leftOffset)
                let rightTransformed = CompareImageService.transformImage(r, scale: rightScale, angleDegrees: rightAngle, offset: rightOffset)
                guard let lt = leftTransformed, let rt = rightTransformed else {
                    saveCompareAlert = .failure("应用变换失败")
                    return
                }
                let leftLabel = showDateLabels ? "Before \(left.formattedDate)" : nil
                let rightLabel = showDateLabels ? "After \(right.formattedDate)" : nil
                guard let composite = CompareImageService.composite(left: lt, right: rt, leftLabel: leftLabel, rightLabel: rightLabel) else {
                    saveCompareAlert = .failure("生成对比图失败")
                    return
                }
                previewImage = composite
            }
        }
    }

    /// 预览 sheet：展示生成的对比图，支持「保存到相册」或「取消」
    private func comparePreviewSheet(image: UIImage) -> some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            .background(Color.kiroku.background)
            .navigationTitle("预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        previewImage = nil
                    }
                    .foregroundStyle(Color.kiroku.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存到相册") {
                        savePreviewToLibrary(image)
                        previewImage = nil
                    }
                    .foregroundStyle(Color.kiroku.primary)
                }
            }
        }
    }

    private func savePreviewToLibrary(_ image: UIImage) {
        CompareImageService.saveToPhotoLibrary(image) { success, message in
            saveCompareAlert = success ? .success : .failure(message ?? "保存失败")
        }
    }

    /// 选择照片
    private func selectPhoto(_ photo: Photo) {
        guard let side = selectingForSide else {
            // 如果没有选中任何一边，默认先选左边
            if leftPhoto == nil {
                leftPhoto = photo
            } else if rightPhoto == nil {
                rightPhoto = photo
            }
            return
        }
        
        switch side {
        case .left:
            leftPhoto = photo
            leftScale = 1.0
            leftAngle = 0
            leftOffset = .zero
        case .right:
            rightPhoto = photo
            rightScale = 1.0
            rightAngle = 0
            rightOffset = .zero
        }
        
        selectingForSide = nil
    }
}

// MARK: - 可编辑对比图图片（双指缩放、旋转、平移）

private struct EditableCompareImageView: View {
    let fileName: String
    @Binding var scale: CGFloat
    @Binding var angle: Double
    @Binding var offset: CGSize

    @GestureState private var magnifyBy: CGFloat = 1.0
    @GestureState private var rotationDelta: Angle = .zero
    @GestureState private var dragOffset: CGSize = .zero

    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 5.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AsyncPhotoImage.fullSize(fileName: fileName, contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale * magnifyBy)
                    .rotationEffect(.degrees(angle) + rotationDelta)
                    .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: size.width, height: size.height)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .updating($magnifyBy) { value, state, _ in state = value }
                            .onEnded { value in
                                let newScale = scale * value
                                scale = min(maxScale, max(minScale, newScale))
                            }
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .updating($rotationDelta) { value, state, _ in state = value }
                            .onEnded { value in angle += value.degrees }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in state = value.translation }
                            .onEnded { value in offset.width += value.translation.width; offset.height += value.translation.height }
                    )
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
    }
}

#Preview {
    CompareView(photos: [])
}
