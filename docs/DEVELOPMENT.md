# 개발 상세 안내

첫 실행은 [README](../README.md), 코드 변경 진입점은 [CODEBASE_MAP](CODEBASE_MAP.md)을 따른다. 아래 경로와 명령은 저장소 루트 기준이다.

## 요구 환경

- Godot **4.7.2 Standard**, 내장 GDScript. 로컬 확인값: `4.7.2.stable.official.ed1daf0bf`.
- Windows와 macOS 빌드는 같은 **4.7.2** export templates를 사용한다.
- 외부 addon, Python package, C#/.NET, Steam SDK 없이 Editor와 데모를 실행한다.
- 예시의 `godot`는 PATH의 실행 파일이다. macOS 기본 경로는 `/Applications/Godot.app/Contents/MacOS/Godot`이다.
- 이 저장소의 작업 명령은 RTK를 사용한다. 일반 개발 환경에 RTK가 없으면 `rtk proxy`를 생략할 수 있다.

## 폴더 구조

```text
autoload/              앱 수명의 공통 관리자 8개
core/input/            기본 입력
core/platform/         Desktop OS·headless·저장 위치
core/storage/          JSON 저장
core/logging/          Debug 로그
services/store/        ESD Service, 기본 Adapter, Debug Mock
ui/settings/           재사용 화면·음량·입력 설정
ui/loading/            장면 전환 overlay
scenes/                bootstrap, 데모와 장면 이동 예제
game/                  게임 코드·리소스·초기화 hook
config/game.cfg        공개 게임 설정
assets/demo/           공통 기능 예제 음원
tools/                 설정 반영·라이선스 고지 생성
tests/                 임시 파일을 쓰는 SceneTree 통합 검사
third_party/           엔진·제3자 배포 고지
docs/                  설계·개발·배포·의존성 안내
docs/template/         템플릿 적용·이력·구현·검증 기록
docs/distribution/     SteamPipe 예시 (업로드 입력용, 런타임 리소스 아님)
build/                 로컬 export 결과, Git 제외
```

## 설정

| section | 주요 키 | 적용 방법 |
| --- | --- | --- |
| `app` | name, version, data_directory, executable_name, macos_bundle | configure 후 Editor 재열기 |
| `app` | main_scene, init_script | 런타임 재실행 |
| `display` | viewport/window/minimum 크기 | configure; 사용자 설정은 기본값보다 우선 |
| `display` | default_mode, default_vsync, default_max_fps | 새 사용자 기본값; 기존 사용자는 설정 UI 사용 |
| `input` | controller_deadzone | 런타임 재실행; 기본 범위 0.05~0.95 |
| `export` | extra_include_filter, extra_exclude_filter, exclude_demo, steam_only_filter | configure 후 export |
| `lifecycle` | pause_on_focus_loss, mute_on_focus_loss | 런타임 재실행 |
| `save` | autosave_seconds | 런타임 재실행; 최소 1초 |
| `features` | store_enabled | 런타임 재실행 |
| `distribution` | channel | Editor 테스트용; export feature가 우선 |
| `services` | mode=mock/native/disabled | 런타임 재실행; Mock은 Debug만 허용 |
| `store` | achievement_ids, leaderboard_ids, timeout_seconds | 런타임 재실행 |

`app/version`은 게임 버전이다. 템플릿 버전은 `GameConfig.TEMPLATE_VERSION`이며 별도로 관리한다. 앱 버전은 숫자 `major.minor.patch[.build]`를 사용한다. `data_directory`는 상대 경로이며 `.`·`..`를 쓰지 않는다. `macos_bundle`은 게임의 고유 reverse-DNS ID로 바꾼다.

Editor를 한 번도 열지 않은 새 복사본은 먼저 `rtk proxy godot --headless --path . --editor --import --quit`로 클래스와 자산을 등록한다.

```bash
rtk proxy godot --headless --path . --script res://tools/configure.gd
```

configure는 앱 메타데이터, 화면 크기, 없는 기본 action과 여섯 preset을 갱신한다. 기존 InputMap, 추가 custom feature, 기존 서명·네이티브 옵션은 유지한다. preset 0~5는 도구가 소유하므로 위치·이름·채널·출력 경로를 직접 바꾸려면 도구도 함께 수정한다. 6번 이후의 추가 preset은 그대로 둔다.

사용자 설정은 `user://`에 저장한다. 표시 이름 변경은 저장 위치를 바꾸지 않는다. `data_directory`를 바꾸려면 이전 저장을 가져오는 migration을 별도로 구현한다. store App ID는 공개 식별자지만 계정 토큰·인증서·비밀 키는 `config/game.cfg`에 넣지 않는다.

## 저장과 오류 처리

```gdscript
SaveManager.set_value("progress", {"stage": 5})
var error := SaveManager.flush()
if error != OK:
	show_save_error(error) # 게임이 제공하는 함수

SaveManager.save_failed.connect(on_save_failed)
SaveManager.load_failed.connect(on_load_failed)
```

기본 슬롯은 `user://saves/slot_1.json`이다. `SaveManager.data`를 직접 수정하면 `mark_dirty()`를 호출한다. JSON 숫자는 읽을 때 float가 될 수 있으므로 게임 데이터 경계에서 `int()` 등으로 변환한다.

