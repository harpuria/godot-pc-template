# Validation

Template 0.1.0 및 미출시 보완의 실제 실행 기록이다. 최신 기록이 위에 있다. 다른 템플릿(모바일 등)이나 다른 OS의 결과를 승계하지 않는다.

## 장면 로딩·입력 저장·파생 게임·출력 폴더 검증 — 2026-11-29

Linux x86_64, Godot 4.7.2 Standard에서 `tools/validate.sh --gui`를 실행했다. 기본·disabled·native 통합 검사는 각각 286개, Xorg GUI 검사는 299개가 통과했다.

- 부트스트랩이 첫 장면 요청을 수락한 뒤 로딩에 실패했을 때 경로를 담은 번역 오류 메시지 하나가 표시됐다.
- 기본 키가 없는 게임 action을 저장하고 다시 읽어 미할당 상태와 다른 action의 변경한 키가 함께 복원됐다.
- 임시 복사본에서 `game/main.tscn`을 제거하고 pause 메뉴 없는 `game/title.tscn`을 첫 장면으로 지정했다. 실제 시작 검사와 headless 전체 검사가 통과했다. 공통 pause 메뉴 fixture를 제거한 별도 실패 검사에서는 통합 러너가 종료 코드 1을 반환했다.
- `build/linux`를 일반 파일로 만들었을 때 configure가 실패 경로를 표시하고 종료 코드 1을 반환했다. 프로젝트 설정과 export preset의 해시가 유지됐으며, 충돌을 해소하고 재실행하자 9개 preset의 출력 폴더가 준비됐다.

## 저장 마이그레이션 실패와 첫 장면 진입 검증 — 2026-11-29

Linux x86_64에서 Godot 4.7.2 Standard로 실행했다.

| 검사 | 확인한 결과 |
| --- | --- |
| 저장 마이그레이션 | 두 번째 변환에서 사본을 비운 뒤 런타임 오류를 발생시켰다. 원본 파일의 바이트와 미저장 메모리가 유지되고 자동 저장은 차단됐다. 변환을 고쳐 같은 슬롯을 다시 읽자 빈 데이터가 최종 버전으로 저장됐다. 회귀 검사 6개 통과. |
| 첫 장면 검증 | 격리한 복사본에서 없는 파일, 장면이 아닌 리소스, 손상된 장면, 빈 경로를 각각 지정했다. 네 경우 모두 configure와 시작 검사가 종료 코드 1을 반환했고, `project.godot`과 `export_presets.cfg`의 해시가 유지됐다. 정상 설정에서는 기본 데모와 파생 게임의 `game/main.tscn` 각각에 진입했다. |
| 전체 회귀 | `tools/validate.sh --gui` 통과. headless 통합 3종 각각 282개, Xorg 가상 디스플레이의 GUI 통합 295개, 초기화 실패 주입 2종 통과. configure와 고지 생성 후 생성 파일 diff 없음. |

## 프로젝트 MCP 기본값과 교체 검증 — 2026-11-28

Linux x86_64, Godot 4.7.2 Standard, Godot AI 4.4.2, uv 0.13.9로 확인했다.

| 검사 | 결과 |
| --- | --- |
| 기본 MCP 연결 | Codex TOML과 Claude Code JSON에서 읽은 실행 파일과 인수가 일치했다. 해당 stdio 명령으로 초기화해 도구 47개를 조회했다. `session_manage(list)`에서 프로젝트 경로와 플러그인·서버 4.4.2를, `editor_state`에서 `ready`와 `res://scenes/bootstrap.tscn`을 확인했다. |
| 공통 회귀 | 기본·disabled·native 각각 282개 통과, 초기화 실패 주입 2종 통과. Xorg dummy 디스플레이에서 GUI 295개 통과. |
| MCP 교체 | 별도 복사본에서 테스트용 EditorPlugin을 선택하고 configure를 두 번 실행했다. 새 선택이 유지되고 이전 helper가 제거되었다. 세 headless 모드에서 각각 281개 통과. |
| 배포 팩 | Linux Standalone PCK를 만들고 저장소 밖에서 엔진으로 실행해 데모 장면 진입을 확인했다. Godot AI helper 스크립트와 Autoload, 두 클라이언트 설정 파일은 팩에서 제외되었다. |

