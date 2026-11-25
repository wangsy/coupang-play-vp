# Research — 전체화면에서 사이트 플레이어 컨트롤

2026-11-25에 기기에 남아 있던 실사용 로그를 `scripts/device-pull.sh`로 가져와 읽었다(`device-logs/`, git 제외).
대상은 시네마 모드가 들어 있는 세션 `261113-211124`, `261117-225405`, `261125-192438`이다.
에이전트는 로그인하지 않았다. 작품 제목 등 시청 내용은 여기에 적지 않는다. 사이트가 바뀌면 이 내용도 낡는다.

## R1. 컨트롤 배치

창은 2560×1360pt, 스크린숏은 5120×2720px다.
좌표는 스크린숏에서 잰 값(±10pt)이고, 괄호 안은 로그에 찍힌 실제 탭 좌표다.
"요소"는 로그의 `describe()` 값이다.

| 컨트롤 | 위치(pt) | 요소 | 누르면 |
|---|---|---|---|
| 뒤로 ← (+ 작품 제목) | 왼쪽 위 (49, 45) (탭 41–48, 45–56) | `img.icon` | 전체화면이 끝난다(`cinema page exit`) |
| 재생 시간 | (35–143, 1199) | `div.buttons-upper` 안 | — |
| 탐색 바 | y 1254, x 35–2524(전체 폭) | (미확인) | — |
| 재생/멈춤 | (51, 1307) (탭 36–38, 1317–1319) | `img`(클래스 없음) | 멈춤(`pause`) |
| 10초 뒤로 / 앞으로 | (138, 1307) / (224, 1307) | (미확인) | — |
| 다음화 | (2112–2166, 1307) | `div.buttons-bottom` 안 | — |
| 자막 | (2232, 1307) | (미확인) | — |
| 모르는 아이콘(스크린숏에 흰 사각형으로 찍힘) | (2300, 1307) | (미확인) | — |
| 재생 속도 | (2369, 1307) | (미확인) | — |
| 볼륨 | (2436, 1307) (탭 2426–2453, 1291–1309) | `img.icon` / `img.icon.active` | 11-17 세션에서 4번 연달아 누름. 클래스 `active`가 바뀜. 무엇이 바뀌는지는 미확인 |
| 전체화면 끝내기 | (2505, 1307) (탭 2492–2513, 1325) | `div.fullscreen-button.Fullscreen_fullscreen__p9MOy` > `img.icon` | 전체화면이 끝난다 |

- 아래 줄은 `div.buttons-upper`(재생 시간)와 `div.buttons-bottom`(재생 시간·다음화 …) 두 덩어리로 보인다. 둘의 정확한 경계는 아직 모른다.
- 클래스 이름에는 두 종류가 섞여 있다. 하나는 해시가 없는 이름(`playpause-toggler`, `buttons-bottom`, `fullscreen-button`)이고,
  다른 하나는 CSS 모듈 해시가 붙은 이름(`Fullscreen_fullscreen__p9MOy`)이다. 해시는 배포마다 바뀔 수 있다.
- **멈춤(x≈51)과 전체화면 끝내기(x≈2505)는 2450pt 떨어진 양쪽 아래 모서리에 있다.** intent의 문제 그대로다.

## R2. 탭: 깨우기와 멈춤

- 영상 위 전체를 `div.playpause-toggler`가 덮는다. 영상 가운데를 누르면 이 요소가 받는다.
- 세 세션에서 이 요소를 누른 19번 가운데 **17번은 `pointerdown`만 오고 `click`이 없었다.** 이것이 컨트롤을 깨우는 탭으로 보인다.
  나머지 2번은 `click`이 왔고 바로 영상이 멈췄다(`pause`). 하나는 11-13 22:17:15, 다른 하나는 11-25 19:51:44다.
  두 번 모두 click 때 클래스가 `playpause-toggler shown`이었다. 그러니 컨트롤이 보일 때 영상을 누르면 멈추는 것으로 보인다.
  - 다만 19:51:44는 pointerdown 때 클래스가 `shown` 없이 `playpause-toggler`였다. 그래서 `shown`이 정확히 무엇을 뜻하는지는 아직 확인하지 않았다.
- 핀치는 이제 `pointerType: "touch"`로 온다. 첫 intent 때(2026-11-13 오전) 기록은 `"mouse"`였다.
  19:51:41에는 같은 지점에서 touch 뒤에 mouse가 한 번 더 왔다.
