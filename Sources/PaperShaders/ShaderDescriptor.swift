/// Describes one ported shader: its MSL fragment source (appended to
/// `MSL.common` at runtime compile) and its texture needs.
public struct ShaderDescriptor: Sendable {
  /// Name.
  public let name: String
  /// MSL source declaring the shader's uniforms struct and a
  /// `fragment float4 ps_fragment(...)` function.
  public let fragmentSource: String
  /// Optional first pass that renders a mask texture for shaders whose
  /// `fwidth`-based antialiasing is not portable enough across backends.
  public let maskFragmentFunctionName: String?
  /// Binds the shared 128×128 noise texture to fragment texture slot 0.
  public let usesNoiseTexture: Bool
  /// Binds the deterministic test image to fragment texture slot 1.
  public let usesImageTexture: Bool
  /// Generates mipmaps for the deterministic image texture, matching
  /// upstream image shaders that opt into `mipmaps={["u_image"]}`.
  public let usesImageMipmaps: Bool
  /// Resource basename for the image texture bound to fragment slot 1.
  public let imageResourceName: String

  /// Creates an instance.
  public init(
    name: String,
    fragmentSource: String,
    maskFragmentFunctionName: String? = nil,
    usesNoiseTexture: Bool = false,
    usesImageTexture: Bool = false,
    usesImageMipmaps: Bool = false,
    imageResourceName: String = "flowers"
  ) {
    self.name = name
    self.fragmentSource = fragmentSource
    self.maskFragmentFunctionName = maskFragmentFunctionName
    self.usesNoiseTexture = usesNoiseTexture
    self.usesImageTexture = usesImageTexture
    self.usesImageMipmaps = usesImageMipmaps
    self.imageResourceName = imageResourceName
  }
}
