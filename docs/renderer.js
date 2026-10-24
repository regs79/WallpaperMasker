// Pure canvas port of Sources/WallpaperMaskerCore/MaskRenderer.swift.
// All rects are {x, y, w, h} with origin top-left, in image pixels unless stated.
const WMRenderer = (() => {
  const round = Math.round;

  /** How the screen maps onto the image (same rounding rules as the Swift version). */
  function mapping(imageW, imageH, spec) {
    const sx = spec.screenPx.w / imageW; // screen px per image px, horizontally
    const sy = spec.screenPx.h / imageH;
    let fx, fy;
    switch (spec.scaleMode) {
      case 'fit':     fx = fy = Math.min(sx, sy); break;
      case 'stretch': fx = sx; fy = sy; break;
      default:        fx = fy = Math.max(sx, sy); // fill
    }
    const screenW = spec.screenPx.w / fx, screenH = spec.screenPx.h / fy;
    const originX = (imageW - screenW) / 2, originY = (imageH - screenH) / 2;
    const win = spec.windowRectPx;
    const rect = {
      x: round(originX + win.x / fx),
      y: round(originY + win.y / fy),
      w: round(win.w / fx),
      h: round(win.h / fy),
    };
    const f = Math.max(fx, fy);
    const screenRect = { x: round(originX), y: round(originY), w: round(screenW), h: round(screenH) };
    return { rect, radius: Math.ceil(spec.cornerRadiusPx / f), screenPxPerImagePx: f, screenRect };
  }

  function intersect(a, b) {
    const x = Math.max(a.x, b.x), y = Math.max(a.y, b.y);
    const r = Math.min(a.x + a.w, b.x + b.w), btm = Math.min(a.y + a.h, b.y + b.h);
    return r > x && btm > y ? { x, y, w: r - x, h: btm - y } : { x: 0, y: 0, w: 0, h: 0 };
  }

  /** The part of the rendered image that actually appears on screen. */
  function visibleRect(imageW, imageH, spec) {
    return intersect(mapping(imageW, imageH, spec).screenRect, { x: 0, y: 0, w: imageW, h: imageH });
  }

  /** Up to four rects of `full` outside `inner`. */
  function subtract(full, other) {
    const inner = intersect(full, other);
    if (inner.w === 0 || inner.h === 0) return [full];
    const parts = [];
    const fx2 = full.x + full.w, fy2 = full.y + full.h, ix2 = inner.x + inner.w, iy2 = inner.y + inner.h;
    if (inner.y > full.y) parts.push({ x: full.x, y: full.y, w: full.w, h: inner.y - full.y });
    if (iy2 < fy2)        parts.push({ x: full.x, y: iy2, w: full.w, h: fy2 - iy2 });
    if (inner.x > full.x) parts.push({ x: full.x, y: inner.y, w: inner.x - full.x, h: inner.h });
    if (ix2 < fx2)        parts.push({ x: ix2, y: inner.y, w: fx2 - ix2, h: inner.h });
    return parts;
  }

  function makeCanvas(w, h, colorSpace) {
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const ctx = c.getContext('2d', colorSpace ? { colorSpace } : undefined);
    return { c, ctx };
  }

  /**
   * Gaussian blur that extends edge pixels (like Core Image's clampedToExtent) instead of fading
   * to transparent at the borders. Uses the canvas `filter` property; sigma is in image pixels.
   */
  function gaussianBlur(source, w, h, sigma, colorSpace) {
    if (!(sigma > 0)) return source;
    const pad = Math.ceil(sigma * 3);
    const { c: padded, ctx: p } = makeCanvas(w + 2 * pad, h + 2 * pad, colorSpace);
    p.imageSmoothingEnabled = false;
    p.drawImage(source, pad, pad, w, h);
    // Edge strips stretched into the padding, then the four corner pixels.
    p.drawImage(source, 0, 0, 1, h, 0, pad, pad, h);
    p.drawImage(source, w - 1, 0, 1, h, pad + w, pad, pad, h);
    p.drawImage(source, 0, 0, w, 1, pad, 0, w, pad);
    p.drawImage(source, 0, h - 1, w, 1, pad, pad + h, w, pad);
    p.drawImage(source, 0, 0, 1, 1, 0, 0, pad, pad);
    p.drawImage(source, w - 1, 0, 1, 1, pad + w, 0, pad, pad);
    p.drawImage(source, 0, h - 1, 1, 1, 0, pad + h, pad, pad);
    p.drawImage(source, w - 1, h - 1, 1, 1, pad + w, pad + h, pad, pad);

    const { c: out, ctx: o } = makeCanvas(w, h, colorSpace);
    o.filter = `blur(${sigma}px)`;
    o.drawImage(padded, -pad, -pad);
    o.filter = 'none';
    return out;
  }

  const rgba = (c) => `rgba(${round(c.r * 255)}, ${round(c.g * 255)}, ${round(c.b * 255)}, ${c.a})`;

  /**
   * Renders the mask over `source` (an Image, ImageBitmap or canvas of size w×h).
   * Returns a new canvas of the same size.
   */
  function render(source, w, h, spec, options = {}) {
    const colorSpace = options.colorSpace;
    const { c, ctx } = makeCanvas(w, h, colorSpace);
    ctx.drawImage(source, 0, 0, w, h);

    const map = mapping(w, h, spec);
    const win = map.rect, radius = map.radius;
    const full = { x: 0, y: 0, w, h };

    const blurCache = new Map();
    const blurred = (blurPx) => {
      const sigma = blurPx / map.screenPxPerImagePx;
      if (!blurCache.has(sigma)) blurCache.set(sigma, gaussianBlur(source, w, h, sigma, colorSpace));
      return blurCache.get(sigma);
    };

    const paint = (style, clip) => {
      ctx.save();
      clip(ctx);
      if (style.blurPx > 0) ctx.drawImage(blurred(style.blurPx), 0, 0, w, h);
      if (style.color.a > 0) { ctx.fillStyle = rgba(style.color); ctx.fillRect(0, 0, w, h); }
      ctx.restore();
    };
    const clipRects = (c2, rects) => {
      c2.beginPath();
      for (const r of rects) c2.rect(r.x, r.y, r.w, r.h);
      c2.clip();
    };

    if (spec.maskMenuBar && win.y > 0) {
      paint(spec.menuBarStyle, (c2) => clipRects(c2, [{ x: 0, y: 0, w, h: win.y }]));
    }

    // Fill-mode crop margins are never visible, but unpainted they leave a hairline in the file.
    const margins = subtract(full, map.screenRect);
    const marginStyle = spec.maskMenuBar ? spec.menuBarStyle : (spec.maskCorners ? spec.cornerStyle : null);
    if (marginStyle && margins.length) paint(marginStyle, (c2) => clipRects(c2, margins));

    if (spec.maskCorners && radius > 0) {
      const r = Math.min(radius, win.w / 2, win.h / 2);
      paint(spec.cornerStyle, (c2) => {
        clipRects(c2, [
          { x: win.x, y: win.y, w: r, h: r },
          { x: win.x + win.w - r, y: win.y, w: r, h: r },
          { x: win.x, y: win.y + win.h - r, w: r, h: r },
          { x: win.x + win.w - r, y: win.y + win.h - r, w: r, h: r },
        ]);
        // Window rect minus its rounded version = the wedges (even-odd).
        c2.beginPath();
        c2.rect(win.x, win.y, win.w, win.h);
        c2.roundRect(win.x, win.y, win.w, win.h, r);
        c2.clip('evenodd');
      });
    }
    return c;
  }

  return { mapping, visibleRect, render, gaussianBlur, subtract };
})();
