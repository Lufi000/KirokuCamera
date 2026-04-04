import SwiftUI

/// 对比视图：选择两张照片进行对比（独立 push 页面，支持缩放/旋转/平移、时间信息开关、预览保存）
struct CompareView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [Photo]
    
    @State private var leftPhoto: Photo?
    @State private var rightPhoto: Photo?
    @State private var selectingForSide: Side?
    @State private var saveCompareAlert: SaveCompareResult?

    // 预览相关状态（使用包装类型以便 fullScreenCover(item:) 使用）
    @State private var previewImageWrapper: PreviewImageWrapper?

    struct PreviewImageWrapper: Identifiable {
        let id = UUID()
        let image: UIImage
    }

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

    // 日期标签位置偏移（相对于默认位置）
    @State private var leftLabelOffset: CGSize = .zero
    @State private var rightLabelOffset: CGSize = .zero

    // 日期标签字号
    @State private var leftLabelFontSize: CGFloat = 18
    @State private var rightLabelFontSize: CGFloat = 18

    // 日期编辑焦点（用 Side? 区分左右，避免两个 TextField 共用 Bool 导致焦点混乱）
    @FocusState private var editingDateSide: Side?

    // 对比排列方式
    @State private var compareLayout: CompareLayout = .topAndBottom
    
    enum Side {
        case left, right
    }

    enum CompareLayout {
        case sideBySide   // 左右排列
        case topAndBottom // 上下排列
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
                    .layoutPriority(1)
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
                    generatePreviewImage()
                }
                .foregroundStyle(canSaveCompare ? Color.kiroku.primary : Color.gray)
                .disabled(!canSaveCompare)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        compareLayout = compareLayout == .sideBySide ? .topAndBottom : .sideBySide
                    }
                } label: {
                    Image(systemName: compareLayout == .sideBySide ? "rectangle.split.2x1" : "rectangle.split.1x2")
                        .foregroundStyle(Color.kiroku.primary)
                }
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
        .fullScreenCover(item: $previewImageWrapper) { wrapper in
            ComparePreviewView(previewImage: wrapper.image)
        }
        .tint(Color.kiroku.primary)
    }
    
    // MARK: - 子视图

    private static let canvasEdgePadding: CGFloat = 8
    private static let canvasCellSpacing: CGFloat = 2

    /// 对比区域：3:4 画布，支持左右或上下排列
    private var compareArea: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geo in
                    let canvasW = geo.size.width
                    let canvasH = geo.size.height
                    let edgePad = Self.canvasEdgePadding
                    let contentW = canvasW - edgePad * 2
                    let contentH = canvasH - edgePad * 2
                    let spacing = Self.canvasCellSpacing

                    let cellSize: CGSize = compareLayout == .sideBySide
                        ? CGSize(width: (contentW - spacing) / 2, height: contentH)
                        : CGSize(width: contentW, height: (contentH - spacing) / 2)

                    // 防止 GeometryReader 首次渲染时尺寸为零导致负值
                    if cellSize.width > 0 && cellSize.height > 0 {
                    ZStack {
                        Color.kiroku.background
                        Group {
                            if compareLayout == .sideBySide {
                                HStack(spacing: spacing) {
                                    comparePhotoView(photo: leftPhoto, side: .left, cellSize: cellSize)
                                    comparePhotoView(photo: rightPhoto, side: .right, cellSize: cellSize)
                                }
                            } else {
                                VStack(spacing: spacing) {
                                    comparePhotoView(photo: leftPhoto, side: .left, cellSize: cellSize)
                                    comparePhotoView(photo: rightPhoto, side: .right, cellSize: cellSize)
                                }
                            }
                        }
                        .padding(edgePad)
                    }
                    }
                }
            }
    }

    /// 单个对比照片视图
    private func comparePhotoView(photo: Photo?, side: Side, cellSize: CGSize) -> some View {
        let cornerRadius: CGFloat = 12

        return Group {
            if let photo = photo {
                let scale = side == .left ? $leftScale : $rightScale
                let angle = side == .left ? $leftAngle : $rightAngle
                let offset = side == .left ? $leftOffset : $rightOffset
                let labelOffset = side == .left ? $leftLabelOffset : $rightLabelOffset
                let labelFontSize = side == .left ? $leftLabelFontSize : $rightLabelFontSize

                ZStack {
                    EditableCompareImageView(
                        fileName: photo.fileName,
                        scale: scale,
                        angle: angle,
                        offset: offset
                    )
                    .frame(width: cellSize.width, height: cellSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(selectingForSide == side ? Color.kiroku.primary : .clear, lineWidth: 3)
                    )

                    // 日期标签叠在图片上
                    if showDateLabels {
                        DraggableLabelView(
                            text: side == .left ? $leftDateLabel : $rightDateLabel,
                            offset: labelOffset,
                            fontSize: labelFontSize,
                            cellSize: cellSize,
                            onFocusChange: { focused in editingDateSide = focused ? side : nil }
                        )
                        .frame(width: cellSize.width, height: cellSize.height)
                    }
                }
                .frame(width: cellSize.width, height: cellSize.height)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    editingDateSide = nil
                    selectingForSide = side
                })
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.kiroku.cardFill)
                    .frame(width: cellSize.width, height: cellSize.height)
                    .overlay {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(Color.kiroku.primary.opacity(0.5))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(selectingForSide == side ? Color.kiroku.primary : .clear, lineWidth: 3)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectingForSide = side }
            }
        }
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
        .frame(maxHeight: 200)
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

    /// 互换左右照片（连同缩放/旋转/平移/日期标签一起交换）
    private func swapPhotos() {
        swap(&leftPhoto, &rightPhoto)
        swap(&leftScale, &rightScale)
        swap(&leftAngle, &rightAngle)
        swap(&leftOffset, &rightOffset)
        swap(&leftDateLabel, &rightDateLabel)
        swap(&leftLabelOffset, &rightLabelOffset)
        swap(&leftLabelFontSize, &rightLabelFontSize)
    }

    /// 生成预览图
    private func generatePreviewImage() {
        guard let leftPhoto = leftPhoto, let rightPhoto = rightPhoto else { return }

        // 加载原图
        guard let leftImage = ImageCacheService.shared.getFullSizeImage(for: leftPhoto.fileName),
              let rightImage = ImageCacheService.shared.getFullSizeImage(for: rightPhoto.fileName) else {
            return
        }

        // 构建编辑参数
        let firstParams = CompareImageService.ImageEditParams(
            image: leftImage,
            scale: leftScale,
            angleDegrees: leftAngle,
            offset: leftOffset,
            dateLabel: leftDateLabel,
            labelOffset: leftLabelOffset,
            labelFontSize: leftLabelFontSize
        )

        let secondParams = CompareImageService.ImageEditParams(
            image: rightImage,
            scale: rightScale,
            angleDegrees: rightAngle,
            offset: rightOffset,
            dateLabel: rightDateLabel,
            labelOffset: rightLabelOffset,
            labelFontSize: rightLabelFontSize
        )

        // 转换布局类型
        let serviceLayout: CompareImageService.CompareLayout = compareLayout == .sideBySide ? .sideBySide : .topAndBottom

        // 生成预览图
        if let image = CompareImageService.compositeWithEdits(
            first: firstParams,
            second: secondParams,
            layout: serviceLayout,
            showDateLabels: showDateLabels
        ) {
            previewImageWrapper = PreviewImageWrapper(image: image)
        }
    }

    /// 选择照片
    private func selectPhoto(_ photo: Photo) {
        guard let side = selectingForSide else {
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
            leftLabelOffset = .zero
            leftLabelFontSize = 18
        case .right:
            rightPhoto = photo
            rightScale = 1.0
            rightAngle = 0
            rightOffset = .zero
            rightDateLabel = photo.formattedDate
            rightLabelOffset = .zero
            rightLabelFontSize = 18
        }
        
        selectingForSide = nil
    }
}

