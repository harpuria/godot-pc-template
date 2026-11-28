## 실패 hook을 실제 bootstrap으로 실행하여 App·저장·장면 진입을 차단하는지 확인한다.
extends Node

func _ready() -> void:
	var runtime_failure := "--runtime-error" in OS.get_cmdline_user_args()
	var directory := "/tmp/godot-pc-init-failure-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	SaveManager.storage_path = directory + "/save.json"
	Settings.storage_path = directory + "/settings.cfg"
	InputManager.storage_path = directory + "/input.cfg"
	if "--main-scene-error" in OS.get_cmdline_user_args():
		GameConfig.config.set_value("app", "init_script", "")
		_deferred_scene_error.call_deferred()
		return
	SaveManager.data = {"untouched": true}
	GameConfig.config.set_value("app", "init_script", "res://tests/fixtures/runtime_error_init_fixture.gd" if runtime_failure else "res://tests/fixtures/failed_init_fixture.gd")
	_run.call_deferred()

func _run() -> void:
	var bootstrap := preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	await get_tree().process_frame
	var blocked := not App.ready_for_game and App.store == null and SaveManager.data == {"untouched": true} \
		and not SceneManager.transitioning and get_tree().current_scene == self
	var message_shown := bootstrap.get_children().any(func(child: Node): return child is Label)
	print("BOOTSTRAP_FAILURE: entry_blocked=%s message_shown=%s" % [blocked, message_shown])
	_cleanup(SaveManager.storage_path.get_base_dir())
	if not blocked or not message_shown:
		get_tree().quit(1)
		return
	# 초기화 실패 후에도 창 닫기 요청으로 종료할 수 있어야 한다.
	App.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().create_timer(1.0).timeout
	print("BOOTSTRAP_FAILURE: close_allowed=false")
	get_tree().quit(1)

## 존재하지만 장면으로 로드할 수 없는 리소스의 지연 실패를 실제 bootstrap UI에서 확인한다.
func _deferred_scene_error() -> void:
	var path := "res://ui/theme/default_theme.tres"
	GameConfig.config.set_value("app", "main_scene", path)
	var bootstrap := preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	var accepted := SceneManager.transitioning
	for frame in 6:
		await get_tree().process_frame
	var labels := bootstrap.find_children("*", "Label", false, false)
	var shown: bool = labels.size() == 1 and labels[0].text == tr("UI_MAIN_SCENE_FAILED") % path
	print("BOOTSTRAP_FAILURE: deferred=%s message_shown=%s" % [accepted, shown])
	_cleanup(SaveManager.storage_path.get_base_dir())
	get_tree().quit(0 if accepted and shown and not SceneManager.transitioning else 1)

func _cleanup(directory: String) -> void:
	var access := DirAccess.open(directory)
	if access != null:
		for name in access.get_files():
			DirAccess.remove_absolute(directory.path_join(name))
		for name in access.get_directories():
			_cleanup(directory.path_join(name))
	DirAccess.remove_absolute(directory)
