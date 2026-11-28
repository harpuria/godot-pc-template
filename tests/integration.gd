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
	func user_id() -> String:
		return "probe-user"
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
	_run.call_deferred()

func _reset_framework_baseline(args: PackedStringArray) -> void:
	# 로컬 사용자 파일이나 파생 게임의 config/init_script 변경이 공통 프레임워크 회귀 검사를 깨지 않도록 기준 상태를 맞춘다.
	GameConfig.config.set_value("features", "store_enabled", not ("--disabled" in args))
	GameConfig.config.set_value("distribution", "channel", "auto")
	GameConfig.config.set_value("services", "mode", "native" if "--native" in args else "mock")
	GameConfig.config.set_value("store", "achievement_ids", {"DEMO_FIRST_WIN": "DEMO_FIRST_WIN"})
	GameConfig.config.set_value("store", "leaderboard_ids", {"DEMO_SCORE": "DEMO_SCORE"})
	Settings.values = Settings.defaults()
	Settings.write_blocked = false
	SaveManager.schema_version = 1
	SaveManager.migrations.clear()
	SaveManager.data = {}
	SaveManager.dirty = false
	SaveManager.write_blocked = false
	App._registered_store_adapter = null
	InputManager.cancel_capture()
	for action in InputManager.actions():
		if not action in InputManager.COMMON_ACTIONS:
			InputMap.erase_action(action)
			InputManager._actions.erase(action)
			InputManager._defaults.erase(action)
	for action in InputManager.COMMON_ACTIONS:
		InputManager._apply_events(action, InputManager._defaults[action])
	InputManager._stored.clear()
	InputManager.write_blocked = false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--migration-runtime-error" in args:
		_migration_failure_checks()
		_cleanup(_directory)
		print("MIGRATION_FAILURE: %d checks, %d failures" % [_checks, _failures])
		get_tree().quit(0 if _failures == 0 else 1)
		return
	var configured_init := str(GameConfig.value("app", "init_script", ""))
	_check(preload("res://scenes/bootstrap.gd").run_init_script(configured_init) == OK, "Game init skeleton is wired and valid")
	# 파생 게임이 config와 init hook을 수정한 상태에서도 기준 복원이 동작하는지 검사한다.
	GameConfig.config.set_value("features", "store_enabled", false)
	GameConfig.config.set_value("store", "achievement_ids", {"DERIVED_ONLY": "ACH_1"})
	SaveManager.schema_version = 3
	SaveManager.register_migration(1, func(old: Dictionary) -> Dictionary: return old)
	InputManager.register_action(&"derived_temp", [DefaultInput.key(KEY_Z)])
	_reset_framework_baseline(args)
	_check(SaveManager.schema_version == 1 and SaveManager.migrations.is_empty() \
		and not (&"derived_temp" in InputManager.actions()), "Derived game hook state isolated from framework baseline")
	_init_checks()
	_check(preload("res://scenes/bootstrap.gd").run_init_script("res://tests/fixtures/game_init_fixture.gd") == OK, "Valid init hook accepted")
	_check(SaveManager.get_meta("hook_before_app", false) and SaveManager.get_meta("init_hook_count", 0) == 1, "Hook runs once before App")
	_check(SaveManager.schema_version == 2 and SaveManager.migrations.has(1), "Hook registers game schema and migration")
	_reset_framework_baseline(args)
	_check(SaveManager._autosave_timer.is_stopped(), "Autosave timer stays stopped before App initialization")
	App.initialize()
	_check(App.ready_for_game and not SaveManager._autosave_timer.is_stopped(), "App initialized and autosave started")
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
	_check(ResourceLoader.exists("res://default_bus_layout.tres") and AudioServer.get_bus_index("BGM") == 1 \
		and AudioServer.get_bus_index("SFX") == 2 and AudioServer.get_bus_index("UI") == 3, "Editor-visible bus layout provides BGM/SFX/UI")
	_check(load(str(ProjectSettings.get_setting("gui/theme/custom", ""))) is Theme, "Project default theme loads")
	_mcp_checks()
	_check(preload("res://scenes/bootstrap.gd").run_init_script("res://game/missing.gd") == ERR_FILE_NOT_FOUND, "Missing hook rejected")
	_save_checks()
	_settings_checks()
	_translation_checks()
	_input_checks()
	_pause_checks()
	await _quit_checks()
	await _service_checks()
	await _display_checks()
	await _audio_checks()
	await _scene_checks(args, store_instance)
	await get_tree().process_frame
	AudioManager.stop_bgm()
	await _wait_for_audio_cleanup()
	if not "--capture" in args:
		_cleanup(_directory)
	print("INTEGRATION: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

## 요청 거절·지연 실패·완료 신호 누락도 유한한 프레임 안에 검사 결과로 남긴다.
func _entered_scene(path: String) -> bool:
	for frame in 120:
		if not SceneManager.transitioning:
			break
		await get_tree().process_frame
	var scene := get_tree().current_scene
	var entered := not SceneManager.transitioning and scene != null and scene.scene_file_path == path
	_check(entered, "Scene transition reached " + path)
	return entered

func _scene_checks(args: PackedStringArray, store_instance: StoreService) -> void:
	# 통합 검사를 App 아래로 옮겨 실제 current_scene 교체 뒤에도 검사를 계속한다.
	reparent(App)
	get_tree().current_scene = null
	InputManager.start_capture(&"primary_action")
	_check(SceneManager.change_scene("res://scenes/main.tscn") == OK and InputManager.capturing.is_empty(), "Scene transition cancels pending input capture")
	_check(SceneManager.change_scene("res://scenes/transition_demo.tscn") == ERR_BUSY, "Duplicate transition rejected")
	if not await _entered_scene("res://scenes/main.tscn"):
		return
	var demo_scrolls := get_tree().current_scene.find_children("*", "ScrollContainer", true, false)
	_check(not demo_scrolls.is_empty() and (demo_scrolls[0] as ScrollContainer).follow_focus, "Demo scroll container follows keyboard/gamepad focus")
	_check(not SceneManager.transitioning, "Transition completed state")
	if "--capture" in args and DesktopPlatform.has_window():
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_check(image.save_png(_directory + "/demo.png") == OK, "Rendered demo captured")
		print("CAPTURE: " + _directory + "/demo.png")
	_check(SceneManager.change_scene("res://scenes/missing.tscn") == ERR_FILE_NOT_FOUND, "Missing scene fails safely")
	_check(SceneManager.change_scene("res://scenes/transition_demo.tscn") == OK, "Second scene accepted")
	if not await _entered_scene("res://scenes/transition_demo.tscn"):
		return
	_check(App.store == store_instance and SaveManager.data.get("recovered") == true, "Managers persist across scenes")
	var fixture := "res://tests/fixtures/pause_menu.tscn"
	_check(SceneManager.change_scene(fixture) == OK, "Pause menu fixture accepted")
	if not await _entered_scene(fixture):
		return
	var game_menu := get_tree().current_scene as PauseMenu
	_check(game_menu != null, "Pause menu fixture loads the shared menu")
	if game_menu != null:
		game_menu.open()
		_check(get_tree().paused and App.has_pause_reason("menu"), "Scene pause menu pauses before transition")
		_check(SceneManager.change_scene("res://scenes/transition_demo.tscn") == OK, "Transition while pause menu is open accepted")
		var pause_action := InputEventAction.new()
		pause_action.action = &"pause"
		pause_action.pressed = true
		game_menu._unhandled_input(pause_action)
		_check(game_menu.is_open(), "Pause shortcut ignored while scene transition is in progress")
		if not await _entered_scene("res://scenes/transition_demo.tscn"):
			return
		_check(not get_tree().paused and not App.has_pause_reason("menu") and not AudioManager._suspended, "Leaving scene with open pause menu releases menu pause and audio")

func _init_checks() -> void:
	var bootstrap := preload("res://scenes/bootstrap.gd")
	_check(bootstrap.run_init_script("res://tests/fixtures/failed_init_fixture.gd") == ERR_UNAVAILABLE, "Hook failure propagated")
	_check(bootstrap.run_init_script("res://tests/fixtures/invalid_init_signature_fixture.gd") == ERR_INVALID_PARAMETER, "Hook arguments rejected before invocation")
	_check(bootstrap.run_init_script("res://tests/fixtures/legacy_init_fixture.gd") == ERR_INVALID_PARAMETER, "Void hook cannot imply success")
	_check(bootstrap.run_init_script("res://tests/fixtures/invalid_init_result_fixture.gd") == ERR_INVALID_DATA, "Missing hook result cannot imply success")
	_check(not SaveManager.has_meta("invalid_hook_called"), "Invalid hook bodies never run")
	_check(not App.ready_for_game and SaveManager.schema_version == 1, "Failed hooks leave App uninitialized")

func _mcp_checks() -> void:
	var addon := "res://addons/godot_ai/plugin.cfg"
	var helper := "*res://addons/godot_ai/runtime/game_helper.gd"
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	var registered: bool = ProjectSettings.get_setting("autoload/_mcp_game_helper", "") == helper
	_check(registered == (addon in enabled), "Godot AI helper follows the project plugin selection")
	if addon in enabled:
		_check(FileAccess.file_exists(addon), "Selected Godot AI plugin is installed")
	if FileAccess.file_exists(addon):
		var presets := ConfigFile.new()
		_check(presets.load("res://export_presets.cfg") == OK, "Export presets load")
		for index in range(9):
			var filters := str(presets.get_value("preset.%d" % index, "exclude_filter", "")).split(",")
			_check("addons/godot_ai/*" in filters, "Godot AI excluded from export preset %d" % index)

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
	_check(not SaveManager.dirty and JsonStore.read(SaveManager.storage_path).document.get("version") == 2, "Migrated save persisted immediately on load")
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
	_check(SaveManager.load_slot() == OK and SaveManager.data.get("recovered") == true and not SaveManager.dirty, "Interrupted replace restores completed temp save")
	_check(FileAccess.file_exists(SaveManager.storage_path) and not FileAccess.file_exists(SaveManager.storage_path + ".tmp"), "Restored save promoted to original path immediately")
	var original_path := SaveManager.storage_path
	SaveManager.storage_path = _directory + "/saves/first_write.json"
	_write(SaveManager.storage_path + ".tmp", "{partial")
	_check(SaveManager.load_slot() == OK and SaveManager.data.is_empty() and not SaveManager.write_blocked, "Incomplete first-write temp starts fresh")
	SaveManager.storage_path = original_path
	_check(SaveManager.load_slot() == OK and SaveManager.data.recovered, "Original save path restored")

## 두 번째 변환에서 실패한 후 원본 보존과 같은 슬롯의 재시도를 검증한다.
func _migration_failure_checks() -> void:
	SaveManager.reset_slot({"progress": 39})
	_check(SaveManager.save_slot() == OK, "Migration fixture saved at version 1")
	var original := FileAccess.get_file_as_bytes(SaveManager.storage_path)
	SaveManager.set_value("unsaved", true)
	var previous := SaveManager.data.duplicate(true)
	SaveManager.schema_version = 3
	SaveManager.register_migration(1, func(old: Dictionary) -> Dictionary:
		old["stage"] = 2
		return old)
	SaveManager.register_migration(2, func(old: Dictionary) -> Dictionary:
		old.clear()
		var target: Variant = null
		return target.deliberate_migration_failure())
	_check(SaveManager.load_slot() == ERR_INVALID_DATA, "Runtime error rejects the entire migration")
	_check(SaveManager.write_blocked and SaveManager.dirty and SaveManager.data == previous, "Failed migration preserves unsaved memory")
	_check(SaveManager.flush() == ERR_UNAUTHORIZED and FileAccess.get_file_as_bytes(SaveManager.storage_path) == original, "Failed migration preserves original bytes and blocks autosave")
	SaveManager.register_migration(2, func(old: Dictionary) -> Dictionary:
		old.clear()
		return old)
	_check(SaveManager.load_slot() == OK and not SaveManager.write_blocked, "Can retry with an intentional empty migration")
	var migrated := JsonStore.read(SaveManager.storage_path)
	_check(migrated.error == OK and migrated.document.version == 3 and migrated.document.data == {} and SaveManager.data.is_empty(), "Explicitly cleared data persisted at the final version")

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
	_check(Settings.defaults().language == Settings.resolve_language(OS.get_locale()), "New users start with the resolved OS or fallback language")
	DirAccess.rename_absolute(Settings.storage_path, Settings.storage_path + ".tmp")
	Settings.values.subtitles_enabled = false
	_check(Settings.load_settings() == OK and Settings.get_setting("subtitles_enabled") == true and not Settings.write_blocked, "Interrupted settings replace restores completed temp")
	_check(FileAccess.file_exists(Settings.storage_path) and not FileAccess.file_exists(Settings.storage_path + ".tmp"), "Restored settings promoted to original path immediately")
	var original_settings_path := Settings.storage_path
	Settings.storage_path = _directory + "/empty_first_settings.cfg"
	_write(Settings.storage_path + ".tmp", "")
	_check(Settings.load_settings() == OK and not Settings.write_blocked, "Empty first-write settings temp starts fresh without blocking writes")
	_write(Settings.storage_path + ".tmp", "[settings]\nwindow_size=\"broken\"\n")
	_check(Settings.load_settings() == OK and not Settings.write_blocked, "Incomplete first-write settings temp starts fresh without blocking writes")
	Settings.storage_path = original_settings_path
	_check(Settings.load_settings() == OK, "Original settings path restored")
	var panel_a := SettingsPanel.new()
	var panel_b := SettingsPanel.new()
	add_child(panel_a)
	add_child(panel_b)
	Settings.set_setting("window_size", Vector2i(1366, 768))
	Settings.set_setting("window_size", Vector2i(1440, 900))
	_check(panel_a._resolution.item_count == SettingsPanel.SIZES.size() + 1 \
		and panel_a._resolution.get_item_metadata(SettingsPanel.SIZES.size()) == Vector2i(1440, 900), "Custom window sizes replace single custom item instead of accumulating")
	Settings.set_setting("window_size", Vector2i(1280, 720))
	_check(panel_a._resolution.item_count == SettingsPanel.SIZES.size(), "Standard window size removes stale custom item")
	Settings.set_setting("max_fps", 75)
	Settings.set_setting("max_fps", 90)
	_check(panel_a._fps.item_count == SettingsPanel.FPS_LIMITS.size() + 1, "Custom FPS limits replace single custom item")
	Settings.set_setting("max_fps", 0)
	_check(panel_a._fps.item_count == SettingsPanel.FPS_LIMITS.size(), "Standard FPS limit removes stale custom item")
	Settings.set_setting("bgm_volume", 0.35)
	_check(is_equal_approx(panel_a._volume_sliders["bgm_volume"].value, 0.35) \
		and is_equal_approx(panel_b._volume_sliders["bgm_volume"].value, 0.35), "External setting updates synchronize all settings panels")
	var sfx_commits: Array[float] = []
	var sfx_listener := func(changed_key: String, value: Variant):
		if changed_key == "sfx_volume":
			sfx_commits.append(float(value))
	Settings.changed.connect(sfx_listener)
	var sfx_slider: HSlider = panel_a._volume_sliders["sfx_volume"]
	sfx_slider.drag_started.emit()
	sfx_slider.value = 0.25
	sfx_slider.value = 0.5
	var sfx_bus := AudioServer.get_bus_index("SFX")
	_check(sfx_commits.is_empty() and absf(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) - 0.5) < 0.001, "Slider drag previews bus volume without intermediate disk writes")
	sfx_slider.drag_ended.emit(true)
	_check(sfx_commits.size() == 1 and is_equal_approx(sfx_commits[0], 0.5) \
		and is_equal_approx(float(Settings.get_setting("sfx_volume")), 0.5), "Slider drag_ended commits final volume once")
	Settings.changed.disconnect(sfx_listener)
	var errors_a: Array[int] = []
	var errors_b: Array[int] = []
	panel_a.operation_failed.connect(func(err: int): errors_a.append(err))
	panel_b.operation_failed.connect(func(err: int): errors_b.append(err))
	Settings.write_blocked = true
	sfx_slider.drag_started.emit()
	sfx_slider.value = 0.2
	sfx_slider.value = 0.3
	_check(errors_a.is_empty(), "Blocked slider drag does not emit repeated failure signals mid-drag")
	sfx_slider.drag_ended.emit(true)
	_check(errors_a == [ERR_UNAUTHORIZED] and is_equal_approx(sfx_slider.value, 0.5), "Blocked slider drag reports failure once on drag_ended and snaps back")
	errors_a.clear()
	var blocked_settings_path := _directory + "/blocked_settings.cfg"
	DirAccess.make_dir_recursive_absolute(blocked_settings_path + ".tmp")
	Settings.storage_path = blocked_settings_path
	_check(Settings.reset_to_defaults() != OK and Settings.write_blocked, "Failed settings reset preserves write_blocked state")
	DirAccess.remove_absolute(blocked_settings_path + ".tmp")
	Settings.storage_path = original_settings_path
	Settings.write_blocked = false
	panel_a._start_capture(0)
	panel_b.free()
	_check(not InputManager.capturing.is_empty(), "Freeing non-owning settings panel keeps active capture alive")
	var panel_c := SettingsPanel.new()
	add_child(panel_c)
	panel_c.operation_failed.connect(func(err: int): errors_b.append(err))
	var conflict_key := InputEventKey.new()
	conflict_key.physical_keycode = KEY_A
	conflict_key.pressed = true
	InputManager._input(conflict_key)
	_check(errors_a == [ERR_ALREADY_IN_USE] and errors_b.is_empty(), "Only the capture-owning settings panel reports capture failure")
	panel_a.free()
	panel_c.free()

