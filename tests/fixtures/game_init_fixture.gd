## 게임 초기화 hook이 App과 저장 읽기 전에 schema를 등록하는지 확인한다.
extends RefCounted

func before_app_initialize() -> Dictionary:
	SaveManager.set_meta("init_hook_count", int(SaveManager.get_meta("init_hook_count", 0)) + 1)
	SaveManager.set_meta("hook_before_app", not App.ready_for_game)
	SaveManager.schema_version = 2
	SaveManager.register_migration(1, func(old: Dictionary) -> Dictionary:
		old["hook_migration"] = true
		return old)
	return {"error": OK}
