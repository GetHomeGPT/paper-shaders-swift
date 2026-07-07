import Foundation
import simd

/// Port of upstream `get-shader-color-from-string.ts`: converts hex
/// (`#rgb`, `#rrggbb`, `#rrggbbaa`), `rgb()`/`rgba()` and `hsl()`/`hsla()`
/// strings to an RGBA vector in the 0...1 range, alpha non-premultiplied.
public enum ShaderColor {
  /// Fallback.
  public static let fallback = SIMD4<Float>(0, 0, 0, 1)

  public static func parse(_ string: String) -> SIMD4<Float> {
    let s = string.trimmingCharacters(in: .whitespaces)
    let color: SIMD4<Float>
    if s.hasPrefix("#") {
      guard let hex = parseHex(s) else { return fallback }
      color = hex
    } else if s.lowercased().hasPrefix("rgb") {
      color = parseRgb(s) ?? SIMD4(0, 0, 0, 1)
    } else if s.lowercased().hasPrefix("hsl") {
      color = hslToRgb(parseComponents(s) ?? [0, 0, 0, 1])
    } else {
      return fallback
    }
    return simd_clamp(color, SIMD4(repeating: 0), SIMD4(repeating: 1))
  }

  private static func parseHex(_ string: String) -> SIMD4<Float>? {
    var hex = String(string.dropFirst())
    if hex.count == 3 {
      hex = hex.map { "\($0)\($0)" }.joined()
    }
    if hex.count == 6 {
      hex += "ff"
    }
    guard hex.count == 8 else { return nil }
    var bytes: [Float] = []
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
      bytes.append(Float(byte) / 255)
      index = next
    }
    return SIMD4(bytes[0], bytes[1], bytes[2], bytes[3])
  }

  private static func parseRgb(_ string: String) -> SIMD4<Float>? {
    // Upstream only accepts integer components; percentages fail its regex.
    guard !string.contains("%"), let c = parseComponents(string), c.count >= 3 else { return nil }
    return SIMD4(c[0] / 255, c[1] / 255, c[2] / 255, c.count >= 4 ? c[3] : 1)
  }

  /// Extracts the numeric components inside `fn(a, b%, c%, d)`.
  private static func parseComponents(_ string: String) -> [Float]? {
    guard let open = string.firstIndex(of: "("), let close = string.lastIndex(of: ")") else {
      return nil
    }
    let values = string[string.index(after: open)..<close]
      .split(separator: ",")
      .compactMap { Float($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")) }
    guard values.count >= 3 else { return nil }
    return values.count >= 4 ? values : values + [1]
  }

  /// h in 0...360, s and l in 0...100.
  private static func hslToRgb(_ hsla: [Float]) -> SIMD4<Float> {
    let h = hsla[0] / 360
    let s = hsla[1] / 100
    let l = hsla[2] / 100
    let a = hsla[3]

    if s == 0 {
      return SIMD4(l, l, l, a)
    }

    func hue2rgb(_ p: Float, _ q: Float, _ t: Float) -> Float {
      var t = t
      if t < 0 { t += 1 }
      if t > 1 { t -= 1 }
      if t < 1 / 6 { return p + (q - p) * 6 * t }
      if t < 1 / 2 { return q }
      if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
      return p
    }

    let q = l < 0.5 ? l * (1 + s) : l + s - l * s
    let p = 2 * l - q
    return SIMD4(
      hue2rgb(p, q, h + 1 / 3),
      hue2rgb(p, q, h),
      hue2rgb(p, q, h - 1 / 3),
      a
    )
  }
}
