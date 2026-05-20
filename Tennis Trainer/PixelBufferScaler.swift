import Foundation
import CoreImage
import CoreVideo
import ImageIO

final class PixelBufferScaler {
    static let shared = PixelBufferScaler()

    private let ciContext: CIContext

    private init() {
        ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    /// Resize with aspect-fill (no letterboxing) and center-crop to exact target size.
    /// - Parameters:
    ///   - pixelBuffer: Source BGRA/RGBA pixel buffer.
    ///   - width: Target width in pixels.
    ///   - height: Target height in pixels.
    /// - Returns: A BGRA CVPixelBuffer of the requested size, or nil on failure.
    func resizeAspectFill(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        let srcW = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let srcH = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let dstW = CGFloat(width)
        let dstH = CGFloat(height)

        guard srcW > 0, srcH > 0, dstW > 0, dstH > 0 else { return nil }

        let scale = max(dstW / srcW, dstH / srcH)

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // High-quality scaler
        let lanczos = CIFilter(name: "CILanczosScaleTransform")
        lanczos?.setValue(ciImage, forKey: kCIInputImageKey)
        lanczos?.setValue(scale, forKey: kCIInputScaleKey)
        lanczos?.setValue(1.0, forKey: kCIInputAspectRatioKey)
        guard var scaled = lanczos?.outputImage else { return nil }

        // Center-crop to requested size (avoid letterboxing)
        let scaledW = srcW * scale
        let scaledH = srcH * scale
        let originX = (scaledW - dstW) * 0.5
        let originY = (scaledH - dstH) * 0.5
        let cropRect = CGRect(x: originX, y: originY, width: dstW, height: dstH)
        scaled = scaled
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -originX, y: -originY))

        // Allocate destination pixel buffer (BGRA)
        var dstPB: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &dstPB)
        if status != kCVReturnSuccess { return nil }
        guard let outPB = dstPB else { return nil }

        ciContext.render(scaled, to: outPB)
        return outPB
    }

    /// Resize with aspect-fit and black padding so the full source frame remains visible.
    func resizeAspectFit(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        let srcW = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let srcH = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let dstW = CGFloat(width)
        let dstH = CGFloat(height)

        guard srcW > 0, srcH > 0, dstW > 0, dstH > 0 else { return nil }

        let scale = min(dstW / srcW, dstH / srcH)
        let scaledW = srcW * scale
        let scaledH = srcH * scale
        let padX = (dstW - scaledW) * 0.5
        let padY = (dstH - scaledH) * 0.5

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let lanczos = CIFilter(name: "CILanczosScaleTransform")
        lanczos?.setValue(ciImage, forKey: kCIInputImageKey)
        lanczos?.setValue(scale, forKey: kCIInputScaleKey)
        lanczos?.setValue(1.0, forKey: kCIInputAspectRatioKey)
        guard let scaled = lanczos?.outputImage else { return nil }

        let translated = scaled.transformed(by: CGAffineTransform(translationX: padX, y: padY))
        let outputRect = CGRect(x: 0, y: 0, width: dstW, height: dstH)
        let background = CIImage(color: CIColor.black).cropped(to: outputRect)
        let composited = translated
            .composited(over: background)
            .cropped(to: outputRect)

        guard let outPB = makePixelBuffer(width: width, height: height) else { return nil }
        ciContext.render(composited, to: outPB)
        return outPB
    }

    /// Apply display orientation to a frame before downstream analysis.
    func copyApplyingOrientation(
        _ pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> CVPixelBuffer? {
        guard orientation != .up else { return pixelBuffer }

        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let extent = oriented.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let translated = oriented.transformed(
            by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
        )
        let width = Int(extent.width)
        let height = Int(extent.height)

        guard let outPB = makePixelBuffer(width: width, height: height) else { return nil }
        ciContext.render(translated, to: outPB)
        return outPB
    }

    private func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var dstPB: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &dstPB)
        if status != kCVReturnSuccess { return nil }
        return dstPB
    }
}
