// Big controls in the middle of the player (intent 261125-cinema-center-controls, spec P1–P5).
// The site's own controls sit along the bottom edge and in the corners — far apart in a window that fills the view.
// This puts a layer over the player whose buttons press the site's buttons (or act directly when that does nothing).
// The site's bottom bar stays as it is. Main frame only, document start, Coupang Play only.
(() => {
  if (window.__cpvpCenter) return;
  Object.defineProperty(window, "__cpvpCenter", { value: true });
  const host = location.hostname.toLowerCase();
  if (!(host === "coupangplay.com" || host.endsWith(".coupangplay.com"))) return;

  const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cpvp;
  const report = (data) => {
    try { handler && handler.postMessage(Object.assign({ kind: "player-center", frame: "main", href: location.href }, data)); } catch (_) {}
  };

  const TAP_MS = 3000;  // visible this long after a tap in the player (decision DC4)
  const ARM_MS = 350;   // buttons ignore taps this long after appearing — the waking tap must not press one (DC4)
  const TICK_MS = 250;
  const CHECK_MS = 500; // a site press that changed nothing by then → act directly (DC7)

  // The site's parts (research R4). First match wins.
  const SITE = {
    mount: ["#playerWrapper", "[class*='Player_playerMain']"],
    shown: [".buttons-bottom.shown", ".buttons-top.shown"],
    playPause: [".playpause-button", "[class*='PlayPause_playPauseButton']"],
    rewind: ["[class*='RewindButton_rewindButton']"],
    forward: ["[class*='ForwardButton_forwardButton']"],
    next: [".nextEpisode-button", "[class*='NextEpisode_nextEpisode']"],
    fullscreen: [".fullscreen-button", "[class*='Fullscreen_fullscreen']"],
  };
  const find = (root, list) => {
    for (const selector of list) { const el = root.querySelector(selector); if (el) return el; }
    return null;
  };

  // Icons, 24×24, drawn here.
  const svg = (body) => `<svg viewBox="0 0 24 24" aria-hidden="true">${body}</svg>`;
  const LINE = 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"';
  const TEN = (x) => `<text x="${x}" y="15.6" font-size="7.5" font-weight="700" text-anchor="middle" fill="currentColor" font-family="-apple-system, system-ui, sans-serif">10</text>`;
  const ICON = {
    play: svg('<path d="M8 5v14l11-7z" fill="currentColor"/>'),
    pause: svg('<path d="M7 5h3.5v14H7zM13.5 5H17v14h-3.5z" fill="currentColor"/>'),
    back10: svg(`<path d="M12 4.5a7.5 7.5 0 1 1-7.5 7.5" ${LINE}/><path d="M12 1.5 8 4.5l4 3z" fill="currentColor"/>${TEN(12.4)}`),
    fwd10: svg(`<path d="M12 4.5a7.5 7.5 0 1 0 7.5 7.5" ${LINE}/><path d="M12 1.5l4 3-4 3z" fill="currentColor"/>${TEN(11.6)}`),
    sound: svg(`<path d="M3 9.5h3.5L11 5.5v13l-4.5-4H3z" fill="currentColor"/><path d="M15 9a4 4 0 0 1 0 6M17.5 6.5a7.5 7.5 0 0 1 0 11" ${LINE}/>`),
    muted: svg(`<path d="M3 9.5h3.5L11 5.5v13l-4.5-4H3z" fill="currentColor"/><path d="M15.5 9.5l5 5M20.5 9.5l-5 5" ${LINE}/>`),
    next: svg('<path d="M5 5v14l10-7z" fill="currentColor"/><path d="M17 5h2.5v14H17z" fill="currentColor"/>'),
    enter: svg(`<path d="M4 9V4h5M15 4h5v5M20 15v5h-5M9 20H4v-5" ${LINE}/>`),
    exit: svg(`<path d="M9 4v5H4M15 4v5h5M20 15h-5v5M4 15h5v5" ${LINE}/>`),
  };

  // 3 × 2: the middle column is the two buttons the user needs most (decision DC2).
  const LAYOUT = [
    ["back10", "m"], ["playPause", "xl"], ["fwd10", "m"],
    ["mute", "m"], ["fullscreen", "xl"], ["next", "m"],
  ];

  const CSS = `
    #cpvp-center { position: absolute; inset: 0; z-index: 2147483000; display: flex; align-items: center; justify-content: center;
      pointer-events: none; opacity: 0; transition: opacity .2s ease;
      --xl: clamp(96px, 17vh, 240px); --m: clamp(60px, 10vh, 140px); }
    #cpvp-center[data-visible="1"] { opacity: 1; }
    #cpvp-center .cpvp-stack { display: flex; flex-direction: column; align-items: center; gap: 3vh; }
    #cpvp-center .cpvp-info { visibility: hidden; pointer-events: none; padding: .45em 1.1em; border-radius: 999px; color: #fff;
      font: 600 clamp(15px, 2.6vh, 34px)/1.2 -apple-system, system-ui, sans-serif; letter-spacing: .02em; white-space: nowrap;
      font-variant-numeric: tabular-nums; background: rgba(20, 20, 20, .6); -webkit-backdrop-filter: blur(12px); backdrop-filter: blur(12px); }
    #cpvp-center .cpvp-info[data-on="1"] { visibility: visible; }
    #cpvp-center .cpvp-grid { display: grid; grid-template-columns: repeat(3, auto); gap: 3vh 5vw; align-items: center; justify-items: center; }
    #cpvp-center .cpvp-cell { display: flex; flex-direction: column; align-items: center; gap: 1.2vh; }
    #cpvp-center .cpvp-cell[hidden] { display: flex; visibility: hidden; }
    #cpvp-center button { all: unset; box-sizing: border-box; display: flex; align-items: center; justify-content: center;
      width: var(--m); height: var(--m); border-radius: 50%; color: #fff; cursor: pointer; pointer-events: none;
      background: rgba(20, 20, 20, .55); -webkit-backdrop-filter: blur(12px); backdrop-filter: blur(12px);
      box-shadow: inset 0 0 0 1.5px rgba(255, 255, 255, .25); }
    #cpvp-center[data-armed="1"] button { pointer-events: auto; }
    #cpvp-center button.cpvp-xl { width: var(--xl); height: var(--xl); background: rgba(20, 20, 20, .65); }
    #cpvp-center button svg { width: 52%; height: 52%; }
    #cpvp-center button:active { background: rgba(255, 255, 255, .3); }
    #cpvp-center .cpvp-label { color: #fff; font: 600 clamp(13px, 2.1vh, 28px)/1.2 -apple-system, system-ui, sans-serif;
      text-shadow: 0 1px 3px rgba(0, 0, 0, .8); white-space: nowrap; pointer-events: none; }
  `;

  let layer = null, parts = {}, info = null, page = null, video = null;
  let lastTap = -Infinity, playedSrc = null, visible = false, armTimer = null; // performance.now() starts near 0 at load

  const isFullscreen = () => !!(document.fullscreenElement || document.webkitFullscreenElement);
  const srcOf = (v) => v.currentSrc || v.src || "";
  const hasPlayed = () => !!video && playedSrc !== null && playedSrc === srcOf(video);

  // "1080p FHD · 1920×1080" from the frames the video is decoding now — adaptive streams change it (spec P6, decision DC9).
  // The class is the 16:9 height the picture fills, so wide films (1920×800) still read as 1080p.
  const NAMES = { 2160: "4K UHD", 1440: "1440p QHD", 1080: "1080p FHD", 720: "720p HD" };
  const resolution = (w, h) => {
    if (!(w > 0 && h > 0)) return "";
    const p = Math.max(h, Math.round((w * 9) / 16));
    const near = (t) => Math.abs(p - t) <= t * 0.03;
    const name = p >= 2160 * 0.97 ? NAMES[2160] : NAMES[[1440, 1080, 720].find(near)] || `${p}p`;
    return `${name} · ${w}×${h}`;
  };

  const build = () => {
    const el = document.createElement("div");
    el.id = "cpvp-center";
    el.dataset.visible = "0";
    el.dataset.armed = "0";
    const style = document.createElement("style");
    style.textContent = CSS;
    const grid = document.createElement("div");
    grid.className = "cpvp-grid";
    parts = {};
    for (const [name, size] of LAYOUT) {
      const cell = document.createElement("div");
      cell.className = "cpvp-cell";
      const button = document.createElement("button");
      button.type = "button";
      button.className = "cpvp-" + size;
      button.dataset.name = name;
      const label = document.createElement("div");
      label.className = "cpvp-label";
      cell.append(button, label);
      grid.appendChild(cell);
      parts[name] = { cell, button, label, state: "" };
      // The site's tap layer toggles play/pause on click — keep our clicks to ourselves (spec P3).
      button.addEventListener("click", (e) => { e.preventDefault(); e.stopPropagation(); press(name); });
    }
    info = document.createElement("div");
    info.className = "cpvp-info";
    info.dataset.on = "0";
    const stack = document.createElement("div");
    stack.className = "cpvp-stack";
    stack.append(info, grid); // the info line keeps its space when hidden, so the buttons never move
    el.append(style, stack);
    return el;
  };

  const setPart = (name, icon, text, show = true) => {
    const part = parts[name];
    const state = `${icon}|${text}|${show}`;
    if (part.state === state) return;
    part.state = state;
    part.button.innerHTML = ICON[icon];
    part.button.setAttribute("aria-label", text);
    part.label.textContent = text;
    part.cell.hidden = !show;
  };

  const reasons = () => {
    const why = [];
    if (find(page, SITE.shown)) why.push("site");
    if (performance.now() - lastTap < TAP_MS) why.push("tap");
    if (video && video.paused && hasPlayed()) why.push("paused");
    return why;
  };

  const tick = () => {
    page = document.getElementById("playerPage");
    if (!page) {
      if (layer) { layer.remove(); layer = null; visible = false; report({ event: "unmount" }); }
      return;
    }
    const mount = find(page, SITE.mount) || page;
    if (!layer) layer = build();
    if (layer.parentElement !== mount) {
      mount.appendChild(layer);
      report({ event: "mount", into: mount.id || (mount.getAttribute("class") || "").split(/\s+/)[0] });
    }
    video = page.querySelector("video");
    if (video && !video.paused) playedSrc = srcOf(video);

    const paused = !video || video.paused;
    const muted = !!video && video.muted;
    const fullscreen = isFullscreen();
    setPart("back10", "back10", "10초 뒤로");
    setPart("playPause", paused ? "play" : "pause", paused ? "재생" : "멈춤");
    setPart("fwd10", "fwd10", "10초 앞으로");
    setPart("mute", muted ? "muted" : "sound", muted ? "소리 켜기" : "음소거");
    setPart("fullscreen", fullscreen ? "exit" : "enter", fullscreen ? "전체화면 끝내기" : "전체화면");
    setPart("next", "next", "다음화", !!find(page, SITE.next));

    // Resolution, only while paused (intent addition 2026-11-25).
    const size = video ? resolution(video.videoWidth, video.videoHeight) : "";
    if (info.textContent !== size) info.textContent = size;
    const infoOn = paused && size ? "1" : "0";
    if (info.dataset.on !== infoOn) info.dataset.on = infoOn;

    const why = reasons();
    const show = why.length > 0;
    if (show === visible) return;
    visible = show;
    layer.dataset.visible = show ? "1" : "0";
    clearTimeout(armTimer);
    if (show) armTimer = setTimeout(() => { if (layer) layer.dataset.armed = "1"; }, ARM_MS);
    else layer.dataset.armed = "0";
    report({ event: show ? "show" : "hide", why: why.join(","), paused, fullscreen, size });
  };

  // Clicks the site's button — on its icon, so the site's handler runs whether it sits on the icon or the button.
  const click = (el) => {
    const target = el.querySelector("img, svg") || el;
    target.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
  };
  const play = (v) => { try { const p = v.play(); if (p && p.catch) p.catch(() => {}); } catch (_) {} };
  const toggleFullscreen = (wasOn) => {
    try { if (wasOn) document.exitFullscreen(); else page.requestFullscreen(); } catch (_) {}
  };

  const press = (name) => {
    lastTap = performance.now();
    if (!page) return;
    const v = video;
    const site = (key) => { const el = find(page, SITE[key]); if (el) click(el); return !!el; };
    let via = "direct";
    switch (name) {
      case "playPause": {
        const wasPaused = !v || v.paused;
        if (site("playPause")) {
          via = "site";
          setTimeout(() => {
            if (v && v.paused === wasPaused) { if (wasPaused) play(v); else v.pause(); report({ event: "fallback", button: name }); }
          }, CHECK_MS);
        } else if (v) {
          if (wasPaused) play(v); else v.pause();
        }
        break;
      }
      case "back10":
      case "fwd10": {
        const back = name === "back10";
        if (site(back ? "rewind" : "forward")) via = "site";
        else if (v) v.currentTime = Math.max(0, v.currentTime + (back ? -10 : 10));
        break;
      }
      case "next":
        via = site("next") ? "site" : "none";
        break;
      case "mute":
        if (v) v.muted = !v.muted; // decision DC5
        break;
      case "fullscreen": {
        const wasOn = isFullscreen();
        if (site("fullscreen")) {
          via = "site";
          setTimeout(() => {
            if (isFullscreen() === wasOn) { toggleFullscreen(wasOn); report({ event: "fallback", button: name }); }
          }, CHECK_MS);
        } else {
          toggleFullscreen(wasOn);
        }
        break;
      }
    }
    report({ event: "press", button: name, via });
    setTimeout(tick, 60);
    setTimeout(() => {
      const now = video;
      report({ event: "after", button: name, paused: now ? now.paused : null, muted: now ? now.muted : null,
        t: now ? Math.round(now.currentTime) : null, fullscreen: isFullscreen() });
    }, 800);
  };

  document.addEventListener("play", (e) => { if (e.target instanceof HTMLMediaElement) playedSrc = srcOf(e.target); }, true);
  document.addEventListener("fullscreenchange", () => tick(), true);
  addEventListener("pointerdown", (e) => {
    const player = document.getElementById("playerPage");
    if (player && player.contains(e.target)) { lastTap = performance.now(); tick(); }
  }, true);
  setInterval(tick, TICK_MS);
})();