func _translation_checks() -> void:
	var registered := PackedStringArray(ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()))
	_check("res://ui/i18n/ui.en.translation" in registered and "res://ui/i18n/ui.ko.translation" in registered, "Common UI translations registered")
	# 공통 UI 코드에서 쓰는 모든 번역 키가 영어·한국어에 있는지 확인한다.
	var missing := PackedStringArray()
	var pattern := RegEx.create_from_string("\"(UI_[A-Z0-9_]*[A-Z0-9])\"")
	for path in ["res://ui/menus/pause_menu.gd", "res://ui/dialogs/quit_dialogs.gd", "res://ui/settings/settings_panel.gd",
			"res://ui/loading/loading.tscn", "res://autoload/window_manager.gd", "res://autoload/input_manager.gd", "res://scenes/bootstrap.gd"]:
		for found in pattern.search_all(FileAccess.get_file_as_string(path)):
			var key := found.get_string(1)
			if SettingsPanel.locale_message("en", StringName(key)).is_empty() or SettingsPanel.locale_message("ko", StringName(key)).is_empty():
				missing.append(key)
	for action in InputManager.COMMON_ACTIONS:
		var action_key := "UI_ACTION_" + str(action).to_upper()
		if SettingsPanel.locale_message("en", StringName(action_key)).is_empty() or SettingsPanel.locale_message("ko", StringName(action_key)).is_empty():
			missing.append(action_key)
	_check(missing.is_empty(), "Every common UI key has English and Korean text: " + ", ".join(missing))
	var extra_ko := Translation.new()
	extra_ko.locale = "ko"
	extra_ko.add_message(&"GAME_ONLY_KEY", &"게임 문구")
	TranslationServer.add_translation(extra_ko)
	_check(SettingsPanel.locale_message("ko", &"UI_LANGUAGE_NAME") == "한국어" \
		and SettingsPanel.locale_message("ko", &"GAME_ONLY_KEY") == "게임 문구", "Multiple translations per locale resolve messages across files")
	TranslationServer.remove_translation(extra_ko)
	var zh_cn := Translation.new()
	zh_cn.locale = "zh_CN"
	var zh_tw := Translation.new()
	zh_tw.locale = "zh_TW"
	TranslationServer.add_translation(zh_cn)
	TranslationServer.add_translation(zh_tw)
	_check(Settings.resolve_language("zh_TW") == "zh_TW" and Settings.resolve_language("zh_CN") == "zh_CN", "Regional locales distinguish scripts instead of truncating to language code")
	TranslationServer.remove_translation(zh_cn)
	TranslationServer.remove_translation(zh_tw)
	_check(Settings.resolve_language("ja_JP") == "en", "Unsupported OS locale falls back to project default language")
	var previous := str(Settings.get_setting("language"))
	_check(Settings.set_setting("language", "ko") == OK and tr("UI_RESUME") == "계속하기", "Korean common UI text applies")
	_check(InputManager.action_text(&"move_left") == "왼쪽 이동" and InputManager.action_text(&"custom_jump") == "Custom Jump", "Action names translate with readable fallback")
	var panel := SettingsPanel.new()
	add_child(panel)
	_check(panel._binding_label.text.contains("키보드"), "Settings panel shows Korean text")
	var english_index := panel._language_index("en")
	_check(panel._language.item_count >= 2 and english_index != -1 and panel._language.get_item_text(panel._language_index("ko")) == "한국어", "Language picker lists native names")
	panel._language.item_selected.emit(english_index)
	_check(Settings.get_setting("language") == "en" and tr("UI_RESUME") == "Resume" and panel._binding_label.text.contains("Keyboard"), "Language picker switches UI text immediately")
	Settings.set_setting("language", "ja")
	_check(panel._language.selected == english_index, "Unsupported configured language selects fallback in picker instead of -1")
	panel.free()
	Settings.set_setting("language", previous)

