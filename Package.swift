// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WallpaperMasker",
    platforms: [.macOS(.v14)],
    targets: [
        // Geometry, rendering and file I/O. No UI, so it can be unit-tested headlessly.
        .target(
            name: "WallpaperMaskerCore",
            path: "Sources/WallpaperMaskerCore"
        ),
        // The SwiftUI app.
        .executableTarget(
            name: "WallpaperMasker",
            dependencies: ["WallpaperMaskerCore"],
            path: "Sources/WallpaperMasker"
        ),
        .testTarget(
            name: "WallpaperMaskerCoreTests",
            dependencies: ["WallpaperMaskerCore"],
            path: "Tests/WallpaperMaskerCoreTests"
        ),
    ]
)
