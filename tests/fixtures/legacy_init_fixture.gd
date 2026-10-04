## 결과를 반환하지 않는 이전 hook 계약을 거절하는지 검사한다.
extends RefCounted

func before_app_initialize() -> void:
	SaveManager.set_meta("invalid_hook_called", true)
