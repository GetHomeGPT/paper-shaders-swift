/// One ported shader with its upstream presets, shared by the parity tests
/// and the demo app so the list of ports lives in a single place.
public struct ShaderCatalogEntry: Sendable {
  /// Named upstream preset for this shader.
  public struct Preset: Sendable {
    /// Name.
    public let name: String
    /// Sizing.
    public let sizing: ShaderSizingParams
    /// Uniforms.
    public let uniforms: [UniformValue]
    /// Speed.
    public let speed: Double

    /// Creates an instance.
    public init(name: String, sizing: ShaderSizingParams, uniforms: [UniformValue], speed: Double) {
      self.name = name
      self.sizing = sizing
      self.uniforms = uniforms
      self.speed = speed
    }
  }

  /// Descriptor.
  public let descriptor: ShaderDescriptor
  /// Member names of the MSL uniforms struct bound at fragment buffer(1),
  /// in declaration order (checked against pipeline reflection by tests).
  public let uniformMemberNames: [String]
  /// Presets.
  public let presets: [Preset]

  /// Creates an instance.
  public init(descriptor: ShaderDescriptor, uniformMemberNames: [String], presets: [Preset]) {
    self.descriptor = descriptor
    self.uniformMemberNames = uniformMemberNames
    self.presets = presets
  }
}