버전과 migration은 [game/README](../game/README.md)의 init hook으로 등록한다. 파싱·변환 실패 시 원본을 보존하고 쓰기를 차단한다. 게임은 실패 UI와 백업·복구 선택을 제공한다. 다중 슬롯·프로필이 필요하면 슬롯 경로와 데이터 수명 정책을 게임에 맞게 확장한다.

## 사용자 설정과 오디오

```gdscript
Settings.set_setting("language", "ko")
Settings.set_setting("master_volume", 0.7)
Settings.set_setting("subtitles_enabled", true)
AudioManager.play_bgm(bgm_stream)
AudioManager.play_sfx(effect_stream)
AudioManager.play_ui(click_stream)
```

Master, BGM, SFX, UI 버스는 시작 시 생성한다. 0~1 음량을 적용하고 0이면 mute한다. BGM 반복 여부는 AudioStream 리소스 설정에서 지정한다. 데모 BGM은 loop가 켜진 WAV다. 효과음은 동시 16개로 제한하고 재생 완료 후 정리한다.

설정 저장 실패 시 기존 활성 값과 파일을 유지하며 `changed`를 보내지 않는다. 반환 오류나 `save_failed`를 UI에서 처리한다. 오디오 suspend 중 새로 요청한 소리도 정지 상태로 준비되고 suspend 해제 후 재생된다.

`language`는 TranslationServer locale을 바꾼다. 실제 번역 리소스와 `tr()` 문자열은 게임이 제공한다. 템플릿 데모 문자열은 영어다. 사용자 설정 파일 손상 후 `reset_to_defaults()`는 복구를 선택받은 뒤 호출한다.

## 화면과 입력

```gdscript
var error := WindowManager.preview_options({
	"window_mode": "borderless", "vsync": true, "max_fps": 120
})
# 앱 수명의 확인창이 나타난다. 미확인 시 자동 복구한다.

var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
InputManager.start_capture(&"primary_action")
InputManager.capture_finished.connect(on_capture_finished)
```

`window_size`는 창 모드의 크기이며 내부 viewport 해상도는 `display/viewport_*` 설정이다. 고DPI와 resize를 지원한다. 기본 UI stretch는 `canvas_items/expand`여서 화면비에 따라 보이는 영역이 늘어난다. 실제 카메라·3D 렌더러·pixel art 확대 방식은 게임에 맞게 선택한다.

common action은 `move_*`, `primary_action`, `pause`, `toggle_fullscreen`이다. `project.godot`의 InputMap이 기본 바인딩의 기준이다. `core/input/default_input.gd`는 없는 action을 생성하는 fallback이다. 게임별 action은 InputMap에 추가하고 사용자 재설정이 필요하면 InputManager의 관리 목록과 기본값을 함께 확장한다.

재설정은 키보드/마우스 또는 게임패드 종류를 교체한다. 기본 UI action을 바꾸지 않는다. capture 중 Esc는 취소이며 동일 공통 action 간 중복 입력을 거절한다. 게임패드의 버튼·축 이벤트는 `device=-1`로 모든 컨트롤러를 받는다. 로컬 다인 입력과 플레이어별 장치 배정은 게임 기능이다.

Ctrl·Shift·Alt·Meta는 조합 키의 일부로 캡처한다. 단독 press/release는 캡처를 끝내지 않는다. 화면 확인 후 저장 실패는 `WindowManager.preview_failed(error)`에서 받으며 SettingsPanel은 `operation_failed`로 전달한다.

## Pause와 종료 UI

`App.set_paused("menu", true/false)`로 게임 메뉴 pause를 관리한다. 기본 game scene을 교체하면 데모의 Esc/Start 핸들러도 교체되므로 게임이 pause action을 처리해야 한다. pause 중 사용할 메뉴는 `PROCESS_MODE_ALWAYS`를 사용한다.

포커스의 pause와 오디오는 `lifecycle/pause_on_focus_loss`, `mute_on_focus_loss`로 각각 선택한다. 예를 들어 true/false이면 백그라운드에서 시뮬레이션은 멈추고 음악은 계속 재생된다. 메뉴·overlay의 pause는 오디오도 멈추며 포커스 복귀로 해제되지 않는다.

창 닫기 확인은 `App.quit_requested`, 저장 실패 처리는 `App.quit_failed`를 구독한다. 구독자가 없으면 App이 자동 저장 후 종료한다. `request_quit()` 실패 시 게임이 복구 UI를 제공한다. 저장 없이 종료하는 선택은 사용자가 명시적으로 선택한 뒤 처리한다.

## 장면 이동과 ESD

```gdscript
var error := SceneManager.change_scene("res://game/scenes/title.tscn")
SceneManager.transition_failed.connect(on_transition_failed)

if App.store.supports("achievements"):
	App.store.unlock_achievement("FIRST_WIN")
App.store.request_failed.connect(on_store_failed)
```

동기 반환값 OK는 요청 수락이다. 장면의 실제 완료는 `transition_completed`, ESD의 실제 완료는 `request_succeeded`로 받는다. logical ID는 게임 config에서 정의한다. Steam 연결 요건은 [STEAM](STEAM.md)을 따른다.

## 검증과 export

회귀 검사는 [CODEBASE_MAP의 변경 후 검증](CODEBASE_MAP.md#변경-후-검증), 실제 빌드·서명·업로드는 [DISTRIBUTION](DISTRIBUTION.md)을 따른다. 최신 실행 결과와 실행하지 못한 범위는 [검증 기록](template/VALIDATION.md)이 기준이다.
