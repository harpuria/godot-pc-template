# 의존성과 라이선스

최초 작성: 2026-10-04. 버전은 자동으로 변경하지 않는다. 아래의 Installed와 Deferred를 구분하여 읽는다.

## 채택 BOM — PC Template 0.1.0

| 구성 | 정확한 버전 / source | license | 현재 상태 |
| --- | --- | --- | --- |
| Godot Engine Standard | `4.7.2.stable.official.ed1daf0bf`; [고정 release](https://godotengine.org/download/archive/4.7.2-stable/), [엔진 source](https://github.com/godotengine/godot/tree/4.7.2-stable) | MIT + 내장 제3자 고지 | 로컬 macOS import·실행 확인 |
| GDScript | Godot 4.7.2 내장 | Godot license | 추가 설치 없음 |
| PC 공통 관리자·StoreService·Mock | 이 저장소 0.1.0 | 템플릿 자체의 외부 배포 license는 별도 결정 | In-repo |
| 데모 WAV | 모바일 템플릿의 자체 생성 사인파 | 외부 자산 library 없음 | 로컬 asset |
| PC SVG 아이콘 | 이 템플릿에서 직접 작성 | 외부 자산 library 없음 | 로컬 asset |
| Windows/macOS/Linux export templates | 엔진과 일치하는 4.7.2; [공식 archive](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz) | Godot 및 포함된 제3자 license | 로컬 macOS 환경에 Windows x86_64 Debug/Release·macOS 설치; Linux x86_64 Debug/Release는 Linux 검증 환경에 설치 |
| 외부 Godot addon / native SDK | 없음 | N/A | 미설치 |

Godot 버전의 세 출처는 `.godot-version`, `GameConfig.ENGINE_VERSION`, 설정 도구의 버전 guard이며 모두 4.7.2다. 엔진을 바꾸려면 모바일 프로젝트와 기준을 함께 결정하고 코드·export·문서의 일치 여부를 확인한다.

## 모바일 템플릿과의 관계

참조: godot-mobile-template 0.2.0, commit `b7210d9601360903d970e953dde28948b346dcd3` (읽을 때 working tree clean).

SaveManager, JsonStore, AudioManager, SceneManager, AppLogger와 loading UI·데모 음원을 기반으로 PC 요구에 맞게 확장했다. 모바일 native addon·Android/iOS export·광고·인앱 결제·모바일 back/safe-area 코드는 가져오지 않았다. 원본 모바일 프로젝트는 수정하지 않았다.

PC export templates는 공식 4.7.2 archive에서 필요한 세 항목만 HTTPS로 내려받고 ZIP size/CRC를 확인하여 기존 엔진 templates 디렉터리에 추가했다. 기존 Android/iOS 파일은 유지했다. export templates는 이 프로젝트의 Git 대상 파일이 아니다.

## 배포 고지

Godot license는 게임과 함께 제공해야 하며 포함된 제3자 고지도 보존한다. [Godot 배포 license 안내](https://godotengine.org/license/)

- [GODOT_LICENSE.txt](../third_party/GODOT_LICENSE.txt): 현재 엔진의 `Engine.get_license_text()` 결과.
- [GODOT_THIRD_PARTY.txt](../third_party/GODOT_THIRD_PARTY.txt): 현재 엔진의 copyright와 license 정보 결과.

두 파일은 export include filter로 패키지 리소스에 포함된다. 게임의 Credits/License 화면에서도 안내하거나 최종 배포 폴더에 텍스트 사본을 함께 제공한다. 새로운 외부 asset·SDK의 license는 별도로 추가한다. 프로젝트 리소스에 들어 있다는 사실만으로 사용자 접근 경로가 완성되지는 않으므로 실제 게임에 고지 UI 또는 동봉 파일을 제공한다.

엔진 버전을 변경하거나 고지 파일을 다시 만들 때:

```bash
godot --headless --path . --script res://tools/write_engine_notices.gd
```

## 선택적 도구와 SDK — Deferred

| 후보 / 도구 | 목적 | 채택 상태 |
| --- | --- | --- |
| GodotSteam 또는 검증한 Steamworks binding | 업적·점수·overlay 등 | 정확 release/SDK/4.7.2 native 조합 아직 미선정·미설치 |
| Steamworks SDK / steamcmd | Steam API·depot 업로드 | 게임별 계약·계정과 지원 플랫폼 확인 후 설치 |
| itch.io butler | 빌드 업로드·패치 | 런타임 dependency 없음; 필요 시 배포 환경에 설치 |
| Apple codesign / notarytool / Developer ID | macOS 공개 배포 서명·공증 | 개발 환경·계정별 준비 |
| Windows SignTool / 지원 서명 도구 | Authenticode | 개발 환경·인증서별 준비 |

미선정 SDK에 임의의 최신 버전을 BOM에 적지 않는다. 현재 Mock은 플랫폼 SDK 호환성을 검증한 증거가 아니다.

## 새 dependency를 추가할 때

README BOM과 이 문서에 이름·정확한 버전·release URL/commit·source·license·native SDK 버전·architecture·Godot **4.7.2** 호환 근거를 기록한다. 설치 방법, 플랫폼별 binary, 업데이트 이유와 검증일도 남긴다.

Verified는 Windows/macOS/Linux의 실제 export·실행 및 해당 기능의 확인이 끝난 조합에만 사용한다. 업스트림의 지원 범위만 확인한 상태는 프로젝트 Unverified로 기록한다. 자격 증명·서명 파일은 Git에 포함하지 않는다.
