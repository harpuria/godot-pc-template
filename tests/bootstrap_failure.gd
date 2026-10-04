## 실패 hook을 실제 bootstrap으로 실행하여 App·저장·장면 진입을 차단하는지 확인한다.
extends Node

func _ready() -> void:
	var runtime_failure := "--runtime-error" in OS.get_cmdline_user_args()
	var directory := "/tmp/godot-pc-init-failure-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	SaveManager.storage_path = directory + "/save.json"
	Settings.storage_path = directory + "/settings.cfg"
	InputManager.storage_path = directory + "/input.cfg"
	SaveManager.data = {"untouched": true}
	GameConfig.config.set_value("app", "init_script", "res://tests/fixtures/runtime_error_init_fixture.gd" if runtime_failure else "res://tests/fixtures/failed_init_fixture.gd")
	_run.call_deferred()

func _run() -> void:
	var bootstrap := preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	await get_tree().process_frame
	var blocked := not App.ready_for_game and App.store == null and SaveManager.data == {"untouched": true} \
		and not SceneManager.transitioning and get_tree().current_scene == self
	print("BOOTSTRAP_FAILURE: entry_blocked=%s" % blocked)
	DirAccess.remove_absolute(SaveManager.storage_path.get_base_dir())
	get_tree().quit(0 if blocked else 1)
