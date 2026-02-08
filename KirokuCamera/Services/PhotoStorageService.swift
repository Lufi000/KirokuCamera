import CoreImage
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// 照片存储服务：管理照片文件的本地存储
final class PhotoStorageService {
    static let shared = PhotoStorageService()
    private let maxPhotoDimension: CGFloat = 4096
    private let saveTimeoutSeconds: UInt64 = 20
    
    private init() {
        createPhotoDirectoryIfNeeded()
    }
    
    /// 照片存储目录
    var photoDirectory: URL {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return documentsPath.appendingPathComponent("Photos", isDirectory: true)
    }
    
    /// 创建照片目录（如果不存在）
    private func createPhotoDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: photoDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: photoDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                print("创建照片目录失败: \(error)")
            }
        }
    }
    
    /// 保存照片到本地（同时生成缩略图）
    /// - Parameter image: 要保存的图片
    /// - Returns: 保存后的文件名，失败返回 nil
    func savePhoto(_ image: UIImage) -> String? {
        Self.savePhoto(
            image,
            directory: photoDirectory,
            maxDimension: maxPhotoDimension
        )
    }

    /// 异步保存照片到本地（避免阻塞主线程）
    /// 必须在主线程调用：会同步从 UIImage 提取 CGImage，再在后台编码写入；不可在 await 后持有 UIImage。
    @MainActor
    func savePhotoAsync(_ image: UIImage) async -> String? {
        // 同步提取，不跨 await 持有 image，避免 EXC_BAD_ACCESS（image 被释放）
        guard let cgImage = Self.makeCGImage(from: image) else { return nil }
        let orientation = Self.cgImagePropertyOrientation(from: image.imageOrientation)
        return await savePhotoAsync(cgImage: cgImage, orientation: orientation)
    }

    /// 异步保存（仅接受 CGImage，供后台安全使用）
    func savePhotoAsync(cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> String? {
        let directory = photoDirectory
        let maxDimension = maxPhotoDimension
        let timeout = saveTimeoutSeconds

        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await Task.detached(priority: .userInitiated) {
                    Self.savePhoto(
                        cgImage: cgImage,
                        orientation: orientation,
                        directory: directory,
                        maxDimension: maxDimension
                    )
                }.value
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeout * 1_000_000_000)
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    /// 预处理图片（超大图缩放，减少保存时间与存储占用）
    nonisolated private static func prepareImageForSaving(_ cgImage: CGImage, maxDimension: CGFloat) -> CGImage {
        scaleCGImage(cgImage, maxDimension: maxDimension)
    }
    
    /// 生成并保存缩略图（静态方法，可在后台线程调用）
    nonisolated private static func saveThumbnail(
        for cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        uuid: String,
        directory: URL
    ) {
        let thumbnailSize: CGFloat = 300
        let thumbnail = scaleCGImage(cgImage, maxDimension: thumbnailSize)
        
        let thumbFileName = "\(uuid)_thumb.jpg"
        let thumbPath = directory.appendingPathComponent(thumbFileName)
        
        // 缩略图用较低质量，节省空间
        if let thumbData = encodeJpeg(thumbnail, orientation: orientation, quality: 0.6) {
            try? thumbData.write(to: thumbPath)
        }
    }
    
    /// 使用 ImageIO 编码 JPEG，避免 UIKit 在后台线程卡住
    nonisolated private static func encodeJpeg(
        _ cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        quality: CGFloat
    ) -> Data? {
        let data = NSMutableData()
        let identifier = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, identifier, 1, nil) else {
            return nil
        }
        
        let options = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: orientation.rawValue
        ] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
    
    /// 保存照片（静态实现，仅接受 CGImage，供后台线程安全调用）
    nonisolated private static func savePhoto(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        directory: URL,
        maxDimension: CGFloat
    ) -> String? {
        let uuid = UUID().uuidString
        let fileName = "\(uuid).jpg"
        let filePath = directory.appendingPathComponent(fileName)
        let preparedImage = prepareImageForSaving(cgImage, maxDimension: maxDimension)

        guard let data = encodeJpeg(preparedImage, orientation: orientation, quality: 0.8) else {
            print("图片转换失败")
            return nil
        }

        do {
            try data.write(to: filePath)
            DispatchQueue.global(qos: .utility).async {
                Self.saveThumbnail(
                    for: preparedImage,
                    orientation: orientation,
                    uuid: uuid,
                    directory: directory
                )
            }
            return fileName
        } catch {
            print("保存照片失败: \(error)")
            return nil
        }
    }

    /// 保存照片（UIImage 版本，仅用于同步接口，必须在主线程调用）
    nonisolated private static func savePhoto(
        _ image: UIImage,
        directory: URL,
        maxDimension: CGFloat
    ) -> String? {
        guard let baseCG = makeCGImage(from: image) else {
            print("获取CGImage失败")
            return nil
        }
        let orientation = cgImagePropertyOrientation(from: image.imageOrientation)
        return savePhoto(cgImage: baseCG, orientation: orientation, directory: directory, maxDimension: maxDimension)
    }
    
    /// 使用 CoreGraphics 缩放图片，避免 UIKit 后台绘制卡顿
    nonisolated private static func scaleCGImage(_ cgImage: CGImage, maxDimension: CGFloat) -> CGImage {
        let width = cgImage.width
        let height = cgImage.height
        let maxPixel = max(width, height)
        
        guard CGFloat(maxPixel) > maxDimension else { return cgImage }
        
        let scale = maxDimension / CGFloat(maxPixel)
        let newWidth = max(1, Int(CGFloat(width) * scale))
        let newHeight = max(1, Int(CGFloat(height) * scale))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
        
        guard let drawContext = context else { return cgImage }
        drawContext.interpolationQuality = .high
        drawContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return drawContext.makeImage() ?? cgImage
    }

    /// 从 UIImage 安全获取 CGImage（避免后台线程使用 UIKit 编码）
    nonisolated private static func makeCGImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }
        
        if let ciImage = image.ciImage {
            let context = CIContext(options: nil)
            return context.createCGImage(ciImage, from: ciImage.extent)
        }
        
        return nil
    }
    
    /// UIImage 方向转换为 CGImagePropertyOrientation
    nonisolated private static func cgImagePropertyOrientation(
        from orientation: UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
    
    /// 删除照片文件（包括缩略图）
    /// - Parameter fileName: 文件名
    func deletePhoto(fileName: String) {
        let filePath = photoDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: filePath)
        } catch {
            print("删除照片失败: \(error)")
        }
        
        // 同时删除缩略图
        let thumbFileName = thumbnailFileName(for: fileName)
        let thumbPath = photoDirectory.appendingPathComponent(thumbFileName)
        try? FileManager.default.removeItem(at: thumbPath)
        
        // 从缓存中移除
        ImageCacheService.shared.removeFromCache(fileName: fileName)
    }
    
    /// 获取缩略图文件名
    private func thumbnailFileName(for fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return "\(name)_thumb.\(ext)"
    }
    
    /// 加载照片
    /// - Parameter fileName: 文件名
    /// - Returns: 图片，失败返回 nil
    func loadPhoto(fileName: String) -> UIImage? {
        let filePath = photoDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: filePath) else {
            return nil
        }
        return UIImage(data: data)
    }
}
