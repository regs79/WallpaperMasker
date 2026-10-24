import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Loading and saving via ImageIO so any format macOS can decode (HEIC, JPEG, PNG, TIFF, …) works.
public enum ImageFile {
    public enum FileError: Error, LocalizedError {
        case unreadable(URL)
        case encodeFailed(URL)
        case sameAsSource
        public var errorDescription: String? {
            switch self {
            case .unreadable(let u): return "Couldn't read \(u.lastPathComponent) as an image."
            case .encodeFailed(let u): return "Couldn't write \(u.lastPathComponent)."
            case .sameAsSource: return "Refusing to overwrite the original file."
            }
        }
    }

    public struct Loaded {
        public let image: CGImage
        public let type: UTType
        public let url: URL
    }

    public static func load(_ url: URL) throws -> Loaded {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let typeId = CGImageSourceGetType(src) else { throw FileError.unreadable(url) }
        let type = UTType(typeId as String) ?? .png

        // Apply EXIF orientation so the pixels we mask are the pixels macOS shows.
        let orientation = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        guard var cg = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw FileError.unreadable(url)
        }
        if orientation != 1, let o = CGImagePropertyOrientation(rawValue: orientation) {
            let ci = CIImage(cgImage: cg).oriented(o)
            let ctx = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
            if let fixed = ctx.createCGImage(ci, from: ci.extent) { cg = fixed }
        }
        return Loaded(image: cg, type: type, url: url)
    }

    /// Types ImageIO can encode on this machine.
    public static let encodableTypes: Set<String> = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])

    /// The type we'll actually write for a given source type (falls back to PNG).
    public static func outputType(for sourceType: UTType) -> UTType {
        encodableTypes.contains(sourceType.identifier) ? sourceType : .png
    }

    public static func save(_ image: CGImage, to url: URL, as type: UTType, source: URL) throws {
        guard url.standardizedFileURL != source.standardizedFileURL else { throw FileError.sameAsSource }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw FileError.encodeFailed(url)
        }
        var props: [CFString: Any] = [:]
        if type.conforms(to: .heic) || type.conforms(to: .jpeg) {
            props[kCGImageDestinationLossyCompressionQuality] = 0.95
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw FileError.encodeFailed(url) }
    }
}
