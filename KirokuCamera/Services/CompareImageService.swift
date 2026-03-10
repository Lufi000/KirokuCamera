import Photos
import UIKit

/// 对比图生成与保存：将左右两张图拼成一张并保存到相册。
/// 仅写入系统相册，不写入应用内记录项/照片数据。
enum CompareImageService {
    /// 最大边长（拼图后单边限制）
    private static let maxSide: CGFloat = 1600

    /// 对比布局
    enum CompareLayout {
        case sideBySide   // 左右排列
        case topAndBottom // 上下排列
    }

    /// 单张图片的编辑参数
    struct ImageEditParams {
        let image: UIImage
        let scale: CGFloat
        let angleDegrees: Double
        let offset: CGSize
        let dateLabel: String?
        let labelOffset: CGSize
        let labelFontSize: CGFloat

        init(
            image: UIImage,
            scale: CGFloat = 1.0,
            angleDegrees: Double = 0,
            offset: CGSize = .zero,
            dateLabel: String? = nil,
            labelOffset: CGSize = .zero,
            labelFontSize: CGFloat = 18
        ) {
            self.image = image
            self.scale = scale
            self.angleDegrees = angleDegrees
            self.offset = offset
            self.dateLabel = dateLabel
            self.labelOffset = labelOffset
            self.labelFontSize = labelFontSize
        }
    }

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
    /// 与 CompareView 对比区域一致：左右等宽、中间间距 2、每栏 3:4 显示区域、圆角与背景/文字色与 Kiroku 一致
    private static let spacing: CGFloat = 2
    private static let imageAspectRatio: CGFloat = 3 / 4
    /// 对比视图上单栏约 200pt 宽时用 12pt 圆角；导出图按栏宽同比例放大圆角，否则会几乎看不见
    private static let imageCornerRadiusOnScreen: CGFloat = 12
    private static let typicalCellWidthOnScreen: CGFloat = 200
    private static let labelAreaSpacing: CGFloat = 8
    private static let labelHeight: CGFloat = 28

    /// Kiroku 背景色 #FAEDD8（与 KirokuColors.background 一致）
    private static var kirokuBackground: UIColor {
        UIColor(red: 250/255, green: 237/255, blue: 216/255, alpha: 1)
    }

    /// Kiroku 次要文字色 #636366（与 KirokuColors.textSecondary 一致）
    private static var kirokuTextSecondary: UIColor {
        UIColor(red: 99/255, green: 99/255, blue: 102/255, alpha: 1)
    }

    /// 将 image 按 aspect fit 绘制到 targetRect 内（居中，可能留白）
    private static func drawImageAspectFit(_ image: UIImage, in targetRect: CGRect) {
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(targetRect.width / size.width, targetRect.height / size.height)
        let drawW = size.width * scale
        let drawH = size.height * scale
        let drawX = targetRect.minX + (targetRect.width - drawW) / 2
        let drawY = targetRect.minY + (targetRect.height - drawH) / 2
        image.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
    }

