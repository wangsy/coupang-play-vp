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
- 14:2x KST 사용자 보고: 전체화면 중 창 아래 **창 닫기**를 누르면 검은 몰입 공간만 남고 컨트롤이 없어 크라운으로만 나올 수 있다.
  원인: 창이 닫혀도 몰입 공간은 그대로 열려 있음. 수정(spec C2, 결정 D4): 창의 `onDisappear` → `browserWindowIsOpen = false` →
  `CinemaSpace`가 몰입 공간을 닫는다 → 남는 장면이 없어 앱이 끝난다(페이지 전체화면은 `exitCinemaFromSystem`으로 끝).
  창 닫기·몰입 공간은 단위 테스트로 잡을 수 없어 재현 절차로 대신한다: 재생 → 전체화면 → 창 닫기 → 검은 화면이 남지 않고 방이 보여야 함,
  로그 `[ui] window closed (cinema on, space open)` → `[media] window closed during cinema → close cinema space` → `cinema space disappeared`.
  14:21 KST(로그) 시뮬레이터 "17 tests in 7 suites passed". 사용자 **D5** 기기 확인 대기.
- 14:32 KST(기기 로그 `device-1421`) D5 1회차 실패: 창 닫기 → `scene inactive` → `scene background`(14:32:18)만 오고 `onDisappear`는 안 옴 →
  몰입 공간이 남음(14:32:25 크라운으로 닫힘). 창 닫기는 창 장면을 background로 보낼 뿐이다 → 판정을 `scenePhase == .background`로 바꿈(결정 D4 갱신).
- 14:33 KST(로그) 시뮬레이터 "17 tests in 7 suites passed". 14:33:51 기기 설치·실행.
- 14:34 KST(기기 로그 `device-1434`) D5 2회차: 전체화면(14:34:03) → 창 닫기 → `scene background` → `window closed (cinema on, space open)` →
  `window closed during cinema → close cinema space` → `cinema space disappeared`(14:34:09) → 페이지 전체화면 끝. 사용자 체감 확인 대기.
- 사용자: "전체화면에서 바로 앱 종료는 이상하다. 전체화면 종료로 해 달라" → 창 닫기 = 창 다시 열기 + 몰입 공간 닫기(결정 D4 갱신, spec C2·D5 갱신).
  창 닫힘 신호를 Bool에서 카운터로 바꿈.
- 14:36 KST(로그) 시뮬레이터 "17 tests in 7 suites passed". 기기 설치·실행.
- 14:36:47–54 KST(기기 로그 `device-1436`) D5 3회차: 전체화면 → 창 닫기 → `scene background` → `window closed (cinema on, space open)` →
  `reopen window, close cinema space` → `scene active`·`window 1280x800`(0.12초 뒤) → `cinema space disappeared` → `cinema page exit` → `cinema exit`.
  사용자 체감 확인 대기.
- 14:36:57 KST(같은 로그) 다시 전체화면 → `cinema enter` 2번·`cinema space open: error` 1번(앞의 `cinema exit`도 2번). 다시 연 창 + background에 남은 옛 창,
  두 `ContentView`가 모두 `isCinema`에 반응. 옛 창의 기억 크기(2560x1360)로 복원될 위험 → background 창의 `setCinema`는 건너뜀.
- 14:37:14 KST(같은 로그) 위험이 실제로 남: 창 닫기 → 전체화면 끝 → `window 1280x800` 뒤 `window 2560x1360`(옛 창이 기억 크기로 되돌림).
  14:38 KST(로그) background 건너뛰기 수정 후 시뮬레이터 "17 tests in 7 suites passed".
- 14:38:31 KST(기기 로그 `device-1439`) 수정본 설치·실행: 시작 시 `scene active` 2번·창 2개 크기 로그 — 이전 실행에서 생긴 창 2개를 시스템이 되살린 것으로 보임.
  사용자가 둘 다 닫음(14:38:38·39). **열린 문제**: 다시 연 창이 옛 창을 대신하지 않고 하나 더 생겨 남는지. D5(반복 2회 — 처리 1번, 창 1280x800 복원) 기기 확인 대기.
