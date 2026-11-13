# Plan — Vision Pro에서 쿠팡플레이 웹으로 로그인해 첫 영상 재생까지

spec: `spec.md` (P1 `Version/26.0`, P2 Inspector 항상, P3 막기)

## 바꿀 파일

| 파일 | 무엇 | spec |
|---|---|---|
| `App/CoupangPlayVPApp.swift` | `WindowGroup` 기본 크기 1280×800 | S1 |
| `App/ContentView.swift` | 웹 화면 + 아래 오너먼트(뒤로·새로고침·홈) + 로드 실패 문구 | S7, S8 |
| `App/Browser/SiteConfig.swift` | 상수: 시작 URL, Mac UA(P1), 막을 호스트 | S2, S3 |
| `App/Browser/NavigationPolicy.swift` | `decide(url) -> .allow / .block(reason)` — WebKit 없는 순수 함수 | S3 |
| `App/Browser/WebViewFactory.swift` | `WKWebViewConfiguration` 만들기(앱·테스트 공용): 사용자 스크립트, 데스크톱 모드, inline 재생, 영구 저장소, Inspector | S2, S5, S6, S8 |
| `App/Browser/BrowserModel.swift` | `@Observable`: `WKWebView` 보유, `canGoBack`, 오류 상태, navigation·UI delegate(S3 적용, 새 창 → 같은 화면) | S3, S4 |
| `App/Browser/WebView.swift` | `UIViewRepresentable` 래퍼 | S1 |
| `App/Resources/mac-disguise.js` | 문서 시작·모든 프레임에서 S2 값 덮어쓰기 | S2 |
| `Tests/CoupangPlayVPTests/NavigationPolicyTests.swift` | A3 | |
| `Tests/CoupangPlayVPTests/DisguiseTests.swift` | A2: 로컬 HTML(메인 + `srcdoc` iframe)을 띄워 `evaluateJavaScript`로 값 읽기 | |
| `project.yml` | 앱 타깃 리소스, 단위 테스트 타깃(앱 호스트, swift-testing), 스킴에 test 포함 | |
| `CLAUDE.md` | 테스트·시뮬레이터 실행·스크린숏 명령과 정상 출력, 구성 표 갱신 | |

## 작업 순서와 검증

1. **이동 정책** — `SiteConfig`·`NavigationPolicy` + `NavigationPolicyTests`, `project.yml`에 테스트 타깃.
   - 검증: `xcodebuild test … -destination 'platform=visionOS Simulator,name=Apple Vision Pro'` → A3 통과.
2. **Mac 위장** — `mac-disguise.js` + `WebViewFactory` + `DisguiseTests`.
   - JS: `Navigator.prototype`의 `maxTouchPoints`(→0)·`platform`(→`"MacIntel"`)을 getter로 다시 정의, `standalone`은 지움,
     `ontouchstart/move/end/cancel`은 `window`·`Window`·`Document`·`Element`·`HTMLElement` 프로토타입에서 지움(실패해도 다음으로).
   - 검증: A2 — 메인 프레임과 iframe 모두 `maxTouchPoints === 0`, `platform === "MacIntel"`, `"ontouchstart" in window === false`,
     `"standalone" in navigator === false`, `userAgent`가 SiteConfig 값과 같음.
3. **화면** — `WebView`·`BrowserModel`·`ContentView`·`App`.
   - 검증: A1 시뮬레이터 빌드 성공.
4. **시뮬레이터 실행** — `simctl boot` → `install` → `launch` → 몇 초 뒤 `simctl io … screenshot`.
   첫 화면 스크린숏, 그다음 시작 URL을 `/login`으로 바꾼 실행(실행 인자 `-startURL`, Debug에서만)의 스크린숏.
   - 검증: A4 — 쿠팡플레이 첫 화면 / 웹 로그인 화면(앱 설치 화면 아님). 로그인은 하지 않는다. 스크린숏은 스크래치에만 두고 커밋하지 않는다.
