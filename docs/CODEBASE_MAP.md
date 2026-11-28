# Codebase Map

AI Agent의 작업 진입 안내서다. 작업 규칙은 [AGENTS.md](../AGENTS.md), 실행 방법은 [README](../README.md)를 따른다.

## 실행 흐름과 소유권

```text
project.godot
  ├─ GameConfig → Settings → SaveManager → AudioManager
  │    → WindowManager → InputManager → SceneManager → App (Autoload)
  └─ scenes/bootstrap.tscn
       ├─ app/init_script (기본 game/game_init.gd)
       │    .before_app_initialize() -> Dictionary (명시적인 error=OK 확인; 실패 시 오류 문구 표시)
       ├─ App.initialize()
       │    ├─ channel + feature + mode → StoreService / Adapter 선택
       │    └─ SaveManager.load_slot()
       └─ SceneManager.change_scene(app/main_scene)
            ├─ 기본 scenes/main.tscn → scenes/demo.gd (데모)
            └─ 게임 game/main.tscn → game/main.gd (PauseMenu + 종료 확인)
```

`App.store`는 `StoreService`, `App.dialogs`는 `QuitDialogs`의 앱 수명 인스턴스다. 다른 공통 관리자는 Autoload를 직접 사용한다. SDK 없이 standalone과 itch.io 빌드가 실행되고, release Mock은 금지된다. `core/` 클래스는 Autoload가 아니다.

## 작업별 시작 위치

