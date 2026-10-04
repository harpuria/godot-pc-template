# Game Layer

게임별 scene, script, resource와 저장 데이터 구조를 이 폴더에 둔다. 첫 장면은 `config/game.cfg`의 `app/main_scene`으로 지정하고 프로젝트 실행은 bootstrap부터 시작한다.

## 공통 API

```gdscript
SaveManager.set_value("progress", {"level": 3, "coins": 100})
var error := SaveManager.flush()
var progress: Dictionary = SaveManager.data.get("progress", {})

Settings.set_setting("sfx_volume", 0.5)
AudioManager.play_sfx(preload("res://game/audio/click.wav"))
SceneManager.change_scene("res://game/scenes/title.tscn")

var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
InputManager.start_capture(&"primary_action")
WindowManager.preview_options({"window_mode": "borderless"})

App.set_paused("menu", true)
App.set_paused("menu", false)
App.store.unlock_achievement("FIRST_WIN")
```

위의 음원·장면·업적 ID는 예시다. 실제 게임 리소스와 `config/game.cfg`의 논리 ID로 교체한다. 오류 반환값과 실패 신호를 처리하고, 업적 성공만으로 아이템이나 게임 진행을 지급하지 않는다.

## 저장 schema와 초기화

`game/game_init.gd`를 만들고 `[app] init_script="res://game/game_init.gd"`로 연결한다. hook은 App 초기화와 저장 읽기 전에 한 번 호출된다.

```gdscript
## 게임별 저장 버전과 변환 함수를 공통 관리자에 등록한다.
extends RefCounted

func before_app_initialize() -> Dictionary:
	SaveManager.schema_version = 2
	SaveManager.register_migration(1, func(old: Dictionary) -> Dictionary:
		old["difficulty"] = "normal"
		return old)
	return {"error": OK}
```

hook script는 `RefCounted`를 상속하고 인수 없는 `before_app_initialize() -> Dictionary`를 제공한다. 동기 초기화를 끝낸 뒤 `{"error": OK}`를 반환한다. 실패하면 `{"error": ERR_...}`를 반환한다. 내부 등록·SDK 함수의 반환 오류도 검사하여 이 결과로 전달한다. `await`를 사용하는 비동기 hook은 지원하지 않는다. 생성자에도 필수 인수를 두지 않는다.

bootstrap은 메서드 서명과 결과의 필수 `error` 필드를 검사한다. `void`·정수 반환형, 누락된 결과, 런타임 오류 또는 실패 코드는 App 초기화·저장 읽기·게임 진입을 차단한다. 정수 반환형은 엔진의 오류 기본값 `0`이 `OK`와 같으므로 사용하지 않는다. 기존 void hook은 반환형과 마지막 결과 반환문을 함께 변경해야 한다. 게임별 schema는 `scenes/bootstrap.gd`에 넣지 않는다.

저장·설정·입력 파일은 서로 분리된다. 손상된 진행을 덮어쓰려면 원본 백업과 사용자 선택 이후 `SaveManager.reset_slot(initial_data)` → `flush()`를 호출한다. 자동으로 reset하지 않는다.

## Pause 메뉴와 종료

게임 시뮬레이션은 기본 process mode를 사용한다. pause 중 조작할 메뉴 루트는 `Node.PROCESS_MODE_ALWAYS`로 둔다. focus·overlay·menu 이유는 독립적으로 관리되어 한 이유의 해제가 다른 pause를 풀지 않는다.

기본 데모의 pause·종료 UI는 `scenes/demo.gd`가 제공한다. 새 게임은 자체 UI를 만든다. `App.quit_requested`에 연결하면 창 닫기 요청을 받아 확인창을 표시할 수 있다. 저장 후 종료는 `App.request_quit()`, 저장 실패 후 사용자가 명시적으로 종료를 선택한 경우는 `App.quit_without_saving()`이다.

게임 코드는 Steam singleton을 직접 호출하지 않고 `App.store`를 사용한다. 구체 Adapter 등록은 [Steam 안내](../docs/STEAM.md)를 따른다.
