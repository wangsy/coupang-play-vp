// Runs at document start in every frame (spec S2, research R2, R5).
// The site treats "MacIntel + touch points" as an iPad and sends the login button to the App Store.
// Hide the *presence* of touch; touch/pointer events themselves still fire, so gaze + pinch keeps working.
(() => {
  // Only when the top-level page is Coupang Play (spec S2). Other sites (the Coupang login) see an iPad,
  // so leave their touch values alone — the UA says iPad there.
  const topHost = (() => {
    try {
      const a = location.ancestorOrigins;
      if (a && a.length) return new URL(a[a.length - 1]).hostname;
    } catch (_) {}
    return location.hostname;
  })().toLowerCase();
  if (!(topHost === "coupangplay.com" || topHost.endsWith(".coupangplay.com"))) return;

  const define = (target, key, value) => {
    try {
      Object.defineProperty(target, key, { get: () => value, configurable: true, enumerable: true });
    } catch (_) {}
  };
  const remove = (target, key) => {
    if (!target) return;
    try { delete target[key]; } catch (_) {}
  };

  define(Navigator.prototype, "maxTouchPoints", 0);
  define(Navigator.prototype, "platform", "MacIntel");

  remove(navigator, "standalone");
  remove(Navigator.prototype, "standalone");

  const touchHandlers = ["ontouchstart", "ontouchmove", "ontouchend", "ontouchcancel"];
  const targets = [
    window,
    typeof Window !== "undefined" && Window.prototype,
    typeof Document !== "undefined" && Document.prototype,
    typeof Element !== "undefined" && Element.prototype,
    typeof HTMLElement !== "undefined" && HTMLElement.prototype,
    typeof SVGElement !== "undefined" && SVGElement.prototype,
    typeof MathMLElement !== "undefined" && MathMLElement.prototype,
  ];
  for (const target of targets) {
    for (const key of touchHandlers) remove(target, key);
  }
})();
