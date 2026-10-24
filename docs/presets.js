// Display presets. Only the point size and the strip above a zoomed window matter for the mask
// (the mask is proportional, so the pixel scale cancels out); scale is informational.
// Mirrors Sources/WallpaperMaskerCore/DisplayPreset.swift — keep the two in sync.
const WM_NOTCH_STRIP = 34; // measured on a 14" MacBook Pro: 32pt menu bar + 2pt gap
const WM_PLAIN_STRIP = 26; // standard 24pt menu bar + 2pt gap
const WM_DEFAULT_CORNER_RADIUS = 16; // NSWindow corner radius on macOS 26

const WM_GROUPS = ['Apple notebooks & iMac', 'Apple displays', 'Common monitors'];

const WM_PRESETS = [
  // Apple notebooks & iMac
  { id: 'mbp14',   group: 0, name: 'MacBook Pro 14″ (notch)',          w: 1512, h: 982,  scale: 2, strip: WM_NOTCH_STRIP },
  { id: 'mbp16',   group: 0, name: 'MacBook Pro 16″ (notch)',          w: 1728, h: 1117, scale: 2, strip: WM_NOTCH_STRIP },
  { id: 'mba13',   group: 0, name: 'MacBook Air 13″ M2–M4 (notch)',    w: 1470, h: 956,  scale: 2, strip: WM_NOTCH_STRIP },
  { id: 'mba15',   group: 0, name: 'MacBook Air 15″ (notch)',          w: 1710, h: 1112, scale: 2, strip: WM_NOTCH_STRIP },
  { id: 'mba13m1', group: 0, name: 'MacBook Air 13″ M1 / Pro 13″',     w: 1440, h: 900,  scale: 2, strip: WM_PLAIN_STRIP },
  { id: 'imac24',  group: 0, name: 'iMac 24″',                         w: 2240, h: 1260, scale: 2, strip: WM_PLAIN_STRIP },
  // Apple displays
  { id: 'studio',  group: 1, name: 'Studio Display 27″',               w: 2560, h: 1440, scale: 2, strip: WM_PLAIN_STRIP },
  { id: 'xdr',     group: 1, name: 'Pro Display XDR 32″',              w: 3008, h: 1692, scale: 2, strip: WM_PLAIN_STRIP },
  // Common monitors
  { id: '1080p',   group: 2, name: '1080p · 1920×1080',                w: 1920, h: 1080, scale: 1, strip: WM_PLAIN_STRIP },
  { id: '1200p',   group: 2, name: 'WUXGA · 1920×1200',                w: 1920, h: 1200, scale: 1, strip: WM_PLAIN_STRIP },
  { id: '1440p',   group: 2, name: 'QHD 1440p · 2560×1440',            w: 2560, h: 1440, scale: 1, strip: WM_PLAIN_STRIP },
  { id: '1600p',   group: 2, name: 'WQXGA · 2560×1600',                w: 2560, h: 1600, scale: 1, strip: WM_PLAIN_STRIP },
  { id: '4k2x',    group: 2, name: '4K UHD @2x (looks like 1920×1080)', w: 1920, h: 1080, scale: 2, strip: WM_PLAIN_STRIP },
  { id: '4kscaled',group: 2, name: '4K UHD scaled (looks like 2560×1440)', w: 2560, h: 1440, scale: 2, strip: WM_PLAIN_STRIP },
  { id: '4k1x',    group: 2, name: '4K UHD @1x · 3840×2160',           w: 3840, h: 2160, scale: 1, strip: WM_PLAIN_STRIP },
  { id: '5k',      group: 2, name: '5K @2x · 5120×2880',               w: 2560, h: 1440, scale: 2, strip: WM_PLAIN_STRIP },
  { id: 'uw3440',  group: 2, name: 'Ultrawide 21:9 · 3440×1440',       w: 3440, h: 1440, scale: 1, strip: WM_PLAIN_STRIP },
  { id: 'uw3840',  group: 2, name: 'Ultrawide 24:10 · 3840×1600',      w: 3840, h: 1600, scale: 1, strip: WM_PLAIN_STRIP },
  { id: '5k2k',    group: 2, name: '5K2K ultrawide @2x · 5120×2160',   w: 2560, h: 1080, scale: 2, strip: WM_PLAIN_STRIP },
  { id: 'suw',     group: 2, name: 'Super ultrawide 32:9 · 5120×1440', w: 5120, h: 1440, scale: 1, strip: WM_PLAIN_STRIP },
];

/** Builds a MaskSpec (screen pixels, origin top-left) from a point size, scale and strip height. */
function wmSpecFromPoints(ptW, ptH, scale, stripPt, cornerRadiusPt, scaleMode) {
  const w = ptW * scale, h = ptH * scale;
  return {
    screenPx: { w, h },
    windowRectPx: { x: 0, y: stripPt * scale, w, h: h - stripPt * scale },
    cornerRadiusPx: cornerRadiusPt * scale,
    scaleMode,
    maskMenuBar: true,
    maskCorners: true,
    menuBarStyle: { color: { r: 0, g: 0, b: 0, a: 1 }, blurPx: 0 },
    cornerStyle: { color: { r: 0, g: 0, b: 0, a: 1 }, blurPx: 0 },
  };
}