// MARK: - 可编辑对比图图片（双指缩放、旋转、单指平移）

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
                Color.black
                AsyncPhotoImage.fullSize(fileName: fileName, contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale * magnifyBy)
                    .rotationEffect(.degrees(angle) + rotationDelta)
                    .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in state = value }
                    .onEnded { value in
                        scale = min(maxScale, max(minScale, scale * value))
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
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
            )
        }
    }
}

// MARK: - 可拖动日期标签（叠在图片上，支持拖动位置和缩放字号）

private struct DraggableLabelView: View {
    @Binding var text: String
    @Binding var offset: CGSize
    @Binding var fontSize: CGFloat
    let cellSize: CGSize
    var onFocusChange: (Bool) -> Void

    @FocusState private var isFocused: Bool
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var scaleDelta: CGFloat = 1.0

    private let minFontSize: CGFloat = 10
    private let maxFontSize: CGFloat = 60

    var body: some View {
        TextField("日期", text: $text)
            .font(.system(size: fontSize * scaleDelta, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            .multilineTextAlignment(.center)
            .fixedSize()
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit { isFocused = false }
            .onChange(of: isFocused) { focused in onFocusChange(focused) }
            .position(
                x: cellSize.width / 2 + offset.width + dragDelta.width,
                y: cellSize.height - 24 + offset.height + dragDelta.height
            )
            .gesture(
                DragGesture()
                    .updating($dragDelta) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($scaleDelta) { value, state, _ in state = value }
                    .onEnded { value in
                        fontSize = min(maxFontSize, max(minFontSize, fontSize * value))
                    }
            )
    }
}

#Preview {
    CompareView(photos: [])
}
