import UIKit

/// 图片缓存服务：使用 NSCache 缓存已加载的图片，避免重复读取磁盘
final class ImageCacheService: @unchecked Sendable {
    static let shared = ImageCacheService()
    
    /// 全尺寸图片缓存
    private let fullSizeCache = NSCache<NSString, UIImage>()
    
    /// 缩略图缓存
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    /// 照片目录（缓存路径避免重复获取）
    private let photoDirectory: URL
    
    private init() {
        // 设置缓存限制（约 50 张全尺寸图片，100 张缩略图）
        fullSizeCache.countLimit = 50
        thumbnailCache.countLimit = 100
        photoDirectory = PhotoStorageService.shared.photoDirectory
    }
    
    // MARK: - 全尺寸图片
    
    /// 获取全尺寸图片（优先从缓存）
    func getFullSizeImage(for fileName: String) -> UIImage? {
        let key = fileName as NSString
        
        // 先查缓存
        if let cached = fullSizeCache.object(forKey: key) {
            return cached
        }
        
        // 缓存未命中，从磁盘加载
        guard let image = loadImageFromDisk(fileName: fileName) else {
            return nil
        }
        
        // 存入缓存
        fullSizeCache.setObject(image, forKey: key)
        return image
    }
    
    /// 异步获取全尺寸图片
    func getFullSizeImageAsync(for fileName: String) async -> UIImage? {
        let key = fileName as NSString
        
        // 先查缓存（主线程安全）
        if let cached = fullSizeCache.object(forKey: key) {
            return cached
        }
        
        // 后台加载
        let directory = photoDirectory
        let image: UIImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.loadImage(from: directory, fileName: fileName)
                continuation.resume(returning: result)
            }
        }
        
        // 存入缓存
        if let image = image {
            fullSizeCache.setObject(image, forKey: key)
        }
        
        return image
    }
    
    // MARK: - 缩略图
    
    /// 获取缩略图（优先从缓存）
    func getThumbnail(for fileName: String, size: CGFloat = 200) -> UIImage? {
        let key = Self.thumbnailKey(fileName: fileName, size: size)
        
        // 先查缓存
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        
        // 缓存未命中，生成缩略图
        guard let fullImage = getFullSizeImage(for: fileName) else {
            return nil
        }
        
        let thumbnail = Self.generateThumbnail(from: fullImage, size: size)
        thumbnailCache.setObject(thumbnail, forKey: key)
        return thumbnail
    }
    
    /// 异步获取缩略图
    func getThumbnailAsync(for fileName: String, size: CGFloat = 200) async -> UIImage? {
        let key = Self.thumbnailKey(fileName: fileName, size: size)
        
        // 先查缓存
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        
        // 后台生成缩略图
        let directory = photoDirectory
        let thumbnail: UIImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // 先尝试从磁盘加载已保存的缩略图
                let thumbFileName = Self.thumbnailFileName(for: fileName)
                if let savedThumb = Self.loadImage(from: directory, fileName: thumbFileName) {
                    continuation.resume(returning: savedThumb)
                    return
                }
                
                // 没有保存的缩略图，从全尺寸图生成
                guard let fullImage = Self.loadImage(from: directory, fileName: fileName) else {
                    continuation.resume(returning: nil)
                    return
                }
                let thumb = Self.generateThumbnail(from: fullImage, size: size)
                continuation.resume(returning: thumb)
            }
        }
        
        // 存入缓存
        if let thumbnail = thumbnail {
            thumbnailCache.setObject(thumbnail, forKey: key)
        }
        
        return thumbnail
    }
    
    // MARK: - 缓存管理
    
    /// 清除所有缓存
    func clearAll() {
        fullSizeCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
    
    /// 从缓存中移除指定图片
    func removeFromCache(fileName: String) {
        let key = fileName as NSString
        fullSizeCache.removeObject(forKey: key)
        
        // 移除各种尺寸的缩略图缓存
        for size in [100, 150, 200, 300] as [CGFloat] {
            thumbnailCache.removeObject(forKey: Self.thumbnailKey(fileName: fileName, size: size))
        }
    }
    
    // MARK: - 私有方法（实例方法）
    
    /// 从磁盘加载图片（使用缓存的目录路径）
    private func loadImageFromDisk(fileName: String) -> UIImage? {
        Self.loadImage(from: photoDirectory, fileName: fileName)
    }
    
    // MARK: - 静态方法（nonisolated，可在 Task.detached 中安全调用）
    
    /// 从磁盘加载图片（静态方法）
    nonisolated private static func loadImage(from directory: URL, fileName: String) -> UIImage? {
        let filePath = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: filePath) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    /// 生成缩略图（静态方法）
    nonisolated private static func generateThumbnail(from image: UIImage, size: CGFloat) -> UIImage {
        let scale = size / max(image.size.width, image.size.height)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// 缩略图缓存 key（静态方法）
    nonisolated private static func thumbnailKey(fileName: String, size: CGFloat) -> NSString {
        "\(fileName)_thumb_\(Int(size))" as NSString
    }
    
    /// 缩略图文件名（静态方法）
    nonisolated private static func thumbnailFileName(for fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return "\(name)_thumb.\(ext)"
    }
}
