import CoreGraphics
import Foundation
import ImageIO
import Metal
import MetalKit
import simd

/// Options for shader error.
public enum ShaderError: Error {
  case noMetalDevice
  case setupFailed
  case missingResource(String)
}

/// Owns the compiled pipeline for one shader and encodes draw calls.
/// Shared by the on-screen view and the offscreen renderer.
final class ShaderRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let pipelineState: MTLRenderPipelineState
  let maskPipelineState: MTLRenderPipelineState?
  let sampler: MTLSamplerState
  private(set) var noiseTexture: MTLTexture?
  private(set) var imageTexture: MTLTexture?

  init(
    descriptor: ShaderDescriptor,
    device explicitDevice: MTLDevice? = nil,
    mathMode: ShaderMathMode = .precise
  ) throws {
    guard let device = explicitDevice ?? MTLCreateSystemDefaultDevice() else {
      throw ShaderError.noMetalDevice
    }
    self.device = device
    guard let queue = device.makeCommandQueue() else { throw ShaderError.setupFailed }
    commandQueue = queue

    let compileOptions = MTLCompileOptions()
    switch mathMode {
    case .precise:
      // Fast math lets the compiler contract/reassociate float ops and use
      // approximate sin/cos, which decorrelates hash-based noise from the
      // WebGL reference at high frequencies (perlin-noise octaves). Both
      // knobs matter: `.safe` alone (or `.relaxed`) still diverges.
      if #available(macOS 15.0, iOS 18.0, *) {
        compileOptions.mathMode = .safe
        compileOptions.mathFloatingPointFunctions = .precise
      } else {
        compileOptions.fastMathEnabled = false
      }
    case .fast:
      compileOptions.fastMathEnabled = true
    }
    let library = try device.makeLibrary(source: MSL.common + descriptor.fragmentSource, options: compileOptions)
    guard let vertexFunction = library.makeFunction(name: "ps_vertex"),
          let fragmentFunction = library.makeFunction(name: "ps_fragment")
    else { throw ShaderError.setupFailed }

    pipelineState = try Self.makePipelineState(
      device: device,
      vertexFunction: vertexFunction,
      fragmentFunction: fragmentFunction,
      pixelFormat: .bgra8Unorm
    )
    if let maskFragmentFunctionName = descriptor.maskFragmentFunctionName {
      guard let maskFragmentFunction = library.makeFunction(name: maskFragmentFunctionName) else {
        throw ShaderError.setupFailed
      }
      maskPipelineState = try Self.makePipelineState(
        device: device,
        vertexFunction: vertexFunction,
        fragmentFunction: maskFragmentFunction,
        pixelFormat: .rgba16Float
      )
    } else {
      maskPipelineState = nil
    }

    // Upstream texture parameters: CLAMP_TO_EDGE + LINEAR. Image shaders
    // can opt into mipmaps when the React source requests them.
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    if descriptor.usesImageMipmaps {
      samplerDescriptor.mipFilter = .linear
    }
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .clampToEdge
    guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
      throw ShaderError.setupFailed
    }
    self.sampler = sampler

    if descriptor.usesNoiseTexture {
      guard let url = Bundle.module.url(forResource: "noise", withExtension: "png") else {
        throw ShaderError.missingResource("noise.png")
      }
      noiseTexture = try Self.loadTexture(url: url, device: device)
    }
    if descriptor.usesImageTexture {
      let resourceName = descriptor.imageResourceName
      guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
        throw ShaderError.missingResource("\(resourceName).png")
      }
      imageTexture = try Self.loadTextureWithTextureLoader(
        url: url,
        device: device,
        generateMipmaps: descriptor.usesImageMipmaps
      )
    }
  }

  private static func makePipelineState(
    device: MTLDevice,
    vertexFunction: MTLFunction,
    fragmentFunction: MTLFunction,
    pixelFormat: MTLPixelFormat
  ) throws -> MTLRenderPipelineState {
    let pipeline = MTLRenderPipelineDescriptor()
    pipeline.vertexFunction = vertexFunction
    pipeline.fragmentFunction = fragmentFunction
    pipeline.colorAttachments[0].pixelFormat = pixelFormat
    return try device.makeRenderPipelineState(descriptor: pipeline)
  }

  /// Decodes an image to raw RGBA8 (top row first, no color conversion —
  /// matching the WebGL `texImage2D` upload) and creates a linear texture.
  /// Assumes opaque images (like noise.png): the CGContext premultiplies
  /// alpha, so semi-transparent assets would need straight-alpha handling.
  static func loadTexture(url: URL, device: MTLDevice) throws -> MTLTexture {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ShaderError.missingResource(url.lastPathComponent) }

    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
      data: &bytes,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else { throw ShaderError.setupFailed }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: width,
      height: height,
      mipmapped: false
    )
    textureDescriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
      throw ShaderError.setupFailed
    }
    texture.replace(
      region: MTLRegionMake2D(0, 0, width, height),
      mipmapLevel: 0,
      withBytes: bytes,
      bytesPerRow: width * 4
    )
    return texture
  }

  static func loadTextureWithTextureLoader(
    url: URL,
    device: MTLDevice,
    generateMipmaps: Bool = false
  ) throws -> MTLTexture {
    let loader = MTKTextureLoader(device: device)
    let options: [MTKTextureLoader.Option: Any] = [
      .SRGB: false,
      .textureUsage: MTLTextureUsage.shaderRead.rawValue,
      .generateMipmaps: generateMipmaps,
    ]
    do {
      return try loader.newTexture(URL: url, options: options)
    } catch {
      throw ShaderError.missingResource(url.lastPathComponent)
    }
  }

  func encode(
    commandBuffer: MTLCommandBuffer,
    renderPassDescriptor: MTLRenderPassDescriptor,
    time: Float,
    resolution: SIMD2<Float>,
    pixelRatio: Float,
    sizing: ShaderSizingParams,
    imageAspectRatio: Float = 1,
    uniforms: [UniformValue]
  ) {
    if let maskPipelineState {
      guard let targetTexture = renderPassDescriptor.colorAttachments[0].texture else {
        return
      }
      let maskDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba16Float,
        width: targetTexture.width,
        height: targetTexture.height,
        mipmapped: false
      )
      maskDescriptor.usage = [.renderTarget, .shaderRead]
      maskDescriptor.storageMode = targetTexture.storageMode
      guard let maskTexture = device.makeTexture(descriptor: maskDescriptor) else {
        return
      }

      let maskRenderPassDescriptor = MTLRenderPassDescriptor()
      maskRenderPassDescriptor.colorAttachments[0].texture = maskTexture
      maskRenderPassDescriptor.colorAttachments[0].loadAction = .clear
      maskRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
      maskRenderPassDescriptor.colorAttachments[0].storeAction = .store

      guard let maskEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: maskRenderPassDescriptor) else {
        return
      }
      maskEncoder.setRenderPipelineState(maskPipelineState)
      configure(
        maskEncoder,
        time: time,
        resolution: resolution,
        pixelRatio: pixelRatio,
        sizing: sizing,
        imageAspectRatio: imageAspectRatio,
        uniforms: uniforms
      )
      maskEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
      maskEncoder.endEncoding()

      guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
        return
      }
      encoder.setRenderPipelineState(pipelineState)
      configure(
        encoder,
        time: time,
        resolution: resolution,
        pixelRatio: pixelRatio,
        sizing: sizing,
        imageAspectRatio: imageAspectRatio,
        uniforms: uniforms,
        maskTexture: maskTexture
      )
      encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
      encoder.endEncoding()
      return
    }

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
      return
    }
    encoder.setRenderPipelineState(pipelineState)
    configure(
      encoder,
      time: time,
      resolution: resolution,
      pixelRatio: pixelRatio,
      sizing: sizing,
      imageAspectRatio: imageAspectRatio,
      uniforms: uniforms
    )

    encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    encoder.endEncoding()
  }

  private func configure(
    _ encoder: MTLRenderCommandEncoder,
    time: Float,
    resolution: SIMD2<Float>,
    pixelRatio: Float,
    sizing: ShaderSizingParams,
    imageAspectRatio: Float,
    uniforms: [UniformValue],
    maskTexture: MTLTexture? = nil
  ) {
    // PSGlobalUniforms { float2 u_resolution; float u_pixelRatio; float u_time; }
    var globals: [Float] = [resolution.x, resolution.y, pixelRatio, time]
    encoder.setVertexBytes(&globals, length: 16, index: 0)
    encoder.setFragmentBytes(&globals, length: 16, index: 0)

    // PSSizingUniforms, declaration order (all floats)
    let effectiveImageAspectRatio = imageTexture.map { Float($0.width) / Float($0.height) } ?? imageAspectRatio
    var sizingFloats: [Float] = [
      sizing.fit.uniformValue,
      sizing.scale,
      sizing.rotation,
      sizing.originX,
      sizing.originY,
      sizing.offsetX,
      sizing.offsetY,
      sizing.worldWidth,
      sizing.worldHeight,
      effectiveImageAspectRatio,
    ]
    encoder.setVertexBytes(&sizingFloats, length: sizingFloats.count * 4, index: 1)
    // Shaders that recompute UVs per fragment (no varyings, e.g. dithering)
    // read the same sizing struct from fragment buffer(2); unused elsewhere.
    encoder.setFragmentBytes(&sizingFloats, length: sizingFloats.count * 4, index: 2)

    if !uniforms.isEmpty {
      let packed = UniformEncoder.pack(uniforms)
      packed.withUnsafeBytes { raw in
        encoder.setFragmentBytes(raw.baseAddress!, length: raw.count, index: 1)
      }
    }

    if let noiseTexture {
      encoder.setFragmentTexture(noiseTexture, index: 0)
      encoder.setFragmentSamplerState(sampler, index: 0)
    }
    if let imageTexture {
      encoder.setFragmentTexture(imageTexture, index: 1)
      encoder.setFragmentSamplerState(sampler, index: 1)
    }
    if let maskTexture {
      encoder.setFragmentTexture(maskTexture, index: 2)
    }
  }
}
