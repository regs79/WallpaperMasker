import SwiftUI
import WallpaperMaskerCore

@main
struct WallpaperMaskerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Wallpaper Masker") {
            ContentView()
                .frame(minWidth: 760, idealWidth: 980, minHeight: 520, idealHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
