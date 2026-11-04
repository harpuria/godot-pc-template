## 임시 저장 경로로 데이터 보호·입력·pause·서비스 계약과 실제 장면 이동을 검사한다.
extends Node

class ProbeAdapter extends StoreAdapter:
	var initialized_count := 0
	var requests: Array[int] = []
	func initialize() -> bool:
		initialized_count += 1
		return true
	func capabilities() -> Dictionary:
		return {"achievements": true, "leaderboards": true, "overlay": true}
	func execute(id: int, _operation: String, _payload: Dictionary) -> void:
		requests.append(id)

var _checks := 0
var _failures := 0
var _directory := "/tmp/godot-pc-check-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var _successes := 0
var _store_failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_directory)
	SaveManager.storage_path = _directory + "/saves/slot_1.json"
	Settings.storage_path = _directory + "/settings.cfg"
	InputManager.storage_path = _directory + "/input.cfg"
	# GUI에서 테스트할 때도 사용자 설정을 쓰지 않는다.
	Settings.values = Settings.defaults()
	Settings.write_blocked = false
	InputManager.write_blocked = false
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--disabled" in args:
		GameConfig.config.set_value("features", "store_enabled", false)
	if "--native" in args:
		GameConfig.config.set_value("services", "mode", "native")
	_init_checks()
	_check(preload("res://scenes/bootstrap.gd").run_init_script("res://tests/fixtures/game_init_fixture.gd") == OK, "Valid init hook accepted")
	_check(SaveManager.get_meta("hook_before_app", false) and SaveManager.get_meta("init_hook_count", 0) == 1, "Hook runs once before App")
	_check(SaveManager.schema_version == 2 and SaveManager.migrations.has(1), "Hook registers game schema and migration")
	SaveManager.schema_version = 1
	SaveManager.migrations.clear()
	App.initialize()
	_check(App.ready_for_game, "App initialized")
	var store_instance := App.store
	App.initialize()
	_check(App.store == store_instance, "Repeated initialization preserves service")
	_check(GameConfig.distribution_channel() in ["standalone", "itch", "steam"], "Distribution channel resolved")
	if "--disabled" in args or "--native" in args:
		_check(not App.store.available, "Disabled / SDK-absent store is unavailable")
		_check(not App.store.is_mock(), "Disabled / native path does not select mock")
		_check(App.store.unlock_achievement("DEMO_FIRST_WIN") == ERR_UNAVAILABLE, "Unavailable store reports failure")
	else:
		_check(App.store.is_mock() == OS.is_debug_build(), "Mock build guard")
		if OS.is_debug_build():
			App.store.request_succeeded.connect(func(_op: String, _id: String, result: Dictionary):
				_check(result.get("mock", false), "Mock completion clearly marked"))
			_check(App.store.unlock_achievement("DEMO_FIRST_WIN") == OK, "Mock request accepted")
			await get_tree().process_frame
	_check(App.store.unlock_achievement("UNKNOWN") == ERR_INVALID_PARAMETER, "Logical ID validation")
	_check(App.store.open_overlay("invalid") == ERR_INVALID_PARAMETER, "Overlay page validation")
	_check(preload("res://scenes/bootstrap.gd").run_init_script("") == OK, "Empty init hook allowed")
	_check(GameConfig.value("app", "init_script") == "res://game/game_init.gd" \
		and preload("res://scenes/bootstrap.gd").run_init_script("res://game/game_init.gd") == OK, "Game init skeleton is wired and valid")
	_check(ResourceLoader.exists("res://default_bus_layout.tres") and AudioServer.get_bus_index("BGM") == 1 \
		and AudioServer.get_bus_index("SFX") == 2 and AudioServer.get_bus_index("UI") == 3, "Editor-visible bus layout provides BGM/SFX/UI")
	_check(load(str(ProjectSettings.get_setting("gui/theme/custom", ""))) is Theme, "Project default theme loads")
	_check(preload("res://scenes/bootstrap.gd").run_init_script("res://game/missing.gd") == ERR_FILE_NOT_FOUND, "Missing hook rejected")
	_save_checks()
	_settings_checks()
	_input_checks()
	_pause_checks()
	await _quit_checks()
	await _service_checks()
	await _display_checks()
	await _audio_checks()
	# 통합 검사를 App 아래로 옮겨 실제 current_scene 교체 뒤에도 검사를 계속한다.
	reparent(App)
	get_tree().current_scene = null
	_check(SceneManager.change_scene("res://scenes/main.tscn") == OK, "Demo transition accepted")
	_check(SceneManager.change_scene("res://scenes/transition_demo.tscn") == ERR_BUSY, "Duplicate transition rejected")
	await SceneManager.transition_completed
	_check(get_tree().current_scene.scene_file_path == "res://scenes/main.tscn", "Demo scene entered")
	_check(not SceneManager.transitioning, "Transition completed state")
	if "--capture" in args and DesktopPlatform.has_window():
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_check(image.save_png(_directory + "/demo.png") == OK, "Rendered demo captured")
		print("CAPTURE: " + _directory + "/demo.png")
	_check(SceneManager.change_scene("res://scenes/missing.tscn") == ERR_FILE_NOT_FOUND, "Missing scene fails safely")
	_check(SceneManager.change_scene("res://scenes/transition_demo.tscn") == OK, "Second scene accepted")
	await SceneManager.transition_completed
	_check(get_tree().current_scene.scene_file_path == "res://scenes/transition_demo.tscn", "Second scene entered")
	_check(App.store == store_instance and SaveManager.data.get("recovered") == true, "Managers persist across scenes")
	_check(SceneManager.change_scene("res://game/main.tscn") == OK, "Game skeleton scene accepted")
	await SceneManager.transition_completed
	_check(get_tree().current_scene.scene_file_path == "res://game/main.tscn" \
		and get_tree().current_scene.get_children().any(func(child: Node): return child is PauseMenu), "Game skeleton enters with pause menu")
	await get_tree().process_frame
	if not "--capture" in args:
		_cleanup(_directory)
	print("INTEGRATION: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _init_checks() -> void:
	var bootstrap := preload("res://scenes/bootstrap.gd")
	_check(bootstrap.run_init_script("res://tests/fixtures/failed_init_fixture.gd") == ERR_UNAVAILABLE, "Hook failure propagated")
	_check(bootstrap.run_init_script("res://tests/fixtures/invalid_init_signature_fixture.gd") == ERR_INVALID_PARAMETER, "Hook arguments rejected before invocation")
	_check(bootstrap.run_init_script("res://tests/fixtures/legacy_init_fixture.gd") == ERR_INVALID_PARAMETER, "Void hook cannot imply success")
	_check(bootstrap.run_init_script("res://tests/fixtures/invalid_init_result_fixture.gd") == ERR_INVALID_DATA, "Missing hook result cannot imply success")
	_check(not SaveManager.has_meta("invalid_hook_called"), "Invalid hook bodies never run")
	_check(not App.ready_for_game and SaveManager.schema_version == 1, "Failed hooks leave App uninitialized")

func _save_checks() -> void:
	_check(SaveManager.data.is_empty(), "Missing save starts empty")
	SaveManager.set_value("progress", {"level": 4, "coins": 12})
	_check(SaveManager.flush() == OK and not SaveManager.dirty, "Save creates directory and clears dirty")
	SaveManager.data = {}
	_check(SaveManager.load_slot() == OK and SaveManager.data.progress.level == 4, "Save round trip")
	SaveManager.schema_version = 2
	SaveManager.register_migration(1, func(old: Dictionary) -> Dictionary:
		old["migrated"] = true
		return old)
	_check(SaveManager.load_slot() == OK and SaveManager.data.migrated, "Schema migration applied")
	_check(SaveManager.dirty and SaveManager.flush() == OK, "Migrated save persisted")
	_write(SaveManager.storage_path, "{broken json")
	var previous := SaveManager.data.duplicate(true)
	_check(SaveManager.load_slot() == ERR_PARSE_ERROR and SaveManager.write_blocked, "Corrupt save blocks writes")
	SaveManager.set_value("attempt", 1)
	_check(SaveManager.flush() == ERR_UNAUTHORIZED, "Blocked auto-save rejected")
	_check(FileAccess.get_file_as_string(SaveManager.storage_path) == "{broken json", "Corrupt original preserved")
	_check(SaveManager.data.progress == previous.progress, "Failed load preserves memory")
	JsonStore.write(SaveManager.storage_path, {"version": 99, "data": {}})
	_check(SaveManager.load_slot() == ERR_INVALID_DATA and SaveManager.write_blocked, "Future schema preserved")
	JsonStore.write(SaveManager.storage_path, {"version": 1.5, "data": {}})
	_check(SaveManager.load_slot() == ERR_INVALID_DATA, "Fractional schema rejected")
	SaveManager.reset_slot({"recovered": true})
	_check(SaveManager.flush() == OK and not SaveManager.write_blocked, "Explicit reset permits save")
	_check(SaveManager.load_slot() == OK and SaveManager.data.recovered, "Recovered save loads")
	# Windows의 rename은 원본 삭제 후 이동한다. 그 사이 중단되면 완성된 .tmp만 남는다.
	DirAccess.rename_absolute(SaveManager.storage_path, SaveManager.storage_path + ".tmp")
	SaveManager.data = {}
	_check(SaveManager.load_slot() == OK and SaveManager.data.get("recovered") == true and SaveManager.dirty, "Interrupted replace restores completed temp save")
	_check(SaveManager.flush() == OK and FileAccess.file_exists(SaveManager.storage_path) \
		and not FileAccess.file_exists(SaveManager.storage_path + ".tmp"), "Restored save rewritten to original path")
	var original_path := SaveManager.storage_path
	SaveManager.storage_path = _directory + "/saves/first_write.json"
	_write(SaveManager.storage_path + ".tmp", "{partial")
	_check(SaveManager.load_slot() == OK and SaveManager.data.is_empty() and not SaveManager.write_blocked, "Incomplete first-write temp starts fresh")
	SaveManager.storage_path = original_path
	_check(SaveManager.load_slot() == OK and SaveManager.data.recovered, "Original save path restored")

func _settings_checks() -> void:
	_check(Settings.set_setting("master_volume", 2.0) == OK and Settings.get_setting("master_volume") == 1.0, "Volume clamped")
	_check(Settings.set_setting("master_volume", "bad") == ERR_INVALID_PARAMETER, "Invalid volume rejected")
	_check(Settings.set_setting("window_size", Vector2i(-1, 720)) == ERR_INVALID_PARAMETER, "Invalid resolution rejected")
	_check(Settings.set_many({"vsync": false, "max_fps": 144}) == OK, "Display settings persisted together")
	Settings.values.vsync = true
	_check(Settings.load_settings() == OK and Settings.get_setting("vsync") == false, "Settings round trip")
	_write(Settings.storage_path, "[wrong]\nvalue=1\n")
	_check(Settings.load_settings() == ERR_INVALID_DATA and Settings.write_blocked, "Malformed settings protected")
	_check(Settings.set_setting("sfx_volume", 0.5) == ERR_UNAUTHORIZED, "Protected settings not overwritten")
	_check(FileAccess.get_file_as_string(Settings.storage_path).begins_with("[wrong]"), "Settings original preserved")
	_check(Settings.reset_to_defaults() == OK, "Explicit settings recovery")
	var changes: Array[String] = []
	var listener := func(key: String, _value: Variant): changes.append(key)
	Settings.changed.connect(listener)
	for invalid in ['window_size="broken"', 'vsync=1', 'max_fps=-1', 'sfx_volume="bad"', 'language=""']:
		var contents: String = "[settings]\nmaster_volume=0.2\n" + invalid + "\n"
		_write(Settings.storage_path, contents)
		var previous := Settings.values.duplicate(true)
		changes.clear()
		_check(Settings.load_settings() == ERR_INVALID_DATA and Settings.write_blocked, "Invalid setting value blocks writes: " + invalid)
		_check(Settings.values == previous and changes.is_empty(), "Invalid file cannot partially apply values or emit changes")
		_check(Settings.set_setting("master_volume", 0.3) == ERR_UNAUTHORIZED and Settings.values == previous and changes.is_empty(), "Failed settings save leaves active values unchanged")
		_check(FileAccess.get_file_as_string(Settings.storage_path) == contents, "Invalid setting file remains byte-for-byte intact")
		_check(Settings.reset_to_defaults() == OK, "Explicit recovery after invalid setting value")
	Settings.changed.disconnect(listener)
	_check(Settings.set_setting("subtitles_enabled", true) == OK and Settings.load_settings() == OK and Settings.get_setting("subtitles_enabled"), "Game-specific settings remain supported")
	_check(Settings.defaults().language == OS.get_locale_language(), "New users start with the OS language")
	DirAccess.rename_absolute(Settings.storage_path, Settings.storage_path + ".tmp")
	Settings.values.subtitles_enabled = false
	_check(Settings.load_settings() == OK and Settings.get_setting("subtitles_enabled") == true and not Settings.write_blocked, "Interrupted settings replace restores completed temp")
	_check(Settings.save_settings() == OK and FileAccess.file_exists(Settings.storage_path), "Restored settings rewritten to original path")

func _input_checks() -> void:
	_check(InputMap.has_action("move_left") and InputMap.has_action("primary_action"), "Default input exists")
	_check(InputMap.action_get_deadzone("move_left") >= 0.05, "Controller deadzone configured")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	_check(InputManager.rebind(&"primary_action", key) == OK, "Keyboard rebind saved")
	var retained_controller := false
	for event in InputMap.action_get_events("primary_action"):
		retained_controller = retained_controller or event is InputEventJoypadButton
	_check(retained_controller, "Rebind preserves controller")
	var primary_keys := InputManager.slot_events(&"primary_action", "keyboard_mouse")
	_check(primary_keys.size() == 2 and primary_keys[0].is_match(key) and primary_keys[1] is InputEventMouseButton, "Primary slot rebind keeps secondary input")
	var secondary := InputEventKey.new()
	secondary.physical_keycode = KEY_H
	_check(InputManager.rebind(&"move_left", secondary, 1) == OK, "Secondary slot rebind saved")
	var left_keys := InputManager.slot_events(&"move_left", "keyboard_mouse")
	_check(left_keys.size() == 2 and left_keys[0].physical_keycode == KEY_A and left_keys[1].physical_keycode == KEY_H, "Secondary rebind keeps primary key")
	_check(InputManager.slot_text(&"move_left", "keyboard_mouse", 0) == "A" and InputManager.slot_text(&"move_left", "controller", 0) == "Left Stick X -", "Slot text is short and readable")
	_check(InputManager.rebind(&"move_left", secondary, 0) == ERR_ALREADY_IN_USE, "Same input in another slot rejected")
	_check(InputManager.rebind(&"move_left", secondary, InputManager.SLOTS) == ERR_INVALID_PARAMETER, "Out-of-range slot rejected")
	_check(InputManager.start_capture(&"move_left", 1) == OK and InputManager.capture_slot == 1, "Capture targets requested slot")
	var captured := InputEventKey.new()
	captured.physical_keycode = KEY_G
	captured.pressed = true
	InputManager._input(captured)
	_check(InputManager.slot_events(&"move_left", "keyboard_mouse")[1].physical_keycode == KEY_G, "Captured input lands in requested slot")
	_check(InputManager.load_bindings() == OK, "Bindings round trip")
	key.physical_keycode = KEY_A
	_check(InputManager.rebind(&"primary_action", key) == ERR_ALREADY_IN_USE, "Binding conflict rejected")
	_check(InputManager.decode_event({"type": "joy_axis", "axis": -1, "value": 1.0}) == null, "Invalid controller axis rejected")
	_check(InputManager.decode_event({"type": "key", "physical": "A"}) == null, "Invalid key type rejected")
	_check(InputManager.register_action(&"test_interact", [DefaultInput.key(KEY_U), DefaultInput.button(JOY_BUTTON_X)]) == OK, "Game action registered")
	_check(&"test_interact" in InputManager.actions() and InputMap.has_action(&"test_interact"), "Registered action is rebindable and in InputMap")
	_check(InputManager.register_action(&"test_interact") == ERR_ALREADY_EXISTS, "Duplicate registration rejected")
	_check(InputManager.register_action(&"ui_accept") == ERR_INVALID_PARAMETER, "UI actions cannot be registered")
	_check(InputManager.register_action(&"test_bad", [null]) == ERR_INVALID_PARAMETER, "Invalid default input rejected")
	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_Y
	_check(InputManager.rebind(&"test_interact", interact) == OK and InputManager.load_bindings() == OK \
		and InputManager.slot_events(&"test_interact", "keyboard_mouse")[0].physical_keycode == KEY_Y, "Registered action binding survives reload")
	_write(InputManager.storage_path, "[bindings]\ntest_later=[{\"type\":\"key\",\"physical\":79}]\n")
	_check(InputManager.load_bindings() == OK and not InputMap.has_action(&"test_later"), "Bindings for unregistered actions wait for registration")
	_check(InputManager.save_bindings() == OK and FileAccess.get_file_as_string(InputManager.storage_path).contains("test_later"), "Unregistered bindings preserved on save")
	# Windows 교체 중단: 원본이 지워지고 완성된 .tmp만 남은 상태를 복구한다.
	DirAccess.rename_absolute(InputManager.storage_path, InputManager.storage_path + ".tmp")
	_check(InputManager.load_bindings() == OK and not InputManager.write_blocked, "Interrupted bindings replace restores completed temp")
	_check(InputManager.register_action(&"test_later", [DefaultInput.key(KEY_P)]) == OK \
		and InputManager.slot_events(&"test_later", "keyboard_mouse")[0].physical_keycode == KEY_O, "Saved binding applied when action registers")
	var load_errors: Array[int] = []
	var load_listener := func(error: int): load_errors.append(error)
	InputManager.load_failed.connect(load_listener)
	_write(InputManager.storage_path, "[bindings]\nprimary_action=[{\"type\":\"unknown\"}]\n")
	_check(InputManager.load_bindings() == ERR_INVALID_DATA and InputManager.write_blocked, "Malformed bindings protected")
	_check(load_errors == [ERR_INVALID_DATA], "Malformed bindings reported through load_failed")
	InputManager.load_failed.disconnect(load_listener)
	_check(InputManager.save_bindings() == ERR_UNAUTHORIZED, "Bindings corruption blocks write")
	_check(InputManager.reset_bindings() == OK, "Default controls restored")
	_check(InputManager.slot_events(&"test_later", "keyboard_mouse")[0].physical_keycode == KEY_P, "Reset restores registered action defaults")
	_check(InputManager.start_capture(&"primary_action") == OK, "Capture started")
	_check(InputManager.start_capture(&"pause") == ERR_BUSY, "Duplicate capture rejected")
	InputManager.cancel_capture()
	_check(InputManager.capturing.is_empty(), "Capture canceled")
	for modifier in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
		InputManager.start_capture(&"primary_action")
		var modifier_event := InputEventKey.new()
		modifier_event.keycode = modifier
		modifier_event.physical_keycode = modifier
		modifier_event.pressed = true
		InputManager._input(modifier_event)
		_check(InputManager.capturing == &"primary_action", "Modifier press waits for a combination")
		modifier_event.pressed = false
		InputManager._input(modifier_event)
		_check(InputManager.capturing == &"primary_action", "Modifier release cannot create a binding")
		var combo := InputEventKey.new()
		combo.keycode = KEY_K
		combo.physical_keycode = KEY_K
		combo.pressed = true
		combo.ctrl_pressed = modifier == KEY_CTRL
		combo.shift_pressed = modifier == KEY_SHIFT
		combo.alt_pressed = modifier == KEY_ALT
		combo.meta_pressed = modifier == KEY_META
		InputManager._input(combo)
		_check(InputManager.capturing.is_empty() and InputMap.event_is_action(combo, &"primary_action", true), "Combination captured with modifier intact")
		_check(InputManager.load_bindings() == OK and InputMap.event_is_action(combo, &"primary_action", true), "Modifier combination survives reload")
	InputManager.start_capture(&"primary_action")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	InputManager._input(escape)
	_check(InputManager.capturing.is_empty(), "Escape still cancels capture")
	_check(InputManager.reset_bindings() == OK, "Controls restored after combination capture")

func _pause_checks() -> void:
	App.set_paused("menu", true)
	App.set_paused("overlay", true)
	_check(get_tree().paused, "Menu and overlay pause simulation")
	App.set_paused("overlay", false)
	_check(get_tree().paused and App.has_pause_reason("menu"), "One pause reason cannot resume another")
	App.set_paused("menu", false)
	_check(not get_tree().paused, "Final pause reason resumes")
	get_tree().paused = true
	App.set_paused("menu", true)
	App.set_paused("menu", false)
	_check(get_tree().paused, "Externally owned pause preserved")
	get_tree().paused = false
	var pause_on_focus: bool = GameConfig.value("lifecycle", "pause_on_focus_loss", true)
	var mute_on_focus: bool = GameConfig.value("lifecycle", "mute_on_focus_loss", true)
	AudioManager.play_bgm(preload("res://assets/demo/bgm.wav"))
	for pause_focus in [false, true]:
		for mute_focus in [false, true]:
			GameConfig.config.set_value("lifecycle", "pause_on_focus_loss", pause_focus)
			GameConfig.config.set_value("lifecycle", "mute_on_focus_loss", mute_focus)
			App._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			_check(get_tree().paused == pause_focus and AudioManager.bgm.stream_paused == mute_focus, "Focus pause and audio policies are independent")
			App.set_paused("menu", true)
			App._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			_check(get_tree().paused and AudioManager.bgm.stream_paused, "Focus return preserves menu pause and audio suspension")
			App.set_paused("menu", false)
			_check(not get_tree().paused and not AudioManager.bgm.stream_paused, "Last menu reason resumes simulation and audio")
	GameConfig.config.set_value("lifecycle", "pause_on_focus_loss", pause_on_focus)
	GameConfig.config.set_value("lifecycle", "mute_on_focus_loss", mute_on_focus)
	AudioManager.stop_bgm()

func _quit_checks() -> void:
	var reason_events: Array[String] = []
	var reason_listener := func(reason: String, active: bool): reason_events.append("%s:%s" % [reason, active])
	App.pause_reason_changed.connect(reason_listener)
	App.set_paused("menu", true)
	App.set_paused("menu", true)
	App.set_paused("menu", false)
	_check(reason_events == ["menu:true", "menu:false"], "Pause reason changes are reported once per transition")
	App.pause_reason_changed.disconnect(reason_listener)
	var menu := PauseMenu.new()
	add_child(menu)
	menu.open()
	_check(menu.is_open() and get_tree().paused, "Pause menu opens and pauses")
	menu.close()
	_check(not menu.is_open() and not get_tree().paused, "Pause menu closes and resumes")
	App.set_paused("menu", true)
	_check(menu.is_open(), "Pause menu follows external menu reason")
	App.set_paused("menu", false)
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	menu._unhandled_input(pause_event)
	_check(menu.is_open(), "Pause action opens the menu")
	menu._unhandled_input(pause_event)
	_check(not menu.is_open() and not get_tree().paused, "Pause action closes the menu")
	menu.queue_free()
	await get_tree().process_frame
	# 게임 UI가 종료 신호를 처리하지 않아도 저장 실패 시 창 닫기가 막히지 않아야 한다.
	_check(App.quit_requested.get_connections().is_empty() and App.quit_failed.get_connections().is_empty(), "No game quit handlers before fallback check")
	SaveManager.write_blocked = true
	SaveManager.set_value("quit_probe", 1)
	App.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	_check(App.dialogs.is_open() and App.has_pause_reason("quit_dialog") and get_tree().paused, "Unhandled close with failed save shows fallback dialog")
	App.dialogs._failure.get_ok_button().pressed.emit()
	_check(not App.dialogs.is_open() and not App.has_pause_reason("quit_dialog") and not get_tree().paused, "Staying after save failure resumes the game")
	var reported: Array[int] = []
	var failure_listener := func(error: int): reported.append(error)
	App.quit_failed.connect(failure_listener)
	_check(App.request_quit() == ERR_UNAUTHORIZED and reported == [ERR_UNAUTHORIZED] and not App.dialogs.is_open(), "Game quit_failed handler replaces fallback dialog")
	App.quit_failed.disconnect(failure_listener)
	SaveManager.write_blocked = false
	SaveManager.data.erase("quit_probe")
	_check(SaveManager.flush() == OK, "Save writable after quit checks")

func _service_checks() -> void:
	var disabled := StoreService.new()
	var probe := ProbeAdapter.new()
	add_child(disabled)
	disabled.initialize("steam", false, probe, {}, {})
	_check(probe.initialized_count == 0, "Disabled service skips SDK initialization")
	disabled.queue_free()
	var service := StoreService.new()
	var delayed := ProbeAdapter.new()
	add_child(service)
	service.initialize("steam", true, delayed, {"WIN": "NATIVE_WIN"}, {"SCORE": "NATIVE_SCORE"}, 1.0)
	service.request_succeeded.connect(func(_op: String, _id: String, _result: Dictionary): _successes += 1)
	service.request_failed.connect(func(_op: String, _id: String, _error: int, _message: String): _store_failures += 1)
	_check(service.unlock_achievement("WIN") == OK, "Adapter request accepted")
	_check(service.submit_score("SCORE", 7) == ERR_BUSY, "Concurrent request rejected")
	await get_tree().process_frame
	var first_id: int = delayed.requests[-1]
	delayed.completed.emit(first_id, {"error": OK})
	_check(_successes == 1, "Matching callback completes")
	delayed.completed.emit(first_id, {"error": OK})
	_check(_successes == 1, "Duplicate callback ignored")
	_check(service.submit_score("SCORE", 8) == OK, "Next request accepted")
	await get_tree().create_timer(1.15, true).timeout
	_check(_store_failures == 2, "Timeout delivered after busy failure")
	var timed_out: int = delayed.requests[-1]
	_check(service.unlock_achievement("WIN") == OK, "Request after timeout accepted")
	await get_tree().process_frame
	delayed.completed.emit(timed_out, {"error": OK})
	_check(_successes == 1, "Late callback cannot complete newer request")
	delayed.completed.emit(delayed.requests[-1], {"error": OK})
	_check(_successes == 2, "New callback completes newer request")
	service.queue_free()

func _display_checks() -> void:
	if not DesktopPlatform.has_window():
		_check(WindowManager.preview_options({"window_mode": "borderless"}) == ERR_UNAVAILABLE, "Headless window operations skipped")
		return
	var previous := WindowManager.current_options()
	_check(WindowManager.preview_options({"vsync": not previous.vsync}, 1.0) == OK, "Display preview accepted")
	_check(WindowManager.preview_options({"vsync": true}) == ERR_BUSY, "Concurrent display preview rejected")
	await get_tree().create_timer(1.2, true).timeout
	_check(not WindowManager.previewing and WindowManager.current_options() == previous, "Unconfirmed display change rolls back")
	_check(WindowManager.preview_options({"vsync": not previous.vsync}) == OK, "Second display preview accepted")
	_check(WindowManager.confirm_preview() == OK and Settings.get_setting("vsync") != previous.vsync, "Confirmed display change persisted")
	Settings.set_many(previous)
	WindowManager.apply_saved_options()
	var panel := SettingsPanel.new()
	add_child(panel)
	var errors: Array[int] = []
	panel.operation_failed.connect(func(error: int): errors.append(error))
	var before_failure := Settings.values.duplicate(true)
	var changes: Array[String] = []
	var listener := func(key: String, _value: Variant): changes.append(key)
	Settings.changed.connect(listener)
	_check(WindowManager.preview_options({"vsync": not previous.vsync}) == OK, "Display preview before protected save")
	Settings.write_blocked = true
	# 확인 버튼의 실제 signal 연결을 거쳐 반환값을 받지 않는 UI 경로를 검사한다.
	WindowManager._confirmation.confirmed.emit()
	_check(errors == [ERR_UNAUTHORIZED], "Confirmation save failure reaches settings UI exactly once")
	_check(not WindowManager.previewing and WindowManager.current_options() == previous, "Failed confirmation rolls back display")
	_check(Settings.values == before_failure and changes.is_empty(), "Failed confirmation never publishes candidate settings")
	Settings.write_blocked = false
	Settings.changed.disconnect(listener)
	panel.queue_free()

func _audio_checks() -> void:
	Settings.set_setting("master_volume", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Master volume zero mutes output")
	Settings.set_setting("master_volume", 0.8)
	_check(not AudioServer.is_bus_mute(0) and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.8) < 0.001, "Master volume restored")
	AudioManager.play_bgm(preload("res://assets/demo/bgm.wav"))
	_check(AudioManager.bgm.playing, "BGM started")
	AudioManager.set_suspended(true)
	_check(AudioManager.bgm.stream_paused, "Audio suspended")
	AudioManager.play_bgm(preload("res://assets/demo/bgm.wav"))
	_check(AudioManager.bgm.stream_paused, "Restarted BGM respects existing suspension")
	AudioManager.play_sfx(preload("res://assets/demo/bgm.wav"))
	AudioManager.play_ui(preload("res://assets/demo/bgm.wav"))
	_check(AudioManager.effect_players.size() == 2, "Suspended SFX and UI players created")
	for player in AudioManager.effect_players:
		_check(player.stream_paused, "New effect respects existing suspension")
	AudioManager.set_suspended(false)
	_check(AudioManager.bgm.playing and not AudioManager.bgm.stream_paused, "Audio resumed")
	for player in AudioManager.effect_players:
		_check(player.playing and not player.stream_paused, "Deferred effect resumes with audio")
		player.stop()
		player.queue_free()
	AudioManager.effect_players.clear()
	AudioManager.stop_bgm()
	_check(not AudioManager.bgm.playing, "BGM stopped")
	_check(AudioServer.get_bus_index("UI") >= 0, "Separate UI audio bus")
	# 오디오 스레드가 stop한 재생기를 정리할 tick을 허용한 뒤 검사를 종료한다.
	await get_tree().create_timer(0.05, true).timeout

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("CHECK FAILED: " + description)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup(directory: String) -> void:
	var access := DirAccess.open(directory)
	for name in access.get_files():
		DirAccess.remove_absolute(directory.path_join(name))
	for name in access.get_directories():
		_cleanup(directory.path_join(name))
	DirAccess.remove_absolute(directory)
