import SwiftUI

/// 异步图片加载组件：自动处理缓存、异步加载和占位符显示
struct AsyncPhotoImage: View {
    let fileName: String
    let contentMode: ContentMode
    let useThumbnail: Bool
    let thumbnailSize: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    init(
        fileName: String,
        contentMode: ContentMode = .fill,
        useThumbnail: Bool = false,
        thumbnailSize: CGFloat = 200
    ) {
        self.fileName = fileName
        self.contentMode = contentMode
        self.useThumbnail = useThumbnail
        self.thumbnailSize = thumbnailSize
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                // 加载中占位符
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay {
                        ProgressView()
                            .tint(.gray)
                    }
            } else {
                // 加载失败占位符
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            }
        }
        .task(id: fileName) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        
        if useThumbnail {
            image = await ImageCacheService.shared.getThumbnailAsync(
                for: fileName,
                size: thumbnailSize
            )
        } else {
            image = await ImageCacheService.shared.getFullSizeImageAsync(for: fileName)
        }
        
        isLoading = false
    }
}

// MARK: - 便捷初始化器

extension AsyncPhotoImage {
    /// 缩略图模式（用于列表、网格）
    static func thumbnail(
        fileName: String,
        size: CGFloat = 200
    ) -> AsyncPhotoImage {
        AsyncPhotoImage(
            fileName: fileName,
            contentMode: .fill,
            useThumbnail: true,
            thumbnailSize: size
        )
    }
    
    /// 全尺寸模式（用于详情页）
    static func fullSize(
        fileName: String,
        contentMode: ContentMode = .fit
    ) -> AsyncPhotoImage {
        AsyncPhotoImage(
            fileName: fileName,
            contentMode: contentMode,
            useThumbnail: false
        )
    }
}

#Preview {
    VStack {
        AsyncPhotoImage.thumbnail(fileName: "test.jpg")
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        
        AsyncPhotoImage.fullSize(fileName: "test.jpg")
            .frame(height: 300)
    }
}
