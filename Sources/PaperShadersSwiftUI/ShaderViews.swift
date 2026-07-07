import PaperShaders
import SwiftUI

/// SwiftUI views for every ported shader.

private protocol ShaderViewParameters {
  var uniforms: [UniformValue] { get }
  var sizing: ShaderSizingParams { get }
  var speed: Double { get }
  var frame: Double { get }
}

extension ColorPanels.Params: ShaderViewParameters {}
extension Dithering.Params: ShaderViewParameters {}
extension DotGrid.Params: ShaderViewParameters {}
extension DotOrbit.Params: ShaderViewParameters {}
extension FlutedGlass.Params: ShaderViewParameters {}
extension GemSmoke.Params: ShaderViewParameters {}
extension GodRays.Params: ShaderViewParameters {}
extension GrainGradient.Params: ShaderViewParameters {}
extension HalftoneCmyk.Params: ShaderViewParameters {}
extension HalftoneDots.Params: ShaderViewParameters {}
extension Heatmap.Params: ShaderViewParameters {}
extension ImageDithering.Params: ShaderViewParameters {}
extension LiquidMetal.Params: ShaderViewParameters {}
extension PaperShaders.MeshGradient.Params: ShaderViewParameters {}
extension Metaballs.Params: ShaderViewParameters {}
extension NeuroNoise.Params: ShaderViewParameters {}
extension PaperTexture.Params: ShaderViewParameters {}
extension PerlinNoise.Params: ShaderViewParameters {}
extension PulsingBorder.Params: ShaderViewParameters {}
extension SimplexNoise.Params: ShaderViewParameters {}
extension SmokeRing.Params: ShaderViewParameters {}
extension Spiral.Params: ShaderViewParameters {}
extension StaticMeshGradient.Params: ShaderViewParameters {}
extension StaticRadialGradient.Params: ShaderViewParameters {}
extension Swirl.Params: ShaderViewParameters {}
extension Voronoi.Params: ShaderViewParameters {}
extension Warp.Params: ShaderViewParameters {}
extension Water.Params: ShaderViewParameters {}
extension Waves.Params: ShaderViewParameters {}

private struct ShaderParamsView<Params: ShaderViewParameters>: View {
  let descriptor: ShaderDescriptor
  let params: Params

  var body: some View {
    ShaderView(
      descriptor: descriptor,
      uniforms: params.uniforms,
      sizing: params.sizing,
      speed: params.speed,
      frame: params.frame
    )
  }
}

/// Color panels view.
public struct ColorPanelsView: View {
  private let params: ColorPanels.Params

  /// Creates an instance.
  public init(params: ColorPanels.Params = ColorPanels.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: ColorPanels.descriptor, params: params)
  }
}

/// Dithering view.
public struct DitheringView: View {
  private let params: Dithering.Params

  /// Creates an instance.
  public init(params: Dithering.Params = Dithering.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Dithering.descriptor, params: params)
  }
}

/// Dot grid view.
public struct DotGridView: View {
  private let params: DotGrid.Params

  /// Creates an instance.
  public init(params: DotGrid.Params = DotGrid.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: DotGrid.descriptor, params: params)
  }
}

/// Dot orbit view.
public struct DotOrbitView: View {
  private let params: DotOrbit.Params

  /// Creates an instance.
  public init(params: DotOrbit.Params) {
    self.params = params
  }

  /// Creates an instance.
  public init(
    colorBack: String = "#000000",
    colors: [String] = ["#ffc96b", "#ff6200", "#ff2f00", "#421100", "#1a0000"],
    stepsPerColor: Float = 4,
    size: Float = 1,
    sizeRange: Float = 0,
    spreading: Float = 1,
    fit: ShaderFit = .none,
    scale: Float = 1,
    rotation: Float = 0,
    originX: Float = 0.5,
    originY: Float = 0.5,
    offsetX: Float = 0,
    offsetY: Float = 0,
    worldWidth: Float = 0,
    worldHeight: Float = 0,
    speed: Double = 1.5,
    frame: Double = 0
  ) {
    params = DotOrbit.Params(
      colorBack: colorBack,
      colors: colors,
      stepsPerColor: stepsPerColor,
      size: size,
      sizeRange: sizeRange,
      spreading: spreading,
      sizing: ShaderSizingParams(
        fit: fit, scale: scale, rotation: rotation,
        originX: originX, originY: originY,
        offsetX: offsetX, offsetY: offsetY,
        worldWidth: worldWidth, worldHeight: worldHeight
      ),
      speed: speed,
      frame: frame
    )
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: DotOrbit.descriptor, params: params)
  }
}

/// Fluted glass view.
public struct FlutedGlassView: View {
  private let params: FlutedGlass.Params

  /// Creates an instance.
  public init(params: FlutedGlass.Params = FlutedGlass.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: FlutedGlass.descriptor, params: params)
  }
}

