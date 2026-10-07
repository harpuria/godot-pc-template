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
| 장면 전환·로딩 | `autoload/scene_manager.gd`, `ui/loading/loading.tscn` |
| ESD 서비스·외부 SDK | `docs/STEAM.md`, `docs/DEPENDENCIES.md`, `services/store/` |
| 게임 이름·버전·저장 위치·bundle | `config/game.cfg`, `tools/configure.gd` |
| export preset·서명·패키징·업로드 | `docs/DISTRIBUTION.md`, `export_presets.cfg`, `docs/distribution/` |
| 회귀 검사·CI | `tools/validate.sh`, `.github/workflows/validate.yml`, `tests/` |
| 동작 예제 / 공통 회귀 | `scenes/demo.gd`, `game/main.gd`, `tests/integration.gd` |
| 실제 bootstrap 실패 차단 | `tests/bootstrap_failure.tscn`, `tests/fixtures/*init*` |

`scenes/`와 `assets/demo/`는 공통 기능 예제다. `tests/`가 사용하므로 유지한다. `game/`의 골격은 파생 게임이 소유하며 템플릿 업데이트로 덮어쓰지 않는다. 게임 배포에서 데모를 제외하는 방법은 배포 문서에 있다. `docs/template/`는 템플릿 자체의 기록이며 게임 설계·검증 문서를 쓰는 위치가 아니다.

## 설정 전파

- 런타임: `config/game.cfg` → GameConfig → App/관리자. 변경 후 재실행한다.
- 프로젝트·export: `config/game.cfg` → `tools/configure.gd` → `project.godot`, 아홉 preset(0~8번; Windows·macOS·Linux × 세 채널). 게임이 이미 정의한 InputMap과 기존 SDK·서명 옵션은 보존한다.
- 배포 채널: preset의 `standalone` / `itch` / `steam` feature가 config보다 우선한다. Editor의 `auto`는 standalone이다.
- 사용자 설정: 전체 파일 검증 / 디스크 저장 성공 → `Settings.changed` → 오디오 버스. 화면 후보는 WindowManager가 즉시 적용하고 확인 후 Settings에 저장한다. 확인 실패는 `preview_failed` → SettingsPanel의 `operation_failed`로 전달한다.
- 바인딩: InputManager가 등록된 action의 허용된 입력 필드만 ConfigFile에 기록한다. 아직 등록되지 않은 action의 저장값은 보존한다. `ui_*` action은 재설정 대상에서 제외한다.
- 저장 위치: `app/data_directory`는 configure 시 고정 user directory에 반영한다. 장면 이동이나 ESD 선택은 위치를 바꾸지 않는다.

## 변경 후 검증

저장소 루트에서 Godot **4.7.2**로 공통 회귀 검사를 실행한다. CI(`.github/workflows/validate.yml`)도 같은 스크립트를 Linux에서 실행한다.

```bash
tools/validate.sh                         # PATH의 godot 사용
GODOT=/path/to/Godot tools/validate.sh    # 예: macOS /Applications/Godot.app/Contents/MacOS/Godot
```

스크립트가 실행하는 검사:

| 이름 | 명령 인수 | 통과 조건 |
| --- | --- | --- |
| import | `--editor --import --quit` | exit 0, 오류 로그 없음 |
| integration (기본 / `--disabled` / `--native`) | `--scene res://tests/integration.tscn [-- 옵션]` | `INTEGRATION: N checks, 0 failures` |
| bootstrap-failure (기본 / `--runtime-error`) | `--scene res://tests/bootstrap_failure.tscn [-- --runtime-error]` | `entry_blocked=true message_shown=true` 후 창 닫기 요청으로 종료 |

모든 검사는 exit 0이어야 하고 로그에 `SCRIPT ERROR`·`Parse Error`·`ERROR:`·객체 누수가 없어야 한다(Godot은 스크립트 오류 뒤에도 exit 0일 수 있다). 예외는 실패 주입 검사의 `Game init script failed`와 `deliberate_init_failure` 로그뿐이다. 로그는 `build/validation_logs/`에 남는다.

설정 도구를 바꿨다면 configure를 두 번 실행해 `project.godot`·`export_presets.cfg`가 달라지지 않는지(`git diff`) 확인한다. CI도 이 검사를 한다.

GUI 화면을 바꿨다면 `godot --path . --scene res://tests/integration.tscn -- --capture`로 실제 창과 화면 설정 rollback을 확인한다. 캡처 경로는 로그에 출력된다. 검사는 고유 `/tmp` 저장 경로를 쓰고 캡처 모드가 아니면 정리한다.

공통 회귀 검증은 Windows/macOS/Linux 실행 파일, 서명, 스토어 서버 검증을 대신하지 않는다. 실제 결과와 남은 범위는 [template/VALIDATION.md](template/VALIDATION.md)에 기록한다.
