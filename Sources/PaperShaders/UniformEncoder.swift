import Foundation
import simd

/// A single fragment-uniform value, in MSL struct declaration order.
public enum UniformValue: Equatable, Sendable {
  case float(Float)
  case float2(SIMD2<Float>)
  case float4(SIMD4<Float>)
  /// Fixed-size MSL array member (e.g. `float4 u_colors[10]`); missing
  /// entries are zero-filled up to `capacity`, extra entries are ignored.
  case float4Array([SIMD4<Float>], capacity: Int)

  var alignment: Int {
    switch self {
    case .float: return 4
    case .float2: return 8
    case .float4, .float4Array: return 16
    }
  }

  var size: Int {
    switch self {
    case .float: return 4
    case .float2: return 8
    case .float4: return 16
    case .float4Array(_, let capacity): return 16 * capacity
    }
  }
}

/// Packs ordered uniform values into bytes matching the layout the Metal
/// compiler gives the corresponding MSL struct (align 4/8/16 per member).
public enum UniformEncoder {
  /// Byte offset of each member, in declaration order.
  public static func offsets(of values: [UniformValue]) -> [Int] {
    var offsets: [Int] = []
    var cursor = 0
    for value in values {
      let alignment = value.alignment
      cursor = (cursor + alignment - 1) / alignment * alignment
      offsets.append(cursor)
      cursor += value.size
    }
    return offsets
  }

  public static func pack(_ values: [UniformValue]) -> Data {
    let offsets = offsets(of: values)
    let maxAlignment = values.map(\.alignment).max() ?? 4
    let end = zip(values, offsets).map { $0.size + $1 }.max() ?? 0
    let size = max((end + maxAlignment - 1) / maxAlignment * maxAlignment, 4)
    var data = Data(count: size)
    data.withUnsafeMutableBytes { raw in
      for (value, offset) in zip(values, offsets) {
        switch value {
        case .float(let v):
          raw.storeBytes(of: v, toByteOffset: offset, as: Float.self)
        case .float2(let v):
          raw.storeBytes(of: v.x, toByteOffset: offset, as: Float.self)
          raw.storeBytes(of: v.y, toByteOffset: offset + 4, as: Float.self)
        case .float4(let v):
          storeFloat4(v, into: raw, at: offset)
        case .float4Array(let vs, let capacity):
          for index in 0..<capacity {
            storeFloat4(index < vs.count ? vs[index] : .zero, into: raw, at: offset + 16 * index)
          }
        }
      }
    }
    return data
  }

  private static func storeFloat4(_ v: SIMD4<Float>, into raw: UnsafeMutableRawBufferPointer, at offset: Int) {
    raw.storeBytes(of: v.x, toByteOffset: offset, as: Float.self)
    raw.storeBytes(of: v.y, toByteOffset: offset + 4, as: Float.self)
    raw.storeBytes(of: v.z, toByteOffset: offset + 8, as: Float.self)
    raw.storeBytes(of: v.w, toByteOffset: offset + 12, as: Float.self)
  }
}
