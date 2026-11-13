# Plan — 시네마 모드

spec: `spec.md` · 결정: `decisions.md`

## 바꿀 파일

| 파일 | 무엇 | spec |
|---|---|---|
| `App/Resources/fullscreen-shim.js` | 전체화면 흉내 | C1 |
| `App/Browser/WebViewFactory.swift` | shim 주입(주 프레임, 문서 시작), `cpvpFullscreen` 핸들러 연결 | C1 |
| `App/Browser/FullscreenBridge.swift` | `cpvpFullscreen` 메시지 → 모델 | C1 |
| `App/Browser/BrowserModel.swift` | `isCinema` 상태, `exitCinemaFromSystem()` | C1, C2 |
| `App/Browser/SiteConfig.swift` | `cinemaWindowSize` | C2 |
| `App/Cinema/CinemaSpace.swift` | 몰입 공간 내용(검은 구) | C2 |
| `App/CoupangPlayVPApp.swift` | 모델을 앱에서 소유, `ImmersiveSpace("cinema")` | C2 |
| `App/ContentView.swift` | `isCinema` 변화 → 창 크기·몰입 공간·오너먼트 | C2, C3 |
| `Tests/CoupangPlayVPTests/FullscreenShimTests.swift` | A2 | |

## 순서와 검증

1. shim + 브리지 + 테스트 → 시뮬레이터 `xcodebuild test` (A1·A2).
2. 시네마(앱 쪽) → 빌드 통과.
3. 실기기 배포(`scripts/device-run.sh`), 로그 지켜보기 → 사용자 D1–D4. 앱 스크린숏으로 전체화면 모양 확인(E1).

## 위험

- 사이트가 `:fullscreen`에 기대 컨트롤을 배치하면 모양이 어긋난다(E1) — 기기 스크린숏으로 확인.
- 창 크기 한도(E2) — 로그로 실제 크기 확인.

## 실행 기록
- 2026-11-13 12:2x KST intent·spec·plan·decisions 작성(사용자 "구현하라" — 승인 없이 이어 감). 직전에 첫 intent 작업을 커밋(`510c03f`).
- 12:26 KST(로그) `fullscreen-shim.js`·`FullscreenBridge`·`CinemaSpace`·창 크기 전환 구현, 시뮬레이터 "17 tests in 7 suites passed"(A1·A2).
- 12:27 KST(기기 로그) 실기기 설치·실행, `/home` 로그인 유지 상태로 뜸. D1–D4 사용자 확인 대기.
- 12:29·12:31 KST(기기 크래시 리포트 `CoupangPlayVP-2026-11-13-122956/123141.ips`) 시네마 빌드가 실행 직후 첫 터치에서 크래시:
  `NSInvalidArgumentException -[__NSArrayM insertObject:atIndex:]: object cannot be nil` ← `-[UIGestureRecognizer _delayTouchesForEvent:inPhase:]`.
  이 빌드에서 모델(WKWebView)을 `App.init`(= `UIApplicationMain` 전)에서 만들도록 바꿨다 → 장면 내용에서 처음 쓸 때 만드는 `BrowserHolder`로 되돌림.
  12:16 KST 리포트(`121648.ips`)는 다른 원인: 실시간 로그 연결이 끊긴 뒤 stdout 쓰기가 ObjC 예외(`-[NSConcreteFileHandle writeData:]`) → `SIGPIPE` 무시 + `write(contentsOf:)`.
  12:33 KST(로그) 테스트 17개 통과, 12:34 KST 기기 설치·실행.
- 12:34–12:35 KST(기기 로그 `261113-123410`, 스크린숏 `snap-006-cinema-enter`) 실기기 시네마 1회차 — 크래시 없음(이전 크래시 수정 확인):
  전체화면 클릭 → `cinema page enter` → 창 2560x1440 요청, 시스템이 **2560x1360**을 줌(spec E2) → 몰입 공간 `opened` → 페이지 2560x1360(창 전체).
  플레이어 나가기 → `cinema exit` → 몰입 공간 닫힘 → 창·페이지 1280x800 복원. 스크린숏: 컨트롤이 창 폭 전체에 배치(영상은 DRM이라 스크린숏에서 검정).
  아이콘 둘이 흰 사각형으로 찍힘(실제 화면 여부 확인 필요). D1–D3 사용자 체감 판정·D4(크라운) 대기.
- 사용자 판정: **D1 OK**(주변 까맣게, 영상 크게).
- 12:38 KST(기기 로그 `261113-123757`) **D2** — 전체화면 중 일시정지 클릭 → `pause`, 다시 → `play`. **D4** — 크라운으로 몰입 종료 →
  `cinema space disappeared` → `cinema closed by system → exit page fullscreen` → `fullscreenchange`(null) → 창 1280x800 복원. 사용자: "다 잘 된다".
  D1–D4 통과. 크래시 없음.