- 컨트롤이 저절로 숨는 시간, 멈춘 동안 컨트롤이 계속 보이는지(intent Q5)는 기존 로그로 알 수 없다. 아래 R3 관찰로 잰다.

## R3. 관찰 코드 (사용자 허락 2026-11-25, intent "제약")

기존 로그로는 DOM 구조(어떤 요소가 아래 줄을 감싸는지), 숨김 방식, 숨는 시간, 볼륨 동작을 알 수 없다.
그래서 `App/Resources/page-events.js`에 관찰 코드를 넣었다. 주 프레임에서 플레이어를 볼 때만 돈다.
플레이어는 전체화면 요소(`mode: "fullscreen"`)이거나, 보통 창에서 누른 `#playerPage`(`mode: "window"`, intent Q1)다.

- `player-outline`: 플레이어의 트리를 보낸다. 각 노드에는 요소, 위치·크기 `r`, 투명도 `o`, 클릭 가능 `p`, `aria-label`·`alt`·`src` 등이 들어간다.
  전체화면에 들어간 1초 뒤와, 안을 누른 0.7초 뒤에 보낸다. 플레이어·모드마다 최대 4번, 노드는 최대 400개다.
  보낼 때마다 앱이 스크린숏(`snap-…-player`)을 찍는다.
- `player-visible`: 트리 속 컨트롤 가운데 화면에 보이는 개수를 0.5초마다 재서, 바뀔 때만 보낸다.
  함께 보내는 값은 직전 개수, 마지막 탭에서 지난 시간 `sinceTap`, 영상 멈춤 여부다.
- 영상 이벤트에 `volumechange`를 더하고 `volume` 값을 기록한다(intent Q6).
- 단위 테스트 `PlayerProbeTests`(가짜 플레이어, 전체화면·보통 창). 시뮬레이터 결과: "20 tests in 8 suites passed", 2026-11-25 20:37 KST(`date`).

### 기기에서 할 일 (사용자)

1. 작품 하나를 **보통 창**에서 재생한다. 영상 가운데를 한 번 눌러 컨트롤을 깨우고, 숨을 때까지 기다린다.
2. 전체화면으로 들어간다. 컨트롤이 저절로 숨을 때까지 기다린다.
3. 영상 가운데를 **한 번** 눌러 깨운 뒤, 다시 숨을 때까지 아무것도 누르지 않는다.
4. 다시 깨워 **볼륨** 아이콘을 눌러 본다(무엇이 바뀌는지).
5. 영상 가운데를 눌러 **멈춘다**. 멈춘 채로 10초쯤 기다린 뒤(컨트롤이 숨는지), 다시 재생한다.
6. 전체화면 끝내기로 나온다.

→ 결과(로그 분석)는 이 아래 R4에 적는다.

## R4. 관찰 결과 (2026-11-25 20:39–20:45 KST, 기기 실시간 로그 `device-2040`, 사용자 조작)

### 플레이어 구조 (전체화면·보통 창 같음)

```
div#playerPage                       전체화면 요소. 보통 창에서는 높이가 0이다([0,0,1280,0]) — 자식이 모두 absolute
  div#playerWrapper.Player_playerWrapper__…        absolute, 플레이어 전체(보통 창 1280×800, 전체화면 2560×1360)
    div.Player_playerMain__…                      relative, 플레이어 전체
      div.ContentRating_contentRating__…          시청 등급 안내(처음에만, 뒤로는 opacity 0)
      div.PlaybackControls_playbackControls__… .static   컨트롤 층(absolute, 전체)
        div.playpause-toggler(.shown)             영상 전체를 덮는 탭 층
        div.buttons-top(.shown)                   뒤로(div.back-button) + 제목
        div.buttons-middle                        가운데 확인 아이콘(누를 때 잠깐 뜨는 재생/멈춤 그림, 67px)
        div.buttons-bottom(.shown)                아래 줄
          div.buttons-upper                       재생 시간(div.TimerText_…)
          div.seekbar.Seekbar_seekbar__…          탐색 바
          div.controls
            div.controls-left
              div.playpause-button.PlayPause_playPauseButton__…     img icon-player-pause.svg / icon-player-play.svg
              div.fr-button.RewindButton_rewindButton__…            img icon-player-rewind.svg (10초 뒤로)
              div.fr-button.ForwardButton_forwardButton__…          img icon-player-forward.svg (10초 앞으로)
            div.controls-right
              div.nextEpisode-button.NextEpisode_nextEpisode__… role=button   "다음화" + svg
              div.popup-control-button.audiosubtitle-button   자막·음성(팝업)
              div.popup-control-button.episodes-button        회차 선택(팝업) — 스크린숏의 "흰 사각형" 아이콘
              div.popup-control-button.speed-button           재생 속도(팝업)
              div.popup-control-button.volume-button          볼륨(팝업)
              div.fullscreen-button.Fullscreen_fullscreen__…  img icon-player-fullscreen.svg(보통 창) / icon-player-fullscreen-min.svg(전체화면)
      div.video-js#vjs_video_… > video.vjs-tech   영상(video.js)
```

