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
    ready: m.readyState, network: m.networkState, paused: m.paused, muted: m.muted,
    size: m.videoWidth ? m.videoWidth + "x" + m.videoHeight : undefined,
    error: m.error ? { code: m.error.code, message: m.error.message } : undefined,
  });
  for (const type of ["loadstart", "loadedmetadata", "canplay", "play", "playing", "pause", "waiting", "stalled",
    "seeked", "ended", "error", "abort", "emptied", "ratechange", "encrypted", "webkitneedkey",
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