func _input_checks() -> void:
	_check(InputMap.has_action("move_left") and InputMap.has_action("primary_action"), "Default input exists")
	var joy_accept := InputEventJoypadButton.new()
	joy_accept.device = 0
	joy_accept.button_index = JOY_BUTTON_A
	joy_accept.pressed = true
	var joy_cancel := InputEventJoypadButton.new()
	joy_cancel.device = 0
	joy_cancel.button_index = JOY_BUTTON_B
	joy_cancel.pressed = true
	_check(InputMap.event_is_action(joy_accept, &"ui_accept") and InputMap.event_is_action(joy_cancel, &"ui_cancel"), "Gamepad A/B buttons drive ui_accept and ui_cancel")
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
	# 표시 문자열은 UI 언어를 따른다. OS 언어(예: 한국어 Mac)와 상관없이 같은 결과가 나오도록 언어를 정해 비교한다.
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var controller_en := InputManager.slot_text(&"move_left", "controller", 0)
	TranslationServer.set_locale("ko")
	var controller_ko := InputManager.slot_text(&"move_left", "controller", 0)
	TranslationServer.set_locale(previous_locale)
	_check(InputManager.slot_text(&"move_left", "keyboard_mouse", 0) == "A" and controller_en == "Left Stick X -", "Slot text is short and readable")
	_check(controller_ko == "왼쪽 스틱 X -", "Controller slot text follows the UI language")
	_check(InputManager.rebind(&"move_left", secondary, 0) == ERR_ALREADY_IN_USE, "Same input in another slot rejected")
	_check(InputManager.rebind(&"move_left", secondary, InputManager.SLOTS) == ERR_INVALID_PARAMETER, "Out-of-range slot rejected")
	_check(InputManager.start_capture(&"move_left", 1) == OK and InputManager.capture_slot == 1, "Capture targets requested slot")
	var captured := InputEventKey.new()
	captured.physical_keycode = KEY_G
	captured.pressed = true
	InputManager._input(captured)
	_check(InputManager.slot_events(&"move_left", "keyboard_mouse")[1].physical_keycode == KEY_G, "Captured input lands in requested slot")
	_check(InputManager.register_action(&"test_unassigned") == OK and InputManager.save_bindings() == OK, "An unassigned game action can be saved")
	InputMap.action_add_event(&"test_unassigned", DefaultInput.key(KEY_T))
	_check(InputManager.load_bindings() == OK and not InputManager.write_blocked and InputMap.action_get_events(&"test_unassigned").is_empty(), "Reload restores the unassigned action")
	_check(InputManager.slot_events(&"move_left", "keyboard_mouse")[1].physical_keycode == KEY_G, "Other bindings survive an unassigned action")
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
	_check(InputManager.load_bindings() == OK and not InputManager.write_blocked \
		and FileAccess.file_exists(InputManager.storage_path) and not FileAccess.file_exists(InputManager.storage_path + ".tmp"), "Interrupted bindings replace restores and promotes completed temp")
	_check(InputManager.register_action(&"test_later", [DefaultInput.key(KEY_P)]) == OK \
		and InputManager.slot_events(&"test_later", "keyboard_mouse")[0].physical_keycode == KEY_O, "Saved binding applied when action registers")
	var original_input_path := InputManager.storage_path
	InputManager.storage_path = _directory + "/empty_first_input.cfg"
	_write(InputManager.storage_path + ".tmp", "")
	_check(InputManager.load_bindings() == OK and not InputManager.write_blocked, "Empty first-write bindings temp starts fresh without blocking writes")
	_write(InputManager.storage_path + ".tmp", "[bindings]\nprimary_action=[{\"type\":\"unknown\"}]\n")
	_check(InputManager.load_bindings() == OK and not InputManager.write_blocked, "Incomplete first-write bindings temp starts fresh without blocking writes")
	InputManager.storage_path = original_input_path
	_check(InputManager.load_bindings() == OK, "Original bindings path restored")
	var load_errors: Array[int] = []
	var load_listener := func(error: int): load_errors.append(error)
	InputManager.load_failed.connect(load_listener)
	_write(InputManager.storage_path, "[bindings]\nprimary_action=[{\"type\":\"unknown\"}]\n")
	_check(InputManager.load_bindings() == ERR_INVALID_DATA and InputManager.write_blocked, "Malformed bindings protected")
	_check(load_errors == [ERR_INVALID_DATA], "Malformed bindings reported through load_failed")
	InputManager.load_failed.disconnect(load_listener)
	_check(InputManager.save_bindings() == ERR_UNAUTHORIZED, "Bindings corruption blocks write")
	var blocked_input_path := _directory + "/blocked_input.cfg"
	DirAccess.make_dir_recursive_absolute(blocked_input_path + ".tmp")
	InputManager.storage_path = blocked_input_path
	_check(InputManager.reset_bindings() != OK and InputManager.write_blocked \
		and InputManager.slot_events(&"test_later", "keyboard_mouse")[0].physical_keycode == KEY_O, "Failed bindings reset rolls back memory and write_blocked")
	DirAccess.remove_absolute(blocked_input_path + ".tmp")
	InputManager.storage_path = original_input_path
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
	var out_mouse := InputEventMouseButton.new()
	out_mouse.button_index = 10 as MouseButton
	out_mouse.pressed = true
	InputManager._input(out_mouse)
	_check(InputManager.encode_event(out_mouse).is_empty() and InputManager.capturing == &"primary_action", "Unsupported mouse button ignored during capture")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	InputManager._input(escape)
	_check(InputManager.capturing.is_empty(), "Escape still cancels capture")
	var mixed_key := InputEventKey.new()
	mixed_key.physical_keycode = KEY_Q
	mixed_key.keycode = KEY_M
	_check(InputManager.rebind(&"primary_action", mixed_key) == OK and InputManager.load_bindings() == OK, "OS key with both physical and keycode saved")
	var reloaded_key := InputManager.slot_events(&"primary_action", "keyboard_mouse")[0] as InputEventKey
	_check(reloaded_key.physical_keycode == KEY_Q and reloaded_key.keycode == 0, "Physical key binding clears logical keycode for consistent matching")
	var legacy_decoded := InputManager.decode_event({"type": "key", "physical": KEY_Q, "key": KEY_M}) as InputEventKey
	_check(legacy_decoded != null and legacy_decoded.physical_keycode == KEY_Q and legacy_decoded.keycode == 0, "Legacy dual-keycode config normalizes to physical key")
	var logical_only := InputEventKey.new()
	logical_only.keycode = KEY_Z
	var logical_decoded := InputManager.decode_event(InputManager.encode_event(logical_only)) as InputEventKey
	_check(logical_decoded != null and logical_decoded.physical_keycode == 0 and logical_decoded.keycode == KEY_Z \
		and InputManager.event_text(logical_decoded) == "Z", "Logical-only key fallback preserved")
	InputManager.start_capture(&"pause", 1)
	InputManager._input(escape)
	_check(InputManager.capturing.is_empty() and InputManager.slot_events(&"pause", "keyboard_mouse").size() == 1, "Escape cancels secondary pause capture when primary already uses Escape")
	_check(InputManager.rebind(&"pause", DefaultInput.key(KEY_L), 0) == OK, "Pause rebound away from Escape")
	InputManager.start_capture(&"pause", 0)
	InputManager._input(escape)
	_check(InputManager.capturing.is_empty() and InputManager.slot_events(&"pause", "keyboard_mouse")[0].physical_keycode == KEY_ESCAPE, "Pause can be rebound back to Escape through capture")
	var shift_escape := InputEventKey.new()
	shift_escape.physical_keycode = KEY_ESCAPE
	shift_escape.shift_pressed = true
	_check(InputManager.rebind(&"pause", shift_escape, 0) == ERR_INVALID_PARAMETER, "Modified Escape rejected even for pause")
	_check(InputManager.reset_bindings() == OK, "Controls restored after combination capture")
	_check(FileAccess.get_file_as_string("res://.godot-version").strip_edges() == GameConfig.ENGINE_VERSION, "Pinned .godot-version matches GameConfig.ENGINE_VERSION")
	var clear_panel := SettingsPanel.new()
	add_child(clear_panel)
	clear_panel._action.select(clear_panel._action_index(&"move_left"))
	clear_panel._refresh_binding()
	var clear_km := clear_panel._clear_buttons["keyboard_mouse"] as Button
	var clear_pad := clear_panel._clear_buttons["controller"] as Button
	_check(not clear_km.disabled and not clear_pad.disabled, "Per-device clear secondary buttons enabled when secondary bindings exist")
	_check(InputManager.clear_slot(&"move_left", "keyboard_mouse", 1) == OK \
		and InputManager.slot_events(&"move_left", "keyboard_mouse").size() == 1, "Secondary slot cleared cleanly")
	InputManager.active_device = "keyboard_mouse"
	_check(clear_km.disabled and not clear_pad.disabled, "Controller secondary clear stays clickable when active_device is keyboard_mouse")
	clear_pad.pressed.emit()
	_check(InputManager.slot_events(&"move_left", "controller").size() == 1 and clear_pad.disabled, "Clicking controller clear button clears controller secondary slot")
	_check(InputManager.rebind(&"primary_action", DefaultInput.key(KEY_LEFT), 0) == OK, "Freed secondary key can be rebound to another action")
	_check(InputManager.clear_slot(&"pause", "keyboard_mouse", 0) == ERR_INVALID_PARAMETER, "Last keyboard pause binding cannot be cleared")
	_check(InputManager.clear_slot(&"test_later", "keyboard_mouse", 0) == ERR_INVALID_PARAMETER, "Last remaining binding on an action cannot be cleared")
	clear_panel.free()
	_check(InputManager.reset_bindings() == OK, "Controls restored after slot clear checks")

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
	_check(menu._settings_scroll.follow_focus, "Pause menu settings scroll follows keyboard/gamepad focus")
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
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	menu._unhandled_input(cancel_event)
	_check(not menu.is_open(), "ui_cancel while closed does not open pause menu")
	menu.open()
	menu._toggle_settings()
	_check(menu._settings_scroll.visible, "Pause menu opens settings view")
	menu._unhandled_input(cancel_event)
	_check(menu.is_open() and not menu._settings_scroll.visible, "ui_cancel closes pause settings view first")
	menu._unhandled_input(cancel_event)
	_check(not menu.is_open() and not get_tree().paused, "Second ui_cancel closes pause menu and resumes")
	menu.queue_free()
	await get_tree().process_frame
	InputManager.start_capture(&"primary_action")
	App._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(InputManager.capturing.is_empty(), "Focus loss cancels pending input capture")
	App._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	InputManager.start_capture(&"primary_action")
	App.dialogs.confirm_quit()
	_check(InputManager.capturing.is_empty() and App.dialogs.is_open(), "Opening quit dialog cancels pending input capture")
	App.dialogs._confirm.canceled.emit()
	_check(not App.dialogs.is_open() and not App.has_pause_reason("quit_dialog") and not get_tree().paused, "Canceling quit confirmation immediately clears dialog and pause")
	# 게임 UI가 종료 신호를 처리하지 않아도 저장 실패 시 창 닫기가 막히지 않아야 한다.
	_check(App.quit_requested.get_connections().is_empty() and App.quit_failed.get_connections().is_empty(), "No game quit handlers before fallback check")
	SaveManager.write_blocked = true
	SaveManager.set_value("quit_probe", 1)
	App.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	_check(App.dialogs.is_open() and App.has_pause_reason("quit_dialog") and get_tree().paused, "Unhandled close with failed save shows fallback dialog")
	App.dialogs.confirm_quit()
	_check(not App.dialogs._confirm.visible and App.dialogs._failure.visible and App.has_pause_reason("quit_dialog"), "Repeated quit request while save-failure dialog is open does not overlap confirm dialog")
	App.dialogs._failure.get_ok_button().pressed.emit()
	_check(not App.dialogs.is_open() and not App.has_pause_reason("quit_dialog") and not get_tree().paused, "Staying after save failure resumes the game")
	var reported: Array[int] = []
	var failure_listener := func(error: int): reported.append(error)
	App.quit_failed.connect(failure_listener)
	_check(App.request_quit() == ERR_UNAUTHORIZED and reported == [ERR_UNAUTHORIZED] and not App.dialogs.is_open(), "Game quit_failed handler replaces fallback dialog")
	reported.clear()
	App.dialogs.show_save_failure(ERR_UNAUTHORIZED)
	App.dialogs._failure.custom_action.emit(&"retry")
	_check(reported == [ERR_UNAUTHORIZED] and not App.dialogs.is_open() and not App.has_pause_reason("quit_dialog") \
		and not get_tree().paused, "Retry failure with custom quit_failed handler releases quit_dialog pause")
	App.quit_failed.disconnect(failure_listener)
	SaveManager.write_blocked = false
	SaveManager.data.erase("quit_probe")
	_check(SaveManager.flush() == OK, "Save writable after quit checks")

