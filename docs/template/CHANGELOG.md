# Changelog

## 미출시 — 런타임·설정·회귀 검사 보완 (2026-11-27)

- 오디오: `menu`·`quit_dialog`·`overlay` 등 focus 외 pause 중에는 `BGM`·`SFX`만 정지하고 메뉴 조작을 위한 `UI` 효과음(`AudioManager.play_ui()`)은 바로 재생한다. 이전에는 메뉴가 열려 있는 동안 `UI` 효과음도 일시 정지되어 메뉴를 닫을 때 밀린 소리가 한꺼번에 재생되었다. `SFX`와 `UI`의 동시 재생 한도(`MAX_EFFECTS`)도 버스별로 분리했다. `AudioManager.play_bgm(stream, restart = false)`은 같은 스트림이 이미 재생 중이거나 일시 정지(`stream_paused`) 중이면 위치를 유지하고 `restart = true`일 때만 처음부터 다시 재생한다.
- 입력·게임패드 UI: 키보드 바인딩에 `physical_keycode`가 있으면 저장·복원 시 `keycode=0`으로 정규화하여 물리 키 위치 기준으로 일관되게 비교하고, 창 환경에서는 현재 키보드 배열 글자로 표시한다. 다른 키로 바꾼 `pause` action도 다른 칸에 Escape가 없을 때는 캡처 UI에서 수정키 없는 단독 Escape로 다시 할당할 수 있다. 시작 시 `ui_accept`·`ui_cancel`에 게임패드 A·B 버튼 기본값을 보강하고 `PauseMenu`·데모 스크롤 컨테이너에 `follow_focus`를 켜 게임패드·키보드만으로 메뉴·목록·대화상자를 조작할 수 있게 했다. 보조 슬롯 개별 해제(`InputManager.clear_slot()`)는 마우스 클릭 시 `active_device` 전환과 충돌하지 않도록 설정 패널에서 키보드/마우스용(`UI_CLEAR_SECONDARY_KEYBOARD`)과 컨트롤러용(`UI_CLEAR_SECONDARY_CONTROLLER`) 버튼을 분리했다. 지원 범위를 벗어난 마우스·패드 버튼 입력은 `encode_event()` 단계에서 거절한다.
- Pause·종료·전환 UI: `PauseMenu`가 열려 있을 때 `ui_cancel`(패드 B 등)로도 설정·메뉴를 닫을 수 있으며, 열린 채 장면 전환 등으로 트리에서 제거될 때 자신이 켰던 `menu` pause 이유를 해제하고 전환 진행 중에는 pause 단축키를 무시한다. `QuitDialogs`는 종료 확인·저장 실패 창이 열려 있을 때 중복 확인창을 띄우지 않으며, 재시도 실패 시 게임이 `quit_failed`를 직접 처리하면 `quit_dialog` pause를 해제한다. 장면 전환·포커스 상실·화면 미리보기 확인·종료 대화상자 표시 시 진행 중인 입력 캡처를 자동 취소한다.
- 저장·복구: 원본 파일 없이 미완성 첫 쓰기 `.tmp`(빈 파일·불완전 값)만 남은 경우 Settings·InputManager도 쓰기를 차단하지 않고 새 사용자로 시작한다. 유효한 `.tmp` 복구 시에는 세 관리자 모두 먼저 rename으로 원본 경로에 무손실 승격한 뒤 필요할 때만(저장 migration 등) 새 `.tmp`를 기록하며, `Settings.reset_to_defaults()`·`InputManager.reset_bindings()`는 디스크 기록 실패 시 이전 상태와 `write_blocked`를 유지한다. SaveManager의 주기적 autosave 타이머는 `App.initialize()` 이후 시작한다.
- 번역·언어: 새 사용자의 초기 언어를 `OS.get_locale()` 기준으로 등록된 번역과 비교해 지역·스크립트(`zh_TW` / `zh_CN` 등)까지 매칭하고, 미지원 OS 언어에서는 프로젝트 fallback 언어를 선택하여 설정 창의 언어 목록이 빈 상태(`-1`)가 되지 않게 했다. Deprecated 대상인 `get_translation_object()` 대신 `find_translations()`로 모든 번역 리소스를 순회한다.
- 설정 패널·창 관리: SettingsPanel이 `Settings.changed`로 복수 패널과 외부 변경을 동기화하고, 커스텀 창 크기·FPS 항목은 단일 항목으로 교체하며, 음량 슬라이더 드래그 중에는 오디오 버스만 먼저 반영한 뒤 드래그 종료 시 디스크에 기록한다(`write_blocked` 상태에서도 드래그 종료 시 1회만 오류를 알린다). 캡처 실패 신호는 캡처를 시작한 패널만 내보낸다. WindowManager는 VSync·FPS만 바꿀 때 창 위치를 다시 중앙으로 옮기지 않고, 전체 화면 전환 뒤 이전 창 위치를 복원하며, 작업 표시줄 영역으로 클램핑한 크기가 저장된 `window_size`를 덮어쓰지 않는다.
- 스토어(`StoreService`): 연속 업적·점수 제출이 `ERR_BUSY`로 탈락하지 않도록 FIFO 요청 대기열(`MAX_QUEUE_SIZE = 32`)로 직렬화하고 대기열 초과 시에만 `ERR_BUSY`를 내보낸다. `StoreService.user_id()` 위임 메서드를 추가했고, `mode = "native"`에서 등록한 검증된 `StoreAdapter`는 `steam` 외 배포 채널에서도 초기화할 수 있다.
- 에디터 MCP(`Godot AI`): `hi-godot/godot-ai` 서명 릴리스 **4.4.2**(`addons/godot_ai/`, MIT, 순수 GDScript)를 포함해 기본 활성화하고(`editor_plugins/enabled`, `autoload/_mcp_game_helper`), 아홉 PC export preset 모두에서 `addons/godot_ai/*`를 제외했다(`GodotAIStripAutoload`로 배포 팩의 helper Autoload도 제거).
- 도구·라이선스·검증: 루트 MIT `LICENSE` 추가 및 BOM 동기화, `GameConfig.ENGINE_VERSION` 단일 상수 참조 및 `.godot-version` 일치 검사, `configure.gd`의 기존 기본 action `deadzone` 갱신·필터 공백/중복 정리, `tools/validate.sh --gui` 옵션 및 알 수 없는 인수 검증 추가, GitHub Actions CI의 Godot 아카이브 공식 `SHA512-SUMS.txt` 검증·Xvfb GUI 검사·생성 산출물(`project.godot`, `export_presets.cfg`, `ui/i18n/`, `third_party/`) diff 검증, 공통 통합 검사(`tests/integration.gd`)의 파생 게임 설정 격리 및 `bootstrap_failure.gd` 임시 디렉터리 재귀 정리.