/// Options for shader catalog.
public enum ShaderCatalog {
  /// All.
  public static let all: [ShaderCatalogEntry] = [
    ShaderCatalogEntry(
      descriptor: SimplexNoise.descriptor,
      uniformMemberNames: ["u_colors", "u_colorsCount", "u_stepsPerColor", "u_softness"],
      presets: SimplexNoise.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: DotOrbit.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_stepsPerColor",
        "u_size", "u_sizeRange", "u_spreading",
      ],
      presets: DotOrbit.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: MeshGradient.descriptor,
      uniformMemberNames: [
        "u_colors", "u_colorsCount", "u_distortion", "u_swirl",
        "u_grainMixer", "u_grainOverlay",
      ],
      presets: MeshGradient.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Waves.descriptor,
      uniformMemberNames: [
        "u_colorFront", "u_colorBack", "u_shape", "u_frequency",
        "u_amplitude", "u_spacing", "u_proportion", "u_softness",
      ],
      presets: Waves.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: DotGrid.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colorFill", "u_colorStroke", "u_dotSize",
        "u_gapX", "u_gapY", "u_strokeWidth", "u_sizeRange",
        "u_opacityRange", "u_shape",
      ],
      presets: DotGrid.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Spiral.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colorFront", "u_density", "u_distortion",
        "u_strokeWidth", "u_strokeCap", "u_strokeTaper", "u_noise",
        "u_noiseFrequency", "u_softness",
      ],
      presets: Spiral.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Swirl.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_bandCount",
        "u_twist", "u_center", "u_proportion", "u_softness",
        "u_noise", "u_noiseFrequency",
      ],
      presets: Swirl.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: NeuroNoise.descriptor,
      uniformMemberNames: [
        "u_colorFront", "u_colorMid", "u_colorBack", "u_brightness", "u_contrast",
      ],
      presets: NeuroNoise.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: StaticMeshGradient.descriptor,
      uniformMemberNames: [
        "u_colors", "u_colorsCount", "u_positions", "u_waveX",
        "u_waveXShift", "u_waveY", "u_waveYShift", "u_mixing",
        "u_grainMixer", "u_grainOverlay",
      ],
      presets: StaticMeshGradient.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: StaticRadialGradient.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_radius",
        "u_focalDistance", "u_focalAngle", "u_falloff", "u_mixing",
        "u_distortion", "u_distortionShift", "u_distortionFreq",
        "u_grainMixer", "u_grainOverlay",
      ],
      presets: StaticRadialGradient.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: PerlinNoise.descriptor,
      uniformMemberNames: [
        "u_colorFront", "u_colorBack", "u_proportion", "u_softness",
        "u_octaveCount", "u_persistence", "u_lacunarity",
      ],
      presets: PerlinNoise.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: ColorPanels.descriptor,
      uniformMemberNames: [
        "u_scale", "u_colors", "u_colorsCount", "u_colorBack",
        "u_density", "u_angle1", "u_angle2", "u_length", "u_edges",
        "u_blur", "u_fadeIn", "u_fadeOut", "u_gradient",
      ],
      presets: ColorPanels.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Dithering.descriptor,
      uniformMemberNames: [
        "u_pxSize", "u_colorBack", "u_colorFront", "u_shape", "u_type",
      ],
      presets: Dithering.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: GodRays.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colorBloom", "u_colors", "u_colorsCount",
        "u_density", "u_spotty", "u_midSize", "u_midIntensity",
        "u_intensity", "u_bloom",
      ],
      presets: GodRays.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Voronoi.descriptor,
      uniformMemberNames: [
        "u_scale", "u_colors", "u_colorsCount", "u_stepsPerColor",
        "u_colorGlow", "u_colorGap", "u_distortion", "u_gap", "u_glow",
      ],
      presets: Voronoi.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: SmokeRing.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_thickness",
        "u_radius", "u_innerShape", "u_noiseScale", "u_noiseIterations",
      ],
      presets: SmokeRing.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Warp.descriptor,
      uniformMemberNames: [
        "u_colors", "u_colorsCount", "u_proportion", "u_softness",
        "u_shape", "u_shapeScale", "u_distortion", "u_swirl", "u_swirlIterations",
      ],
      presets: Warp.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Metaballs.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_size", "u_count",
      ],
      presets: Metaballs.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: PulsingBorder.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_roundness",
        "u_thickness", "u_marginLeft", "u_marginRight", "u_marginTop",
        "u_marginBottom", "u_aspectRatio", "u_softness", "u_intensity",
        "u_bloom", "u_spotSize", "u_spots", "u_pulse", "u_smoke",
        "u_smokeSize",
      ],
      presets: PulsingBorder.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: HalftoneCmyk.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colorC", "u_colorM", "u_colorY", "u_colorK",
        "u_size", "u_contrast", "u_grainSize", "u_grainMixer",
        "u_grainOverlay", "u_gridNoise", "u_softness", "u_floodC",
        "u_floodM", "u_floodY", "u_floodK", "u_gainC", "u_gainM",
        "u_gainY", "u_gainK", "u_type",
      ],
      presets: HalftoneCmyk.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: PaperTexture.descriptor,
      uniformMemberNames: [
        "u_colorFront", "u_colorBack", "u_contrast", "u_roughness",
        "u_fiber", "u_fiberSize", "u_crumples", "u_crumpleSize",
        "u_folds", "u_foldCount", "u_drops", "u_seed", "u_fade",
      ],
      presets: PaperTexture.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: GrainGradient.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_softness",
        "u_intensity", "u_noise", "u_shape",
      ],
      presets: GrainGradient.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Water.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colorHighlight", "u_highlights", "u_layering",
        "u_edges", "u_caustic", "u_waves", "u_size",
      ],
      presets: Water.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: FlutedGlass.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colorShadow", "u_colorHighlight", "u_size",
        "u_shadows", "u_angle", "u_stretch", "u_shape",
        "u_distortion", "u_highlights", "u_distortionShape", "u_shift",
        "u_blur", "u_edges", "u_marginLeft", "u_marginRight",
        "u_marginTop", "u_marginBottom", "u_grainMixer", "u_grainOverlay",
      ],
      presets: FlutedGlass.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: GemSmoke.descriptor,
      uniformMemberNames: [
        "u_colors", "u_colorsCount", "u_colorBack", "u_colorInner",
        "u_innerDistortion", "u_outerDistortion", "u_outerGlow",
        "u_innerGlow", "u_offset", "u_angle", "u_size", "u_shape",
        "u_isImage",
      ],
      presets: GemSmoke.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: HalftoneDots.descriptor,
      uniformMemberNames: [
        "u_colorFront", "u_colorBack", "u_radius", "u_contrast",
        "u_size", "u_grainMixer", "u_grainOverlay", "u_grainSize",
        "u_grid", "u_originalColors", "u_inverted", "u_type",
      ],
      presets: HalftoneDots.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: Heatmap.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colors", "u_colorsCount", "u_angle",
        "u_noise", "u_innerGlow", "u_outerGlow", "u_contour",
      ],
      presets: Heatmap.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: ImageDithering.descriptor,
      uniformMemberNames: [
        "u_colorFront", "u_colorBack", "u_colorHighlight", "u_type",
        "u_pxSize", "u_originalColors", "u_inverted", "u_colorSteps",
      ],
      presets: ImageDithering.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
    ShaderCatalogEntry(
      descriptor: LiquidMetal.descriptor,
      uniformMemberNames: [
        "u_colorBack", "u_colorTint", "u_softness", "u_repetition",
        "u_shiftRed", "u_shiftBlue", "u_distortion", "u_contour",
        "u_angle", "u_shape", "u_isImage",
      ],
      presets: LiquidMetal.presets.map {
        ShaderCatalogEntry.Preset(
          name: $0.name,
          sizing: $0.params.sizing,
          uniforms: $0.params.uniforms,
          speed: $0.params.speed
        )
      }
    ),
  ]
}
