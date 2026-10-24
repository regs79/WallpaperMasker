# Wallpaper Masker

On macOS the wallpaper shows through the transparent menu bar and peeks around the rounded corners of a maximised window. Wallpaper Masker takes an image and writes a **copy** with exactly those regions painted over, so a maximised window sits on a clean black (or any colour, or frosted) frame.

**Use it in your browser:** <https://regs79.github.io/WallpaperMasker/> — everything runs locally with Canvas, nothing is uploaded.

**Or download the Mac app:** [WallpaperMasker.zip](https://github.com/regs79/WallpaperMasker/releases/latest/download/WallpaperMasker.zip) (ad-hoc signed, see below).

## What it masks

A zoomed window on a 14″ MacBook Pro covers everything except a 34pt strip at the top (the 32pt menu bar plus a 2pt gap) and four wedges outside the window's 16pt rounded corners. The tool paints exactly that: everything outside the rounded rectangle of a maximised window.

- **Resolution**: defaults to the display you're on. Presets cover current Apple notebooks and displays plus common monitor sizes. The mask only depends on the screen's point size and the menu bar height, so presets carry an estimated strip height (34pt for notch models, 26pt otherwise) that you can adjust.
- **Wallpaper mode**: Fill Screen (macOS default), Fit, or Stretch. In Fill mode the crop margins are painted too so no hairline of wallpaper survives.
- **Menu bar / Corners**: each region can be toggled, given a colour with opacity, and optionally **frosted** (the wallpaper under it is blurred first, then tinted) to mimic the translucent menu bar on Sonoma and Sequoia. **Match menu bar** copies the menu bar's style to the corners.
- **Preview**: full resolution, zoomable, cropped to the on-screen area.

Output keeps the input format in the Mac app (HEIC in → HEIC out). The web version writes PNG or JPEG. macOS accepts either as a wallpaper.

## The Mac app and Gatekeeper

The app is signed ad-hoc, not with an Apple Developer ID, so the first launch is blocked with *"Apple could not verify WallpaperMasker is free of malware"*. Either:

1. Click **Done**, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**, then confirm; or
2. In Terminal: `xattr -d com.apple.quarantine ~/Downloads/WallpaperMasker.app`

You only need to do this once per download.

### Build from source

```sh
git clone git@github.com:regs79/WallpaperMasker.git
cd WallpaperMasker
Scripts/make-app.sh      # swift build -c release → WallpaperMasker.app
open WallpaperMasker.app
```

Requires Xcode 16+ / Swift 5.9+. `swift test` runs the pixel-level renderer tests headlessly. The same checks run in the browser at [docs/test.html](https://regs79.github.io/WallpaperMasker/test.html).

## Layout

| Path | What |
|---|---|
| `Sources/WallpaperMaskerCore` | Geometry, renderer, image I/O, presets (no UI, unit-tested) |
| `Sources/WallpaperMasker` | SwiftUI app |
| `Tests/WallpaperMaskerCoreTests` | XCTest pixel checks |
| `docs/` | The web app, served by GitHub Pages (`renderer.js` is a line-for-line port of the Swift renderer) |
| `Scripts/make-app.sh` | Builds and ad-hoc signs the `.app` |
| `Scripts/make-icon.sh` | Renders `Resources/icon.svg` into `AppIcon.icns` |
| `fixtures/white-test.png` | 3024×1964 white image; the easiest way to see the mask |

## Icon

`Resources/icon.svg` is a placeholder. Replace it with your own 1024×1024 SVG and run `Scripts/make-icon.sh`; copy it to `docs/favicon.svg` for the site.

## License

MIT
