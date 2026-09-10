import CoreImage
import FoldCore

/// Hinge-based glass projection. Core Image keeps the
/// perspective, distance-based diffusion and silhouette in one seamless pass.
final class FoldRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private static let kernel: CIKernel? = {
        let source = """
        #include <CoreImage/CoreImage.h>
        using namespace metal;
        namespace coreimage {
        [[ stitchable ]] float4 hingedDesktop(sampler sharp, sampler soft, sampler blurred,
                             float2 size, float verticalScale, float depthScale,
                             float amount, destination dest) {
            float2 uv = dest.coord() / size;
            // Intersect the ray from a stationary eye through the rotating glass
            // with the desktop plane. Core Image's origin is at the bottom hinge.
            float span = 1.0 - uv.y * depthScale;
            float2 sourceUV = float2((uv.x - 0.5) / span + 0.5,
                (uv.y * verticalScale - 0.5 * uv.y * depthScale) / span);
            float2 point = clamp(sourceUV, float2(0.0), float2(1.0)) * size;
            float gap = abs(depthScale) * 2.4 * uv.y;
            float focus = clamp(gap / 0.76604444, 0.0, 1.0);
            float4 a = sharp.sample(sharp.transform(point));
            float4 b = soft.sample(soft.transform(point));
            float4 c = blurred.sample(blurred.transform(point));
            float4 content = mix(mix(a, b, smoothstep(0.0, 0.4, focus)),
                                 c, smoothstep(0.2, 1.0, focus));
            // Let diffusion soften all four borders without stretching edge pixels
            // into the background. Keep the hinge crisp and eliminate a hard rim.
            float2 edge = min(sourceUV, 1.0 - sourceUV) * size;
            float feather = max(0.5, 28.0 * size.y / 1200.0 * focus);
            float coverage = smoothstep(-feather, feather, min(edge.x, edge.y));
            coverage = mix(1.0, coverage, smoothstep(0.0, 0.02, amount));
            float shade = exp(-0.85 * gap);
            return float4(content.rgb * shade * coverage, 1.0);
        }
        }
        """
        do { return try CIKernel.kernels(withMetalString: source).first }
        catch {
            NSLog("MacDuo: unable to compile hinged desktop kernel: %@", String(describing: error))
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
        let radius = extent.height / 1200
        let clamped = source.clampedToExtent()
        let soft = clamped.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 6 * radius]).cropped(to: extent)
        let blurred = clamped.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 28 * radius]).cropped(to: extent)
        guard let output = kernel.apply(extent: extent, roiCallback: { _, _ in extent.insetBy(dx: -80, dy: -80) },
            arguments: [clamped, soft, blurred, CIVector(x: extent.width, y: extent.height), pose.verticalScale, pose.depthScale, pose.intensity]) else { return nil }
        return context.createCGImage(output, from: extent)
    }
}