Windows·macOS 클라이언트, 서명된 실행 파일, 외부 대체 MCP 서버와의 통신은 이 실행의 검증 범위 밖이다.

## 런타임·설정·회귀 검사 보완 검증 — 2026-11-27

메뉴 pause 중 `UI` 효과음 유지·한도 분리·일시 정지 중 동일 BGM 위치 유지, 물리 키코드 정규화·`pause`의 Escape 재할당·게임패드 `ui_accept`/`ui_cancel` 기본 매핑 및 스크롤 포커스 추적·장치별 보조 슬롯 비우기 버튼 분리·입력 범위 대칭화, 열린 `PauseMenu`의 `ui_cancel` 닫기 및 장면 전환 정리·`QuitDialogs` 중복/재시도 pause 처리·캡처 자동 취소, 미완성 첫 쓰기 `.tmp` 보호·복구 `.tmp` 무손실 선(先) 승격·복구 실패 시 롤백·autosave 시작 시점 분리, 로케일 지역/fallback 매칭·다중 번역 리소스 순회, `SettingsPanel` 동기화·커스텀 항목 단일 유지·슬라이더 드래그 저장 디바운스·캡처 소유권 분리, `WindowManager` 클램핑 역덮어쓰기 차단·위치 유지, `StoreService` FIFO 요청 대기열·`user_id()`·채널 무관 native adapter 활성화, `Godot AI` **4.4.2**(`addons/godot_ai`) 기본 활성화 및 export 제외, MIT `LICENSE`·단일 엔진 버전 상수·`configure.gd` deadzone/필터 보완·`validate.sh --gui` 및 파생 게임 설정 격리 후 실행했다. **Linux 환경**의 결과이며 Windows/macOS 실행으로 간주하지 않는다.

환경: Linux x86_64(Ubuntu 24.04), Godot `4.7.2.stable.official.ed1daf0bf` 공식 Linux 바이너리. GUI는 Xvfb + Mesa llvmpipe(OpenGL 4.5, Compatibility), 오디오는 dummy 드라이버.

| 검사 | 결과 |
| --- | --- |
| `tools/validate.sh` | import PASS; integration 기본 / `--disabled` / `--native` 각각 **271 checks, 0 failures**; bootstrap 실패 2종 PASS; 알 수 없는 CLI 옵션 거절(exit 2); 전체 exit 0 |
| `xvfb-run -a tools/validate.sh --gui` | 위 headless 검사 + `gui-integration` **284 checks, 0 failures**, exit 0, 스크립트·누수 오류 없음 (usable 클램핑 크기 미덮어쓰기·비해상도 변경 시 창 위치 유지 포함) |
| `Godot AI` 4.4.2 서명·에디터 로드 | 공식 `v4.4.2` 매니페스트 RSA-4096 서명·ZIP·설치 트리 해시(`1ba13c2c...`, 325개 파일) 검증 통과; Xvfb GUI `--editor --quit-after 3` 실행 시 `MCP | plugin loaded` ~ `plugin unloaded` 정상 종료, 스크립트 오류 없음, `project.godot` 무변경 |
| 파생 게임 복사본 격리 검사 | 임시 복사본에서 `main_scene="res://game/main.tscn"`, `store_enabled=false`, `mode="disabled"`, 게임 전용 `achievement_ids`/`leaderboard_ids`, `game/game_init.gd`의 `schema_version=2`·migration·`register_action(&"interact", ...)` 활성화 후 `tools/validate.sh` 실행 → 전 항목 PASS |
| configure·고지 생성 반복성 및 격리 검사 | `tools/configure.gd`·`tools/write_engine_notices.gd` 실행 후 `git diff --exit-code -- project.godot export_presets.cfg third_party/` 변경 없음(exit 0); 격리 복사본에서 `controller_deadzone=0.35` 변경 시 기존 기본 action 7종 `deadzone` 갱신 및 필터 공백/중복 제거 확인 |
| GitHub Actions `Validate` | PR #5의 GitHub 러너 실행에서 공식 `SHA512-SUMS.txt` 검증·Xvfb `--gui`·리소스 diff 단계까지 통과 확인 |

