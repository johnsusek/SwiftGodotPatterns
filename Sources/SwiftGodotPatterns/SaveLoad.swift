import Foundation

/// Minimal JSON save/load helpers for `Codable` data.
///
/// Uses `JSONEncoder`/`JSONDecoder` with default settings and writes atomically.
public enum SaveIO {
  /// Encodes a codable value to JSON and writes it to disk atomically.
  ///
  /// - Parameters:
  ///   - value: The codable instance to persist.
  ///   - url: Destination file URL.
  /// - Throws: Any error from `JSONEncoder.encode` or `Data.write`.
  public static func save<T: Codable>(_ value: T, to url: URL) throws {
    let data = try JSONEncoder().encode(value)
    try data.write(to: url, options: .atomic)
  }

  /// Loads JSON from disk and decodes it into the requested type.
  ///
  /// - Parameters:
  ///   - _: The concrete `Codable` type to decode.
  ///   - url: Source file URL.
  /// - Returns: The decoded instance of `T`.
  /// - Throws: Any error from `Data.init(contentsOf:)` or `JSONDecoder.decode`.
  public static func load<T: Codable>(_: T.Type, from url: URL) throws -> T {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
  }
}
