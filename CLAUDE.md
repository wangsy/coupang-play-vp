# 쿠팡플레이 Vision Pro 앱 (coupang-play-vp)

쿠팡플레이 웹(https://www.coupangplay.com/)을 Apple Vision Pro에서 편하게 보기 위한 visionOS 앱.
앱으로 배포하지 않는다. **소스를 공개**하고, 필요한 사람이 자기 Apple Developer 계정으로 빌드해 쓴다.
기능별 결정은 `intent/` 문서에 있다. 이 문서는 작업 방식만 정한다.

## 개발 워크플로우 (Intent → Spec → Plan → Build → Verify)

mintAgent(`../mintagent/CLAUDE.md`)·Mac AI Lab(`../macai-lab-app/CLAUDE.md`)과 같은 방식이다.
[The AI-Native SDLC Playbook](https://claude.com/blog/the-ai-native-sdlc-playbook)의 Plan / Design / Build 단계를 따른다.
모든 작업은 주제별 디렉토리에서 문서로 시작한다.

```
intent/
  YYMMDD-<slug>/          # 주제 하나당 디렉토리 하나 (예: 261113-web-login-first-play)
    intent.md             # 1. 무엇을 왜 하려는가 (해결 방법은 쓰지 않는다)
    research.md           # (필요할 때) 직접 조사·측정한 값 — 사이트 동작, UA별 응답 등
    spec.md               # 2. 요구사항 + 설계 + 완료 판정 기준(acceptance criteria)
    plan.md               # 3. 구현 로드맵 + 실행 기록
    decisions.md          # (필요할 때) 사용자 대신 에이전트가 정한 것 — 나중에 사용자가 검토한다
```

디렉토리 이름 규칙:

- `YYMMDD`는 **intent.md를 처음 작성한 날짜**다. 이후 작업이 이어지거나 문서를 고쳐도 바꾸지 않는다.
- slug는 kebab-case 영문 소문자 2~4단어.

### 진행 규칙

- **한 단계씩만 진행한다.** `intent.md` 없이 `spec.md`를 쓰지 않고, `spec.md` 없이 `plan.md`를 쓰지 않으며,
  승인된 `plan.md` 없이 코드를 작성하지 않는다.
- 각 문서를 작성한 뒤에는 **멈추고 사용자의 승인을 받는다.** 다음 단계로 자동 진행 금지.
  사용자가 "한 번에"라고 하면 승인 없이 이어 가되, 정책 판단은 `decisions.md`에 결정·이유·버린 대안·바꾸는 법으로 남긴다.
- 앞 단계 문서와 어긋나는 점을 발견하면 임의로 해석하지 말고 해당 문서에 열린 질문으로 적고 사용자에게 확인한다.
- 구현 중 설계가 바뀌면 코드만 고치지 말고 `spec.md` / `plan.md`를 함께 갱신한다.
- `plan.md`는 코드와 같은 커밋에 넣는다. 실행 기록의 시각은 `date`·파일 시각·로그로 확인한 값만 적는다.

### 문서별 내용

**intent.md** — 사용자 설명을 받아 정리한다. 문제 / 기대 결과 / 영향 받는 사용자·시스템 / 제약 / 열린 질문.
해결 방법은 쓰지 않는다(사용자가 이미 정한 방향은 "제약"에 적는다).

**spec.md** — 동작 요구사항, 인터페이스(화면·제스처), 예외·에지 케이스, 완료 판정 기준.
정책상 판단이 필요한 항목은 별도로 표시해 사용자가 먼저 결정하게 한다.

**plan.md** — plan mode(읽기 전용)에서 작성한다. 변경할 파일 목록, 작업 순서, 위험 요소,
각 단계의 검증 방법(proof criteria). 구현하면서 아래에 "실행 기록"을 쌓는다.

## 검증

검증은 두 층이다. **시뮬레이터 통과 ≠ 기기 통과.**

1. **에이전트(이 Mac)**: 빌드·단위 테스트·visionOS 시뮬레이터 실행까지 직접 돌려 통과를 확인한 뒤 보고한다.
2. **사용자(Vision Pro 실기기)**: 로그인·재생·제스처·DRM 재생은 실기기에서만 판정할 수 있다.
   에이전트는 spec의 완료 기준 중 "기기 확인" 항목을 체크리스트로 넘기고, 사용자가 확인한 결과를 `plan.md` 실행 기록에 적는다.

- "완료"라고 보고하기 전에 빌드와 테스트를 직접 실행한다. 못 돌린 단계가 있으면 그렇다고 적는다.
- 버그 수정은 실패하는 테스트를 먼저 쓰고, 그 테스트를 고치지 않은 채 코드를 고친다(웹 화면 문제처럼 테스트로 잡기 어려우면 재현 절차를 plan에 적는다).
- 테스트 코드에서 trap을 내지 않는다(배열 범위 초과·`!`·`precondition`). `try #require`로 쓴다.
- 검증 명령어는 아래에 정상 출력 예시와 함께 누적해 기록한다.

```bash
# 이 Mac은 xcode-select가 CommandLineTools를 가리킨다 → Xcode 명령 앞에 DEVELOPER_DIR를 준다.
# 확인(2026-11-13): Xcode 27.2 (27B52), visionOS 27.2 SDK(xros27.2 / xrsimulator27.2), 시뮬레이터 런타임 visionOS 27.2
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcodebuild -showsdks | grep -i xr

# XcodeGen → 시뮬레이터 빌드. 정상: "** BUILD SUCCEEDED **" (2026-11-13, 빈 껍데기 앱)
# xcodegen은 ~/.local/bin. 로그는 스크래치에 두고 grep으로 본다.
export PATH="$HOME/.local/bin:$PATH"
xcodegen generate
xcodebuild -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP \
  -destination 'generic/platform=visionOS Simulator' -derivedDataPath build build

# 실기기 빌드(서명). Xcode > Settings > Accounts에 Apple 계정이 로그인돼 있어야 한다(없으면 "No Accounts").
# 정상: "** BUILD SUCCEEDED **", build/Build/Products/Debug-xros/CoupangPlayVP.app 이 Apple Development 인증서로 서명됨(2026-11-13)
# 기기 목록: xcrun devicectl list devices — Vision Pro가 페어링돼 있어야 기기에 설치·실행할 수 있다.
xcodebuild -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP \
  -destination 'generic/platform=visionOS' -derivedDataPath build -allowProvisioningUpdates build

# 단위 테스트(위장 값·이동 정책·UA 선택·로그 가리기·페이지 이벤트·전체화면 흉내).
# 정상: "Test run with 17 tests in 7 suites passed" + "** TEST SUCCEEDED **" (2026-11-13 시네마 모드 뒤)
# 실제 사이트 E2E(SiteE2ETests)는 건너뛴다.
xcodebuild test -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' -derivedDataPath build

# 실제 사이트 E2E(네트워크, 로그인하지 않음): 첫 화면이 Mac으로 보이는지, "시작하기"가 웹 로그인(/oauth2/login)으로 가는지.
# 정상: "CTA candidates: [{"tag":"A","text":"시작하기","href":"/oauth2/login?…"…" + "Test run with 2 tests in 1 suite passed"
TEST_RUNNER_CPVP_E2E=1 xcodebuild test -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' -derivedDataPath build -only-testing:CoupangPlayVPTests/SiteE2ETests

# 시뮬레이터에서 앱 실행 + 스크린숏. Debug 빌드는 -startURL <url>로 시작 주소를 바꾼다. 스크린숏은 스크래치에(커밋 안 함).
# 이동 기록: 앱 로그(subsystem coupangplay-vp)에 start / commit / finish / blocked 줄이 남는다.
xcrun simctl boot "Apple Vision Pro"; xcrun simctl install booted build/Build/Products/Debug-xrsimulator/CoupangPlayVP.app
xcrun simctl launch booted <bundle id> [-startURL https://…]
xcrun simctl io booted screenshot <스크래치>/shot.png
xcrun simctl spawn booted log show --last 2m --predicate 'subsystem == "coupangplay-vp"' --style compact

# 실기기 동작 추적(spec S9). 빌드·설치·실행하고 앱의 이벤트 로그를 실시간으로 받는다(stdout). 에이전트는 run_in_background로 돌리고
# 출력 파일을 Monitor(tail -f | grep)로 본다. 정상 첫 줄: "[app] launch 0.1.0 (1) visionOS … Apple Vision Pro", 이어 "[nav] response main 200 …"
scripts/device-run.sh [--no-build] [-startURL https://…]
# 기기에 쌓인 로그·스크린숏(Documents/logs/<실행 시각>/events.log, snap-NNN-<이유>.jpg)을 device-logs/로 가져온다(git 제외).
scripts/device-pull.sh

# 실기기(페어링된 Vision Pro): 빌드 → 설치 → 실행(수동). 정상: "Launched application with <bundle id> bundle identifier."
xcrun devicectl list devices                         # Reality가 physical, State가 connected인 줄의 UDID
xcodebuild -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP -destination "id=<UDID>" -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> build/Build/Products/Debug-xros/CoupangPlayVP.app
xcrun devicectl device process launch --device <UDID> <bundle id>

# 로컬 설정 확인. Local.xcconfig가 있으면 본인 값, 없으면 DEVELOPMENT_TEAM 빈 값 + com.example.coupangplay-vp
xcodebuild -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP -showBuildSettings | grep -E " (PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM) "
```

## 구성

| 경로 | 무엇 |
|---|---|
| `project.yml` | XcodeGen 프로젝트 정의(visionOS 27.0, Swift 6). `CoupangPlayVP.xcodeproj`는 커밋하지 않는다 |
| `App/` | SwiftUI visionOS 앱 소스. `Info.plist`는 XcodeGen이 `project.yml`의 `info`로 만든다 |
| `App/Browser/` | 웹 화면: `SiteConfig`(URL·UA·막을 호스트), `NavigationPolicy`(앱 유도 이동 판정, 순수 함수), `WebViewFactory`(설정·위장 스크립트), `BrowserModel`(delegate) |
| `App/Cinema/CinemaSpace.swift` | 시네마 모드 몰입 공간(검은 구). 창 쪽 전환은 `ContentView.setCinema` (intent/261113-cinema-mode) |
| `App/Resources/fullscreen-shim.js` | 사이트의 전체화면 요청을 페이지 안에서 흉내 → `FullscreenBridge`로 앱에 알림 |
| `App/Diagnostics/` | 동작 기록: `EventLog`(통합 로그·stdout·파일), `LogRedaction`, `PageEventBridge`, `Snapshotter` |
| `App/Resources/page-events.js` | 페이지의 모든 동작(클릭·경로·console·영상·DRM·전체화면 …)을 앱에 보고 |
| `scripts/device-run.sh`, `device-pull.sh` | 실기기 설치·실행·실시간 로그 / 기기 로그·스크린숏 가져오기 |
| `App/Resources/mac-disguise.js` | 문서 시작 시 모든 프레임에서 터치 표시를 숨기고 Mac처럼 보이게 하는 스크립트 |
| `Tests/CoupangPlayVPTests/` | swift-testing 단위 테스트(앱 호스트). `SiteE2ETests`는 `CPVP_E2E=1`일 때만 |
| `Config/Base.xcconfig` | 공통 설정. `Local.xcconfig`를 `#include?`로 읽어 Team ID·번들 ID 접두어를 덮어쓴다 |
| `Config/Local.xcconfig.example` | 소스를 받은 사람이 복사해 쓰는 예시. 실제 `Local.xcconfig`는 git-ignore |
| `intent/` | 기능별 intent·spec·plan |

## 주의

- 쿠팡플레이 계정·비밀번호·쿠키는 코드·문서·로그 어디에도 남기지 않는다. 로그인은 사용자가 기기에서 직접 한다.
- 사이트를 조사할 때 사용자 계정으로 로그인하지 않는다. 로그인 전 화면·응답까지만 본다.
- **공개 저장소다.** 개발자 Team ID·서명 설정·번들 ID 접두어처럼 사람마다 다른 값은 커밋하지 않는 로컬 파일
  (예: `Config/Local.xcconfig`, `.gitignore`에 등록)에 두고, 저장소에는 예시 파일만 둔다. `CLAUDE.local.md`도 커밋하지 않는다.
- 문서(intent 등)에 사용자 개인 정보(이메일, 계정, 기기 이름)를 적지 않는다.
- **WKWebView(`BrowserModel`)를 `App.init`에서 만들지 않는다.** `UIApplicationMain` 전이라 첫 터치에서 UIKit 제스처 처리가 크래시했다
  (2026-11-13, intent/261113-cinema-mode plan). 장면 내용에서 처음 쓸 때 만든다(`BrowserHolder`).
- 실기기 실시간 로그는 실행마다 **새 파일**로 받는다(`> 새파일`). 이전 `devicectl --console`이 같은 파일을 쥔 채 끝나면 NUL로 덮어쓴다.
- 기기 크래시 리포트: `xcrun devicectl device copy from --device <UDID> --domain-type systemCrashLogs --source / --destination <스크래치>` → `CoupangPlayVP-*.ips`.
