import Foundation
import ImageIO

actor PersonalImageReader: PersonalImageReading {
  func readImage(at url: URL) throws -> Data {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let maximum = 2 * 1024 * 1024
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: maximum + 1) ?? Data()
    guard data.count <= maximum else { throw PersonalImageError.tooLarge }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0, width <= 12_000, height <= 12_000,
      width * height <= 40_000_000
    else { throw PersonalImageError.invalidImage }
    // Keep the supplied bytes unchanged; reject excessive dimensions before display.
    return data
  }
}
