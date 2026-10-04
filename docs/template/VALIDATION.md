# Validation — 2026-10-04

Template 0.1.0 및 미출시 보완의 실제 실행 기록이다. 모바일 프로젝트의 검증 결과를 PC 결과로 승계하지 않는다.

## 검토 후 보완 검증 — 2026-10-04

검토에서 재현한 6건을 수정하고 정상 경로와 실패 경로를 다시 실행했다. 아래 결과가 현재 소스 기준이며 뒤의 최초 제작 기록은 당시의 이력이다.

| 검사 | 결과 |
| --- | --- |
| 최종 Editor import | exit 0, script/parse 오류·경고·누수 없음 |
| Headless 기본 / `--disabled` / `--native` | 각각 **147 checks, 0 failures**, exit 0 |
| 실제 macOS GUI `--capture` | **156 checks, 0 failures**, exit 0 |
| 실제 bootstrap 명시적 실패 / 런타임 오류 주입 | 두 경우 모두 `entry_blocked=true`, exit 0 |
| Windows/macOS Standalone Debug + 세 채널 Release | 기존 **8개 패키지 재생성**, 모두 exit 0, export 오류 없음 |
| 갱신한 macOS Release 데모 앱 | 실제 GUI 시작·종료 exit 0, script/parse 오류·누수 없음 |
| 실제 macOS Release bootstrap 실패 주입 | 명시적 실패 / 런타임 오류 모두 `entry_blocked=true`, exit 0 |

추가한 회귀 검사는 초기화 서명·결과 검증, 잘못된 설정 값 5종의 원본·메모리·신호 보호, 저장 실패 시 설정 미반영, Ctrl/Shift/Alt/Meta 캡처·저장·복원, focus pause/mute 4가지 조합, 메뉴 pause 유지, suspend 중 BGM 재시작·SFX/UI 추가·재개, 화면 확인 실패의 rollback·UI 전달을 포함한다. 키 입력은 합성 이벤트로 검사했으며 실제 게임패드 검증은 아니다.

일반 통합 검사는 오류·누수 없이 완료했다. 별도 `bootstrap_failure` 검사는 실패를 의도적으로 주입하므로 `Game init script failed` 로그가 정상이다. 런타임 오류 검사의 `deliberate_init_failure` 호출 오류도 예상 로그다. 두 경우 모두 App·Store 생성, 저장 읽기, 장면 전환이 발생하지 않음을 확인했다.

`Error` 반환형 hook은 런타임 오류 후 기본값 `0(OK)`으로 반환되는 엔진 동작을 재현했다. 따라서 최종 hook 계약은 `Dictionary`와 필수 `error` 필드이며, 결과 누락을 성공으로 처리하지 않는다. 최초 오디오 회귀 검사에서는 정지 상태의 `playing` 값을 잘못 가정한 assertion을 발견해 `stream_paused`와 재개 후 실제 `playing`을 각각 확인하도록 수정했다.

Release 실패 검사는 임시 프로젝트 복사본에서 검사 장면과 fixture를 `game/`으로 옮기고 프로젝트 시작 장면을 검사 장면으로 지정한 뒤 macOS Release로 export했다. 앱 내부에서 `OS.is_debug_build() == false`와 실제 bootstrap 진입 차단을 함께 확인하고 복사본을 정리했다. 배포 엔진은 `--scene` 경로 override를 허용하지 않아 이 방식으로 검사했다. 최종 fixture는 실패 호출을 반환식에 두어 미사용 연산 제거를 피한다. Release는 상세 `SCRIPT ERROR` 문구를 생략할 수 있으므로 `Game init script failed`와 `entry_blocked=true`, 종료 코드로 판정한다. 원본 프로젝트의 시작 장면은 변경하지 않았다.

로그는 `build/validation_logs/review-*.log`에 보관한다. export 로그는 기존 `Windows-*-release.log`, `macOS-*-release.log` 및 Standalone Debug 로그를 갱신했다. 초기 실패를 최종 통과로 집계하지 않았다. Windows 실제 실행, 실제 Steam SDK, 서명·공증과 하드웨어 입력의 미확인 범위는 아래와 같다.

## 환경

- Godot `4.7.2.stable.official.ed1daf0bf`, Standard, GDScript.
- macOS / Apple M1. GUI renderer: `OpenGL API 4.1 Metal - 90.5`, Compatibility.
- 공식 4.7.2 archive에서 Windows x86_64 Debug/Release·macOS templates를 설치했다. 기존 Android/iOS templates는 유지했다.
- 추가 Godot plugin, Steam SDK, butler는 이 프로젝트에 설치하지 않았다.
- 처음에 비어 있는 로컬 폴더였으며 Git repository·remote·tag 생성은 하지 않았다.

## 최초 0.1.0 제작 시 실행 결과

| 검사 | 실제 결과 |
| --- | --- |
| Godot Editor headless import | exit 0, 최종 script/parse error 없음 |
| 공개 설정 반영 | 여섯 preset·기본 InputMap 생성, exit 0 |
| 엔진 license 고지 생성 | 두 텍스트 파일 생성, exit 0 |
| Headless 공통 통합 | **79 checks, 0 failures**, exit 0 |
| Store feature off (`--disabled`) | **79 checks, 0 failures**, exit 0 |
| SDK 없는 mode (`--native`) | **79 checks, 0 failures**, exit 0 |
| 실제 macOS GUI (`--capture`) | **84 checks, 0 failures**, exit 0 |
| GUI capture | 1280×720 데모 PNG를 생성하고 화면·버튼·설정·스크롤 배치를 확인 |
| 설정 도구의 격리된 복사본 검사 | 재실행 일관성·기존 InputMap/custom feature/서명 보존·배포 필터·잘못된 경로 거절 통과 |
| Windows/macOS Standalone Debug export | 두 실행 패키지 생성, exit 0, 오류 0 |
| Windows/macOS × Standalone/Itch/Steam Release export | 여섯 실행 패키지 생성, 모두 exit 0, 오류 0 |
| 생성된 macOS Debug/Release 앱 직접 실행 | headless 데모와 최신 Release GUI 자동 시작·종료, exit 0, script/parse/종료 누수 오류 없음 |
| 실제 macOS Release 채널 검사 | 임시 게임의 standalone/itch/steam 각각 **16 checks, 0 failures**; 합계 **48 checks, 0 failures** |

