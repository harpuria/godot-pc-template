# Changelog

## 미출시 — 점검 보완 (2026-11-04)

- 저장: Windows의 rename(원본 삭제 후 이동)이 중단되어 `.tmp`만 남은 경우 SaveManager·Settings·InputManager가 그 내용을 복구한다. SaveManager는 복구한 진행을 원본 경로에 다시 저장한다. 이전에는 새 게임으로 시작하여 진행이 사라질 수 있었다.
- Settings: 새 사용자의 `language` 기본값을 `"en"`에서 OS 언어로 변경. 이전에는 설정을 한 번 저장하면 다음 실행부터 OS 언어 대신 영어가 고정되었다.
- 공통 UI 번역: PauseMenu·SettingsPanel·QuitDialogs·화면 확인창·로딩·시작 실패 문구를 `ui/i18n/ui.csv`(English / 한국어)의 `UI_*` 키로 변경. 설정 패널에 언어 선택을 추가하고 언어를 바꾸면 열린 UI도 바로 바뀐다. `InputManager.action_text()`는 `UI_ACTION_<ACTION>` 키로 action 이름을 번역한다. configure가 공통 UI 번역을 Project Settings에 등록한다.
- 전체 화면 단축키: F11 / Alt+Enter(`WindowManager.toggle_fullscreen()`)는 15초 확인창 없이 창 ↔ 테두리 없는 전체 화면을 바로 저장·적용한다. 미리보기 중에는 `ERR_BUSY`, 저장 실패 시 화면을 바꾸지 않고 오류를 반환한다. 설정 패널은 `options_applied`로 바뀐 모드를 표시한다.
- CI: Node 20 지원 종료에 맞춰 `actions/checkout@v5`, `actions/cache@v5`, `actions/upload-artifact@v6`으로 갱신.
- 문서: Windows SmartScreen·macOS Gatekeeper(미서명 다운로드) 안내, macOS `.app` 이름 기준, Steam Linux 런타임·Steam Deck 준비 항목, butler 버전 일치, Steam 라이브러리와 hardened runtime 주의, 2026-11-04 버전 점검 기록.

기존 게임 적용:

- configure를 다시 실행하여 `ui/i18n/ui.en.translation`·`ui.ko.translation`을 등록한다. 등록하지 않으면 공통 UI에 `UI_RESUME` 같은 키가 그대로 보인다.
- 공통 UI 버튼을 영어 문구(`"Resume"` 등)로 찾던 게임 코드는 `UI_*` 키로 바꾼다.
- `toggle_fullscreen()`은 더 이상 `preview_started`·`preview_finished`를 보내지 않는다. 단축키 전환을 감지하려면 `options_applied` 또는 `Settings.changed`를 구독한다.
- 게임이 `language` 기본값 `"en"`을 전제했다면 init hook 이후 직접 지정하거나 `Settings.defaults()` 결과를 확인한다. 이미 저장된 사용자 설정은 바뀌지 않는다.

## 미출시 — 개발 착수 보완 (2026-10-07)

- 재사용 UI: `PauseMenu`(Esc / Start, 계속하기·설정·종료)와 `QuitDialogs`(종료 확인, 저장 실패 시 머무르기·재시도·저장 없이 종료). App이 기본 인스턴스 `App.dialogs`를 소유한다.
- 창 닫기: `quit_failed` 구독자가 없으면 기본 저장 실패 대화상자를 표시한다. 초기화 전·init hook 실패 후에는 창 닫기를 바로 허용한다. init 실패 시 화면에 오류 문구를 표시한다.
- `App.pause_reason_changed(reason, active)` 신호 추가.
- 입력: `InputManager.register_action()`으로 게임 action을 재설정·저장 대상에 추가. 장치 종류별 주·보조 두 칸 재설정(`rebind(action, event, slot)`, `start_capture(action, slot)`), `load_failed` 신호, `slot_events()`·`slot_text()`·`event_text()`. `DefaultInput.key/mouse/button/axis` 공개.
- `game/` 골격(`main.tscn`, `main.gd`, `game_init.gd`)과 `init_script` 기본 연결, 에디터에서 보이는 `default_bus_layout.tres`, 프로젝트 기본 Theme(`ui/theme/default_theme.tres`).
- Linux x86_64 export preset 3종(Standalone·Itch·Steam)과 SteamPipe Linux depot 예시. configure는 preset 0~8번을 소유하며 다른 이름의 preset을 덮어쓰지 않는다.
- `tools/validate.sh` 공통 회귀 검사 스크립트와 GitHub Actions CI(`.github/workflows/validate.yml`).
- 문서: 셸 명령을 일반 `godot`·`git` 명령으로 통일, `docs/HOWTO.md` 단계별 안내 추가, DEVELOPMENT를 참고 문서·용어 표로 정리, APPLYING을 GitHub 저장소 기준으로 변경, STEAM의 잘못된 기본 저장 경로 설명 수정.