func _service_checks() -> void:
	var disabled := StoreService.new()
	var probe := ProbeAdapter.new()
	add_child(disabled)
	disabled.initialize("steam", false, probe, {}, {})
	_check(probe.initialized_count == 0 and disabled.user_id().is_empty(), "Disabled service skips SDK initialization and returns empty user_id")
	disabled.queue_free()
	var itch_service := StoreService.new()
	var itch_probe := ProbeAdapter.new()
	add_child(itch_service)
	itch_service.initialize("itch", true, itch_probe, {"WIN": "ITCH_WIN"}, {})
	_check(itch_service.available and itch_probe.initialized_count == 1 and itch_service.user_id() == "probe-user", "Verified native adapter initializes and exposes user_id on non-Steam channels")
	itch_service.queue_free()
	var service := StoreService.new()
	var delayed := ProbeAdapter.new()
	add_child(service)
	service.initialize("steam", true, delayed, {"WIN": "NATIVE_WIN"}, {"SCORE": "NATIVE_SCORE"}, 1.0)
	service.request_succeeded.connect(func(_op: String, _id: String, _result: Dictionary): _successes += 1)
	service.request_failed.connect(func(_op: String, _id: String, _error: int, _message: String): _store_failures += 1)
	_check(service.unlock_achievement("WIN") == OK, "Adapter request accepted")
	_check(service.submit_score("SCORE", 7) == OK, "Burst request queued instead of dropped")
	await get_tree().process_frame
	_check(delayed.requests.size() == 1, "Adapter receives one serialized request at a time")
	var first_id: int = delayed.requests[-1]
	delayed.completed.emit(first_id, {"error": OK})
	_check(_successes == 1, "Matching callback completes")
	delayed.completed.emit(first_id, {"error": OK})
	_check(_successes == 1, "Duplicate callback ignored")
	await get_tree().process_frame
	_check(delayed.requests.size() == 2, "Queued second request dispatched automatically after first completes")
	var second_id: int = delayed.requests[-1]
	delayed.completed.emit(second_id, {"error": OK})
	_check(_successes == 2, "Queued second request completes")
	_check(service.submit_score("SCORE", 8) == OK, "Timeout test request accepted")
	await get_tree().create_timer(1.15, true).timeout
	_check(_store_failures == 1, "Timeout delivered as request_failed")
	var timed_out: int = delayed.requests[-1]
	_check(service.unlock_achievement("WIN") == OK, "Request after timeout accepted")
	await get_tree().process_frame
	delayed.completed.emit(timed_out, {"error": OK})
	_check(_successes == 2, "Late callback cannot complete newer request")
	delayed.completed.emit(delayed.requests[-1], {"error": OK})
	_check(_successes == 3, "New callback completes newer request")
	_check(service.unlock_achievement("WIN") == OK, "Queue head accepted before saturation check")
	for i in StoreService.MAX_QUEUE_SIZE:
		service.unlock_achievement("WIN")
	_check(service.unlock_achievement("WIN") == ERR_BUSY and _store_failures == 2, "Overflowing bounded request queue reports ERR_BUSY")
	service.queue_free()