확인하지 않은 범위: 이번 변경의 Windows/macOS 실제 실행, 다중 물리 모니터·작업 표시줄 환경 및 실제 물리 게임패드·비-QWERTY 키보드 직접 조작, export 템플릿 재빌드.

## 점검 보완 검증 — 2026-11-04

`.tmp` 복구, OS 언어 기본값, CI action 갱신 후 실행했다. 이어서 공통 UI 번역과 확인창 없는 전체 화면 단축키를 추가하고 다시 실행했다(아래 표의 최신 수치). **Linux 환경**의 결과이며 Windows/macOS 실행으로 간주하지 않는다.

환경: Linux x86_64 컨테이너, Godot `4.7.2.stable.official.ed1daf0bf` 공식 Linux 바이너리, 공식 4.7.2 archive의 Windows x86_64·macOS·Linux x86_64 Debug/Release templates. 사운드 장치 없음(dummy 드라이버).

| 검사 | 결과 |
| --- | --- |
| `tools/validate.sh` | import PASS; integration 기본 / `--disabled` / `--native` 각각 **198 checks, 0 failures**; bootstrap 실패 2종 PASS; exit 0 |
| Xvfb GUI `--capture` | **210 checks, 0 failures**, exit 0. 단축키 전환이 확인창 없이 저장·적용되고, 미리보기 중 `ERR_BUSY`, 저장 차단 시 모드 유지 |
| 번역 검사 | 공통 UI 코드의 모든 `UI_*` 키와 공통 action 이름에 English·한국어 문구 존재, 한국어 적용, 언어 선택으로 즉시 전환 |
| 한국어 화면 확인 | Xvfb 캡처로 pause 메뉴·설정 패널·종료 확인창의 한국어 표시를 눈으로 확인(시스템 글꼴 WenQuanYi 대체). 엔진 기본 Cancel 버튼이 영어로 남는 것을 발견하여 `UI_CANCEL`을 추가 |
| CSV import | 두 번 import해도 `ui.en.translation`·`ui.ko.translation`이 바이트 단위로 같음 |
| 새 회귀 검사의 감지력 | `JsonStore` 수정을 되돌리면 `.tmp` 복구 검사 3건 FAIL |
| configure | 새 clone에서 실행 후 `project.godot`·`export_presets.cfg` 변경 없음 |
| 9개 preset Release export (Linux에서) | Windows·macOS·Linux × Standalone/Itch/Steam 모두 exit 0, ERROR·WARNING 0 |
| 결과물 내용 | Linux Steam `.pck`에 `config/game.cfg`·`third_party/*.txt` 포함, docs·tests·tools 제외. Windows exe는 PE32+ x86-64 GUI이며 FileVersion·ProductName 리소스 포함. macOS ZIP의 `.app`에 실행 권한·`_CodeSignature`(ad-hoc)·`PrivacyInfo.xcprivacy` 포함 |
| Linux Steam Release 실행 | headless 시작·종료 exit 0 |

확인하지 않은 범위: Windows exe와 macOS `.app`의 실제 실행, Developer ID 서명·공증, 갱신한 CI action의 GitHub 러너 실행, 실제 Windows 파일 교체 중단(강제 종료) 재현. `.tmp` 복구는 원본 삭제 후 이동 전 상태를 파일 조작으로 재현하여 검사했다.

## 개발 착수 보완 검증 — 2026-10-07

pause 메뉴·종료 대화상자, 입력 action 등록·주/보조 칸, `game/` 골격·Theme·버스 레이아웃, Linux preset, `tools/validate.sh`·CI를 추가한 뒤 실행했다. 이번 결과는 **Linux 환경**의 결과이며 Windows/macOS 실행으로 간주하지 않는다.

