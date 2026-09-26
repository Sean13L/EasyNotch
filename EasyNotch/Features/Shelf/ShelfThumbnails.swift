import AppKit
import QuickLookThumbnailing

/// Makes preview images for shelf files with Quick Look (the same previews Finder shows),
/// keeping them in memory so each is made only once.
final class ShelfThumbnails {
    private let cache = NSCache<NSURL, NSImage>()

    /// A thumbnail about `size` points across, or the file's Finder icon if Quick Look can't
    /// make one.
    func image(for url: URL, size: CGFloat) async -> NSImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: 2,
            representationTypes: .all
        )
        let cgImage = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
        let image = cgImage.map { NSImage(cgImage: $0, size: NSSize(width: size, height: size)) }
            ?? NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
