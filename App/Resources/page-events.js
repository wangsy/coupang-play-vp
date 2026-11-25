// Reports what happens on the page to the app (spec S9). Runs at document start in every frame.
// Never sends typed values: inputs are described by tag/type/name only.
(() => {
  if (window.__cpvpEvents) return;
  Object.defineProperty(window, "__cpvpEvents", { value: true });
  const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cpvp;
  if (!handler) return;

  const frame = window.top === window ? "main" : "sub";
  const clip = (value, max = 300) => {
    let s;
    try { s = typeof value === "string" ? value : JSON.stringify(value); } catch (_) { s = String(value); }
    if (s === undefined) s = String(value);
    return s.length > max ? s.slice(0, max) + "…" : s;
  };
  const send = (kind, data) => {
    try { handler.postMessage(Object.assign({ kind, frame, href: location.href }, data || {})); } catch (_) {}
  };
  // Keep wrapped natives looking native (toString) so the page behaves as it would without us.
  const wrap = (owner, key, make) => {
    const original = owner && owner[key];
    if (typeof original !== "function") return;
    const wrapped = make(original);
    try { Object.defineProperty(wrapped, "toString", { value: () => original.toString() }); } catch (_) {}
    try { owner[key] = wrapped; } catch (_) {}
  };

  const isField = (el) => el && /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName) || (el && el.isContentEditable);
  const describe = (el) => {
    if (!el || !el.tagName) return null;
    const d = { tag: el.tagName.toLowerCase() };
    if (el.id) d.id = el.id;
    const cls = typeof el.className === "string" ? el.className.trim().split(/\s+/).slice(0, 2).join(" ") : "";
    if (cls) d.cls = cls;
    const role = el.getAttribute("role"); if (role) d.role = role;
    const aria = el.getAttribute("aria-label"); if (aria) d.aria = clip(aria, 60);
    if (isField(el)) {
      if (el.type) d.type = el.type;
      if (el.name) d.name = el.name;
    } else {
      const text = (el.innerText || el.textContent || "").trim().replace(/\s+/g, " ");
      if (text) d.text = clip(text, 60);
    }
    const href = el.getAttribute("href"); if (href) d.href = clip(href, 200);
    return d;
  };
  const interactive = (el) =>
    (el && el.closest && el.closest("a,button,[role=button],[role=link],[role=tab],[role=menuitem],input,select,textarea,label,[onclick],video")) || el;

  // Console and errors.
  for (const level of ["log", "info", "warn", "error", "debug"]) {
    wrap(console, level, (original) => function (...args) {
      send("console", { level, text: clip(args.map((a) => (a instanceof Error ? a.stack || a.message : clip(a, 200))).join(" "), 600) });
      return original.apply(this, args);
    });
  }
  addEventListener("error", (e) => {
    if (e.target && e.target !== window && e.target.tagName) {
      send("resource-error", { el: describe(e.target), src: clip(e.target.currentSrc || e.target.src || e.target.href || "", 200) });
    } else {
      send("js-error", { message: clip(e.message), source: clip(e.filename || "", 200), line: e.lineno, col: e.colno });
    }
  }, true);
  addEventListener("unhandledrejection", (e) => {
    const r = e.reason;
    send("js-rejection", { reason: clip(r && (r.stack || r.message) || r, 400) });
  });

  // Routes (Next.js navigates with history.pushState).
  for (const key of ["pushState", "replaceState"]) {
    wrap(history, key, (original) => function (state, title, url) {
      const result = original.apply(this, arguments);
      send("route", { how: key, to: clip(String(url == null ? location.href : new URL(url, location.href)), 300) });
      return result;
    });
  }
  addEventListener("popstate", () => send("route", { how: "popstate", to: location.href }));
  addEventListener("hashchange", () => send("route", { how: "hashchange", to: location.href }));

  // What the user does on screen.
  const point = (e) => ({ x: Math.round(e.clientX), y: Math.round(e.clientY) });
  addEventListener("pointerdown", (e) => send("pointer", Object.assign({ type: e.pointerType, el: describe(interactive(e.target)) }, point(e))), true);
  addEventListener("click", (e) => send("click", Object.assign({ el: describe(interactive(e.target)) }, point(e))), true);
  addEventListener("dblclick", (e) => send("dblclick", Object.assign({ el: describe(interactive(e.target)) }, point(e))), true);
  addEventListener("contextmenu", (e) => send("contextmenu", Object.assign({ el: describe(interactive(e.target)) }, point(e))), true);
  addEventListener("focusin", (e) => send("focus", { el: describe(e.target) }), true);
  addEventListener("keydown", (e) => {
    const named = e.key && e.key.length > 1; // Enter, Escape, ArrowLeft, Tab… — never characters
    send("key", { key: named ? e.key : "char", inField: !!isField(e.target) });
  }, true);
  addEventListener("submit", (e) => {
    const f = e.target;
    send("submit", { action: clip(f.getAttribute && f.getAttribute("action") || "", 200), method: f.method, el: describe(f) });
  }, true);
  addEventListener("change", (e) => {
    const t = e.target;
    const d = { el: describe(t) };
    if (t.type === "checkbox" || t.type === "radio") d.checked = t.checked;
    send("change", d);
  }, true);
  let scrollTimer = null;
  addEventListener("scroll", () => {
    if (scrollTimer) return;
    scrollTimer = setTimeout(() => {
      scrollTimer = null;
      send("scroll", { y: Math.round(scrollY), x: Math.round(scrollX), height: document.documentElement.scrollHeight });
    }, 1000);
  }, { capture: true, passive: true });
  addEventListener("resize", () => send("resize", { w: innerWidth, h: innerHeight }));

  // Dialogs, modals, popups that appear.
  const modalLike = (el) =>
    el.nodeType === 1 && (el.matches("dialog,[role=dialog],[role=alertdialog],[aria-modal=true]") ||
      /modal|popup|dialog|toast|sheet|overlay|banner/i.test(typeof el.className === "string" ? el.className : ""));
  const startObserver = () => {
    let budget = 200;
    new MutationObserver((records) => {
      for (const r of records) {
        for (const n of r.addedNodes) {
          if (budget > 0 && modalLike(n)) { budget--; send("appear", { el: describe(n) }); }
        }
      }
    }).observe(document.documentElement, { childList: true, subtree: true });
  };

  // Media playback (media events don't bubble — capture on document).
  const mediaInfo = (m) => ({
    src: clip(m.currentSrc || m.src || "", 160), t: Math.round(m.currentTime * 10) / 10,
    duration: isFinite(m.duration) ? Math.round(m.duration) : String(m.duration),
    ready: m.readyState, network: m.networkState, paused: m.paused, muted: m.muted, volume: Math.round(m.volume * 100) / 100,
    size: m.videoWidth ? m.videoWidth + "x" + m.videoHeight : undefined,
    error: m.error ? { code: m.error.code, message: m.error.message } : undefined,
  });
  for (const type of ["loadstart", "loadedmetadata", "canplay", "play", "playing", "pause", "waiting", "stalled",
    "seeked", "ended", "error", "abort", "emptied", "ratechange", "volumechange", "resize", "encrypted", "webkitneedkey",
    "webkitbeginfullscreen", "webkitendfullscreen", "webkitpresentationmodechanged", "enterpictureinpicture", "leavepictureinpicture"]) {
    document.addEventListener(type, (e) => {
      const m = e.target;
      if (!(m instanceof HTMLMediaElement)) return;
      const d = { event: type, media: mediaInfo(m) };
      if (type === "encrypted") d.initDataType = e.initDataType;
      if (type === "webkitpresentationmodechanged") d.mode = m.webkitPresentationMode;
      send("media", d);
    }, true);
  }

  // DRM requests.
  wrap(navigator, "requestMediaKeySystemAccess", (original) => function (keySystem, configs) {
    send("drm", { step: "request", keySystem, configs: clip(configs, 400) });
    return original.apply(this, arguments).then(
      (access) => { send("drm", { step: "granted", keySystem: access.keySystem }); return access; },
      (error) => { send("drm", { step: "denied", keySystem, error: clip(error && (error.name + ": " + error.message)) }); throw error; });
  });
  if (window.WebKitMediaKeys) {
    wrap(window.WebKitMediaKeys, "isTypeSupported", (original) => function (keySystem, type) {
      const ok = original.apply(this, arguments);
      send("drm", { step: "WebKitMediaKeys.isTypeSupported", keySystem, type, ok });
      return ok;
    });
  }

  // Fullscreen.
  for (const type of ["fullscreenchange", "webkitfullscreenchange", "fullscreenerror", "webkitfullscreenerror"]) {
    document.addEventListener(type, () => send("fullscreen", { event: type, element: describe(document.fullscreenElement || document.webkitFullscreenElement) }), true);
  }

  // Player controls — layout research (intent 261125-cinema-center-controls). Main frame only.
  // The player is the fullscreen element (mode "fullscreen") or, in the normal window, `#playerPage` once tapped (mode "window").
  // "player-outline": the player as a tree — where each part is (r = x,y,w,h), clickable (p), opacity (o) —
  //   1 s after entering fullscreen and 0.7 s after a tap inside it (at most 4 per player/mode).
  // "player-visible": how many of the outline's controls are on screen, logged on every change (shows and auto-hides).
  if (frame === "main") {
    let root = null, mode = "", sampler = null, controls = [], last = -1, tappedAt = 0, outlines = 0, changes = 0;
    const box = (el) => { const r = el.getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)]; };
    const label = (el) => {
      let s = el.tagName.toLowerCase();
      if (el.id) s += "#" + el.id;
      const cls = (el.getAttribute("class") || "").trim();
      if (cls) s += "." + cls.split(/\s+/).slice(0, 3).join(".");
      return s;
    };
    const outline = (el, depth, budget) => {
      if (budget.n <= 0) return null;
      const s = getComputedStyle(el);
      if (s.display === "none") return null;
      budget.n--;
      const node = { e: label(el), r: box(el) };
      if (s.opacity !== "1") node.o = s.opacity;
      if (s.visibility !== "visible") node.v = s.visibility;
      if (s.cursor === "pointer") node.p = 1;
      if (s.position !== "static") node.pos = s.position;
      for (const a of ["role", "aria-label", "title", "alt", "type", "src"]) {
        const v = el.getAttribute(a);
        if (v) node[a] = clip(v, a === "src" ? 80 : 40);
      }
      const own = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent.trim()).join(" ").trim();
      if (own) node.text = clip(own, 30);
      if (s.cursor === "pointer" || /^(BUTTON|INPUT|IMG|SVG)$/.test(el.tagName.toUpperCase())) controls.push(el);
      if (depth < 14) {
        const kids = [];
        for (const c of el.children) { const k = outline(c, depth + 1, budget); if (k) kids.push(k); }
        if (kids.length) node.c = kids;
      }
      return node;
    };
    const dump = (reason) => {
      if (!root || outlines >= 4) return;
      outlines++;
      controls = [];
      const budget = { n: 400 };
      const tree = outline(root, 0, budget);
      send("player-outline", { mode, reason, viewport: innerWidth + "x" + innerHeight, nodes: 400 - budget.n, tree });
      last = -1;
      sample();
    };
    const shown = (el) => {
      if (!el.isConnected) return false;
      const r = el.getBoundingClientRect();
      if (r.width < 1 || r.height < 1) return false;
      for (let n = el; n; n = n.parentElement) {
        const s = getComputedStyle(n);
        if (s.display === "none" || s.visibility === "hidden" || parseFloat(s.opacity) < 0.05) return false;
        if (n === root) break;
      }
      return true;
    };
    const sample = () => {
      if (!root) return;
      if (!root.isConnected) { stop(); return; } // the page left the player
      if (!controls.length) return;
      const n = controls.filter(shown).length;
      if (n === last || changes >= 200) return;
      const was = last < 0 ? null : last;
      last = n;
      changes++;
      const video = root.querySelector("video");
      send("player-visible", { mode, visible: n, of: controls.length, was,
        sinceTap: tappedAt ? Math.round(performance.now() - tappedAt) : null, paused: video ? video.paused : null });
    };
    const stop = () => { clearInterval(sampler); sampler = null; root = null; mode = ""; controls = []; };
    const attach = (el, how) => {
      stop();
      root = el; mode = how; outlines = 0; changes = 0; last = -1; tappedAt = 0;
      sampler = setInterval(sample, 500);
    };
    document.addEventListener("fullscreenchange", () => {
      const el = document.fullscreenElement || document.webkitFullscreenElement;
      if (el && (el !== root || mode !== "fullscreen")) {
        attach(el, "fullscreen");
        setTimeout(() => dump("enter"), 1000);
      } else if (!el && root) {
        stop(); // back in the window: the next tap on the player attaches it again
      }
    }, true);
    addEventListener("pointerdown", (e) => {
      if (!root) {
        const player = document.getElementById("playerPage");
        if (player && player.contains(e.target)) attach(player, "window");
      }
      if (!root || !root.contains(e.target)) return;
      tappedAt = performance.now();
      setTimeout(() => dump("tap"), 700);
    }, true);
  }

  // What the site's 4K check sees (research R6, intent 261125 addition). The site asks
  // navigator.mediaCapabilities.decodingInfo({type: "media-source"}) for HEVC/Dolby Vision 3840×2160 and only then sends
  // "x-support-uhd" with its play request. Measure the same questions (and the "file" answers native HLS would get) once
  // per Coupang Play page, and log the x-support-* headers the site actually sends.
  if (frame === "main" && /(^|\.)coupangplay\.com$/i.test(location.hostname)) {
    const caps = async () => {
      const out = {
        MediaSource: typeof MediaSource, ManagedMediaSource: typeof ManagedMediaSource,
        decodingInfo: !!(navigator.mediaCapabilities && navigator.mediaCapabilities.decodingInfo),
      };
      const configs = [
        ["hevc-2160p60", 'video/mp4; codecs="hvc1.1.6.L153.B0"', 3840, 2160, 3e7, 60],
        ["hevc-2160p30", 'video/mp4; codecs="hvc1.1.6.L150.B0"', 3840, 2160, 15e6, 30],
        ["hevc-1080p60", 'video/mp4; codecs="hvc1.1.6.L123.B0"', 1920, 1080, 1e7, 60],
        ["dv-2160p30", 'video/mp4; codecs="dvh1.05.01"', 3840, 2160, 15e6, 30],
        ["avc-1080p30", 'video/mp4; codecs="avc1.640028"', 1920, 1080, 8e6, 30],
      ];
      for (const type of ["media-source", "file"]) {
        for (const [name, contentType, width, height, bitrate, framerate] of configs) {
          let answer;
          try {
            const r = await navigator.mediaCapabilities.decodingInfo({ type, video: { contentType, width, height, bitrate, framerate } });
            answer = r.supported ? (r.smooth ? "smooth" : "yes") : "no";
          } catch (e) { answer = "error " + e.name; }
          out[type + " " + name] = answer;
        }
      }
      try { out["MSE hvc1"] = MediaSource.isTypeSupported('video/mp4; codecs="hvc1.1.6.L123.B0"'); } catch (e) { out["MSE hvc1"] = "error " + e.name; }
      const v = document.createElement("video");
      out["canPlay hls"] = v.canPlayType("application/vnd.apple.mpegurl");
      out["canPlay hvc1"] = v.canPlayType('video/mp4; codecs="hvc1.1.6.L153.B0"');
      out["canPlay dvh1"] = v.canPlayType('video/mp4; codecs="dvh1.05.01"');
      const mq = (q) => { try { return matchMedia(q).matches; } catch (_) { return "error"; } };
      out["dynamic-range high"] = mq("(dynamic-range: high)");
      out["video-dynamic-range high"] = mq("(video-dynamic-range: high)");
      out["color-gamut p3"] = mq("(color-gamut: p3)");
      out.screen = screen.width + "x" + screen.height + " dpr " + devicePixelRatio + " depth " + screen.colorDepth;
      send("video-caps", out);
    };
    addEventListener("load", () => setTimeout(caps, 1500), { once: true });

    const header = (name, value, url) => {
      if (/^x-support-/i.test(name)) send("play-header", { url: clip(String(url).split("?")[0], 160), name, value: clip(String(value), 60) });
    };
    if (window.XMLHttpRequest) {
      wrap(XMLHttpRequest.prototype, "open", (original) => function (method, url) {
        this.__cpvpUrl = url;
        return original.apply(this, arguments);
      });
      wrap(XMLHttpRequest.prototype, "setRequestHeader", (original) => function (name, value) {
        header(name, value, this.__cpvpUrl || "");
        return original.apply(this, arguments);
      });
    }
    // The play response, cut down to quality-like fields (research R6): which stream the server picked and why.
    // Only scalar values under quality-like keys; URLs keep host + path; long token-looking strings are dropped.
    const QUALITY_KEY = /resol|quality|uhd|hevc|codec|hdr|range|height|width|profile|format|stream|type|bitrate|max|tier|feature|support|required|enabled/i;
    const summarize = (value, path, out, depth) => {
      if (out.length >= 80 || depth > 7 || value == null) return;
      if (Array.isArray(value)) { value.slice(0, 12).forEach((v, i) => summarize(v, `${path}[${i}]`, out, depth + 1)); return; }
      if (typeof value === "object") { for (const k of Object.keys(value)) summarize(value[k], path ? `${path}.${k}` : k, out, depth + 1); return; }
      if (!QUALITY_KEY.test(path.split(".").pop())) return;
      let v = String(value);
      if (/^https?:\/\//.test(v)) { try { const u = new URL(v); v = u.host + u.pathname; } catch (_) {} }
      else if (v.length > 60 || /[A-Za-z0-9_-]{32,}/.test(v)) return;
      out.push(`${path}=${clip(v, 120)}`);
    };
    const isPlay = (url) => /\/api\/playback\/play(?:[?#]|$)/.test(String(url || ""));
    wrap(window, "fetch", (original) => function (input, init) {
      let url = "";
      try {
        url = typeof input === "string" ? input : (input && input.url) || "";
        const h = (init && init.headers) || (input && input.headers);
        if (h) {
          if (Array.isArray(h)) for (const [name, value] of h) header(name, value, url);
          else if (typeof h.forEach === "function") h.forEach((value, name) => header(name, value, url));
          else for (const name of Object.keys(h)) header(name, h[name], url);
        }
      } catch (_) {}
      const result = original.apply(this, arguments);
      if (isPlay(url) && result && result.then) {
        result.then((response) => response.clone().json()).then((json) => {
          const fields = [];
          summarize(json, "", fields, 0);
          send("play-response", { fields });
        }).catch(() => {});
      }
      return result;
    });

    // The stream list (HLS master playlist) of each long video (> 5 min, so not ads or previews): which resolutions,
    // codecs and dynamic ranges the server offers — tells "no 4K offered" apart from "4K offered but not picked".
    const listed = new Set();
    const variants = async (m) => {
      const src = m.currentSrc || m.src || "";
      if (!src || src.startsWith("blob:") || listed.has(src) || !(m.duration > 300)) return;
      listed.add(src);
      const info = {};
      try { const u = new URL(src); info.host = u.host; info.path = clip(u.pathname, 120); info.query = [...u.searchParams.keys()].join(","); } catch (_) {}
      const read = async (credentials) => {
        const r = await fetch(src, { credentials });
        info["status " + credentials] = r.status;
        return r.ok ? r.text() : null;
      };
      try {
        const text = (await read("same-origin").catch(() => null)) || (await read("include"));
        if (text) {
          const lines = text.split(/\r?\n/);
          const pick = (line, names) => {
            const out = {};
            for (const [, k, v] of line.matchAll(/([A-Z0-9-]+)=("[^"]*"|[^,]*)/g)) if (names.includes(k)) out[k] = v.replace(/"/g, "");
            return Object.entries(out).map(([k, v]) => `${k}=${v}`).join(" ");
          };
          const NAMES = ["RESOLUTION", "CODECS", "SUPPLEMENTAL-CODECS", "BANDWIDTH", "FRAME-RATE", "VIDEO-RANGE", "HDCP-LEVEL"];
          info.variants = lines.filter((l) => l.startsWith("#EXT-X-STREAM-INF:")).map((l) => pick(l, NAMES)).slice(0, 40);
          info.iframes = lines.filter((l) => l.startsWith("#EXT-X-I-FRAME-STREAM-INF:")).length;
          info.audio = lines.filter((l) => l.startsWith("#EXT-X-MEDIA:") && l.includes("TYPE=AUDIO")).length;
          info.keyFormats = [...new Set(lines.filter((l) => /^#EXT-X-(SESSION-)?KEY:/.test(l)).map((l) => pick(l, ["KEYFORMAT"])))].join(" | ");
          if (!info.variants.length) info.head = clip(lines.filter((l) => l.startsWith("#")).slice(0, 6).join(" / "), 300);
        }
      } catch (e) { info.error = clip(e.name + ": " + e.message, 120); }
      send("variants", info);
    };
    document.addEventListener("loadedmetadata", (e) => { if (e.target instanceof HTMLVideoElement) variants(e.target); }, true);
  }

  // New windows.
  wrap(window, "open", (original) => function (url, target) {
    send("window-open", { url: clip(String(url || ""), 300), target: target || "" });
    return original.apply(this, arguments);
  });

  // Page lifecycle + what the site's device detection sees (research R2).
  document.addEventListener("DOMContentLoaded", () => {
    send("lifecycle", { event: "DOMContentLoaded", title: document.title });
    send("identity", {
      maxTouchPoints: navigator.maxTouchPoints, platform: navigator.platform,
      ontouchstart: "ontouchstart" in window, standalone: "standalone" in navigator,
      ua: navigator.userAgent, viewport: innerWidth + "x" + innerHeight, dpr: devicePixelRatio,
    });
    startObserver();
  });
  addEventListener("load", () => send("lifecycle", { event: "load", title: document.title }));
  addEventListener("pageshow", (e) => send("lifecycle", { event: "pageshow", persisted: e.persisted }));
  addEventListener("pagehide", () => send("lifecycle", { event: "pagehide" }));
  document.addEventListener("visibilitychange", () => send("lifecycle", { event: "visibility", state: document.visibilityState }));
})();