- 아이콘은 모두 34pt다. 창이 2560pt인 전체화면에서도 크기가 그대로다.
- 해시가 없는 클래스(`playpause-button`, `nextEpisode-button`, `fullscreen-button`, `buttons-bottom`, `shown`)와
  CSS 모듈 접두어(`RewindButton_rewindButton`, `ForwardButton_forwardButton` …)로 버튼을 찾을 수 있다.
- 보통 창의 전체화면 버튼(`div.fullscreen-button`)을 누르면 전체화면으로 들어간다(20:43:03 `cinema enter`).
  전체화면에서 누르면 나온다(20:41:07, 20:43:23).

### 보이고 숨는 시간 (`player-visible`, 컨트롤 36–38개 중 보이는 수)

- 재생 중 탭: 바로 30개가 보인다. **약 3.6초 뒤** 4개로 줄고(20:40:52→56), 약 7초 뒤 0이 된다.
- **멈춘 상태에서도 숨는다.** 보통 창에서 멈춤을 누르면 3.5초 뒤 0이 됐다(20:41:10→13).
  멈춘 채 전체화면에 들어가면 3초 뒤 0이 됐다(20:43:04→07). intent Q5("멈춘 동안에는 보인다")는 사이트가 해 주지 않는다.
- 컨트롤이 보일 때 영상(탭 층)을 누르면 click이 와서 멈춤과 재생이 번갈아 바뀐다(20:43:12–21, 6번).
- 볼륨 버튼은 이번에 누르지 않았다. 음소거만 하기로 해서(Q6) 영상 요소의 `muted`를 직접 바꾸면 되므로, 팝업을 조사할 필요는 없다.

## R5. 영상 해상도 (추가 요청, 2026-11-25)

- 영상 요소의 `videoWidth`×`videoHeight`는 **지금 디코딩하는 프레임 크기**다. DRM(FairPlay) 작품에서도 값이 나온다.
  예: 20:56:23 `play` 이벤트의 `"size":"1920x1080"`(기기 로그 `device-2055`).
- 적응형 스트리밍이라 재생 중에 바뀐다. 예: 11-25 19:42:49 `play`는 1280x720이었고, 뒤에 1920x1080이 됐다(세션 `261125-192438`).
- 지금까지 모든 기기 로그(세션 6개 + 실시간 로그 2개)에 찍힌 크기는 다음과 같다. 광고와 미리보기가 섞여 있다.
  - 1920x1080: 1595번
  - 1280x720: 280번
  - 640x360: 16번
  - 960x540: 2번
  - **4K는 한 번도 없었다.** 사이트가 Mac Safari UA에 4K를 주는지는 모른다(조사하지 않음).
- 크기가 바뀌면 영상 요소에 `resize` 이벤트가 온다(HTML 표준). `page-events.js`의 영상 이벤트에 더해 기록한다.

## R6. 4K 배지가 있는데 1080p로만 재생되는 이유 (2026-11-25 21:2x–21:33 KST)

사용자 보고: 화면에는 "4K"라고 나오는데, 계속 재생해도 1080p만 나온다.
11-25 21:25 세션(`device-2103`)의 DRM 영화(약 2시간)는 처음부터 끝까지 1920×1080이었다.

**사이트 코드**(공개 JS 번들, 빌드 `01afdda-317036`, 로그인 없이 받음):
- 재생 요청 `POST /api/playback/play`의 헤더 `x-support-uhd`는 `videoCapabilities.uhd && isLiveFamily(metadataForPlay)`일 때만 붙는다.
  `isLiveFamily`는 라이브 이벤트·채널·라이브 쇼·라이브 회차·라이브 영화다.
  → **영화·드라마 같은 VOD는 기기가 4K를 디코딩할 수 있어도 웹 플레이어가 4K를 요청하지 않는다.**
  `x-support-hevc`는 따로 보낸다.
