import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// 图像处理服务：物体分割与轮廓提取
final class ImageProcessingService {
    static let shared = ImageProcessingService()
    
    private init() {}
    
    /// 提取人物外轮廓（虚线）
    /// - Parameters:
    ///   - image: 原始图片
    ///   - lineColor: 轮廓线颜色
    ///   - lineWidth: 线条粗细（默认 3pt）
    ///   - dashLength: 虚线段长度（默认 10pt）
    ///   - gapLength: 虚线间隔（默认 8pt）
    func extractEdgeOutline(
        from image: UIImage,
        lineColor: UIColor = .cyan,
        lineWidth: CGFloat = 10.0,
        dashLength: CGFloat = 10.0,
        gapLength: CGFloat = 8.0
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 使用 Vision 进行人物分割
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgImageOrientation(from: image),
            options: [:]
        )
        
        do {
            try handler.perform([request])
        } catch {
            print("人物分割失败: \(error)")
            return nil
        }
        
        guard let result = request.results?.first else {
            return nil
        }
        
        // 从蒙版提取轮廓点
        let contourPoints = extractContourPoints(from: result.pixelBuffer, imageSize: image.size)
        
        guard !contourPoints.isEmpty else { return nil }
        
        // 绘制虚线轮廓
        return drawDashedContour(
            points: contourPoints,
            size: image.size,
            color: lineColor,
            lineWidth: lineWidth,
            dashLength: dashLength,
            gapLength: gapLength
        )
    }
    
    /// 获取图片的 CGImage 方向
    private func cgImageOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
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
    
    /// 从分割蒙版提取外轮廓点
    private func extractContourPoints(from pixelBuffer: CVPixelBuffer, imageSize: CGSize) -> [CGPoint] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return [] }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var contourPoints: [CGPoint] = []
        
        // 每隔几个像素采样一次，减少点数
        let sampleStep = 2
        
        for y in stride(from: 1, to: height - 1, by: sampleStep) {
            for x in stride(from: 1, to: width - 1, by: sampleStep) {
                let current = buffer[y * bytesPerRow + x]
                
                // 只在边界处采样（前景和背景的交界）
                if current > 128 {
                    let top = buffer[(y - 1) * bytesPerRow + x]
                    let bottom = buffer[(y + 1) * bytesPerRow + x]
                    let left = buffer[y * bytesPerRow + (x - 1)]
                    let right = buffer[y * bytesPerRow + (x + 1)]
                    
                    if top < 128 || bottom < 128 || left < 128 || right < 128 {
                        // 转换到图片坐标
                        let px = CGFloat(x) / CGFloat(width) * imageSize.width
                        let py = CGFloat(y) / CGFloat(height) * imageSize.height
                        contourPoints.append(CGPoint(x: px, y: py))
                    }
                }
            }
        }
        
        return contourPoints
    }
    
    /// 绘制虚线轮廓
    private func drawDashedContour(
        points: [CGPoint],
        size: CGSize,
        color: UIColor,
        lineWidth: CGFloat,
        dashLength: CGFloat,
        gapLength: CGFloat
    ) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { ctx in
            let context = ctx.cgContext
            
            // 设置虚线样式
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineDash(phase: 0, lengths: [dashLength, gapLength])
            
            // 按位置排序点，尝试连成线
            // 简单方法：用小圆点绘制每个轮廓点
            context.setFillColor(color.cgColor)
            
            for point in points {
                let dotRect = CGRect(
                    x: point.x - lineWidth,
                    y: point.y - lineWidth,
                    width: lineWidth * 2,
                    height: lineWidth * 2
                )
                context.fillEllipse(in: dotRect)
            }
        }
    }
}