| 작업 | 먼저 읽을 문서 / 코드 |
| --- | --- |
| 새 게임에 적용 / 템플릿 업데이트 | `docs/template/APPLYING.md`, `docs/template/CHANGELOG.md` |
| 게임 장면·규칙·데이터 | `game/README.md`, `docs/HOWTO.md`, `game/`; 연결은 `config/game.cfg` |
| 초기화·hook·서비스 선택 | `docs/ARCHITECTURE.md`, `scenes/bootstrap.gd`, `autoload/app.gd` |
| 저장 schema·migration | `game/game_init.gd`, `autoload/save_manager.gd` |
| 파일 입출력 | `core/storage/json_store.gd` |
| 화면 모드·VSync·FPS·rollback | `autoload/window_manager.gd`, `autoload/settings.gd`, `ui/settings/settings_panel.gd` |
| 키보드·게임패드·재설정·게임 action 등록 | `autoload/input_manager.gd`, `core/input/default_input.gd`, `project.godot`의 InputMap, `game/game_init.gd` |
| 음량·BGM·SFX·UI | `autoload/audio_manager.gd`, `autoload/settings.gd`, `default_bus_layout.tres`; 음원은 `game/` |
| pause·focus·창 닫기 | `autoload/app.gd`, `ui/menus/pause_menu.gd`, `ui/dialogs/quit_dialogs.gd` |
| 공통 UI 모양 | `ui/theme/default_theme.tres` (`gui/theme/custom`) |
| 공통 UI 문구·번역·언어 선택 | `ui/i18n/ui.csv`, `ui/settings/settings_panel.gd`, `docs/HOWTO.md` 번역 절 |
| 장면 전환·로딩 | `autoload/scene_manager.gd`, `ui/loading/loading.tscn` |
| ESD 서비스·외부 SDK | `docs/STEAM.md`, `docs/DEPENDENCIES.md`, `services/store/` |
| 게임 이름·버전·저장 위치·bundle | `config/game.cfg`, `tools/configure.gd` |
| export preset·서명·패키징·업로드 | `docs/DISTRIBUTION.md`, `export_presets.cfg`, `docs/distribution/` |
| 에디터 MCP 연결·교체 | [README의 연결 절차](../README.md#ai-클라이언트-연결-및-교체), `.codex/config.toml`, `.mcp.json`, `project.godot`의 `editor_plugins/enabled` |
| 회귀 검사·CI | `tools/validate.sh`, `.github/workflows/validate.yml`, `tests/` |
| 동작 예제 / 공통 회귀 | `scenes/demo.gd`, `game/main.gd`, `tests/integration.gd` |
| 설정된 첫 장면 진입 | `tests/bootstrap_smoke.gd`가 프로젝트 기본 진입점에서 App 초기화와 실제 전환된 장면을 확인 |
| 초기화 실패 차단·첫 장면 오류 표시 | `tests/bootstrap_failure.tscn`, `tests/fixtures/*init*` |

`scenes/`와 `assets/demo/`는 공통 기능 예제다. `tests/`가 사용하므로 유지한다. `game/`의 골격은 파생 게임이 소유하며 템플릿 업데이트로 덮어쓰지 않는다. pause 메뉴 전환 검사는 `tests/fixtures/pause_menu.tscn`에서 실행하므로 게임의 첫 장면은 이동하거나 교체할 수 있다. 게임 배포에서 데모를 제외하는 방법은 배포 문서에 있다. `docs/template/`는 템플릿 자체의 기록이며 게임 설계·검증 문서를 쓰는 위치가 아니다.

## 설정 전파

- 런타임: `config/game.cfg` → GameConfig → App/관리자. 변경 후 재실행한다.
- 프로젝트·export: `config/game.cfg` → `tools/configure.gd` → `project.godot`, 아홉 preset(0~8번; Windows·macOS·Linux × 세 채널). 공통 UI 번역(`ui/i18n/ui.*.translation`)이 빠져 있으면 등록하고, 기본 활성화된 에디터 MCP 플러그인 `addons/godot_ai`의 `_mcp_game_helper` Autoload를 유지한다. Godot AI를 끄면 configure가 해당 helper 등록을 정리한다. configure는 모든 export preset에서 `addons/godot_ai/*`를 제외한다(`GodotAIStripAutoload`가 배포 팩의 `_mcp_game_helper` 항목도 제거). 게임이 이미 정의한 InputMap 바인딩과 기존 SDK·서명 옵션은 보존한다.
- 배포 채널: preset의 `standalone` / `itch` / `steam` feature가 config보다 우선한다. Editor의 `auto`는 standalone이다.
- 사용자 설정: 전체 파일 검증 / 디스크 저장 성공 → `Settings.changed` → 오디오 버스. 화면 후보는 WindowManager가 즉시 적용하고 확인 후 Settings에 저장한다. 확인 실패는 `preview_failed` → SettingsPanel의 `operation_failed`로 전달한다.
- 바인딩: InputManager가 등록된 action의 허용된 입력 필드만 ConfigFile에 기록한다. 아직 등록되지 않은 action의 저장값은 보존한다. `ui_*` action은 재설정 대상에서 제외한다.
- 저장 위치: `app/data_directory`는 configure 시 고정 user directory에 반영한다. 장면 이동이나 ESD 선택은 위치를 바꾸지 않는다.

## 변경 후 검증

저장소 루트에서 Godot **4.7.2**로 공통 회귀 검사를 실행한다. CI(`.github/workflows/validate.yml`)는 공식 아카이브 체크섬을 확인한 뒤 `xvfb-run`으로 `--gui` 모드까지 실행한다.

```bash
tools/validate.sh                         # PATH의 godot으로 headless 검사 실행
tools/validate.sh --gui                   # 창 환경(또는 xvfb-run)에서 GUI 화면 검사까지 추가 실행
GODOT=/path/to/Godot tools/validate.sh    # 예: macOS /Applications/Godot.app/Contents/MacOS/Godot
```

스크립트가 실행하는 검사:

| 이름 | 명령 인수 | 통과 조건 |
| --- | --- | --- |
| import | `--editor --import --quit` | exit 0, 오류 로그 없음 |
| bootstrap | `--main-loop BootstrapSmokeTest --quit-after 600` | `BOOTSTRAP: entered`와 설정된 장면 경로 |
| migration-runtime-error | `--scene res://tests/integration.tscn -- --migration-runtime-error` | 변환 오류 후 원본·메모리 보존, 쓰기 차단, 재시도 검사를 모두 통과 |
| integration (기본 / `--disabled` / `--native`) | `--scene res://tests/integration.tscn [-- 옵션]` | `INTEGRATION: N checks, 0 failures` |
| bootstrap-failure (기본 / `--runtime-error`) | `--scene res://tests/bootstrap_failure.tscn [-- --runtime-error]` | `entry_blocked=true message_shown=true` 후 창 닫기 요청으로 종료 |
| bootstrap-scene-error | `--scene res://tests/bootstrap_failure.tscn -- --main-scene-error` | 지연 로드 실패 후 `deferred=true message_shown=true` |
| gui-integration (`--gui` 선택 시) | `--audio-driver Dummy --scene res://tests/integration.tscn` (headless 제외) | 창·화면 rollback 검사를 포함한 `INTEGRATION: N checks, 0 failures` |

모든 검사는 exit 0이어야 하고 로그에 `SCRIPT ERROR`·`Parse Error`·`ERROR:`·객체 누수가 없어야 한다(Godot은 스크립트 오류 뒤에도 exit 0일 수 있다). 예외는 실패 주입 검사의 `Game init script failed`와 `deliberate_init_failure`, 저장 변환의 `deliberate_migration_failure`, 장면으로 지정한 Theme의 `Cannot open main scene` 오류뿐이다. 로그는 `build/validation_logs/`에 남는다.

설정 도구·번역·라이선스 고지를 바꿨다면 `configure.gd`와 `write_engine_notices.gd`, CSV import 후 `project.godot`·`export_presets.cfg`·`ui/i18n/`·`third_party/`가 달라지지 않는지(`git diff`) 확인한다. CI도 이 검사를 한다.

GUI 스크린샷까지 남기려면 `godot --path . --scene res://tests/integration.tscn -- --capture`로 실행한다. 캡처 경로는 로그에 출력된다. 검사는 고유 `/tmp` 저장 경로를 쓰고 캡처 모드가 아니면 정리한다.

공통 회귀 검증은 Windows/macOS/Linux 실행 파일, 서명, 스토어 서버 검증을 대신하지 않는다. 실제 결과와 남은 범위는 [template/VALIDATION.md](template/VALIDATION.md)에 기록한다.