- 작품 화면의 "4K" 배지(`getVideoTags`)는 작품 메타데이터 `videoMaxQuality === "4K"`에서 나온다.
  그 작품이 어딘가(TV 앱 등)에서 낼 수 있는 최고 화질이지, 웹에서 재생되는 화질이 아니다.
- 플레이어 화질 메뉴에는 4K 항목이 막혔을 때 쓰는 문구 키 `player_4k_hdr_block_browser_msg`(브라우저) / `…_device_msg`(기기)가 있다.
  사이트가 브라우저에서 4K·HDR을 막는 경우를 따로 다룬다.
- `videoCapabilities.uhd`는 `navigator.mediaCapabilities.decodingInfo({type: "media-source", …})`로
  HEVC·돌비 비전 3840×2160을 물어 정한다.

**기기 측정**(관찰 코드 `video-caps`·`play-header`, 2026-11-25 21:33 `device-2133`):
- `media-source`와 `file` 모두 `hevc-2160p60: yes`, `hevc-2160p30: yes`, `dv-2160p30: smooth`였다.
  `dynamic-range: high`는 true, `MediaSource`와 `ManagedMediaSource`는 있었다.
  → **기기는 4K HEVC·돌비 비전을 디코딩할 수 있다고 답한다.** 기기가 한계가 아니다.
- 21:33:06 실제 재생 요청(`/api/playback/play`, 첫 화면 미리보기)에는 `x-support-hevc: true`만 있고 `x-support-uhd`는 없었다.

**결론:** 쿠팡플레이 **웹** 플레이어가 VOD에는 4K를 요청하지 않는다(라이브만 요청한다). 이 앱은 사이트에 Mac 브라우저로 보이므로 VOD는 최대 1080p다.
앱의 해상도 표시(디코딩 크기)는 맞게 나온 것이다.

**바꿔 볼 수 있는 것(하지 않음, 사용자 결정 필요):**
- 재생 요청에 `x-support-uhd: true`를 붙이는 것.
- 서버가 4K 목록을 줄지, 다른 조건(작품 `features`의 `required: device` 등)으로 거절할지는 모른다.
- 사이트가 웹 클라이언트에 의도적으로 두지 않은 요청을 만드는 것이라, 이용 약관에 어긋날 수 있다. 재생이 깨질 위험도 있다.

### R6 이어서: 4K 헤더 실험 결과 (2026-11-25 21:42–21:54 KST)

- 21:42:07(`device-2142`): 4K 배지 영화의 재생 요청에 `x-support-uhd: true`를 붙였다. 응답은 200이었지만 영상은 계속 1920×1080이었다. 사용자도 "계속 1080p"라고 확인했다.
- 21:53:31(`device-2154`, 관찰 코드 `play-response`로 재생 응답의 화질 관련 항목만 기록):
  - `sources`: HLS·DASH 모두 `codecs=avc1`, `hdr_type=SDR`. H.264만 있고 HEVC는 없다.
  - `content_meta`: `max_resolution=2160`, `eligible_resolution=2160`. 이 작품 자체는 4K가 있다.
  - `features[0]`: `type=resolution`, `supported=true`, **`enabled=false`**, **`required=[prime, device]`**.
  - `nudge_info[0].type=prime`, `ad_info.exposure.preroll`. 광고가 붙고, prime 안내 대상이다.
- 21:54:02(`variants`, 관찰 코드로 HLS 목록을 받아 주소를 뺀 속성만 기록):
  - 영상 목록 최고가 `RESOLUTION=1920x1080 CODECS=avc1.640028 BANDWIDTH=11455858`이다. 그 아래로 720p·540p·480p·360p·216p다.
  - **4K 항목은 목록에 없다.**

**최종 결론:** 이 작품의 4K는 서버가 계정 조건 `prime`과 기기 조건 `device`가 갖춰져야 켠다.
요청 헤더를 바꿔도 서버가 4K를 목록에 넣지 않는다. 사용자가 확인했다: 계정이 Prime이 아니다(2026-11-25).
공개 기사로는 광고 없는 유료 상품 "프리미엄 패스"가 있다고 하는데, 서버의 `prime`과 같은 것인지는 확인하지 않았다.
Prime 계정이어도 `device` 조건(웹 브라우저)이 남을 수 있다 — 그때 실험(DC12)을 다시 켜 볼 수 있다.
