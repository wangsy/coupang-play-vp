# Spec — Vision Pro에서 쿠팡플레이 웹으로 로그인해 첫 영상 재생까지

intent: `intent.md` · 조사: `research.md`

## 0. 한 줄 요약

앱은 창 하나에 웹 화면 하나를 띄우고 https://www.coupangplay.com/ 을 연다.
이 웹 화면은 최상위 페이지가 쿠팡플레이(`coupangplay.com`)일 때 모든 프레임에서 **Mac Safari처럼 보인다** — UA뿐 아니라 터치 관련 값까지(research R2).
쿠팡 로그인 등 다른 도메인에서는 iPad Safari로 보인다(S2, research R5).
앱 설치로 빠지는 길은 막는다.
(2026-11-25: 요약을 S2의 2026-11-13 변경에 맞춰 고쳤다. 처음 요약은 "모든 도메인에서 Mac"이었다.)

## 1. 동작 요구사항

### S1. 창과 첫 화면
- 앱을 열면 창 하나가 뜨고 `https://www.coupangplay.com/` 을 불러온다.
- 창 기본 크기는 1280×800pt(데스크톱 레이아웃이 펼쳐지는 폭). 사용자가 크기를 바꿀 수 있다.
- 웹 화면은 데스크톱 콘텐츠 모드로 요청한다.

### S2. Mac 브라우저로 보이기 (핵심)
**최상위 페이지가 `coupangplay.com`(하위 도메인 포함)일 때** 모든 페이지가 스크립트를 돌리기 **전에**, 모든 프레임에서 다음과 같이 보여야 한다.
최상위 페이지가 그 밖의 도메인(쿠팡 로그인 `login.coupang.com` 등)이면 **iPad Safari로** 보인다: UA `Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1`,
위장 스크립트는 아무것도 바꾸지 않는다(UA와 터치 값이 어긋나지 않게). UA는 주 프레임 이동 때 목적지 호스트로 정한다. (2026-11-13 변경 — research R5, intent Q4)

| 값 | 보여 줄 값 | 왜 (research) |
|---|---|---|
| HTTP·`navigator.userAgent` | Mac Safari UA: `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/<V> Safari/605.1.15` | R2 |
| `navigator.platform` | `"MacIntel"` | R2 |
| `navigator.maxTouchPoints` | `0` | R2 — `MacIntel && maxTouchPoints > 1` → iPad 판정을 끊는다 |
| `"ontouchstart" in window` (및 `document`, 요소) | `false` | R2 — Swiper·`isTouchDevice` |
| `navigator.standalone` | 없음(`undefined`) | R2 — ua-parser의 iPad 판정 |

- `<V>`(Safari 버전)는 코드 한 곳의 상수로 둔다. 기본값은 정책 결정 **P1**.
- 위 값을 덮어써도 visionOS의 시선+핀치 입력은 그대로 클릭으로 들어와야 한다(터치 이벤트 *발생*은 막지 않고, 존재 *표시*만 숨긴다).
- 쿠팡플레이 페이지 안의 iframe은 출처와 상관없이 Mac으로 보인다(최상위 호스트 기준 — `location.ancestorOrigins`).

### S3. 앱으로 빠지는 길 막기
웹 화면이 다음으로 이동하려 하면 이동하지 않는다(현재 페이지에 머문다):
- `http`/`https`/`about`/`blob`/`data` 가 아닌 스킴(예: `coupangplay://`) — research R3
- `apps.apple.com`, `itunes.apple.com`, `*.app.link`(Branch 딥링크)
- 막은 이동은 디버그 로그에 남긴다(어떤 길로 앱 유도가 오는지 기록용).

### S4. 새 창 요청
- 페이지가 새 창(`window.open`, `target=_blank`)을 열려 하면 같은 웹 화면에서 그 주소를 연다(로그인 팝업 대비).

### S5. 로그인 유지
- 쿠키·로컬 저장소는 앱의 영구 저장소에 둔다. 앱을 껐다 켜도 로그인이 남는다.
- 앱은 계정 정보를 따로 읽거나 저장하지 않는다.

### S6. 재생
- 페이지 안 재생(inline)을 허용하고, 재생 시작에 추가 사용자 동작 요구를 두지 않는다(사이트의 재생 버튼 핀치 한 번이면 된다).
- 사이트의 전체화면 요청(Fullscreen API)은 허용한다(웹 기본 동작까지만 — 몰입형 보기는 이번 범위 밖).
  → 다음 intent `261113-cinema-mode`에서 바뀜: 주 프레임의 전체화면 요청은 WebKit 대신 앱이 처리한다(`fullscreen-shim.js`, 그 intent의 spec C1·결정 D3).

