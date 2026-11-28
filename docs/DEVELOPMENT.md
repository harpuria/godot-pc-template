# 개발 참고

첫 실행은 [README](../README.md), 단계별 작업은 [자주 하는 작업](HOWTO.md)을 본다. 이 문서는 환경·폴더·용어·설정을 찾아보는 참고 자료다. 경로와 명령은 저장소 루트 기준이다.

## 요구 환경

- Godot **4.7.2 Standard**(내장 GDScript). 확인한 빌드: `4.7.2.stable.official.ed1daf0bf`.
- 실행 파일을 만들려면 같은 **4.7.2** export templates.
- 외부 런타임 addon, C#/.NET, Steam SDK 없이 Editor와 데모가 실행된다. 기본 활성화된 **Godot AI**(`addons/godot_ai`, v4.4.2) 독으로 외부 AI(MCP) 클라이언트를 연결할 때만 [uv](https://docs.astral.sh/uv/)가 필요하다(`uv` 없이도 Editor·테스트·export는 그대로 동작한다).
- 명령의 `godot`는 PATH의 Godot 실행 파일이다. macOS 기본 경로는 `/Applications/Godot.app/Contents/MacOS/Godot`다.

## 폴더 구조

```text
addons/godot_ai/       기본 활성화된 Godot AI MCP 에디터 플러그인 (export에서는 자동 제외)
autoload/              앱 수명의 공통 관리자 8개 (GameConfig, Settings, SaveManager, AudioManager,
                       WindowManager, InputManager, SceneManager, App)
core/                  입력 기본값, OS·저장 위치, JSON 저장, Debug 로그
services/store/        스토어 서비스(StoreService), 기본 Adapter, Debug Mock
ui/menus/              재사용 pause 메뉴 (PauseMenu)
ui/dialogs/            종료 확인·저장 실패 대화상자 (QuitDialogs, App.dialogs)
ui/settings/           재사용 화면·음량·입력 설정 패널 (SettingsPanel)
ui/loading/            장면 전환 로딩 화면
ui/theme/              프로젝트 기본 Theme
ui/i18n/               공통 UI 번역 (ui.csv: en, ko)
game/                  게임 코드·리소스. main.tscn(첫 장면)과 game_init.gd(초기화 hook) 골격 포함
scenes/                bootstrap(진입점), 데모와 장면 이동 예제
config/game.cfg        공개 게임 설정
default_bus_layout.tres  Master / BGM / SFX / UI 오디오 버스
assets/demo/           데모 음원
tools/                 설정 반영(configure), 회귀 검사(validate.sh), 라이선스 고지 생성
tests/                 공통 통합 검사와 실패 주입 fixture
third_party/           엔진·제3자 배포 고지
docs/                  가이드와 참고 문서
docs/template/         템플릿 적용·이력·구현·검증 기록
docs/distribution/     SteamPipe 업로드 예시
.github/workflows/     CI (tools/validate.sh --gui로 Linux headless·Xvfb GUI 회귀 및 리소스 일관성 검사)
build/                 로컬 export 결과 (Git 제외)
```

## 용어

| 용어 | 뜻 |
| --- | --- |
| Autoload | 게임 시작 시 한 번 만들어져 장면이 바뀌어도 유지되는 전역 노드. `SaveManager.flush()`처럼 이름으로 호출한다 |
| init hook | `game/game_init.gd`의 `before_app_initialize()`. 저장 읽기 전에 저장 구조·입력 action·스토어 Adapter를 등록한다 |
| 배포 채널 | `standalone`(스토어 없음) / `itch` / `steam`. export preset의 feature로 정해진다 |
| ESD / 스토어 서비스 | Steam 같은 전자 소프트웨어 유통(Electronic Software Distribution) 플랫폼 기능. 게임은 `App.store`(StoreService)로만 호출한다 |
| Adapter | 실제 SDK(예: GodotSteam)를 `StoreAdapter` 계약에 맞게 감싼 클래스 |
| Mock | SDK 없이 성공 결과를 흉내 내는 개발용 Adapter. Debug 빌드에서만 동작한다 |
| pause 이유 | `menu`, `focus`, `quit_dialog` 등 이름별 pause. 모두 해제되어야 게임이 다시 움직인다 |
| 화면 미리보기 | 화면 설정을 먼저 적용하고 15초 안에 확인해야 저장하는 방식. 확인하지 않으면 되돌린다. F11 / Alt+Enter 전환은 확인 없이 바로 저장한다 |
| 주 입력 / 보조 입력 | action마다 장치 종류(키보드·마우스 / 게임패드)별로 바꿀 수 있는 두 칸 |