기존 게임 적용:

- `InputManager.ACTIONS`는 `COMMON_ACTIONS`(템플릿 기본 action)와 `actions()`(등록된 전체 목록)로 나뉘었다. 게임 action을 다루려고 `ACTIONS`를 직접 수정했다면 되돌리고 init hook에서 `register_action()`을 호출한다.
- `rebind()`는 이제 같은 장치 종류의 지정한 칸(기본 0번)만 교체한다. 이전에는 같은 종류의 입력을 모두 지우고 하나만 남겼다.
- `quit_failed`를 구독하지 않던 게임은 저장 실패 시 기본 대화상자가 뜬다. 직접 UI를 제공하던 게임은 동작이 같다.
- export preset 6~8번에 직접 만든 preset이 있다면 9번 이후로 옮긴 뒤 configure를 실행한다. 그대로 두면 configure가 실패하고 파일을 바꾸지 않는다.
- 데모(`scenes/demo.gd`)의 자체 종료 대화상자는 `App.dialogs`로 대체되었다.

## 미출시 — 검증 후 보완 (2026-10-04)

- 초기화 hook을 `before_app_initialize() -> Dictionary` / `{"error": OK}` 계약으로 변경. 서명·결과·런타임 실패 시 App·저장·장면 진입 차단.
- 잘못된 설정 값의 전체 파일 검증과 원본·메모리 보호. 설정 변경은 저장 성공 후에만 반영.
- focus pause와 오디오 옵션 분리, 정지 중 새 BGM/SFX/UI에도 suspend 유지.
- Ctrl·Shift·Alt·Meta 조합 키 캡처와 저장·복원.
- 화면 확인의 저장 실패를 `preview_failed` → 설정 UI까지 전달하고 후보를 복구.
- 6건의 회귀 검사 및 실제 bootstrap 실패 주입 장면 추가.

기존 게임 hook은 void 반환형을 Dictionary로 바꾸고 끝에 `return {"error": OK}`를 추가한다. 실패 반환값도 `{"error": error}`로 전달한다. 검증 결과와 미확인 플랫폼은 [VALIDATION](VALIDATION.md)을 따른다.

## 0.1.0 — 2026-10-04

Godot **4.7.2 Standard**를 사용하는 첫 PC 공통 템플릿이다. 모바일 템플릿 0.2.0의 공통 저장·오디오·장면 구조와 문서 구성을 기반으로 한다.

- Windows x86_64 / macOS universal용 Steam·itch.io·Standalone 여섯 export preset.
- 고정 user data directory, JSON version/migration, 자동 저장과 손상·미래 schema 원본 보호.
- 별도 사용자 설정, Master/BGM/SFX/UI 버스, 장면 전환·중복 방지·로딩 화면.
- 화면 모드·창 크기·VSync·FPS와 15초 확인·자동 복구.
- 키보드·마우스·게임패드 입력, deadzone·바인딩 저장·중복 감지·재설정.
- 이유별 pause, focus/overlay lifecycle, 저장 실패 시 종료 보류.
- 선택적 StoreService/Adapter와 Debug 전용 Mock; 외부 Steam SDK 미설치.
- 게임 초기화 hook, 설정 반영·배포 필터·엔진 고지 생성 도구.
- 실행 데모, 공통 SceneTree 통합 검사, 모바일과 대응하는 설계·개발·적용·검증 문서.

### 파생 게임 적용 시 주의

표시 이름·게임 version·bundle ID·executable_name·main_scene을 바꾸고 `data_directory`는 출시 후 고정한다. 게임 schema는 init hook에 등록한다. 게임 배포에서 데모를 제외하고 실제 Windows/macOS export와 서명·ESD를 검증한다. 첫 버전은 외부 native 기능과 스토어 출시까지 확인한 상태가 아니다.

0.1.0은 로컬 프로젝트로 제작했고, 이후 GitHub 저장소(<https://github.com/harpuria/godot-pc-template>)로 공개했다.