/// Gem smoke view.
public struct GemSmokeView: View {
  private let params: GemSmoke.Params

  /// Creates an instance.
  public init(params: GemSmoke.Params = GemSmoke.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: GemSmoke.descriptor, params: params)
  }
}

/// God rays view.
public struct GodRaysView: View {
  private let params: GodRays.Params

  /// Creates an instance.
  public init(params: GodRays.Params = GodRays.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: GodRays.descriptor, params: params)
  }
}

/// Grain gradient view.
public struct GrainGradientView: View {
  private let params: GrainGradient.Params

  /// Creates an instance.
  public init(params: GrainGradient.Params = GrainGradient.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: GrainGradient.descriptor, params: params)
  }
}

/// Halftone cmyk view.
public struct HalftoneCmykView: View {
  private let params: HalftoneCmyk.Params

  /// Creates an instance.
  public init(params: HalftoneCmyk.Params = HalftoneCmyk.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: HalftoneCmyk.descriptor, params: params)
  }
}

/// Halftone dots view.
public struct HalftoneDotsView: View {
  private let params: HalftoneDots.Params

  /// Creates an instance.
  public init(params: HalftoneDots.Params = HalftoneDots.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: HalftoneDots.descriptor, params: params)
  }
}

/// Heatmap view.
public struct HeatmapView: View {
  private let params: Heatmap.Params

  /// Creates an instance.
  public init(params: Heatmap.Params = Heatmap.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Heatmap.descriptor, params: params)
  }
}

/// Image dithering view.
public struct ImageDitheringView: View {
  private let params: ImageDithering.Params

  /// Creates an instance.
  public init(params: ImageDithering.Params = ImageDithering.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: ImageDithering.descriptor, params: params)
  }
}

/// Liquid metal view.
public struct LiquidMetalView: View {
  private let params: LiquidMetal.Params

  /// Creates an instance.
  public init(params: LiquidMetal.Params = LiquidMetal.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: LiquidMetal.descriptor, params: params)
  }
}

/// Mesh gradient view.
public struct MeshGradientView: View {
  private let params: PaperShaders.MeshGradient.Params

  /// Creates an instance.
  public init(params: PaperShaders.MeshGradient.Params) {
    self.params = params
  }

  /// Creates an instance.
  public init(
    colors: [String] = ["#e0eaff", "#241d9a", "#f75092", "#9f50d3"],
    distortion: Float = 0.8,
    swirl: Float = 0.1,
    grainMixer: Float = 0,
    grainOverlay: Float = 0,
    fit: ShaderFit = .contain,
    scale: Float = 1,
    rotation: Float = 0,
    originX: Float = 0.5,
    originY: Float = 0.5,
    offsetX: Float = 0,
    offsetY: Float = 0,
    worldWidth: Float = 0,
    worldHeight: Float = 0,
    speed: Double = 1,
    frame: Double = 0
  ) {
    params = PaperShaders.MeshGradient.Params(
      colors: colors,
      distortion: distortion,
      swirl: swirl,
      grainMixer: grainMixer,
      grainOverlay: grainOverlay,
      sizing: ShaderSizingParams(
        fit: fit, scale: scale, rotation: rotation,
        originX: originX, originY: originY,
        offsetX: offsetX, offsetY: offsetY,
        worldWidth: worldWidth, worldHeight: worldHeight
      ),
      speed: speed,
      frame: frame
    )
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: PaperShaders.MeshGradient.descriptor, params: params)
  }
}

/// Metaballs view.
public struct MetaballsView: View {
  private let params: Metaballs.Params

  /// Creates an instance.
  public init(params: Metaballs.Params = Metaballs.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Metaballs.descriptor, params: params)
  }
}

/// Neuro noise view.
public struct NeuroNoiseView: View {
  private let params: NeuroNoise.Params

  /// Creates an instance.
  public init(params: NeuroNoise.Params = NeuroNoise.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: NeuroNoise.descriptor, params: params)
  }
}

/// Paper texture view.
public struct PaperTextureView: View {
  private let params: PaperTexture.Params

  /// Creates an instance.
  public init(params: PaperTexture.Params = PaperTexture.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: PaperTexture.descriptor, params: params)
  }
}

/// Perlin noise view.
public struct PerlinNoiseView: View {
  private let params: PerlinNoise.Params

  /// Creates an instance.
  public init(params: PerlinNoise.Params = PerlinNoise.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: PerlinNoise.descriptor, params: params)
  }
}

/// Pulsing border view.
public struct PulsingBorderView: View {
  private let params: PulsingBorder.Params

  /// Creates an instance.
  public init(params: PulsingBorder.Params = PulsingBorder.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: PulsingBorder.descriptor, params: params)
  }
}

/// Simplex noise view.
public struct SimplexNoiseView: View {
  private let params: SimplexNoise.Params

