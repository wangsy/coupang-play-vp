# Plan — 재생 화면 가운데 컨트롤

spec: `spec.md`, 결정: `decisions.md` (사용자 "한 번에 구현", 2026-11-25)

## 바꿀 파일

| 파일 | 무엇 | spec |
|---|---|---|
| `App/Resources/center-controls.js` (새) | 가운데 층: 붙이기, 버튼, 대신 누르기·직접 하기, 보이기 규칙, 기록 | P1–P5 |
| `App/Browser/WebViewFactory.swift` | `center-controls.js`를 주 프레임·문서 시작에 넣기 | P1 |
| `App/Browser/BrowserModel.swift` | `player-center` 이벤트 때 스크린숏 | P5 |
| `Tests/CoupangPlayVPTests/CenterControlsTests.swift` (새) | 가짜 사이트 플레이어로 A2 | A2 |
| `CLAUDE.md` | 구성 표, 테스트 수 | |
| `App/Resources/center-controls.js`, `page-events.js` (추가) | 멈췄을 때 해상도 한 줄, 기록에 `size`, 영상 `resize` 이벤트 기록 | P5, P6 |
| `Tests/CoupangPlayVPTests/CenterControlsTests.swift` (추가) | 크기별 해상도 글자, 재생 중 숨김 | A2 |

(조사용 관찰 코드 `page-events.js`·`PlayerProbeTests`는 research R3에서 이미 넣었다.)

## 순서와 검증

1. `center-controls.js` + `WebViewFactory` 주입 + `CenterControlsTests` → 시뮬레이터 `xcodebuild test`(A1·A2).
2. `BrowserModel` 스크린숏 → 빌드.
3. 실기기 배포(`scripts/device-run.sh`), 실시간 로그로 `player-center` 확인. 스크린숏으로 배치를 본다. 그다음 사용자에게 D1–D6을 넘긴다.

## 위험

- 사이트가 합성 click을 무시할 수 있다 → DC7의 직접 하기, 기록 `via`로 본다.
- 가운데 층이 사이트 탭 층(멈춤/재생 토글)과 겹쳐 두 번 바뀔 수 있다 → 버튼 click 전파 막기, 나타난 뒤 0.35초 무장 지연(DC4).
- 시뮬레이터에는 DRM 재생이 없어 실제 플레이어 동작은 기기에서만 판정한다.

## 실행 기록
- 2026-11-25 20:39–20:45 KST(기기 로그 `device-2040`) 관찰 빌드로 사이트 플레이어 구조·숨김 시간을 쟀다(research R4).
- 사용자 "한 번에 구현" → spec·decisions·plan 작성, `center-controls.js`·주입·`CenterControlsTests` 구현.
- 20:53 KST(`date`) 첫 시뮬레이터 테스트에서 `CenterControlsTests` 1건 실패: 처음부터 층이 보였다.
  원인은 `lastTap` 초기값 0이었다. 페이지가 열린 뒤 3초 동안 "방금 탭함"으로 판정됐다 → `-Infinity`로 고쳤다(테스트는 그대로).
- 20:54 KST(`date`) 시뮬레이터 "27 tests in 9 suites passed"(A1·A2).
  20:54:42 KST(기기 로그 `device-2055`) 실기기 빌드·설치·실행(A1 실기기 빌드). D1–D6 사용자 확인 대기.
- 20:55–20:58 KST(기기 로그 `device-2055`) 실기기 사용, 사용자: "잘 된다".
  - 층이 `#playerWrapper`에 붙었다(20:55:50).
  - 보통 창 가운데 "전체화면" → 사이트 버튼(`via: site`) → `cinema enter`(20:56:25). **D6**
  - 시네마 가운데 "전체화면 끝내기" → 사이트 버튼 → `cinema exit`(20:57:15). **D3**
  - 멈춘 동안(20:57:13–20:58:06) 보통 창 ↔ 시네마를 오가도 계속 보였다.
    가운데 "재생" → 사이트 버튼 → `play`(20:58:06), 3초 뒤 숨음(20:58:09). **D1·D2**
  - **D4**(10초 뒤로·앞으로, 음소거, 다음화)는 로그에 누른 기록이 없다. **D5**는 사용자 "잘 된다"로 갈음한다.
