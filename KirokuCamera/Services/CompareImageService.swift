import Photos
import UIKit

/// 对比图生成与保存：将左右两张图拼成一张并保存到相册。
/// 仅写入系统相册，不写入应用内记录项/照片数据。
enum CompareImageService {
    /// 最大边长（拼图后单边限制）
    private static let maxSide: CGFloat = 1600

    /// 对图片应用缩放、旋转、平移（用于对比图编辑后导出）
    static func transformImage(_ image: UIImage, scale: CGFloat, angleDegrees: Double, offset: CGSize = .zero) -> UIImage? {
        guard scale > 0 else { return nil }
        let size = image.size
        let scaledW = size.width * scale
        let scaledH = size.height * scale
        let scaledSize = CGSize(width: scaledW, height: scaledH)

        guard let scaledImage = drawImage(image, in: CGRect(origin: .zero, size: scaledSize), outputSize: scaledSize) else { return nil }

        let angle = angleDegrees
        let radians = angle * .pi / 180
        let rotatedSize: CGSize
        let rotatedImage: UIImage?

        if abs(angle).remainder(dividingBy: 360) == 0 {
            rotatedSize = scaledSize
            rotatedImage = scaledImage
        } else {
            rotatedSize = rotatedBounds(width: scaledW, height: scaledH, radians: radians)
            let ctxTransform = CGAffineTransform(translationX: rotatedSize.width / 2, y: rotatedSize.height / 2)
                .rotated(by: CGFloat(radians))
                .translatedBy(x: -scaledW / 2, y: -scaledH / 2)
            rotatedImage = drawImage(scaledImage, in: CGRect(origin: .zero, size: scaledSize), outputSize: rotatedSize, contextTransform: ctxTransform)
        }

        guard let rotated = rotatedImage else { return nil }

        if offset == .zero {
            return rotated
        }
        let translate = CGAffineTransform(translationX: offset.width, y: offset.height)
        return drawImage(rotated, in: CGRect(origin: .zero, size: rotatedSize), outputSize: rotatedSize, contextTransform: translate)
    }

    private static func drawImage(
        _ image: UIImage,
        in rect: CGRect,
        outputSize: CGSize,
        contextTransform: CGAffineTransform = .identity
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            cgContext.concatenate(contextTransform)
            image.draw(in: rect)
        }
    }

    private static func rotatedBounds(width: CGFloat, height: CGFloat, radians: Double) -> CGSize {
        let c = cos(abs(radians)), s = sin(abs(radians))
        let w = width * c + height * s
        let h = width * s + height * c
        return CGSize(width: abs(w), height: abs(h))
    }
    private static let gap: CGFloat = 4
    private static let labelHeight: CGFloat = 28

    /// 将左右两张图拼成一张（等高分屏），可选底部日期文案
    /// 使用固定 2x scale 生成图片，避免 UIScreen.main 在 iOS 26+ 的弃用
    static func composite(left: UIImage, right: UIImage, leftLabel: String?, rightLabel: String?) -> UIImage? {
        let scale: CGFloat = 2
        let maxPixels = maxSide * scale

        func scaledSize(for image: UIImage) -> CGSize {
            let w = image.size.width * image.scale
            let h = image.size.height * image.scale
            guard w > 0, h > 0 else { return image.size }
            if max(w, h) <= maxPixels { return CGSize(width: w / scale, height: h / scale) }
            let r = maxPixels / max(w, h)
            return CGSize(width: (w * r) / scale, height: (h * r) / scale)
        }

        let leftSize = scaledSize(for: left)
        let rightSize = scaledSize(for: right)
        let height = max(leftSize.height, rightSize.height)
        let hasLabels = (leftLabel.map { !$0.isEmpty } ?? false) || (rightLabel.map { !$0.isEmpty } ?? false)
        let totalHeight = height + (hasLabels ? labelHeight : 0)
        let totalWidth = leftSize.width + gap + rightSize.width

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight), format: format)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight))
            UIColor.white.setFill()
            ctx.fill(rect)
            left.draw(in: CGRect(x: 0, y: 0, width: leftSize.width, height: height))
            right.draw(in: CGRect(x: leftSize.width + gap, y: 0, width: rightSize.width, height: height))
            if hasLabels {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.darkGray
                ]
                if let leftLabel = leftLabel, !leftLabel.isEmpty {
                    (leftLabel as NSString).draw(at: CGPoint(x: 4, y: height + 4), withAttributes: attr)
                }
                if let rightLabel = rightLabel, !rightLabel.isEmpty {
                    (rightLabel as NSString).draw(at: CGPoint(x: leftSize.width + gap + 4, y: height + 4), withAttributes: attr)
                }
            }
        }
        return image
    }

    /// 请求相册写入权限并保存图片，完成后在主线程调用 completion(success, errorMessage)
    static func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        func doSave() {
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, nil)
                    } else {
                        completion(false, error?.localizedDescription ?? "保存失败")
                    }
                }
            }
        }
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    guard status == .authorized || status == .limited else {
                        completion(false, "未获得保存到相册的权限")
                        return
                    }
                    doSave()
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        completion(false, "未获得保存到相册的权限")
                        return
                    }
                    doSave()
                }
            }
        }
    }
}
