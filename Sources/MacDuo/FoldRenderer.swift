import CoreImage
import FoldCore

/// A continuous inverse warp avoids seams between strips and keeps the desktop
/// full height. Metal samples progressively softer textures along the curve.
final class FoldRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private static let kernel: CIKernel? = {
        let source = """
        #include <CoreImage/CoreImage.h>
        using namespace metal;
        namespace coreimage {
        [[ stitchable ]] float4 curvedDesktop(sampler sharp, sampler soft, sampler blurred,
                             float2 size, float progress, destination dest) {
            float2 uv = dest.coord() / size;
            float amount = abs(progress);
            float depth = progress >= 0.0 ? uv.y : 1.0 - uv.y;
            float width = 1.0 - 0.24 * amount * depth * depth;
            float2 sourceUV = float2((uv.x - 0.5) / width + 0.5,
                uv.y + progress * 0.32 * uv.y * (1.0 - uv.y));
            float2 point = clamp(sourceUV, float2(0.0), float2(1.0)) * size;
            float focus = amount * smoothstep(0.08, 0.88, depth);
            float4 a = sharp.sample(sharp.transform(point));
            float4 b = soft.sample(soft.transform(point));
            float4 c = blurred.sample(blurred.transform(point));
            float4 content = mix(mix(a, b, smoothstep(0.0, 0.45, focus)),
                                 c, smoothstep(0.35, 1.0, focus));
            // A narrow soft rim, with no duplicate desktop behind the surface.
            float edge = min(sourceUV.x, 1.0 - sourceUV.x);
            float feather = max(1.0 / size.x, 0.018 * amount);
            float coverage = smoothstep(0.0, feather, edge);
            float shade = 1.0 - 0.10 * amount * depth * depth;
            return mix(float4(0.025, 0.028, 0.035, 1.0),
                       float4(content.rgb * shade, 1.0), coverage);
        }
        }
        """
        do { return try CIKernel.kernels(withMetalString: source).first }
        catch {
            NSLog("MacDuo: unable to compile curved desktop kernel: %@", String(describing: error))
            return nil
        }
    }()

    func render(_ image: CGImage, progress: Double) -> CGImage? {
        let pose = FoldPose(progress: progress)
        guard pose.intensity >= 0.001 else { return image }
        guard let kernel = Self.kernel else { return nil }
        let scale = min(1, 1920 / CGFloat(image.width))
        let source = CIImage(cgImage: image)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = source.extent
        let radius = extent.width / 1920
        let clamped = source.clampedToExtent()
        let soft = clamped.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 5 * radius]).cropped(to: extent)
        let blurred = clamped.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 24 * radius]).cropped(to: extent)
        guard let output = kernel.apply(extent: extent, roiCallback: { _, _ in extent.insetBy(dx: -80, dy: -80) },
            arguments: [clamped, soft, blurred, CIVector(x: extent.width, y: extent.height), pose.progress]) else { return nil }
        return context.createCGImage(output, from: extent)
    }
}
