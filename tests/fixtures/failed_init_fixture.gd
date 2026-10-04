## 명시적인 초기화 오류가 bootstrap까지 전달되는지 검사한다.
extends RefCounted

func before_app_initialize() -> Dictionary:
	return {"error": ERR_UNAVAILABLE}