  /// Creates an instance.
  public init(params: SimplexNoise.Params) {
    self.params = params
  }

  /// Creates an instance.
  public init(
    colors: [String] = ["#4449CF", "#FFD1E0", "#F94446", "#FFD36B", "#FFFFFF"],
    stepsPerColor: Float = 2,
    softness: Float = 0,
    fit: ShaderFit = .none,
    scale: Float = 0.6,
    rotation: Float = 0,
    originX: Float = 0.5,
    originY: Float = 0.5,
    offsetX: Float = 0,
    offsetY: Float = 0,
    worldWidth: Float = 0,
    worldHeight: Float = 0,
    speed: Double = 0.5,
    frame: Double = 0
  ) {
    params = SimplexNoise.Params(
      colors: colors,
      stepsPerColor: stepsPerColor,
      softness: softness,
      sizing: ShaderSizingParams(
        fit: fit, scale: scale, rotation: rotation,
        originX: originX, originY: originY,
        offsetX: offsetX, offsetY: offsetY,
        worldWidth: worldWidth, worldHeight: worldHeight
      ),
      speed: speed,
      frame: frame
    )
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: SimplexNoise.descriptor, params: params)
  }
}

/// Smoke ring view.
public struct SmokeRingView: View {
  private let params: SmokeRing.Params

  /// Creates an instance.
  public init(params: SmokeRing.Params = SmokeRing.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: SmokeRing.descriptor, params: params)
  }
}

/// Spiral view.
public struct SpiralView: View {
  private let params: Spiral.Params

  /// Creates an instance.
  public init(params: Spiral.Params = Spiral.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Spiral.descriptor, params: params)
  }
}

/// Static mesh gradient view.
public struct StaticMeshGradientView: View {
  private let params: StaticMeshGradient.Params

  /// Creates an instance.
  public init(params: StaticMeshGradient.Params = StaticMeshGradient.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: StaticMeshGradient.descriptor, params: params)
  }
}

/// Static radial gradient view.
public struct StaticRadialGradientView: View {
  private let params: StaticRadialGradient.Params

  /// Creates an instance.
  public init(params: StaticRadialGradient.Params = StaticRadialGradient.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: StaticRadialGradient.descriptor, params: params)
  }
}

/// Swirl view.
public struct SwirlView: View {
  private let params: Swirl.Params

  /// Creates an instance.
  public init(params: Swirl.Params = Swirl.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Swirl.descriptor, params: params)
  }
}

/// Voronoi view.
public struct VoronoiView: View {
  private let params: Voronoi.Params

  /// Creates an instance.
  public init(params: Voronoi.Params = Voronoi.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Voronoi.descriptor, params: params)
  }
}

/// Warp view.
public struct WarpView: View {
  private let params: Warp.Params

  /// Creates an instance.
  public init(params: Warp.Params = Warp.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Warp.descriptor, params: params)
  }
}

/// Water view.
public struct WaterView: View {
  private let params: Water.Params

  /// Creates an instance.
  public init(params: Water.Params = Water.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Water.descriptor, params: params)
  }
}

/// Waves view.
public struct WavesView: View {
  private let params: Waves.Params

  /// Creates an instance.
  public init(params: Waves.Params = Waves.Params()) {
    self.params = params
  }

  /// Body.
  public var body: some View {
    ShaderParamsView(descriptor: Waves.descriptor, params: params)
  }
}

/// Renders any ported shader from its descriptor and raw uniforms,
/// e.g. a `ShaderCatalog` preset, without a dedicated typed view.
public struct ShaderView: View {
  private let descriptor: ShaderDescriptor
  private let uniforms: [UniformValue]
  private let sizing: ShaderSizingParams
  private let speed: Double
  private let frame: Double
  private let renderOptions: ShaderRenderOptions
  private let onRenderMetricsChanged: ((ShaderRenderMetrics) -> Void)?

  /// Creates an instance.
  public init(
    descriptor: ShaderDescriptor,
    uniforms: [UniformValue],
    sizing: ShaderSizingParams = .defaultObject,
    speed: Double = 1,
    frame: Double = 0,
    renderOptions: ShaderRenderOptions = .fixed,
    onRenderMetricsChanged: ((ShaderRenderMetrics) -> Void)? = nil
  ) {
    self.descriptor = descriptor
    self.uniforms = uniforms
    self.sizing = sizing
    self.speed = speed
    self.frame = frame
    self.renderOptions = renderOptions
    self.onRenderMetricsChanged = onRenderMetricsChanged
  }

  /// Body.
  public var body: some View {
    ShaderViewRepresentable(
      descriptor: descriptor,
      uniforms: uniforms,
      sizing: sizing,
      speed: speed,
      frame: frame,
      renderOptions: renderOptions,
      onRenderMetricsChanged: onRenderMetricsChanged
    )
    .id("\(descriptor.name)-\(renderOptions.mathMode.rawValue)")
  }
}