- 추가 요청(해상도 표시) → intent "추가 요청", research R5, spec P6·D7, 결정 DC9–DC11.
  21:01 KST(`date`) 시뮬레이터 "29 tests in 9 suites passed".
  21:01:54 KST(기기 로그 `device-2103`) 실기기 설치·실행. D7 사용자 확인 대기.
- 사용자 보고: 작품에 "4K" 배지가 있는데 1080p로만 재생된다 → 원인 조사(research R6).
  `page-events.js`에 `video-caps`(사이트와 같은 4K 디코딩 질문)·`play-header`(`x-support-*` 요청 헤더)를 넣고 테스트를 더했다.
  21:32 KST(`date`) 시뮬레이터 "30 tests in 9 suites passed".
  21:33:03 KST(기기 로그 `device-2133`) 실기기 실행. 기기는 4K HEVC·돌비 비전 디코딩 가능, 재생 요청에 `x-support-uhd` 없음
  → 웹 플레이어가 VOD에 4K를 요청하지 않는 것이 원인이다.
- 사용자 "시험해 봐" → `uhd-request.js`, `SiteConfig.requestUHD`, `UHDRequestTests`(spec P7, 결정 DC12).
  21:39 KST(`date`) 테스트 1건 실패: 테스트 코드가 같은 페이지에서 `const x`를 두 번 선언했다 → 블록으로 감쌌다(앱 코드 아님).
  21:41 KST(`date`) 시뮬레이터 "34 tests in 10 suites passed".
  21:41:50 KST(기기 로그 `device-2142`) 실기기 실행. 첫 화면 미리보기 재생 요청에 `x-support-uhd: true`가 붙었고(fetch), 응답은 200이었다.
  미리보기는 1920x1080이었다. D8(4K 배지 작품) 사용자 확인 대기.
- 사용자: 4K 헤더를 붙여도 "계속 1080p"다 → 재생 응답·HLS 목록 관찰 코드(`play-response`·`variants`)를 넣고 테스트를 더했다.
  21:47 KST(`date`) 시뮬레이터 "35 tests in 10 suites passed".
  - `scripts/device-run.sh -startURL …`이 실패했다(21:53, devicectl: `'https://…' is invalid for '-t <seconds>'`).
    devicectl이 앱 인자를 자기 옵션으로 읽은 것이다 → 앱 인자 앞에 `--`를 넣었다(첫 intent 때부터 있던 버그).
  - 21:53:29 KST(기기 로그 `device-2154`) 4K 배지 영화로 바로 열었다.
    재생 응답 `features[0]`: `resolution supported=true enabled=false required=[prime, device]`. 영상은 avc1 SDR만 왔다.
    21:54:02 HLS 목록 최고는 1920x1080 H.264였고 4K 항목은 없었다 → **D8 실패.** 사용자 확인: 계정이 Prime이 아니다.
  - `SiteConfig.requestUHD = false`로 실험을 껐다. 21:57 KST(`date`) 시뮬레이터 "35 tests in 10 suites passed".
    21:57:45 KST(기기 로그 `device-2158`) 재생 요청에 `x-support-hevc`만 있고 `x-support-uhd`는 없다(사이트 원래대로).
- 사용자 요청: "영상 해상도 표시는 컨트롤이 보이는 동안은 항상 보이도록" → `infoOn`을 멈춤 조건 없이 바꿨다(spec P6·D7, 결정 DC10 갱신).
  테스트 `resolutionHiddenWhilePlaying`을 `resolutionShowsWhilePlayingToo`로 바꿨다.
  22:17 KST(`date`) 시뮬레이터 "35 tests in 10 suites passed". 22:18:13 KST(기기 로그 `device-2218`) 실기기 설치·실행. D7 사용자 확인 대기.
