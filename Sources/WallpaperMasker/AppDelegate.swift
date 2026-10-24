import AppKit
import WallpaperMaskerCore

/// Handles files dropped on the Dock icon or passed via `open -a WallpaperMasker file.heic`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var pendingURL: URL?
    static var onOpen: ((URL) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if let onOpen = Self.onOpen { onOpen(url) } else { Self.pendingURL = url }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
