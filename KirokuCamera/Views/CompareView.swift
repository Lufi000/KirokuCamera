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

    // 可编辑的日期标签（选照片时从 formattedDate 初始化，用户可自行修改）
    @State private var leftDateLabel: String = ""
    @State private var rightDateLabel: String = ""

    // 日期编辑焦点（用 Side? 区分左右，避免两个 TextField 共用 Bool 导致焦点混乱）
    @FocusState private var editingDateSide: Side?

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
        .ignoresSafeArea(.keyboard)
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
                Button("预览") {
                    editingDateSide = nil
                    generateAndShowPreview()
                }
                .foregroundStyle(canSaveCompare ? Color.kiroku.primary : Color.gray)
                .disabled(!canSaveCompare || isSavingCompare)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    editingDateSide = nil
                }
                .foregroundStyle(Color.kiroku.primary)
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
        VStack(spacing: 16) {
            if let photo = photo {
                let scale = side == .left ? $leftScale : $rightScale
                let angle = side == .left ? $leftAngle : $rightAngle
                let offset = side == .left ? $leftOffset : $rightOffset
                ZStack {
                    EditableCompareImageView(
                        fileName: photo.fileName,
                        scale: scale,
                        angle: angle,
                        offset: offset,
                        onHorizontalSwipe: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                swapPhotos()
                            }
                        }
                    )
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
                .simultaneousGesture(
                    TapGesture().onEnded {
                        editingDateSide = nil
                        selectingForSide = side
                    }
                )
                .accessibilityLabel(String(localized: "对比照片"))
                .accessibilityHint(String(localized: "双指缩放或旋转，点击更换照片"))
                
                TextField("日期", text: side == .left ? $leftDateLabel : $rightDateLabel)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.kiroku.textSecondary)
                    .multilineTextAlignment(.center)
                    .focused($editingDateSide, equals: side)
                    .submitLabel(.done)
                    .onSubmit { editingDateSide = nil }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
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

    /// 生成预览图并弹出预览 sheet（与对比区域所见一致：缩放/旋转/平移后裁剪，用 ImageRenderer 渲染）
    private func generateAndShowPreview() {
        guard let left = leftPhoto, let right = rightPhoto else { return }
        isSavingCompare = true
        // 捕获当前状态，避免后台闭包引用 self
        let ls = leftScale, la = leftAngle, lo = leftOffset
        let rs = rightScale, ra = rightAngle, ro = rightOffset
        let ll = showDateLabels ? leftDateLabel : nil
        let rl = showDateLabels ? rightDateLabel : nil
        // 在主线程取出文件路径，后台线程读文件数据，避免 actor 隔离问题
        let leftPath = left.filePath
        let rightPath = right.filePath
        Task.detached(priority: .userInitiated) {
            let leftImage = _loadImageFromPath(leftPath)
            let rightImage = _loadImageFromPath(rightPath)
            await MainActor.run {
                isSavingCompare = false
                guard let l = leftImage, let r = rightImage else {
                    saveCompareAlert = .failure(String(localized: "无法加载照片"))
                    return
                }
                let content = ExportCompareAreaView(
                    leftImage: l,
                    rightImage: r,
                    leftScale: ls,
                    leftAngle: la,
                    leftOffset: lo,
                    rightScale: rs,
                    rightAngle: ra,
                    rightOffset: ro,
                    leftLabel: ll,
                    rightLabel: rl
                )
                let renderer = ImageRenderer(content: content)
                renderer.scale = 1
                if let rendered = renderer.uiImage {
                    previewImage = rendered
                } else {
                    saveCompareAlert = .failure(String(localized: "生成对比图失败"))
                }
            }
        }
    }

    // 图片加载使用模块级函数 _loadImageFromPath，避免 MainActor 隔离

    /// 预览 sheet：展示生成的对比图，支持「保存到相册」或「取消」
    private func comparePreviewSheet(image: UIImage) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer().frame(maxHeight: 40)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                Text("导出效果预览")
                    .font(.caption)
                    .foregroundStyle(Color.kiroku.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Button {
                        savePreviewToLibrary(image)
                        previewImage = nil
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel(Text("保存到相册"))
                    .foregroundStyle(Color.kiroku.primary)
                }
            }
        }
    }

    private func savePreviewToLibrary(_ image: UIImage) {
        CompareImageService.saveToPhotoLibrary(image) { success, message in
            saveCompareAlert = success ? .success : .failure(message ?? String(localized: "保存失败"))
        }
    }

    /// 互换左右照片（连同缩放/旋转/平移/日期标签一起交换）
    private func swapPhotos() {
        swap(&leftPhoto, &rightPhoto)
        swap(&leftScale, &rightScale)
        swap(&leftAngle, &rightAngle)
        swap(&leftOffset, &rightOffset)
        swap(&leftDateLabel, &rightDateLabel)
    }

    /// 选择照片
    private func selectPhoto(_ photo: Photo) {
        guard let side = selectingForSide else {
            // 如果没有选中任何一边，默认先选左边
            if leftPhoto == nil {
                leftPhoto = photo
                leftDateLabel = photo.formattedDate
            } else if rightPhoto == nil {
                rightPhoto = photo
                rightDateLabel = photo.formattedDate
            }
            return
        }
        
        switch side {
        case .left:
            leftPhoto = photo
            leftScale = 1.0
            leftAngle = 0
            leftOffset = .zero
            leftDateLabel = photo.formattedDate
        case .right:
            rightPhoto = photo
            rightScale = 1.0
            rightAngle = 0
            rightOffset = .zero
            rightDateLabel = photo.formattedDate
        }
        
        selectingForSide = nil
    }
}