func _display_checks() -> void:
	if not DesktopPlatform.has_window():
		_check(WindowManager.preview_options({"window_mode": "borderless"}) == ERR_UNAVAILABLE, "Headless window operations skipped")
		_check(WindowManager.toggle_fullscreen() == ERR_UNAVAILABLE, "Headless fullscreen shortcut skipped")
		return
	var previous := WindowManager.current_options()
	_check(WindowManager.preview_options({"vsync": not previous.vsync}, 1.0) == OK, "Display preview accepted")
	_check(WindowManager.preview_options({"vsync": true}) == ERR_BUSY, "Concurrent display preview rejected")
	await get_tree().create_timer(1.2, true).timeout
	_check(not WindowManager.previewing and WindowManager.current_options() == previous, "Unconfirmed display change rolls back")
	_check(WindowManager.preview_options({"vsync": not previous.vsync}) == OK, "Second display preview accepted")
	_check(WindowManager.confirm_preview() == OK and Settings.get_setting("vsync") != previous.vsync, "Confirmed display change persisted")
	Settings.set_setting("window_mode", "windowed")
	_check(WindowManager.toggle_fullscreen() == OK and not WindowManager.previewing \
		and not WindowManager._confirmation.visible and Settings.get_setting("window_mode") == "borderless", "Fullscreen shortcut saves and applies without confirmation")
	_check(WindowManager.toggle_fullscreen() == OK and Settings.get_setting("window_mode") == "windowed", "Fullscreen shortcut returns to windowed mode")
	_check(WindowManager.preview_options({"vsync": not previous.vsync}) == OK and WindowManager.toggle_fullscreen() == ERR_BUSY, "Fullscreen shortcut waits for display preview")
	WindowManager.revert_preview()
	Settings.write_blocked = true
	_check(WindowManager.toggle_fullscreen() == ERR_UNAUTHORIZED and Settings.get_setting("window_mode") == "windowed", "Failed fullscreen save keeps current mode")
	Settings.write_blocked = false
	Settings.set_many({"window_mode": "windowed", "window_size": Vector2i(3840, 2160)})
	WindowManager.apply_saved_options()
	await get_tree().create_timer(0.6, true).timeout
	_check(Settings.get_setting("window_size") == Vector2i(3840, 2160), "Usable-rect clamping does not overwrite saved window_size")
	Settings.set_many(previous)
	WindowManager.apply_saved_options()
	DisplayServer.window_set_position(Vector2i(40, 40))
	await get_tree().process_frame
	var placed := DisplayServer.window_get_position()
	_check(WindowManager.preview_options({"max_fps": 120}) == OK and WindowManager.confirm_preview() == OK \
		and DisplayServer.window_get_position() == placed, "FPS-only display update preserves window position")
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
	var demo_bgm := preload("res://assets/demo/bgm.wav")
	Settings.set_setting("master_volume", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Master volume zero mutes output")
	Settings.set_setting("master_volume", 0.8)
	_check(not AudioServer.is_bus_mute(0) and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.8) < 0.001, "Master volume restored")
	AudioManager.play_bgm(demo_bgm)
	_check(AudioManager.bgm.playing, "BGM started")
	AudioManager.bgm.seek(0.2)
	AudioManager.play_bgm(demo_bgm)
	_check(AudioManager.bgm.get_playback_position() >= 0.15, "Re-requesting active BGM keeps playback position")
	AudioManager.play_bgm(demo_bgm, true)
	_check(AudioManager.bgm.get_playback_position() < 0.1, "play_bgm restart=true restarts stream from the beginning")
	AudioManager.bgm.seek(0.25)
	AudioManager.set_suspended(true)
	_check(AudioManager.bgm.stream_paused, "Audio suspended")
	AudioManager.play_bgm(demo_bgm)
	_check(AudioManager.bgm.stream_paused and AudioManager.bgm.get_playback_position() >= 0.2, "Re-requesting BGM while suspended preserves pause and playback position")
	AudioManager.play_sfx(demo_bgm)
	AudioManager.play_ui(demo_bgm)
	_check(AudioManager.effect_players.size() == 2, "Suspended SFX and UI players created")
	for player in AudioManager.effect_players:
		_check(player.stream_paused, "New effect respects existing suspension")
	AudioManager.set_suspended(false)
	_check(AudioManager.bgm.playing and not AudioManager.bgm.stream_paused and AudioManager.bgm.get_playback_position() >= 0.2, "Audio resumed from preserved BGM position")
	for player in AudioManager.effect_players:
		_check(player.playing and not player.stream_paused, "Deferred effect resumes with audio")
		player.stop()
		player.queue_free()
	AudioManager.effect_players.clear()
	# 메뉴 pause 중에는 BGM·SFX만 멈추고 UI 조작음은 바로 재생되며, 백그라운드 포커스 상실 시에는 UI도 함께 멈춘다.
	var mute_on_focus: bool = GameConfig.value("lifecycle", "mute_on_focus_loss", true)
	GameConfig.config.set_value("lifecycle", "mute_on_focus_loss", true)
	App.set_paused("menu", true)
	AudioManager.play_sfx(demo_bgm)
	AudioManager.play_ui(demo_bgm)
	var menu_sfx := AudioManager.effect_players[0]
	var menu_ui := AudioManager.effect_players[1]
	_check(AudioManager.bgm.stream_paused and menu_sfx.stream_paused and menu_ui.playing and not menu_ui.stream_paused, "Menu pause suspends BGM/SFX while keeping UI sound active")
	App._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(menu_ui.stream_paused, "Focus loss mute also suspends active UI sound")
	App._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(menu_sfx.stream_paused and menu_ui.playing and not menu_ui.stream_paused, "Focus return resumes UI sound while menu pause keeps SFX suspended")
	App.set_paused("menu", false)
	GameConfig.config.set_value("lifecycle", "mute_on_focus_loss", mute_on_focus)
	for player in AudioManager.effect_players:
		player.stop()
		player.queue_free()
	AudioManager.effect_players.clear()
	for i in AudioManager.MAX_EFFECTS:
		AudioManager.play_sfx(demo_bgm)
	AudioManager.play_ui(demo_bgm)
	_check(AudioManager.effect_players.size() == AudioManager.MAX_EFFECTS + 1 \
		and AudioManager.effect_players[-1].bus == &"UI", "Full SFX pool does not drop UI sound")
	for player in AudioManager.effect_players:
		player.stop()
		player.queue_free()
	AudioManager.effect_players.clear()
	AudioManager.stop_bgm()
	_check(not AudioManager.bgm.playing, "BGM stopped")
	_check(AudioServer.get_bus_index("UI") >= 0, "Separate UI audio bus")
	await _wait_for_audio_cleanup()

## 멈춘 재생 객체(AudioStreamPlayback)는 오디오 스레드와 메인 스레드가 번갈아 정리한다. 바로 종료하면 가끔
## 정리 전에 끝나 `ObjectDB instances were leaked`·`resources still in use` 경고가 남으므로 시간과 프레임을 넉넉히 준다.
func _wait_for_audio_cleanup() -> void:
	await get_tree().create_timer(0.25, true).timeout
	for i in 5:
		await get_tree().process_frame

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
