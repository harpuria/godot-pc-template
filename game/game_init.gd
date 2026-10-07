## 게임 초기화 hook이다. App 초기화와 저장 읽기 전에 한 번 실행된다.
## 저장 schema·migration, 설정에서 바꿀 게임 입력 action, 검증한 스토어 Adapter를 여기서 등록한다.
extends RefCounted

func before_app_initialize() -> Dictionary:
	# 저장 구조를 바꾸면 버전을 올리고 이전 버전의 변환 함수를 등록한다.
	# SaveManager.schema_version = 2
	# SaveManager.register_migration(1, func(old: Dictionary) -> Dictionary:
	# 	old["difficulty"] = "normal"
	# 	return old)

	# 설정 화면에서 바꿀 수 있는 게임 action을 추가한다.
	# Project Settings → Input Map에 이미 정의한 action은 기본 입력 인수를 생략한다.
	# var error := InputManager.register_action(&"interact", [DefaultInput.key(KEY_E), DefaultInput.button(JOY_BUTTON_X)])
	# if error != OK:
	# 	return {"error": error}

	# 실패하면 {"error": ERR_...}를 반환한다. 게임 진입이 차단되고 화면에 오류가 표시된다.
	return {"error": OK}
