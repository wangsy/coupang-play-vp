// EXPERIMENT (intent 261125-cinema-center-controls, research R6, decision DC12): ask for 4K on every play request.
// The site's web player sends "x-support-uhd" only for live content, even when the device can decode 4K HEVC / Dolby Vision
// (it can — research R6). This adds "x-support-uhd: true" to POST /api/playback/play when the site already says
// "x-support-hevc: true" and did not ask for UHD itself. Whether the server then sends 4K is up to the server.
// Main frame only, document start, Coupang Play only. Turned off with SiteConfig.requestUHD = false.
(() => {
  if (window.__cpvpUhd) return;
  Object.defineProperty(window, "__cpvpUhd", { value: true });
  const host = location.hostname.toLowerCase();
  if (!(host === "coupangplay.com" || host.endsWith(".coupangplay.com"))) return;

  const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cpvp;
  const report = (data) => {
    try { handler && handler.postMessage(Object.assign({ kind: "player-uhd", frame: "main", href: location.href }, data)); } catch (_) {}
  };
  const isPlay = (url) => /\/api\/playback\/play(?:[?#]|$)/.test(String(url || ""));
  const path = (url) => String(url || "").split("?")[0];
  const nativeLike = (fn, original) => {
    try { Object.defineProperty(fn, "toString", { value: () => original.toString() }); } catch (_) {}
    return fn;
  };

  // XHR: remember the URL and the headers the site sets; add ours just before sending.
  const proto = window.XMLHttpRequest && XMLHttpRequest.prototype;
  if (proto) {
    const open = proto.open, setHeader = proto.setRequestHeader, send = proto.send;
    proto.open = nativeLike(function (method, url) {
      this.__cpvpUhdUrl = url;
      this.__cpvpUhdHeaders = {};
      return open.apply(this, arguments);
    }, open);
    proto.setRequestHeader = nativeLike(function (name, value) {
      if (this.__cpvpUhdHeaders) this.__cpvpUhdHeaders[String(name).toLowerCase()] = String(value);
      return setHeader.apply(this, arguments);
    }, setHeader);
    proto.send = nativeLike(function () {
      try {
        const h = this.__cpvpUhdHeaders || {};
        if (isPlay(this.__cpvpUhdUrl) && h["x-support-hevc"] === "true" && !("x-support-uhd" in h)) {
          this.setRequestHeader("x-support-uhd", "true"); // through any other wrapper, so page-events logs it too
          const url = path(this.__cpvpUhdUrl);
          report({ event: "added", via: "xhr", url });
          this.addEventListener("loadend", () => report({ event: "response", via: "xhr", url, status: this.status }), { once: true });
        }
      } catch (_) {}
      return send.apply(this, arguments);
    }, send);
  }

  // fetch: rebuild the headers with ours added.
  if (typeof window.fetch === "function") {
    const original = window.fetch;
    window.fetch = nativeLike(function (input, init) {
      try {
        const url = typeof input === "string" ? input : input && input.url;
        if (isPlay(url)) {
          const headers = new Headers((init && init.headers) || (input instanceof Request ? input.headers : undefined));
          if (headers.get("x-support-hevc") === "true" && !headers.has("x-support-uhd")) {
            headers.set("x-support-uhd", "true");
            report({ event: "added", via: "fetch", url: path(url) });
            return original.call(this, input, Object.assign({}, init, { headers })).then((response) => {
              report({ event: "response", via: "fetch", url: path(url), status: response.status });
              return response;
            });
          }
        }
      } catch (_) {}
      return original.apply(this, arguments);
    }, original);
  }
})();