환경: Linux x86_64 컨테이너, Godot `4.7.2.stable.official.ed1daf0bf` 공식 Linux 바이너리, 공식 4.7.2 archive의 Linux x86_64 Debug/Release templates. GUI는 Xvfb + Mesa llvmpipe(OpenGL 4.5, Compatibility). 사운드 장치가 없어 Godot이 dummy 오디오 드라이버로 대체했다(ALSA `ERR_CANT_OPEN` 로그 1건은 이 환경 원인).

| 검사 | 결과 |
| --- | --- |
| `tools/validate.sh` (새 clone, `.godot` 없음) | import PASS; integration 기본 / `--disabled` / `--native` 각각 **182 checks, 0 failures**; bootstrap 실패 2종 `entry_blocked=true message_shown=true` 후 창 닫기 요청으로 종료; 전체 exit 0 |
| Xvfb GUI `--capture` | **191 checks, 0 failures**, exit 0 (화면 미리보기·rollback·확인 실패 경로 포함) |
| `validate.sh` 실패 감지 | 통합 검사에 `push_error`를 주입하면 Godot exit 0이어도 3건 FAIL·exit 1; Godot 경로가 없으면 exit 1 |
| configure | 9 preset 생성, 두 번 실행해도 `project.godot`·`export_presets.cfg` 변경 없음; 기존 Windows/macOS preset 내용 유지; 7번 자리에 다른 이름 preset이 있으면 exit 1이고 파일 미변경 |
| Linux export | Standalone Debug + Standalone/Itch/Steam Release 모두 exit 0, 오류 없음. configure 전(`build/` 없음)에는 "export path doesn't exist"로 실패함을 확인하고 문서에 반영 |
| Linux 실행 파일 | 네 실행 파일 headless 시작·종료 exit 0. Debug는 `Channel=standalone Mock=true` |
| Linux Release 채널 검사 | 임시 복사본에서 확인 장면을 `game/`에 두고 `exclude_demo=true`로 export: 세 preset이 각각 `standalone`·`itch`·`steam`, `debug=false`, Store Mock 아님, 직접 만든 Mock도 초기화 실패, `config/game.cfg` 포함, tests·docs·데모 제외 |
| 화면 확인 | Xvfb 캡처로 데모, pause 메뉴, pause 메뉴 안 설정 패널의 배치와 Theme 적용을 눈으로 확인 |

추가한 회귀 검사: pause 이유 변경 신호, PauseMenu 열기·닫기·외부 이유 동기화·pause action 전환, 게임 종료 처리기가 없을 때 저장 실패 대화상자 표시와 머무르기, `quit_failed` 구독 시 기본 대화상자 생략, 주/보조 칸 재설정·중복 거절·캡처 칸 지정, `register_action`(등록·중복·`ui_*`·잘못된 기본값 거절, 저장·재로드, 미등록 action 저장값 보존 후 등록 시 적용, reset), `load_failed` 신호, `game/` 골격 진입과 init hook, 버스 레이아웃, 기본 Theme.

확인하지 않은 범위:

- 새 UI·입력 변경의 Windows/macOS 실행, 실제 Steam Deck·Linux 데스크톱 사람 조작, 실제 게임패드.
- 창 닫기는 `NOTIFICATION_WM_CLOSE_REQUEST` 전달로 검사했다. 실제 창 관리자의 X 버튼 클릭은 아니다.
- GitHub Actions 워크플로는 로컬에서 같은 단계를 재현했으며, GitHub 러너에서의 실행은 저장소에 push된 뒤 첫 실행으로 확인한다(워크플로는 `main` push와 PR에서 실행).
- Windows/macOS export는 이번에 다시 실행하지 않았다. 해당 preset 내용은 바뀌지 않았다.

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
- 0.1.0 제작 당시에는 비어 있는 로컬 폴더였으며 Git repository·remote·tag를 만들지 않았다. 이후 GitHub 저장소로 공개했다.

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