5. **실기기 빌드** — `generic/platform=visionOS` 서명 빌드(A1). Vision Pro가 페어링돼 있으면 `devicectl`로 설치, 아니면 사용자가 Xcode에서 ⌘R.
   - 검증: 사용자에게 D1–D5 체크리스트를 넘기고 결과를 아래 실행 기록에 적는다.
6. 커밋: spec·research·plan과 코드를 함께.

## 위험 요소

- **R-a. `ontouchstart`를 못 지울 수 있다**(WebKit이 고칠 수 없는 속성으로 두면). 2단계 테스트가 바로 잡는다.
  못 지우면 `maxTouchPoints = 0`만으로도 iPad 판정 규칙(R2 표) 셋은 끊긴다 — 남는 것은 `isTouchDevice` 하나라 실기기 D1로 영향을 본다.
- **R-b. 사이트의 다른 판별 신호**(spec E1) — 시뮬레이터 A4가 통과해도 실기기에서 다를 수 있다. Web Inspector(P2)로 찾는다.
- **R-c. 시뮬레이터와 실기기 차이** — 시뮬레이터에는 FairPlay 하드웨어가 없어 재생(D3)은 시뮬레이터로 판정하지 않는다.
- **R-d. 사이트의 봇 방지**가 자동 실행(시뮬레이터 접속)을 막을 수 있다. 막히면 A4를 "확인 못 함"으로 적고 D1로 넘긴다.

## 실행 기록

(구현하면서 쌓는다. 시각은 `date`·로그로 확인한 값만.)
- 2026-11-13 11:40 KST(`date`) 구현 시작. 1~3단계 파일 작성.
- 11:43 KST(로그) `xcodebuild test` 시뮬레이터: "Test run with 5 tests in 2 suites passed"(A2·A3). `ontouchstart` 지우기 동작 — 위험 R-a 해소.
- 11:44 KST(스크린숏) A4 첫 화면: 쿠팡플레이 첫 화면 + 오너먼트. `/login`은 서버가 308로 `/`에 돌려보낸다(Mac UA curl도 같음) → `/login` 스크린숏 방식 대신
  실제 사이트 E2E 시험 `SiteE2ETests`(`CPVP_E2E=1`)로 "시작하기"를 눌러 확인하기로 바꿨다. 결과: 버튼은 `/oauth2/login?…`(웹 로그인), 2 tests passed.
- 11:46 KST(로그·스크린숏) 그 길 끝 `login.coupang.com/login/login.pang`이 **Access Denied**(Akamai). 11:47–11:50 원인 조사 → research R5:
  쿠팡 로그인 서버가 WKWebView의 Mac UA를 거부, iPad UA는 받음. 페이지마다 UA를 바꾸는 시제품으로 로그인 화면까지 확인(임시 시험은 지웠다).
  intent Q4("모두 Mac으로")와 어긋나 **사용자 결정 대기**.
- 11:52 KST(`date`) 사용자 결정: "실기기에서 먼저 확인". 페어링된 Vision Pro에 빌드·설치·실행("Launched application"). 지금 빌드는 모든 도메인을 Mac으로 보인다(Q4 그대로). 사용자 확인 대기.
- 11:53 KST 사용자 요청: 기기에서 일어나는 일을 에이전트가 로그로 직접 추적할 수 있게, 화면의 모든 동작을 기록 → spec S9·A5 추가.
  `App/Diagnostics/{EventLog,LogRedaction,PageEventBridge,Snapshotter}.swift`, `App/Resources/page-events.js`, `BrowserModel`(모든 delegate 기록, alert/confirm/prompt 처리),
  `scripts/{device-run,device-pull}.sh`. 11:58 KST(로그) 단위 테스트 "10 tests in 5 suites passed"
  (처음엔 인코딩된 `%3Fcode%3D`를 못 가려 1건 실패 → 정규식 수정).
