# 쿠팡플레이 VP

Apple Vision Pro에서 [쿠팡플레이 웹](https://www.coupangplay.com/)을 보기 위한 비공식 visionOS 앱입니다.
쿠팡과 관계없는 개인 프로젝트입니다. 앱은 배포하지 않습니다. 필요한 분은 소스를 받아 직접 빌드해 설치하세요.

> 개발 중입니다. 진행 상황은 `intent/` 문서를 보세요.

## 빌드·설치

필요한 것: Xcode 27 이상(visionOS SDK), [XcodeGen](https://github.com/yonaskolb/XcodeGen), Apple Developer 계정.

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # 본인 Team ID와 번들 ID 접두어로 수정
xcodegen generate
open CoupangPlayVP.xcodeproj                            # Vision Pro를 대상으로 골라 실행(⌘R)
```

`Config/Local.xcconfig`는 git에 올라가지 않습니다.

## 라이선스

[The Unlicense](LICENSE) — 퍼블릭 도메인. 마음대로 쓰세요.
