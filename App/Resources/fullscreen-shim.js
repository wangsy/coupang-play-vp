// Handles the page's fullscreen requests inside the page instead of WebKit's fullscreen window (cinema spec C1, decision D3).
// visionOS WebKit's element fullscreen shrinks the app window to a small fixed size; here the element fills the
// window instead and the app makes the window big and the room dark.
// Main frame only, document start.
(() => {
  if (window.__cpvpFullscreenShim) return;
  Object.defineProperty(window, "__cpvpFullscreenShim", { value: true });
  const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cpvpFullscreen;
  const post = (state) => { try { handler && handler.postMessage({ state }); } catch (_) {} };

  const ATTR = "data-cpvp-fullscreen";
  const ROOT_ATTR = "data-cpvp-fullscreen-root";
  const css = `
    [${ATTR}] {
      position: fixed !important; inset: 0 !important; top: 0 !important; left: 0 !important;
      width: 100vw !important; height: 100vh !important; max-width: none !important; max-height: none !important;
      min-width: 0 !important; min-height: 0 !important; margin: 0 !important; padding: 0 !important;
      transform: none !important; border: 0 !important; border-radius: 0 !important;
      z-index: 2147483647 !important; background: #000 !important; box-sizing: border-box !important;
    }
    [${ATTR}] video { object-fit: contain !important; }
    html[${ROOT_ATTR}], html[${ROOT_ATTR}] body { overflow: hidden !important; }
  `;
  const ensureStyle = () => {
    if (document.getElementById("cpvp-fullscreen-style")) return;
    const style = document.createElement("style");
    style.id = "cpvp-fullscreen-style";
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);
  };

  let current = null;
  const fire = (target) => {
    for (const type of ["fullscreenchange", "webkitfullscreenchange"]) {
      const node = target && target.isConnected ? target : document;
      node.dispatchEvent(new Event(type, { bubbles: true }));
    }
  };
  const enter = (el) => {
    if (!(el instanceof Element)) return;
    if (current === el) return;
    if (current) current.removeAttribute(ATTR);
    ensureStyle();
    current = el;
    el.setAttribute(ATTR, "");
    document.documentElement.setAttribute(ROOT_ATTR, "");
    fire(el);
    post("enter");
  };
  const exit = () => {
    if (!current) return;
    const old = current;
    current = null;
    old.removeAttribute(ATTR);
    document.documentElement.removeAttribute(ROOT_ATTR);
    fire(old);
    post("exit");
  };
  Object.defineProperty(window, "__cpvpExitFullscreen", { value: exit });

  const nativeLike = (fn, name) => {
    try { Object.defineProperty(fn, "name", { value: name }); } catch (_) {}
    try { Object.defineProperty(fn, "toString", { value: () => `function ${name}() {\n    [native code]\n}` }); } catch (_) {}
    return fn;
  };
  const method = (proto, name, fn) => {
    try { Object.defineProperty(proto, name, { value: nativeLike(fn, name), configurable: true, writable: true }); } catch (_) {}
  };
  const getter = (proto, name, get) => {
    try { Object.defineProperty(proto, name, { get, configurable: true, enumerable: true }); } catch (_) {}
  };

  method(Element.prototype, "requestFullscreen", function () { enter(this); return Promise.resolve(); });
  method(Element.prototype, "webkitRequestFullscreen", function () { enter(this); });
  method(Element.prototype, "webkitRequestFullScreen", function () { enter(this); });
  method(Document.prototype, "exitFullscreen", function () { exit(); return Promise.resolve(); });
  method(Document.prototype, "webkitExitFullscreen", function () { exit(); });
  method(Document.prototype, "webkitCancelFullScreen", function () { exit(); });

  for (const name of ["fullscreenElement", "webkitFullscreenElement", "webkitCurrentFullScreenElement"]) {
    getter(Document.prototype, name, () => current);
  }
  for (const name of ["fullscreen", "webkitIsFullScreen"]) getter(Document.prototype, name, () => !!current);
  for (const name of ["fullscreenEnabled", "webkitFullscreenEnabled", "webkitFullScreenKeyboardInputAllowed"]) {
    getter(Document.prototype, name, () => true);
  }

  addEventListener("keydown", (e) => { if (current && e.key === "Escape") exit(); }, true);
  // A page navigation (or the element leaving the DOM) ends fullscreen, as in a browser.
  addEventListener("pagehide", () => { if (current) { current = null; post("exit"); } });
  const watch = new MutationObserver(() => { if (current && !current.isConnected) exit(); });
  const startWatch = () => watch.observe(document.documentElement, { childList: true, subtree: true });
  if (document.documentElement) startWatch(); else document.addEventListener("DOMContentLoaded", startWatch);
})();