- 11:59 KST(기기 로그) `scripts/device-run.sh`로 실기기 설치·실행, stdout 실시간 수신 확인: `launch … visionOS 27.2.1 Apple Vision Pro`, `response main 200`, `commit`, `title → 쿠팡플레이`.
- 11:59 KST(기기 로그 `261113-115904/events.log`) 실기기 결과:
  - **D1 통과** — `[page] main click {"el":{"tag":"button","text":"시작하기"},"x":1178,"y":24}` 뒤 `login.coupang.com/login/login.pang?…platform=PC_WEB…`(앱 설치로 가지 않음).
    기기에서도 identity가 `maxTouchPoints 0 · MacIntel · ontouchstart false`(메인·iframe 모두).
  - **로그인 막힘** — 그 페이지 `title → Access Denied`. 시뮬레이터와 같다(research R5). 핀치는 페이지에 `pointerType "mouse"`로 온다.
  - 로그에 OAuth `state`·`nonce`·`code_challenge` 값이 그대로 찍혀 가리는 키에 더했다(테스트 10개 통과, 12:0x KST).
- 12:02 KST 사용자 결정: 도메인별로 나눈다(intent Q4 재결정, spec S2 갱신) — 쿠팡플레이만 Mac(UA + 위장 스크립트), 다른 도메인은 iPad UA·위장 없음.
  UA는 주 프레임 이동 때 목적지 호스트로 바꾸고(`SiteConfig.userAgent(for:)`), 스크립트는 최상위 호스트(`ancestorOrigins`)로 판단한다.
- 12:05 KST(로그) 시뮬레이터 `CPVP_E2E=1` 포함 "14 tests in 6 suites passed" — "시작하기" → `login.coupang.com/login/login.pang`, 제목 "로그인", UA iPad (A4 통과).
- 12:05–12:06 KST(기기 로그 `261113-120544`) 실기기:
  - **D1 통과** — 시작하기 → `user agent → iPad for login.coupang.com` → 로그인 화면(Access Denied 없음).
  - **D2 통과** — 이메일·비밀번호 칸 클릭(값은 기록 안 됨) → "로그인" → `user agent → Mac for www.coupangplay.com` → `/login/callback` → 프로필 선택.
  - DRM 탐색: Widevine·PlayReady 거부, FairPlay(`com.apple.fps.1_0`, `sinf`)는 기본 구성 허용·`persistentState: required`만 거부. 홈 미리보기(non-drm HLS 1920x1080) 재생.
  - D3(작품 재생·소리)·D4(재실행 뒤 로그인 유지) 확인 대기.
- 12:06–12:10 KST(기기 로그 `261113-120544`) **D3** — DRM 작품(`output/drm/…`, 4119초): `encrypted`(initDataType `skd`, FairPlay) → `play`·`playing` 1920x1080, `muted:false`.
  사용자: "영상 재생했다". 사용자 보고: 재생 뒤 돌아오면 웹 레이아웃이 왼쪽 위 절반만 쓴다.
  로그: 전체화면 진입 때 창 959x539, 나온 뒤 창 1280x800인데 `[page] main resize {"h":539,"w":959}`. 앱 스크린숏(`snap-026`)이 1918x1078 — WKWebView 프레임이 959x539로 남음.
  → spec S10·D6 추가, `WebViewContainer`(레이아웃마다·전체화면 끝 0/0.3/1초 뒤 프레임 맞춤, 로그) 구현. 12:13 KST(로그) 테스트 14개 통과. 기기에 배포, 확인 대기.
- 12:2x KST 사용자 확인: "전체화면 문제는 해결되었는데" → **D6 통과**. D1–D4·D6 통과로 이 intent의 목표(첫 영상 재생)를 이뤘다.
  남은 불편(전체화면이 작은 고정 창으로 열림)은 다음 intent `261113-cinema-mode`로 넘긴다. D5(불편 기록)도 그쪽 intent에 적는다.
