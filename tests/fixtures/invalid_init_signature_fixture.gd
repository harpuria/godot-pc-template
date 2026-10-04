## 필수 인수가 있는 hook을 실행 전에 거절하는지 검사한다.
extends RefCounted

func before_app_initialize(_required: int) -> Dictionary:
	SaveManager.set_meta("invalid_hook_called", true)
	return {"error": OK}
