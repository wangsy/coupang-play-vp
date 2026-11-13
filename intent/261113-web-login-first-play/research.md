# Research — 사이트가 기기를 어떻게 판별하는가

2026-11-13, 로그인하지 않고 공개 페이지와 JS 번들(`assets.coupangplay.com/_next/static/…`, 빌드 `30dc08e-306360`)만 받아 읽었다.
사이트가 바뀌면 이 내용도 낡는다. 번들 이름(해시)은 배포마다 바뀐다.

## R1. 서버는 UA로 갈라 주지 않는다

`curl`로 Mac Safari UA와 iPad Safari UA로 `/`를 받으면 둘 다 200, 같은 URL, 크기 거의 같음(338163 / 337876 bytes).
→ 모바일/앱 유도 분기는 **브라우저에서 도는 JS**가 한다(Next.js 앱).

## R2. JS는 UA만 보지 않는다 — "터치되는 Mac"을 iPad로 본다

번들에 흔한 판별 라이브러리(`react-device-detect`, `ua-parser-js`, Swiper의 `getDevice`)가 들어 있고 모두 같은 규칙을 쓴다:

| 위치(번들) | 규칙 |
|---|---|
| `_app` (react-device-detect) | `/iPad\|iPhone\|iPod/.test(platform) \|\| (platform === "MacIntel" && maxTouchPoints > 1)` → iOS |
| `_app` (ua-parser) | UA가 `Macintosh`인데 `navigator.standalone`이 있고 `maxTouchPoints > 2` → 기기를 `"iPad"`로 바꿈 |
| `8068` (Swiper) | `platform === "MacIntel" && ("ontouchstart" in window \|\| maxTouchPoints > 0) && maxTouchPoints > 1` → ios |
| `7754` | `isTouchDevice = "ontouchstart" in window \|\| navigator.maxTouchPoints` |

Vision Pro Safari는 기본으로 Mac UA(`Macintosh; Intel Mac OS X 10_15_7`)를 보내지만 터치 지점이 있다고 알린다(iPad와 같은 방식).
그래서 **UA만 Mac으로 바꾸면 부족하다.** `maxTouchPoints`·`ontouchstart`·`standalone`까지 Mac처럼 보여야 한다.

## R3. 로그인 버튼 → 앱 설치로 가는 길

- 로그인 CTA는 `useCtaLink`가 만든다. `isMobileOrTablet`(컨텍스트 값)이 참이면 웹 로그인 URL(`getOAuth2LoginUrl`) 대신
  `https://coupangplay.app.link/…`(Branch 딥링크 → App Store)로 보낸다.
- 다른 길: `coupangplay://` 스킴으로 `location.replace` 한 뒤 5초 뒤 `https://apps.apple.com/kr/app/…/id1536885649`로 보낸다.
- 모바일 전용 경로: `/mobile`, `/mobile-install`, `/webview/mobile`.
- 웹 로그인 경로: `/login`, `/login/coupang`, `/login/callback`, 쿠팡 로그인 `…/login/login.pang?rtnUrl=…`(다른 도메인) — intent Q4에 따라 이 페이지들도 Mac으로 보여야 한다.

## R4. 재생과 DRM

- 플레이어가 고르는 보호 방식: `widevine`·`fairplay`·`playready`·`clear`. HLS 매니페스트에서 `com.apple.streamingkeydelivery` → `com.apple.fps.1_0`(FairPlay)를 읽는 코드가 있다.
  → Mac Safari 길(HLS + FairPlay)이 있다. visionOS의 WKWebView에서 FairPlay EME가 되는지는 **실기기에서만** 확인된다(intent Q3, 사용자 확인).
- `/unsupported-browser` 경로가 있다. 어떤 조건에서 가는지는 이번 조사에서 찾지 못했다 — UA의 Safari 버전이 너무 낮거나 이상하면 걸릴 수 있다.

## R5. 쿠팡 로그인 서버는 WKWebView의 Mac UA를 거부한다 (구현 중 발견, 2026-11-13 11:47–11:50 KST)

쿠팡플레이의 "시작하기" 버튼(Mac 위장 상태)은 웹 로그인 경로 `/oauth2/login?…`을 가리키고(앱 설치 링크 아님),
누르면 `login.coupang.com/login/forceLogout.pang` → `login.coupang.com/login/login.pang`으로 간다. 그 페이지에서 Akamai가 **Access Denied**를 돌려준다.

`login.coupang.com/login/login.pang`을 UA만 바꿔 직접 열어 본 결과(시뮬레이터 WKWebView, 위장 스크립트 유무 같음):

| UA | 결과 |
|---|---|
| WKWebView 기본(`Macintosh … (KHTML, like Gecko)`, Safari 표기 없음) | Access Denied |
| Mac Safari `Version/26.0` | Access Denied |
| Mac Safari `Version/18.6` | Access Denied |
| iPad Safari `iPad; CPU OS 18_6 … Mobile/15E148 Safari/604.1` | 정상 ("이메일 로그인") |
| (비교) **macOS** WKWebView, 이 Mac에서 Mac UA / 기본 UA | 둘 다 Access Denied |

- visionOS·시뮬레이터 탓이 아니다. 이 서버는 WKWebView가 "Mac"이라고 하면 거부하고 "iPad"라고 하면 받는다(이유는 확인하지 않았다 — 봇 방지 판정을 우회하는 조사는 하지 않는다).
- 페이지(주 프레임 이동)마다 UA를 바꾸면 흐름이 이어진다: 쿠팡플레이 첫 화면(Mac) → 시작하기 → `login.coupang.com`(iPad) → 로그인 화면 정상.
  로그인 뒤 `www.coupangplay.com/login/callback`으로 돌아오는 단계(Mac)는 계정 없이 확인할 수 없다 — 실기기 D2.
- 이 상태에서 위장 스크립트가 로그인 페이지에도 돌아 `maxTouchPoints`가 0이었다(iPad UA와 어긋남). 나누게 되면 스크립트도 쿠팡플레이 도메인에서만 돌려야 한다.
