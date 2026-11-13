# Spec — 시네마 모드

intent: `intent.md` · 결정: `decisions.md`

## 0. 한 줄 요약

사이트의 전체화면 요청을 WebKit의 전체화면(작은 고정 창) 대신 **앱이 직접** 처리한다:
페이지 안에서는 그 요소를 창 전체로 키우고(웹 쪽 흉내), 앱은 창을 크게 키우고 주변을 까맣게 하는 몰입 공간을 연다.

## 1. 동작 요구사항

### C1. 페이지 안 전체화면 흉내 (`fullscreen-shim.js`, 주 프레임만)
- `Element.requestFullscreen` / `webkitRequestFullscreen` / `webkitRequestFullScreen`을 가로채 그 요소를
  `position: fixed; inset: 0; 100vw × 100vh; 검은 배경; 맨 위`로 만든다. 페이지 스크롤은 막는다.
- `document.fullscreenElement` / `webkitFullscreenElement` / `webkitCurrentFullScreenElement` / `webkitIsFullScreen` / `fullscreen`이
  흉내 중인 요소(또는 null/false)를 돌려준다. `fullscreenEnabled` / `webkitFullscreenEnabled`는 true.
- `document.exitFullscreen` / `webkitExitFullscreen` / `webkitCancelFullScreen`은 흉내를 끝낸다. Escape 키도 끝낸다.
- 들어갈 때와 나올 때 `fullscreenchange` / `webkitfullscreenchange`를 사이트가 듣는 대로 보낸다(요소에서 시작해 문서까지 bubble).
- 상태가 바뀔 때 앱에 알린다(메시지 핸들러 `cpvpFullscreen`: `enter` / `exit`).
- 앱이 부르는 `window.__cpvpExitFullscreen()`으로 끝낼 수 있다(사용자가 시스템 쪽에서 몰입 공간을 닫았을 때).

### C2. 시네마 (앱)
`enter`를 받으면:
- 창을 크게 키운다 — 기본 2560×1440pt(16:9, 결정 D2). 키우기 전 크기를 기억한다.
- 몰입 공간 `cinema`를 연다: 검은 구(사용자를 둘러싼 안쪽 면)로 주변을 가린다. 스타일은 progressive, 처음 100%(디지털 크라운으로 줄이면 방이 보인다 — 결정 D1).
- 창의 오너먼트(뒤로·새로고침·홈)를 숨긴다.

`exit`를 받으면: 몰입 공간을 닫고, 창을 기억한 크기로 되돌리고, 오너먼트를 보인다.

몰입 공간이 시스템에 의해 닫히면(크라운 누름 등) 페이지 전체화면도 끝낸다(C1의 `__cpvpExitFullscreen`).

### C3. 기록 (이전 intent S9에 더함)
- `[media] cinema enter/exit`, 창 크기 요청과 결과, 몰입 공간 열기/닫기 결과, 시스템이 닫은 경우를 로그에 남긴다.

## 2. 예외·에지 케이스

- **E1.** 사이트 CSS가 `:fullscreen` 의사 클래스에 기대는 모양(컨트롤 배치 등)은 흉내로 맞지 않을 수 있다 → 기기 스크린숏으로 보고 필요하면 CSS를 더한다.
- **E2.** 창 크기 요청이 시스템 한도에 걸리면 시스템이 줄인다 → 결과 크기를 로그로 보고 D2 값을 조정한다.
- **E3.** 몰입 공간을 못 열면(다른 앱이 몰입 중 등) 창만 키우고 계속한다(로그).
- **E4.** iframe 안의 전체화면 요청은 이번 범위 밖(쿠팡플레이 플레이어는 주 프레임).

## 3. 완료 판정 기준

### 에이전트(이 Mac)
- **A1.** 시뮬레이터 빌드·테스트 통과.
- **A2.** 단위 테스트: 로컬 HTML에서 `el.requestFullscreen()` → `document.fullscreenElement === el`, `fullscreenchange` 1번, 요소가 창 전체(`getBoundingClientRect`가 viewport와 같음), 앱이 `enter`를 받음.
  `document.exitFullscreen()` → null, 이벤트 1번, 원래 크기, 앱이 `exit`를 받음. Escape로도 끝남.

### 사용자(Vision Pro)
- **D1.** 재생 중 전체화면을 누르면 주변이 까매지고, 영상이 크게 가운데 꽉 차게 나온다.
- **D2.** 전체화면 상태에서 사이트 컨트롤(멈춤·탐색·나가기)이 동작한다.
- **D3.** 나가면 원래 창 크기와 밝은 주변, 오너먼트로 돌아온다.
- **D4.** 크라운을 눌러 몰입을 끝내도 페이지가 전체화면에서 나온다.
