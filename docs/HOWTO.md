# 자주 하는 작업

게임을 만들 때 자주 하는 작업을 단계별로 정리했다. 경로는 저장소 루트 기준이다. 용어는 [개발 참고](DEVELOPMENT.md#용어)를 참고한다.

- [첫 장면 바꾸기](#첫-장면-바꾸기)
- [입력 action 추가하기](#입력-action-추가하기)
- [pause 메뉴와 종료 처리](#pause-메뉴와-종료-처리)
- [진행 저장하기와 저장 구조 바꾸기](#진행-저장하기와-저장-구조-바꾸기)
- [사용자 설정 항목 추가하기](#사용자-설정-항목-추가하기)
- [소리 재생하기](#소리-재생하기)
- [장면 이동하기](#장면-이동하기)
- [UI 모양 바꾸기](#ui-모양-바꾸기)
- [번역 추가하기](#번역-추가하기)
- [앱 아이콘 바꾸기](#앱-아이콘-바꾸기)
- [Steam 업적·리더보드 연결하기](#steam-업적리더보드-연결하기)

## 첫 장면 바꾸기

1. `game/main.tscn`을 연다. pause 메뉴와 창 닫기 확인이 이미 연결된 빈 장면이다.
2. 루트 노드는 게임에 맞게 바꿔도 된다(예: `Node2D`, `Node3D`). `game/main.gd`의 두 줄(`PauseMenu` 추가, `quit_requested` 연결)은 유지한다.
3. `config/game.cfg`에서 `main_scene="res://game/main.tscn"`으로 바꾸고 F5로 실행한다.

데모(`scenes/`)는 지우지 않아도 된다. 배포할 때 `[export] exclude_demo=true`로 빠진다.

## 입력 action 추가하기

공통 action(`move_*`, `primary_action`, `pause`, `toggle_fullscreen`)은 이미 있다. 점프·상호작용처럼 게임 action을 추가하려면:

1. **Project → Project Settings → Input Map**에서 action(예: `interact`)과 기본 입력을 추가한다.
2. 플레이어가 설정 화면에서 바꿀 수 있게 하려면 `game/game_init.gd`에서 등록한다.

```gdscript
var error := InputManager.register_action(&"interact")
if error != OK:
	return {"error": error}
```

Input Map에 정의하지 않았다면 기본 입력을 함께 넘긴다.

```gdscript
InputManager.register_action(&"interact", [DefaultInput.key(KEY_E), DefaultInput.button(JOY_BUTTON_X)])
```

3. 게임 코드에서 읽는다.

```gdscript
if Input.is_action_just_pressed("interact"):
	open_door()
var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
```

등록한 action은 설정 화면(`SettingsPanel`)의 Action 목록에 나타나고, 장치 종류(키보드·마우스 / 게임패드)마다 주 입력·보조 입력 두 칸을 바꿀 수 있다. 사용자 바인딩은 `user://input.cfg`에 저장된다.

## pause 메뉴와 종료 처리

`game/main.tscn`에는 이미 연결되어 있다. 다른 장면에 붙이려면:

```gdscript
func _ready() -> void:
	add_child(PauseMenu.new())                    # Esc / Start로 열고 닫는다
	App.quit_requested.connect(_on_quit_requested) # 창 닫기(X) 요청

func _on_quit_requested() -> void:
	App.dialogs.confirm_quit()                    # 저장 후 종료 확인창
```

- 게임 쪽 pause 처리: `App.set_paused("cutscene", true/false)`처럼 이유별로 켜고 끈다. 마지막 이유가 해제될 때 게임이 다시 움직인다.
- pause 중에도 동작해야 하는 노드는 `process_mode = Node.PROCESS_MODE_ALWAYS`로 둔다.
- 저장에 실패하면 `App.dialogs`가 머무르기·재시도·저장 없이 종료를 묻는다. 직접 UI를 만들려면 `App.quit_failed`를 구독한다. 구독하면 기본 대화상자는 뜨지 않는다.
- 메뉴를 직접 만들려면 `PauseMenu.new()`의 `handle_pause_action = false`로 두고 `open()` / `close()`를 호출하거나, `App.set_paused("menu", ...)`를 직접 쓴다.

## 진행 저장하기와 저장 구조 바꾸기

```gdscript
SaveManager.set_value("progress", {"stage": 5, "coins": 120})
var error := SaveManager.flush()   # 즉시 저장. 안 해도 30초마다·pause·종료 때 저장된다
if error != OK:
	show_save_error(error)          # 게임이 제공하는 함수

var progress: Dictionary = SaveManager.data.get("progress", {})
var stage := int(progress.get("stage", 1))   # JSON 숫자는 float로 읽힐 수 있다
```

- `SaveManager.data`를 직접 고쳤다면 `SaveManager.mark_dirty()`를 호출한다.
- JSON으로 표현할 수 있는 값(Dictionary, Array, 문자열, 숫자, bool)만 저장한다.

출시 후 저장 구조를 바꾸면 `game/game_init.gd`에서 버전을 올리고 변환 함수를 등록한다.

```gdscript
SaveManager.schema_version = 2
SaveManager.register_migration(1, func(old: Dictionary) -> Dictionary:
	old["difficulty"] = "normal"
	return old)
```

저장 파일이 손상되었거나 더 새로운 버전이면 원본을 보존하고 쓰기를 막는다(`SaveManager.write_blocked`). 사용자에게 새로 시작할지 물은 뒤에만 `SaveManager.reset_slot()` → `flush()`를 호출한다.

## 사용자 설정 항목 추가하기

음량·화면 외의 사용자 설정도 같은 파일(`user://settings.cfg`)에 저장할 수 있다.

```gdscript
var error := Settings.set_setting("subtitles_enabled", true)   # 실패하면 값이 바뀌지 않는다
var subtitles: bool = Settings.get_setting("subtitles_enabled", false)
Settings.changed.connect(func(key: String, value: Variant): ...)
```

진행 데이터(레벨, 아이템)는 Settings가 아니라 SaveManager에 저장한다.

## 소리 재생하기

```gdscript
AudioManager.play_bgm(preload("res://game/audio/theme.ogg"))  # 반복은 리소스의 loop 설정
AudioManager.play_sfx(preload("res://game/audio/hit.wav"))
AudioManager.play_ui(preload("res://game/audio/click.wav"))
```

장면에 직접 놓는 `AudioStreamPlayer2D/3D`는 Inspector의 **Bus**에서 `SFX`·`BGM`·`UI`를 고른다. 버스 구성은 `default_bus_layout.tres`에 있고, 설정 화면의 음량 슬라이더가 각 버스에 적용된다.

## 장면 이동하기

```gdscript
var error := SceneManager.change_scene("res://game/scenes/stage_2.tscn")
SceneManager.transition_completed.connect(on_stage_ready)
SceneManager.transition_failed.connect(on_transition_failed)
```

반환값 OK는 "요청 수락"이다. 실제 완료는 `transition_completed`로 받는다. 전환 중 다른 요청은 `ERR_BUSY`로 거절된다. 로딩 화면은 `ui/loading/loading.tscn`이다.

## UI 모양 바꾸기

프로젝트 기본 Theme은 `ui/theme/default_theme.tres`다(Project Settings의 `gui/theme/custom`). 더블클릭하여 Theme 편집기에서 버튼·패널 색과 글꼴을 바꾸면 pause 메뉴·설정 화면·대화상자에 함께 적용된다. 게임 전용 Theme을 쓰려면 `game/`에 새 Theme을 만들고 `gui/theme/custom`을 그 파일로 바꾼다.

## 번역 추가하기

1. `game/i18n/text.csv`를 만든다. 첫 줄은 `keys,en,ko`처럼 키와 언어 코드다.

```csv
keys,en,ko
MENU_START,Start,시작
```

2. Godot이 CSV를 import하면 `text.en.translation`, `text.ko.translation`이 생긴다. **Project Settings → Localization → Translations**에 추가한다.
3. 코드에서는 `tr("MENU_START")`, 장면의 Label·Button은 text에 키(`MENU_START`)를 그대로 쓴다.
4. 언어 변경은 `Settings.set_setting("language", "ko")`다. 다음 실행에도 유지된다. 새 사용자의 기본값은 OS 언어(`OS.get_locale_language()`)이며, 번역이 없는 언어는 Project Settings의 fallback locale로 표시된다.

공통 UI(pause 메뉴·설정 화면·대화상자·화면 확인창)는 `ui/i18n/ui.csv`에 English / 한국어가 이미 있다. 설정 화면의 **Language(언어)** 목록은 불러온 번역에서 자동으로 만들어진다.

- 공통 UI 문구를 바꾸려면 `ui/i18n/ui.csv`의 해당 칸을 고친다.
- 언어를 추가하려면 `ui/i18n/ui.csv`와 게임 CSV에 같은 언어 열(예: `ja`)을 추가하고, 생성된 `ui.ja.translation`도 Translations에 등록한다. 언어 목록에 표시할 이름은 `UI_LANGUAGE_NAME` 행에 쓴다.
- 게임 action 이름은 게임 CSV에 `UI_ACTION_<ACTION 이름 대문자>` 키(예: `UI_ACTION_INTERACT`)를 추가하면 설정 화면에 번역되어 표시된다. 키가 없으면 `Interact`처럼 표시된다.
- 키 이름이나 OS 키 이름(`Space` 등)은 엔진이 만든 문자열이라 번역하지 않는다.

기본 글꼴에는 한글이 없어 OS 글꼴로 대체하여 표시한다. 한글 글꼴이 없는 시스템에서는 네모로 보일 수 있으므로, 출시 게임은 한글을 포함한 글꼴(라이선스 확인)을 Theme의 기본 글꼴로 지정한다.

## 앱 아이콘 바꾸기

- 창·작업 표시줄 아이콘: 루트의 `icon.svg`를 교체한다(Project Settings의 `application/config/icon`).
- Windows `.exe` 아이콘: 여러 크기(16~256px)를 담은 `.ico`를 만들고 Windows preset의 **Application → Icon**과 Project Settings의 `application/config/windows_native_icon`에 지정한다.
- macOS 앱 아이콘: `.icns`를 macOS preset의 **Application → Icon**과 `application/config/macos_native_icon`에 지정한다.

`configure.gd`는 preset의 아이콘 설정을 덮어쓰지 않는다. 자세한 형식은 [Godot Windows 아이콘 안내](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html)를 따른다.

## Steam 업적·리더보드 연결하기

게임 코드는 항상 `App.store`만 사용한다. SDK 연결은 [Steam 안내](STEAM.md)를 따른다.

```gdscript
if App.store.supports("achievements"):
	App.store.unlock_achievement("FIRST_WIN")   # config/game.cfg [store]의 논리 ID
App.store.request_failed.connect(on_store_failed)
```

업적 성공 여부만으로 아이템·진행을 지급하지 않는다. 게임 보상은 SaveManager에 저장한다.