capture 경로는 `build/validation_logs/final-gui.log`에 기록된다. `/tmp` 이미지이므로 영구 배포 자산은 아니다. 테스트는 독립적인 `/tmp` 저장 경로를 사용하고 캡처 모드 이외에는 정리한다. export와 native Release 로그도 `build/validation_logs/`에 보관하며 Git 대상은 아니다.

확인한 계약:

- 앱 초기화 중복 방지, disabled SDK 초기화 생략, SDK 없는 unavailable.
- 유효한 게임 init hook의 1회 호출, App 초기화 전 schema·migration 등록.
- 저장 round trip, schema migration, 손상·미래·분수 schema 거절, 원본·메모리 보존, explicit reset.
- 설정 round trip, 음량 제한·타입·해상도 검사, 손상 설정 보호·복구.
- 입력 재설정·파일 round trip, 게임패드 보존, 중복 binding·잘못된 입력 필드 거절, capture 취소.
- 메뉴·overlay reason 독립성, 외부 소유 pause 보존.
- 서비스 요청 직렬화, timeout, 중복·늦은 callback 무시.
- BGM 시작·suspend·resume·stop 및 UI 버스.
- Master 음량 0의 mute, 0.8 음량의 dB 반영·mute 해제.
- 실제 SceneTree의 데모·다음 장면 이동, 중복/없는 경로 거절, 공통 관리자 유지.
- GUI에서 화면 후보 적용·중복 거절·자동 rollback·확인 후 저장.
- native macOS Release에서 mode=mock이어도 GameConfig·App이 Mock을 선택하지 않고, 직접 생성한 Mock의 초기화·요청도 실패함.
- native macOS Release에서 세 preset feature의 채널 선택, config·엔진 고지 포함, tests/tools/README 제외.

## 최초 export 실패와 해결

Windows:

```text
--export-debug "Windows Standalone" build/windows/standalone/pc-template.exe
exit 1
Missing: 4.7.2.stable/windows_debug_x86_64.exe
Missing: 4.7.2.stable/windows_release_x86_64.exe
```

macOS:

```text
--export-debug "macOS Standalone" build/macos/standalone/pc-template.zip
exit 1
Missing: 4.7.2.stable/macos.zip
```

macOS 최초 시도에서는 ASTC import 비활성화도 발견했다. 프로젝트의 S3TC/ASTC import와 macOS preset의 ASTC 포맷을 켠 뒤 공식 4.7.2 PC templates 세 항목을 설치했다. 이후 표에 기록한 **8개 export**와 native macOS 실행을 완료했다.

최종 실행 파일은 `build/windows/{standalone,itch,steam}/`, `build/macos/{standalone,itch,steam}/`에 있다. Debug 확인용은 `build/verification/`에 별도로 둔다. Windows 결과물은 PE32+ x86-64 GUI executable과 별도 PCK이며 macOS ZIP에는 Universal `.app`을 포함한다.

Release guard는 임시 프로젝트의 게임 장면에서 실제 macOS Release 엔진으로 확인했다. 사용자 게임 코드나 템플릿의 main_scene을 바꾸지 않았으며 임시 복사본은 검사 뒤 정리했다.

## 아직 확인하지 않은 범위

- Windows 실제 exe 실행, Windows 입력·그래픽 드라이버·파일 교체.
- macOS Intel 하드웨어 실행, export binary의 사람 조작·Developer ID 서명·공증·Gatekeeper. Apple M1에서 export 앱의 headless 및 Release GUI 자동 시작·종료를 확인했다.
- Windows Release executable의 실제 Mock guard 동작. macOS의 실제 Release 검증을 Windows 실행 결과로 간주하지 않는다.
- 실제 하드웨어 게임패드 입력·연결·분리와 여러 화면·고DPI 환경.
- 사람의 음원 청취 판정. 재생기·버스 상태를 검사했다.
- 실제 Steam 계정·업적·리더보드·overlay·Cloud와 SteamPipe/butler 업로드.
- 설치 프로그램·자동 업데이트·다중 프로세스·Cloud 충돌·계정별 저장.

## 환경 이슈와 수정

초기 sandbox 실행은 사용자 data/cache 디렉터리 생성과 시스템 CA 접근이 차단되었다. 표준 Godot 디렉터리에 접근하는 허용된 실행으로 import를 다시 완료했다.

최초 데모에서 교체 전 생성한 Button이 orphan으로 남는 종료 경고를 발견하여 불필요한 생성 코드를 제거했다. headless 검사에서 재생 직후 종료 시 리소스 정리 경고가 간헐적으로 관찰되어 오디오 정리 tick을 허용했다. 최종 세 headless 모드와 GUI에서는 script/parse/종료 누수 오류 없이 완료했다.

## 재현

실행 명령은 [CODEBASE_MAP의 변경 후 검증](../CODEBASE_MAP.md#변경-후-검증)을 따른다. stdout의 실패 수, 종료 코드, script/parse error와 종료 경고를 함께 확인한다. 양 OS·native·배포 관련 검증은 [DISTRIBUTION](../DISTRIBUTION.md)과 [STEAM](../STEAM.md)의 실제 환경에서 수행한다.
