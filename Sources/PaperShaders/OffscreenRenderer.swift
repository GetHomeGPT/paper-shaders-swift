import CoreGraphics
import Foundation
import ImageIO
import Metal
import simd
import UniformTypeIdentifiers

/// Renders one deterministic frame of a shader into a CPU-readable texture,
/// for golden-image parity tests and tooling.
public final class OffscreenRenderer {
  /// Device.
  public let device: MTLDevice
  private let renderer: ShaderRenderer

  /// Creates an instance.
  public init(descriptor: ShaderDescriptor, device: MTLDevice? = nil) throws {
    renderer = try ShaderRenderer(descriptor: descriptor, device: device)
    self.device = renderer.device
  }

  /// Renders `image` in place of the bundled sample of an image shader
  /// (`usesImageTexture`), or the sample again for `nil`.
  public func setImage(_ image: CGImage?) throws {
    try renderer.setImage(image)
  }

  /// `frame` is in milliseconds, like the upstream prop (`u_time` = frame × 0.001).
  public func render(
    width: Int,
    height: Int,
    frame: Double,
    pixelRatio: Float = 1,
    sizing: ShaderSizingParams,
    uniforms: [UniformValue]
  ) throws -> MTLTexture {
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm,
      width: width,
      height: height,
      mipmapped: false
    )
    textureDescriptor.usage = [.renderTarget, .shaderRead]
    textureDescriptor.storageMode = .shared
    guard let target = device.makeTexture(descriptor: textureDescriptor) else {
      throw ShaderError.setupFailed
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = target
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    guard let commandBuffer = renderer.commandQueue.makeCommandBuffer() else {
      throw ShaderError.setupFailed
    }
    renderer.encode(
      commandBuffer: commandBuffer,
      renderPassDescriptor: renderPassDescriptor,
      time: Float(frame * 0.001),
      resolution: SIMD2(Float(width), Float(height)),
      pixelRatio: pixelRatio,
      sizing: sizing,
      uniforms: uniforms
    )
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    if let error = commandBuffer.error {
      throw error
    }
    return target
  }

  /// Returns the texture contents as RGBA bytes (top row first).
  public static func rgbaBytes(of texture: MTLTexture) -> [UInt8] {
    let width = texture.width
    let height = texture.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { raw in
      texture.getBytes(
        raw.baseAddress!,
        bytesPerRow: width * 4,
        from: MTLRegionMake2D(0, 0, width, height),
        mipmapLevel: 0
      )
    }
    // bgra8Unorm → RGBA
    for i in stride(from: 0, to: bytes.count, by: 4) {
      bytes.swapAt(i, i + 2)
    }
    return bytes
  }

  /// Writes the texture as an opaque RGB PNG, bytes verbatim (no color
  /// space conversion), matching how the WebGL goldens were captured.
  ///
  /// `background`: source-over composites the premultiplied output onto that
  /// RGB color first. The goldens are element screenshots of a transparent
  /// canvas over the harness page, so they include the white page behind
  /// any non-opaque pixels (no-op for opaque renders).
  public static func writePNG(
    _ texture: MTLTexture,
    to url: URL,
    background: SIMD3<Float>? = nil
  ) throws {
    let width = texture.width
    let height = texture.height
    var rgba = rgbaBytes(of: texture)
    if let background {
      for i in stride(from: 0, to: rgba.count, by: 4) {
        let inverseAlpha = 1 - Float(rgba[i + 3]) / 255
        rgba[i] = UInt8(clamping: Int((Float(rgba[i]) + background.x * 255 * inverseAlpha).rounded()))
        rgba[i + 1] = UInt8(clamping: Int((Float(rgba[i + 1]) + background.y * 255 * inverseAlpha).rounded()))
        rgba[i + 2] = UInt8(clamping: Int((Float(rgba[i + 2]) + background.z * 255 * inverseAlpha).rounded()))
        rgba[i + 3] = 255
      }
    }

    guard let provider = CGDataProvider(data: Data(rgba) as CFData),
          let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
          ),
          let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
          )
    else { throw ShaderError.setupFailed }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw ShaderError.setupFailed
    }
  }
}
