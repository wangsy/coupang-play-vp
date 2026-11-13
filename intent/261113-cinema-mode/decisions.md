# Decisions — 시네마 모드

사용자가 "구현하라"고 해서 에이전트가 정했다. 사용자가 나중에 검토한다.

## D1. 주변을 까맣게: 몰입 공간(progressive, 처음 100%) + 검은 구
- 결정: `ImmersiveSpace("cinema")`에 사용자를 둘러싼 큰 검은 구(안쪽 면, unlit)를 두고 `.progressive(0.0...1.0, initialAmount: 1.0)`로 연다. 웹 창은 그 앞에 그대로 떠 있다.
- 이유: "배경이 까맣게"를 확실히 만든다. progressive라 디지털 크라운으로 어둠을 줄여 방(손·음료)을 볼 수 있다.
- 버린 대안: 창에 `preferredSurroundingsEffect(.ultraDark)`만 — 패스스루를 어둡게만 하고 까맣게는 안 되며 창에서 효과가 나는지 불확실.
  `.full` — 크라운으로 조절할 수 없다. 영상을 RealityKit 화면에 띄우기 — DRM 영상이 그려지는지 불확실하고 사이트 컨트롤을 잃는다.
- 바꾸는 법: `CinemaSpace.swift`의 immersion style·구 색. 어둡게만 하려면 구를 빼고 `.mixed` + `.preferredSurroundingsEffect(.ultraDark)`.

## D2. 창 크기 2560×1440pt
- 결정: 시네마에 들어가면 창을 2560×1440pt(16:9)로 요청한다. 시스템이 더 작게 주면 그 크기를 받아들인다(로그).
- 이유: 기본 1280×800의 두 배 폭 — 기본 거리에서 시야를 거의 채운다. 사용자가 "눈에 꽉 찬 크기"를 원했다.
- 바꾸는 법: `SiteConfig.cinemaWindowSize`.

## D3. 사이트의 전체화면을 앱이 대신한다 (WebKit 전체화면을 쓰지 않음)
- 결정: 주 프레임에 `fullscreen-shim.js`를 넣어 `requestFullscreen` 등을 가로챈다.
- 이유: visionOS WebKit의 요소 전체화면은 창을 작은 고정 크기로 바꾸고 앱이 크기·주변을 조절할 길이 없다(이전 intent 기기 로그).
- 버린 대안: `isElementFullscreenEnabled = false` — 사이트가 전체화면 버튼을 숨기거나 영상만의 기본 전체화면으로 가 사이트 컨트롤을 잃을 수 있다.
- 남는 것: 사이트 CSS의 `:fullscreen` 규칙은 적용되지 않는다(spec E1).
- 바꾸는 법: `WebViewFactory`에서 `fullscreen-shim.js`를 빼면 WebKit 전체화면으로 돌아간다.
