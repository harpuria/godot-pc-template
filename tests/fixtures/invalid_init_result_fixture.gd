## 완료 결과에 error가 없으면 초기화 성공으로 간주하지 않는지 확인한다.
extends RefCounted

func before_app_initialize() -> Dictionary:
	return {}