### S7. 최소한의 이동 조작
웹에 갇히지 않도록 창 아래 오너먼트(ornament)에 버튼 셋: **뒤로**, **새로고침**, **홈**(쿠팡플레이 첫 화면).
- 뒤로는 갈 곳이 없으면 비활성.
- 이 밖의 UI(주소창, 탭, 설정)는 만들지 않는다.

### S8. 디버깅
- Mac의 Safari Web Inspector로 기기·시뮬레이터의 웹 화면을 볼 수 있게 한다(정책 **P2**).
- 페이지 로드 실패는 화면에 짧은 문구 + 다시 시도로 보인다.

### S9. 동작 기록 (2026-11-13 구현 중 사용자 요청으로 추가)
앱과 화면에서 일어나는 모든 동작을 기록해 에이전트가 기기 밖에서 분석할 수 있게 한다.
- **남기는 곳:** ① 통합 로그(`subsystem coupangplay-vp`) ② stdout — `scripts/device-run.sh`가 실기기에서 실시간으로 받는다
  ③ 기기의 `Documents/logs/<실행 시각>/events.log` — `scripts/device-pull.sh`로 가져온다. 최근 10회 실행만 남긴다.
- **앱:** 실행·화면 상태(scene)·창 크기, 이동 판단(allow/BLOCK과 이유)·리다이렉트·응답 코드·commit/finish·실패, URL·제목 변화(SPA 포함),
  새 창 요청, 웹 프로세스 종료, 오너먼트 버튼, 사이트의 alert/confirm/prompt(화면에 띄우고 답도 기록).
- **페이지(모든 프레임, `page-events.js`):** console, JS 오류·거부, 리소스 오류, 경로 변경(pushState 등), pointer·click·dblclick 좌표와 대상,
  포커스, 키 종류, 폼 제출, 선택 변경, 스크롤(1초에 한 번), 크기 변경, 나타난 대화상자·모달, 영상 이벤트(상태·오류 코드), DRM 요청 결과,
  전체화면, `window.open`, 페이지 생명주기, 사이트가 보는 기기 정보(identity).
- **스크린숏:** 페이지 로드 끝, 경로 변경, 클릭 뒤, 모달 등장, 대화상자, 막은 이동, 로드 실패, 영상 이벤트 때 JPEG로 같은 폴더에(최소 1초 간격). DRM 영상은 검게 나온다.
- **개인 정보:** 입력란의 값과 문자 키는 보내지 않는다(종류만). URL·문장 안의 `code`·`token`·`password` 등의 값과 Bearer 토큰은 `***`로 가린다.
  스크린숏에는 화면에 보이는 것(로그인 화면의 이메일 등)이 그대로 담기므로 기기·이 Mac 밖으로 내보내지 않는다(`device-logs/`는 git 제외).

### S10. 전체화면에서 돌아온 뒤 레이아웃 (2026-11-13 실기기에서 발견)
- 사이트 플레이어의 전체화면을 끝내면 웹 화면은 다시 창 크기 전체를 채운다.
- 발견: 전체화면 동안 창이 959×539가 되고, 끝난 뒤 창은 1280×800으로 돌아오지만 웹 화면은 959×539로 남아 왼쪽 위에만 그려졌다
  (앱 스크린숏 1918×1078, 로그 `[page] main resize {"h":539,"w":959}`).
- 웹 화면을 감싼 컨테이너가 레이아웃 때와 전체화면이 끝난 직후·0.3초·1초 뒤에 웹 화면 크기를 창에 맞추고, 바꿀 때 `[ui] web frame A → B`를 남긴다.
- 판정(기기): 재생 → 전체화면 → 나오기 뒤 `[page] main resize`가 창 크기(1280×800 또는 사용자가 바꾼 크기)와 같고 화면이 꽉 찬다.
- (2026-11-25 덧붙임) `261113-cinema-mode` 뒤로는 주 프레임의 전체화면을 앱이 처리해 플레이어 전체화면이 이 길로 오지 않는다.
  컨테이너는 WebKit 요소 전체화면이 아직 쓰일 수 있는 경우(iframe 안의 요청 — 그 intent의 spec E4)를 위한 안전망으로 남긴다.

## 2. 인터페이스

- 화면: SwiftUI `WindowGroup` 하나 → 웹 화면(WKWebView 래핑) + 아래 오너먼트(S7).
- 설정 상수(한 파일): 시작 URL, Mac UA 문자열(P1), 막을 호스트 목록(S3).
- 사용자 스크립트(JS, 문서 시작 시점·모든 프레임): S2 표의 값을 덮어쓴다. 앱 번들에 파일로 넣는다.

## 3. 예외·에지 케이스

