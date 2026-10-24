// UI for the web version. Geometry/rendering live in renderer.js; presets in presets.js.
(() => {
  const $ = (id) => document.getElementById(id);
  const el = {
    dropzone: $('dropzone'), scroll: $('scroll'), stage: $('stage'), empty: $('empty'), canvas: $('canvas'),
    zoombar: $('zoombar'), working: $('working'), zoomOut: $('zoomOut'), zoomIn: $('zoomIn'), zoomPct: $('zoomPct'),
    zoomFit: $('zoomFit'), zoom100: $('zoom100'),
    resolution: $('resolution'), mode: $('mode'), strip: $('strip'), radius: $('radius'),
    barOn: $('barOn'), barColor: $('barColor'), barAlpha: $('barAlpha'), barAlphaOut: $('barAlphaOut'), barFrost: $('barFrost'),
    cornerOn: $('cornerOn'), cornerColor: $('cornerColor'), cornerAlpha: $('cornerAlpha'), cornerAlphaOut: $('cornerAlphaOut'),
    cornerMatch: $('cornerMatch'), cornerFrost: $('cornerFrost'), blur: $('blur'),
    summary: $('summary'), format: $('format'), download: $('download'), status: $('status'),
    file: $('file'), file2: $('file2'),
  };

  // ---------- display options ----------
  const thisDisplay = {
    id: 'this', w: screen.width, h: screen.height, scale: window.devicePixelRatio || 1,
    get strip() {
      const notch = WM_PRESETS.find(p => p.strip === WM_NOTCH_STRIP && p.w === this.w && p.h === this.h);
      return notch ? WM_NOTCH_STRIP : WM_PLAIN_STRIP;
    },
    get name() { return `This display · ${Math.round(this.w * this.scale)}×${Math.round(this.h * this.scale)}`; },
  };
  function buildResolutionMenu() {
    const groups = [['Connected', [thisDisplay]], ...WM_GROUPS.map((g, i) => [g, WM_PRESETS.filter(p => p.group === i)])];
    for (const [label, items] of groups) {
      const og = document.createElement('optgroup'); og.label = label;
      for (const p of items) {
        const o = document.createElement('option'); o.value = p.id;
        o.textContent = p.id === 'this' ? p.name : `${p.name} · ${p.w * p.scale}×${p.h * p.scale}`;
        og.appendChild(o);
      }
      el.resolution.appendChild(og);
    }
    el.resolution.value = 'this';
    el.strip.value = thisDisplay.strip;
  }
  const currentDisplay = () => el.resolution.value === 'this' ? thisDisplay : WM_PRESETS.find(p => p.id === el.resolution.value);

  // ---------- state ----------
  let source = null;        // HTMLImageElement
  let sourceName = '';
  let rendered = null;      // full-size canvas
  let zoom = 1;             // 1 = fit
  let renderTimer = 0;
  const supportsP3 = (() => { try { return !!document.createElement('canvas').getContext('2d', { colorSpace: 'display-p3' }); } catch { return false; } })();

  const hexToRgb = (hex) => ({ r: parseInt(hex.slice(1, 3), 16) / 255, g: parseInt(hex.slice(3, 5), 16) / 255, b: parseInt(hex.slice(5, 7), 16) / 255 });

  function spec() {
    const d = currentDisplay();
    const s = wmSpecFromPoints(d.w, d.h, d.scale, Number(el.strip.value), Number(el.radius.value), el.mode.value);
    s.maskMenuBar = el.barOn.checked;
    s.maskCorners = el.cornerOn.checked;
    const blurPx = Number(el.blur.value) * d.scale;
    s.menuBarStyle = { color: { ...hexToRgb(el.barColor.value), a: Number(el.barAlpha.value) / 100 }, blurPx: el.barFrost.checked ? blurPx : 0 };
    s.cornerStyle = el.cornerMatch.checked
      ? s.menuBarStyle
      : { color: { ...hexToRgb(el.cornerColor.value), a: Number(el.cornerAlpha.value) / 100 }, blurPx: el.cornerFrost.checked ? blurPx : 0 };
    return s;
  }

  function setStatus(text, isError = false) { el.status.textContent = text; el.status.classList.toggle('error', isError); }

  function updateSummary() {
    const s = spec();
    let text = `Screen ${s.screenPx.w}×${s.screenPx.h} px · top strip ${Math.round(s.windowRectPx.y)} px · corner radius ${Math.round(s.cornerRadiusPx)} px`;
    if (source) {
      const m = WMRenderer.mapping(source.naturalWidth, source.naturalHeight, s);
      text += `\nImage ${source.naturalWidth}×${source.naturalHeight} px → strip ${m.rect.y} px, radius ${m.radius} px`;
    }
    el.summary.textContent = text;
  }

  function updateEnabled() {
    const bar = el.barOn.checked, corners = el.cornerOn.checked, match = el.cornerMatch.checked;
    const set = (input, on) => { input.disabled = !on; input.closest('.row')?.classList.toggle('disabled', !on); };
    set(el.barColor, bar); set(el.barAlpha, bar); set(el.barFrost, bar);
    set(el.cornerMatch, corners && bar);
    set(el.cornerColor, corners && !match); set(el.cornerAlpha, corners && !match); set(el.cornerFrost, corners && !match);
    set(el.blur, (bar && el.barFrost.checked) || (corners && !match && el.cornerFrost.checked));
    el.download.disabled = !source || !(bar || corners);
    el.barAlphaOut.value = `${el.barAlpha.value}%`;
    el.cornerAlphaOut.value = `${el.cornerAlpha.value}%`;
  }

  // When a region is first frosted and still opaque, suggest a menu-bar-like tint for the current appearance.
  function suggestFrostTint(colorInput, alphaInput) {
    if (Number(alphaInput.value) < 100) return;
    const dark = matchMedia('(prefers-color-scheme: dark)').matches;
    colorInput.value = dark ? '#1a1a1a' : '#ffffff';
    alphaInput.value = dark ? 55 : 70;
  }

  // ---------- rendering ----------
  function scheduleRender() {
    updateSummary(); updateEnabled();
    clearTimeout(renderTimer);
    if (!source) return;
    el.working.hidden = false;
    renderTimer = setTimeout(renderNow, 120);
  }

  function renderNow() {
    const s = spec();
    const w = source.naturalWidth, h = source.naturalHeight;
    rendered = WMRenderer.render(source, w, h, s, supportsP3 ? { colorSpace: 'display-p3' } : {});
    // Preview shows only the on-screen area (Fill mode crops the rest).
    const vis = WMRenderer.visibleRect(w, h, s);
    el.canvas.width = vis.w; el.canvas.height = vis.h;
    el.canvas.getContext('2d').drawImage(rendered, vis.x, vis.y, vis.w, vis.h, 0, 0, vis.w, vis.h);
    el.canvas.hidden = false; el.empty.hidden = true; el.zoombar.hidden = false;
    el.working.hidden = true;
    applyZoom();
  }

  // ---------- zoom ----------
  const dpr = () => window.devicePixelRatio || 1;
  function fitScale() {
    const pad = 32;
    const sw = el.scroll.clientWidth - pad, sh = el.scroll.clientHeight - pad;
    return Math.min(sw / el.canvas.width, sh / el.canvas.height);
  }
  const oneToOne = () => (1 / dpr()) / fitScale(); // zoom at which 1 image px = 1 device px
  function applyZoom() {
    if (el.canvas.hidden) return;
    const scale = fitScale() * zoom;
    el.canvas.style.width = `${el.canvas.width * scale}px`;
    el.canvas.style.height = `${el.canvas.height * scale}px`;
    el.canvas.classList.toggle('pixelated', scale * dpr() >= 1);
    el.zoomPct.textContent = `${Math.round(zoom / oneToOne() * 100)}%`;
    el.zoomOut.disabled = zoom <= 1;
    el.zoomIn.disabled = zoom >= 64;
    el.zoomFit.disabled = zoom === 1;
  }
  function setZoom(z, anchor) {
    const prev = zoom;
    zoom = Math.min(Math.max(z, 1), 64);
    if (zoom === prev) return;
    // Keep the point under the cursor (or the centre) fixed while zooming.
    const sc = el.scroll;
    const ax = anchor ? anchor.x : sc.clientWidth / 2, ay = anchor ? anchor.y : sc.clientHeight / 2;
    const cx = (sc.scrollLeft + ax), cy = (sc.scrollTop + ay);
    applyZoom();
    const k = zoom / prev;
    sc.scrollLeft = cx * k - ax; sc.scrollTop = cy * k - ay;
  }
  el.zoomOut.onclick = () => setZoom(zoom / 1.25);
  el.zoomIn.onclick = () => setZoom(zoom * 1.25);
  el.zoomFit.onclick = () => setZoom(1);
  el.zoom100.onclick = () => setZoom(oneToOne());
  el.scroll.addEventListener('wheel', (e) => {
    if (!e.ctrlKey || el.canvas.hidden) return; // trackpad pinch arrives as ctrl+wheel in Chrome/Safari
    e.preventDefault();
    const r = el.scroll.getBoundingClientRect();
    setZoom(zoom * Math.exp(-e.deltaY * 0.01), { x: e.clientX - r.left, y: e.clientY - r.top });
  }, { passive: false });
  let gestureStart = null;
  el.scroll.addEventListener('gesturestart', (e) => { e.preventDefault(); gestureStart = zoom; });
  el.scroll.addEventListener('gesturechange', (e) => { e.preventDefault(); if (gestureStart) setZoom(gestureStart * e.scale); });
  el.scroll.addEventListener('gestureend', () => { gestureStart = null; });
  document.addEventListener('keydown', (e) => {
    if (!(e.metaKey || e.ctrlKey) || el.canvas.hidden || e.target.matches('input, select, textarea')) return;
    const map = { '-': () => setZoom(zoom / 1.25), '=': () => setZoom(zoom * 1.25), '+': () => setZoom(zoom * 1.25), '0': () => setZoom(1), '1': () => setZoom(oneToOne()) };
    if (map[e.key]) { e.preventDefault(); map[e.key](); }
  });
  new ResizeObserver(() => applyZoom()).observe(el.scroll);

  // ---------- loading ----------
  async function load(file) {
    if (!file) return;
    const url = URL.createObjectURL(file);
    const img = new Image();
    try {
      await new Promise((resolve, reject) => { img.onload = resolve; img.onerror = () => reject(new Error('decode')); img.src = url; });
    } catch {
      URL.revokeObjectURL(url);
      const heic = /\.hei[cf]$/i.test(file.name) || /hei[cf]/.test(file.type);
      setStatus(heic ? `Couldn't decode ${file.name}. HEIC needs Safari; PNG and JPEG work in any browser.` : `Couldn't read ${file.name} as an image.`, true);
      return;
    }
    if (source?.src) URL.revokeObjectURL(source.src);
    source = img; sourceName = file.name; zoom = 1;
    setStatus(`Loaded ${file.name} (${img.naturalWidth}×${img.naturalHeight})`);
    scheduleRender();
  }
  el.file.onchange = () => load(el.file.files[0]);
  el.file2.onchange = () => load(el.file2.files[0]);
  for (const ev of ['dragenter', 'dragover']) el.dropzone.addEventListener(ev, (e) => { e.preventDefault(); el.dropzone.classList.add('drag'); });
  for (const ev of ['dragleave', 'drop']) el.dropzone.addEventListener(ev, (e) => { e.preventDefault(); el.dropzone.classList.remove('drag'); });
  el.dropzone.addEventListener('drop', (e) => load(e.dataTransfer.files[0]));
  document.addEventListener('dragover', (e) => e.preventDefault());
  document.addEventListener('drop', (e) => e.preventDefault());

  // ---------- download ----------
  el.download.onclick = () => {
    if (!rendered) return;
    const type = el.format.value;
    const ext = type === 'image/jpeg' ? 'jpg' : 'png';
    const base = sourceName.replace(/\.[^.]+$/, '') || 'wallpaper';
    setStatus('Encoding…');
    el.download.disabled = true;
    rendered.toBlob((blob) => {
      el.download.disabled = false;
      if (!blob) { setStatus('Encoding failed.', true); return; }
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `${base} masked.${ext}`;
      a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 10000);
      setStatus(`Saved ${a.download} (${(blob.size / 1048576).toFixed(1)} MB)`);
    }, type, 0.95);
  };

  // ---------- wiring ----------
  el.resolution.onchange = () => { el.strip.value = currentDisplay().strip; scheduleRender(); };
  el.barFrost.onchange = () => { if (el.barFrost.checked) suggestFrostTint(el.barColor, el.barAlpha); scheduleRender(); };
  el.cornerFrost.onchange = () => { if (el.cornerFrost.checked) suggestFrostTint(el.cornerColor, el.cornerAlpha); scheduleRender(); };
  for (const input of [el.mode, el.strip, el.radius, el.barOn, el.barColor, el.barAlpha, el.cornerOn, el.cornerColor, el.cornerAlpha, el.cornerMatch, el.blur]) {
    input.addEventListener('input', scheduleRender);
    input.addEventListener('change', scheduleRender);
  }

  buildResolutionMenu();
  updateSummary();
  updateEnabled();
})();