    /// 将左右两张图拼成一张，视觉与 CompareView 对比区域一致：背景、等宽两栏、3:4、圆角 12、aspect fit、日期样式一致
    /// 使用固定 2x scale 生成图片，避免 UIScreen.main 在 iOS 26+ 的弃用
    static func composite(left: UIImage, right: UIImage, leftLabel: String?, rightLabel: String?) -> UIImage? {
        let renderScale: CGFloat = 2
        let logicalWidth: CGFloat = maxSide
        let cellWidth = (logicalWidth - spacing) / 2
        let imageAreaHeight = cellWidth / imageAspectRatio
        let cornerRadius = cellWidth * (imageCornerRadiusOnScreen / typicalCellWidthOnScreen)

        let hasLabels = (leftLabel.map { !$0.isEmpty } ?? false) || (rightLabel.map { !$0.isEmpty } ?? false)
        let totalHeight = imageAreaHeight + (hasLabels ? labelAreaSpacing + labelHeight : 0)
        let totalWidth = logicalWidth

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight), format: format)
        let image = renderer.image { ctx in
            let cgContext = ctx.cgContext
            let rect = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: totalHeight))

            kirokuBackground.setFill()
            ctx.fill(rect)

            let leftImageRect = CGRect(x: 0, y: 0, width: cellWidth, height: imageAreaHeight)
            let rightImageRect = CGRect(x: cellWidth + spacing, y: 0, width: cellWidth, height: imageAreaHeight)

            cgContext.saveGState()
            UIBezierPath(roundedRect: leftImageRect, cornerRadius: cornerRadius).addClip()
            drawImageAspectFit(left, in: leftImageRect)
            cgContext.restoreGState()

            cgContext.saveGState()
            UIBezierPath(roundedRect: rightImageRect, cornerRadius: cornerRadius).addClip()
            drawImageAspectFit(right, in: rightImageRect)
            cgContext.restoreGState()

            if hasLabels {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: kirokuTextSecondary
                ]
                let labelY = imageAreaHeight + labelAreaSpacing
                if let leftLabel = leftLabel, !leftLabel.isEmpty {
                    (leftLabel as NSString).draw(at: CGPoint(x: 4, y: labelY), withAttributes: attr)
                }
                if let rightLabel = rightLabel, !rightLabel.isEmpty {
                    (rightLabel as NSString).draw(at: CGPoint(x: cellWidth + spacing + 4, y: labelY), withAttributes: attr)
                }
            }
        }
        return image
    }

    /// 将两张图按编辑参数合成对比图，日期标签叠加在图片上
    /// - Parameters:
    ///   - first: 第一张图的编辑参数（上下布局时为上图，左右布局时为左图）
    ///   - second: 第二张图的编辑参数（上下布局时为下图，左右布局时为右图）
    ///   - layout: 布局方式
    ///   - showDateLabels: 是否显示日期标签
    /// - Returns: 合成后的对比图
    static func compositeWithEdits(
        first: ImageEditParams,
        second: ImageEditParams,
        layout: CompareLayout,
        showDateLabels: Bool
    ) -> UIImage? {
        let renderScale: CGFloat = 2
        let canvasAspectRatio: CGFloat = 3.0 / 4.0

        // 计算画布和单元格尺寸
        let canvasWidth: CGFloat
        let canvasHeight: CGFloat
        let cellSize: CGSize

        switch layout {
        case .sideBySide:
            canvasWidth = maxSide
            canvasHeight = maxSide / canvasAspectRatio
            let contentW = canvasWidth - canvasEdgePadding * 2
            let contentH = canvasHeight - canvasEdgePadding * 2
            cellSize = CGSize(width: (contentW - spacing) / 2, height: contentH)
        case .topAndBottom:
            canvasWidth = maxSide
            canvasHeight = maxSide / canvasAspectRatio
            let contentW = canvasWidth - canvasEdgePadding * 2
            let contentH = canvasHeight - canvasEdgePadding * 2
            cellSize = CGSize(width: contentW, height: (contentH - spacing) / 2)
        }

        let cornerRadius = cellSize.width * (imageCornerRadiusOnScreen / typicalCellWidthOnScreen)

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight), format: format)

        let image = renderer.image { ctx in
            let cgContext = ctx.cgContext

            // 填充背景
            kirokuBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: canvasWidth, height: canvasHeight)))

            // 计算两个单元格的位置
            let firstRect: CGRect
            let secondRect: CGRect

            switch layout {
            case .sideBySide:
                firstRect = CGRect(x: canvasEdgePadding, y: canvasEdgePadding, width: cellSize.width, height: cellSize.height)
                secondRect = CGRect(x: canvasEdgePadding + cellSize.width + spacing, y: canvasEdgePadding, width: cellSize.width, height: cellSize.height)
            case .topAndBottom:
                firstRect = CGRect(x: canvasEdgePadding, y: canvasEdgePadding, width: cellSize.width, height: cellSize.height)
                secondRect = CGRect(x: canvasEdgePadding, y: canvasEdgePadding + cellSize.height + spacing, width: cellSize.width, height: cellSize.height)
            }

            // 绘制第一张图
            drawEditedImage(first, in: firstRect, cornerRadius: cornerRadius, cgContext: cgContext, showDateLabel: showDateLabels)

            // 绘制第二张图
            drawEditedImage(second, in: secondRect, cornerRadius: cornerRadius, cgContext: cgContext, showDateLabel: showDateLabels)
        }

        return image
    }

    /// 绘制带编辑效果的图片到指定区域
    private static func drawEditedImage(
        _ params: ImageEditParams,
        in rect: CGRect,
        cornerRadius: CGFloat,
        cgContext: CGContext,
        showDateLabel: Bool
    ) {
        cgContext.saveGState()

        // 裁剪圆角区域
        let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        clipPath.addClip()

        // 填充黑色背景
        UIColor.black.setFill()
        UIRectFill(rect)

        // 计算屏幕到导出画布的缩放因子
        let scaleFactor = rect.width / typicalCellWidthOnScreen

        // 计算图片的原始尺寸和填充比例
        let imageSize = params.image.size
        let fillScale = max(rect.width / imageSize.width, rect.height / imageSize.height)

        // 应用用户的缩放
        let totalScale = fillScale * params.scale

        // 计算居中后的绘制尺寸
        let drawWidth = imageSize.width * totalScale
        let drawHeight = imageSize.height * totalScale

        // 计算居中位置（offset 需要按比例缩放）
        let centerX = rect.midX + params.offset.width * scaleFactor
        let centerY = rect.midY + params.offset.height * scaleFactor

        // 保存当前状态用于旋转
        cgContext.saveGState()

        // 移动到中心点，旋转，再移回
        cgContext.translateBy(x: centerX, y: centerY)
        cgContext.rotate(by: CGFloat(params.angleDegrees * .pi / 180))
        cgContext.translateBy(x: -centerX, y: -centerY)

        // 绘制图片
        let drawRect = CGRect(
            x: centerX - drawWidth / 2,
            y: centerY - drawHeight / 2,
            width: drawWidth,
            height: drawHeight
        )
        params.image.draw(in: drawRect)

        cgContext.restoreGState()

        // 绘制日期标签（如果有）
        if showDateLabel, let label = params.dateLabel, !label.isEmpty {
            let scaleFactor = rect.width / typicalCellWidthOnScreen
            let fontSize = params.labelFontSize * scaleFactor
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 2 * scaleFactor
            shadow.shadowOffset = CGSize(width: 0, height: 1 * scaleFactor)

            let attr: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .shadow: shadow
            ]

            let attrString = NSAttributedString(string: label, attributes: attr)
            let textSize = attrString.size()

            // 默认位置：底部居中，距底 24pt（按比例缩放）
            let defaultY = rect.maxY - 24 * scaleFactor
            let labelX = rect.midX + params.labelOffset.width * scaleFactor - textSize.width / 2
            let labelY = defaultY + params.labelOffset.height * scaleFactor - textSize.height / 2

            attrString.draw(at: CGPoint(x: labelX, y: labelY))
        }

        cgContext.restoreGState()
    }

    /// 画布边距
    private static let canvasEdgePadding: CGFloat = 8

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
                        completion(false, error?.localizedDescription ?? String(localized: "保存失败"))
                    }
                }
            }
        }
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    guard status == .authorized || status == .limited else {
                        completion(false, String(localized: "未获得保存到相册的权限"))
                        return
                    }
                    doSave()
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        completion(false, String(localized: "未获得保存到相册的权限"))
                        return
                    }
                    doSave()
                }
            }
        }
    }
}