## 설정 (`config/game.cfg`)

| section | 주요 키 | 적용 방법 |
| --- | --- | --- |
| `app` | name, version, data_directory, executable_name, macos_bundle | configure 후 Editor 다시 열기 |
| `app` | main_scene, init_script | 다시 실행 |
| `display` | viewport/window/minimum 크기 | configure; 사용자 설정이 기본값보다 우선 |
| `display` | default_mode, default_vsync, default_max_fps | 새 사용자의 기본값 |
| `input` | controller_deadzone | configure 또는 다시 실행; 0.05~0.95 |
| `export` | extra_include_filter, extra_exclude_filter, exclude_demo, steam_only_filter | configure 후 export |
| `lifecycle` | pause_on_focus_loss, mute_on_focus_loss | 다시 실행 |
| `save` | autosave_seconds | 다시 실행; 최소 1초 |
| `features` | store_enabled | 다시 실행 |
| `distribution` | channel | Editor 테스트용; export preset의 채널이 우선 |
| `services` | mode = mock / native / disabled | 다시 실행; Mock은 Debug에서만 동작 |
| `store` | achievement_ids, leaderboard_ids, timeout_seconds | 다시 실행 |

- `app/version`은 게임 버전이며 숫자 `major.minor.patch[.build]` 형식이다. 템플릿 버전(`GameConfig.TEMPLATE_VERSION`)과 별개다.
- `data_directory`는 `.`·`..` 없는 상대 경로다. 바꾸면 기존 저장을 찾지 못하므로 출시 후에는 고정한다.
- `macos_bundle`은 게임 고유의 reverse-DNS ID로 바꾼다.
- 계정 토큰·인증서·비밀 키는 이 파일에 넣지 않는다. 스토어 App ID 같은 공개 식별자는 괜찮다.

`[app]`·`[display]`·`[export]`를 바꾸면 configure를 실행한다. 새로 받은 복사본은 먼저 import로 클래스와 자산을 등록한다.

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/configure.gd
```

configure는 먼저 `app/main_scene`이 인스턴스를 만들 수 있는 `PackedScene`인지 확인한다. 잘못된 경로를 지정하면 프로젝트 설정과 preset을 쓰기 전에 실패한다. 검사를 통과하면 앱 정보, 화면 크기, 기본 action(및 기존 기본 action의 deadzone), 공통 UI 번역 등록과 export preset 0~8번(Windows·macOS·Linux × Standalone·Itch·Steam)을 갱신하고 `build/` 출력 폴더를 만든다. 이미 있는 Input Map의 바인딩, 추가 custom feature, 서명·아이콘 같은 preset 옵션은 유지한다. 출력 폴더 생성이 실패하면 경로와 오류를 보고하고 프로젝트 설정과 preset을 쓰기 전에 종료한다. 직접 만든 preset은 9번 이후에 두며, 0~8번 자리에 다른 이름의 preset이 있으면 덮어쓰지 않고 실패한다.

## 사용자 데이터 파일

| 파일 | 담당 | 내용 |
| --- | --- | --- |
| `user://saves/slot_1.json` | SaveManager | 게임 진행 |
| `user://settings.cfg` | Settings | 음량·언어·화면과 게임별 사용자 설정 |
| `user://input.cfg` | InputManager | 사용자 입력 바인딩 |

`user://`는 `data_directory` 아래의 OS별 사용자 폴더다(Windows `%APPDATA%\<data_directory>`, macOS `~/Library/Application Support/<data_directory>`, Linux `~/.local/share/<data_directory>`). 손상된 파일은 원본을 보존하고 덮어쓰지 않는다. 세부 규칙은 [설계 설명](ARCHITECTURE.md#저장-데이터와-설정)에 있다.

## 화면

`window_size`는 창 모드의 크기이고 내부 해상도는 `display/viewport_*` 설정이다. 기본 stretch는 `canvas_items` / `expand`라서 화면비에 따라 보이는 영역이 넓어진다. 카메라, 3D 렌더러, pixel art 확대 방식은 게임에 맞게 고른다.

## 검증과 export

변경 후 검사는 [코드 안내서의 변경 후 검증](CODEBASE_MAP.md#변경-후-검증), 실행 파일·서명·업로드는 [배포 안내](DISTRIBUTION.md)를 따른다. 실제로 실행한 결과와 확인하지 못한 범위는 [검증 기록](template/VALIDATION.md)이 기준이다.