// MARK: - 导出用对比区域（与屏幕一致：scale/rotation/offset 后裁剪，用 ImageRenderer 渲染）

private struct ExportCompareAreaView: View {
    let leftImage: UIImage
    let rightImage: UIImage
    let leftScale: CGFloat
    let leftAngle: Double
    let leftOffset: CGSize
    let rightScale: CGFloat
    let rightAngle: Double
    let rightOffset: CGSize
    let leftLabel: String?
    let rightLabel: String?

    private static let contentWidth: CGFloat = 1600
    /// 导出图四周留白，与预览所见一致
    private static let edgePadding: CGFloat = 48
    private static let totalWidth: CGFloat = contentWidth + edgePadding * 2
    private static let spacing: CGFloat = 2
    private static let cellWidth = (contentWidth - spacing) / 2
    private static let imageAspectRatio: CGFloat = 3 / 4
    private static let imageAreaHeight = cellWidth / imageAspectRatio
    private static let cornerRadius = cellWidth * 12 / 200
    /// 与对比视图一致：日期 18pt、VStack spacing 8；导出按栏宽同比例放大
    private static let typicalCellWidthOnScreen: CGFloat = 200
    private static let labelFontSizeOnScreen: CGFloat = 18
    private static let labelSpacingOnScreen: CGFloat = 8
    private static let labelHeightOnScreen: CGFloat = 28
    private static var labelScale: CGFloat { cellWidth / typicalCellWidthOnScreen }
    private static var labelFontSize: CGFloat { labelFontSizeOnScreen * labelScale }
    private static var labelSpacing: CGFloat { labelSpacingOnScreen * labelScale }
    private static var labelHeight: CGFloat { labelHeightOnScreen * labelScale }

    var body: some View {
        let hasLabels = (leftLabel.map { !$0.isEmpty } ?? false) || (rightLabel.map { !$0.isEmpty } ?? false)
        let contentHeight = Self.imageAreaHeight + (hasLabels ? Self.labelSpacing + Self.labelHeight : 0)
        let canvasHeight = contentHeight + Self.edgePadding * 2

        ZStack {
            Color.kiroku.background
            VStack(spacing: 0) {
                HStack(spacing: Self.spacing) {
                    exportCell(image: leftImage, scale: leftScale, angle: leftAngle, offset: leftOffset)
                    exportCell(image: rightImage, scale: rightScale, angle: rightAngle, offset: rightOffset)
                }
                if hasLabels {
                    HStack(alignment: .top, spacing: Self.spacing) {
                        if let leftLabel = leftLabel, !leftLabel.isEmpty {
                            Text(leftLabel)
                                .font(.system(size: Self.labelFontSize, weight: .medium))
                                .foregroundStyle(Color.kiroku.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        if let rightLabel = rightLabel, !rightLabel.isEmpty {
                            Text(rightLabel)
                                .font(.system(size: Self.labelFontSize, weight: .medium))
                                .foregroundStyle(Color.kiroku.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.top, Self.labelSpacing)
                    .frame(height: Self.labelHeight)
                }
            }
            .frame(width: Self.contentWidth)
        }
        .frame(width: Self.totalWidth, height: canvasHeight)
    }

    private func exportCell(image: UIImage, scale: CGFloat, angle: Double, offset: CGSize) -> some View {
        // offset 是屏幕坐标（约 200pt 栏宽），导出图栏宽约 800pt，需按同比例放大
        let s = Self.labelScale
        return ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: Self.cellWidth, height: Self.imageAreaHeight)
                .scaleEffect(scale)
                .rotationEffect(.degrees(angle))
                .offset(x: offset.width * s, y: offset.height * s)
        }
        .frame(width: Self.cellWidth, height: Self.imageAreaHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}

// MARK: - 可编辑对比图图片（双指缩放、旋转、平移；拖到对侧互换）

private struct EditableCompareImageView: View {
    let fileName: String
    @Binding var scale: CGFloat
    @Binding var angle: Double
    @Binding var offset: CGSize

    /// 拖到另一侧框位置时调用，由外部执行互换
    var onHorizontalSwipe: (() -> Void)?

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
                            .onEnded { value in
                                if scale <= 1.05 {
                                    // 未放大：拖到另一侧框位置（水平位移超过半个栏宽）→ 互换
                                    // 不提交 offset，GestureState 自动归零 → 图片弹回原位
                                    if abs(value.translation.width) > size.width * 0.5 {
                                        onHorizontalSwipe?()
                                    }
                                } else {
                                    // 已放大：提交拖拽位移用于平移
                                    offset.width += value.translation.width
                                    offset.height += value.translation.height
                                }
                            }
                    )
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
    }
}

// MARK: - 后台图片加载（nonisolated，不受 MainActor 约束）

/// 从文件路径加载图片，供 Task.detached 安全调用
private nonisolated func _loadImageFromPath(_ path: URL) -> UIImage? {
    guard let data = try? Data(contentsOf: path) else { return nil }
    return UIImage(data: data)
}

#Preview {
    CompareView(photos: [])
}
