## 저장·설정·소리·입력·ESD 공통 API를 직접 조작하는 PC 템플릿 시작 화면이다.
extends Control

var _status := Label.new()
var _device := Label.new()
var _pause_menu := PauseMenu.new()
var _save_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = Color("141d2b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "PC TEMPLATE"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(App.dialogs.confirm_quit)
	header.add_child(quit_button)
	var subtitle := Label.new()
	subtitle.text = "Godot %s · %s · %s · %s" % [GameConfig.ENGINE_VERSION, DesktopPlatform.current(), App.store.channel,
		"Development Mock" if App.store.is_mock() else ("Store connected" if App.store.available else "Local play")]
	layout.add_child(subtitle)
	_status.text = "Ready. Save files live in your user data folder."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 44
	_status.add_theme_color_override("font_color", Color("80d5b6"))
	layout.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	layout.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	scroll.add_child(columns)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 10)
	columns.add_child(actions)
	_label(actions, "TRY THE COMMON FEATURES", 18)
	var first := _button(actions, "Save test", _save_test)
	_button(actions, "Load test", _load_test)
	_button(actions, "Open save folder", func():
		if DesktopPlatform.has_window():
			OS.shell_open(OS.get_user_data_dir()))
	_button(actions, "Play BGM", func(): AudioManager.play_bgm(preload("res://assets/demo/bgm.wav")))
	_button(actions, "Stop BGM", AudioManager.stop_bgm)
	_button(actions, "Play SFX", func(): AudioManager.play_sfx(preload("res://assets/demo/tone.wav")))
	_button(actions, "Play UI sound", func(): AudioManager.play_ui(preload("res://assets/demo/tone.wav")))
	_button(actions, "Open pause menu", _pause_menu.open)
	_button(actions, "Scene transition", func():
		App.set_paused("menu", false)
		SceneManager.change_scene("res://scenes/transition_demo.tscn"))
	_label(actions, "OPTIONAL STORE FEATURES", 18)
	_button(actions, "Unlock demo achievement", func(): App.store.unlock_achievement("DEMO_FIRST_WIN"))
	_button(actions, "Submit demo score", func(): App.store.submit_score("DEMO_SCORE", 100))
	_button(actions, "Request achievements overlay", func(): App.store.open_overlay())
	_label(actions, "CONTROLS", 18)
	_device.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(_device)
	_update_device(InputManager.active_device)
	_label(actions, "WASD / arrows / left stick: move\nSpace / left click / pad A: primary\nEsc / Start: pause   ·   F11 / Alt+Enter: display", 14)
	var settings := SettingsPanel.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(settings)
	settings.operation_failed.connect(func(error: int): _log("Settings: " + error_string(error)))
	App.store.request_succeeded.connect(func(operation: String, logical_id: String, result: Dictionary):
		_log("%s: %s completed · mock=%s" % [operation, logical_id, result.get("mock", false)]))
	App.store.request_failed.connect(func(operation: String, _id: String, error: int, message: String):
		_log("%s: %s (%s)" % [operation, message, error_string(error)]))
	InputManager.device_changed.connect(_update_device)
	InputManager.controller_connection_changed.connect(func(_id: int, _connected: bool): _update_device(InputManager.active_device))
	SaveManager.save_failed.connect(func(error: int): _log("Save failed: " + error_string(error)))
	# 재사용 pause 메뉴: Esc / Start로 열고 닫는다. 저장 실패 대화상자는 App.dialogs가 기본 제공한다.
	_pause_menu.operation_failed.connect(func(error: int): _log("Settings: " + error_string(error)))
	add_child(_pause_menu)
	App.quit_requested.connect(_on_quit_requested)
	if SaveManager.write_blocked:
		_log("Save could not be loaded. Original file preserved; writing is blocked.")
	first.grab_focus()

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Control, text: String, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func _save_test() -> void:
	_save_count = int(SaveManager.data.get("demo_count", 0)) + 1
	SaveManager.set_value("demo_count", _save_count)
	var error := SaveManager.flush()
	_log("Saved demo_count=%d" % _save_count if error == OK else "Save failed: " + error_string(error))

func _load_test() -> void:
	var error := SaveManager.load_slot()
	_log("Loaded demo_count=%s" % SaveManager.data.get("demo_count", 0) if error == OK else "Load failed: " + error_string(error))

func _on_quit_requested() -> void:
	App.dialogs.confirm_quit()

func _update_device(device: String) -> void:
	_device.text = "Active input: %s · controllers: %d" % [device, Input.get_connected_joypads().size()]

func _log(message: String) -> void:
	_status.text = message
	AppLogger.info("Demo", message)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("primary_action") and not event.is_echo():
		_log("Primary action received from " + InputManager.active_device)