- **E1.** 사이트가 다른 신호(예: 화면 크기, `matchMedia("(pointer: coarse)")`, `(hover: none)`)로 모바일을 판별하면 S2로 부족하다.
  → 실기기에서 로그인 버튼이 여전히 앱 설치로 가면, Web Inspector로 판별 지점을 찾아 S2 표에 더한다(spec 갱신).
- **E2.** `/unsupported-browser`로 가면 UA의 Safari 버전(P1)을 바꿔 본다(research R4).
- **E3.** DRM(FairPlay)이 visionOS WKWebView에서 안 돌면 로그인까지는 되고 재생에서 에러가 난다. 이번 범위에서 고칠 수 없다 —
  에러 문구·코드를 기록하고 사용자와 방향을 다시 정한다(intent Q3).
- **E4.** 터치 표시를 숨겨 사이트가 hover 전제 UI(마우스 올려야 보이는 메뉴)를 보여 줄 수 있다. 이번에는 기록만 한다(intent 범위 밖).
- **E5.** 쿠팡 로그인의 봇 방지(캡차·기기 인증)가 UA와 실제 엔진의 불일치를 잡을 수 있다. 생기면 기록한다.

## 4. 완료 판정 기준 (acceptance criteria)

### 에이전트가 이 Mac에서 확인 (자동)
- **A1.** 시뮬레이터·실기기 대상 빌드 성공(`** BUILD SUCCEEDED **`).
- **A2.** 단위 테스트: 같은 설정의 웹 화면에 로컬 HTML을 띄워 JS로 읽은 값이 S2 표와 같다 — 메인 프레임과 iframe 모두.
  쿠팡플레이가 아닌 호스트에서는 위장 스크립트가 값을 바꾸지 않고, 호스트별 UA 선택이 맞다.
- **A3.** 단위 테스트: S3 판정 함수가 `coupangplay://…`, `https://apps.apple.com/…`, `https://coupangplay.app.link/…` 은 막고
  `https://www.coupangplay.com/…`, 쿠팡 로그인 도메인은 통과시킨다.
- **A5.** 단위 테스트: 로그 가리기(`LogRedactionTests`), 페이지 이벤트가 메인·iframe에서 앱으로 오고 입력값은 오지 않는다(`PageEventsTests`).
- **A4.** visionOS 시뮬레이터에서 앱을 실행하면 쿠팡플레이 첫 화면이 뜬다(스크린숏). 실제 사이트 E2E(`SiteE2ETests`)로 "시작하기"를 누르면
  앱 설치가 아니라 쿠팡 로그인 화면(제목 "로그인", Access Denied 아님)이 뜬다. 로그인은 하지 않는다.
  (`/login`을 바로 여는 방식은 서버가 `/`로 돌려보내 쓸 수 없다 — plan 실행 기록)

### 사용자가 Vision Pro 실기기에서 확인
- **D1.** 첫 화면에서 로그인 버튼을 누르면 웹 로그인 화면이 뜬다(앱 설치로 가지 않는다).
- **D2.** 로그인이 끝나 프로필 선택 또는 홈 화면이 뜬다.
- **D3.** 콘텐츠 하나를 재생하면 영상과 소리가 나온다(Q3 — 안 되면 에러 문구·코드를 알려 준다).
- **D6.** 재생에서 돌아오면(전체화면 끝) 웹 화면이 창을 꽉 채운다(S10).
- **D4.** 앱을 완전히 끄고 다시 열면 로그인 상태다.
- **D5.** 쓰면서 불편했던 조작을 적어 둔다(다음 intent의 입력).

## 5. 정책 결정 — 2026-11-13 사용자가 셋 다 제안대로 정했다

- **결정:** P1 `Version/26.0` 고정 · P2 Web Inspector 항상 허용 · P3 앱 유도 이동을 막는다.


- **P1. UA의 Safari 버전** — 기본 제안: `Version/26.0`(최근 정식 Mac Safari 계열, 사이트가 알아볼 만한 값).
  대안: 기기의 실제 WebKit에 맞춘 값을 매번 만들기(정확하지만 사이트가 모르는 새 버전이면 E2 위험).
- **P2. Web Inspector 허용** — 기본 제안: 항상 허용. 소스를 받아 직접 빌드해 쓰는 앱이고, 사이트가 바뀌었을 때 원인을 찾는 유일한 수단이다.
  대안: Debug 빌드에서만.
- **P3. 앱 유도 이동 막기(S3)** — 기본 제안: 막는다. 대안: 막지 않고 로그만(막으면 사이트가 기대한 흐름이 멈춰 빈 화면이 될 수 있다 — 그때는 기록하고 다시 정한다).

## 6. 범위 밖 (intent와 같다)

손 제스처 조작 개선, 몰입형/전체화면 보기, 창 크기·비율 최적화, 배포.
(몰입형/전체화면 보기는 `261113-cinema-mode`에서 다뤘다.)