기존 게임 적용:

- `AudioManager.set_suspended(suspended, include_ui = true)`는 기본 호출 시 기존처럼 `UI`까지 모두 정지하고, `App`의 메뉴·오버레이 pause만 `include_ui = false`를 전달한다. 이미 재생·일시 정지 중인 같은 BGM을 처음부터 다시 재생하려면 `AudioManager.play_bgm(stream, true)`를 호출한다.
- 기존 `user://input.cfg`에 물리 키코드와 논리 키코드가 함께 저장되어 있던 키 바인딩은 불러올 때 물리 키 기준으로 정규화된다. 공통 UI 번역(`ui/i18n/ui.csv`)을 수정해 쓰는 게임은 `UI_CLEAR_SECONDARY_KEYBOARD`·`UI_CLEAR_SECONDARY_CONTROLLER` 키를 함께 반영한다.
- 새 사용자의 `Settings.defaults().language`는 미지원 OS 언어 코드를 그대로 남기지 않고 등록된 번역 또는 프로젝트 fallback 언어로 결정된다.
- `StoreService`에 동시에 여러 요청을 보낼 때 즉시 `ERR_BUSY`를 기대하던 코드는 최대 32건까지 순차 실행됨을 전제로 맞춘다.

## 미출시 — 점검 보완 (2026-11-04)

- 저장: Windows의 rename(원본 삭제 후 이동)이 중단되어 `.tmp`만 남은 경우 SaveManager·Settings·InputManager가 그 내용을 복구한다. SaveManager는 복구한 진행을 원본 경로에 다시 저장한다. 이전에는 새 게임으로 시작하여 진행이 사라질 수 있었다.
- Settings: 새 사용자의 `language` 기본값을 `"en"`에서 OS 언어로 변경. 이전에는 설정을 한 번 저장하면 다음 실행부터 OS 언어 대신 영어가 고정되었다.
- 공통 UI 번역: PauseMenu·SettingsPanel·QuitDialogs·화면 확인창·로딩·시작 실패 문구를 `ui/i18n/ui.csv`(English / 한국어)의 `UI_*` 키로 변경. 설정 패널에 언어 선택을 추가하고 언어를 바꾸면 열린 UI도 바로 바뀐다. `InputManager.action_text()`는 `UI_ACTION_<ACTION>` 키로 action 이름을 번역한다. configure가 공통 UI 번역을 Project Settings에 등록한다.
- 전체 화면 단축키: F11 / Alt+Enter(`WindowManager.toggle_fullscreen()`)는 15초 확인창 없이 창 ↔ 테두리 없는 전체 화면을 바로 저장·적용한다. 미리보기 중에는 `ERR_BUSY`, 저장 실패 시 화면을 바꾸지 않고 오류를 반환한다. 설정 패널은 `options_applied`로 바뀐 모드를 표시한다.
- 테스트: 통합 검사 종료 시 가끔(verbose 200회 중 19회) `5 ObjectDB instances were leaked`·`1 resources still in use`가 남아 `tools/validate.sh`가 실패했다. 남은 객체는 오디오 검사에서 멈춘 `bgm.wav` 재생 객체(`AudioStreamPlaybackWAV` 4개)였다. 오디오 검사 뒤와 종료 직전에 정리 시간을 0.05초에서 0.25초 + 5프레임으로 늘렸다.
- 테스트: `Slot text is short and readable`이 컨트롤러 표시를 영어 문자열로 고정 비교해 한국어 등 영어가 아닌 OS에서 실패했다. 영어·한국어로 각각 언어를 정해 비교하도록 바꾸고(검사 1개 추가), 끝나면 원래 언어로 되돌린다.
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
