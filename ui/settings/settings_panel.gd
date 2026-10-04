## 화면·음량·입력 설정을 제공하며 게임 메뉴에서도 재사용할 수 있는 패널이다.
class_name SettingsPanel
extends VBoxContainer

signal operation_failed(error: int)
var _mode := OptionButton.new()
var _resolution := OptionButton.new()
var _vsync := CheckButton.new()
var _fps := OptionButton.new()
var _binding_label := Label.new()
var _action := OptionButton.new()
var _rebind_button := Button.new()
const MODES := ["windowed", "borderless", "fullscreen"]
const SIZES := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 10)
	_heading("DISPLAY")
	for label in ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"]:
		_mode.add_item(label)
	_row("Window mode", _mode)
	for size in SIZES:
		_resolution.add_item("%d × %d" % [size.x, size.y])
		_resolution.set_item_metadata(_resolution.item_count - 1, size)
	_row("Window size", _resolution)
	_vsync.text = "VSync"
	add_child(_vsync)
	for fps in FPS_LIMITS:
		_fps.add_item("Unlimited" if fps == 0 else "%d FPS" % fps)
		_fps.set_item_metadata(_fps.item_count - 1, fps)
	_row("Frame limit", _fps)
	var apply := Button.new()
	apply.text = "Preview display settings"
	apply.pressed.connect(_preview_display)
	add_child(apply)
	WindowManager.preview_finished.connect(func(_confirmed: bool): _refresh_display())
	WindowManager.preview_failed.connect(_report)
	_refresh_display()
	_heading("AUDIO")
	for bus in ["master", "bgm", "sfx", "ui"]:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.x = 180
		slider.value = float(Settings.get_setting(bus + "_volume", 0.8))
		slider.value_changed.connect(func(value: float):
			var error := Settings.set_setting(bus + "_volume", value)
			if error != OK:
				slider.set_value_no_signal(float(Settings.get_setting(bus + "_volume", 0.8)))
			_report(error))
		_row(bus.to_upper(), slider)
	_heading("INPUT")
	for action in InputManager.ACTIONS:
		_action.add_item(str(action).replace("_", " ").capitalize())
		_action.set_item_metadata(_action.item_count - 1, action)
	_action.selected = InputManager.ACTIONS.find(&"primary_action")
	_action.item_selected.connect(func(_index: int): _refresh_binding())
	_row("Action", _action)
	_binding_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_binding_label.add_theme_font_size_override("font_size", 14)
	add_child(_binding_label)
	_rebind_button.text = "Rebind primary action"
	_rebind_button.pressed.connect(func():
		var error := InputManager.start_capture(_selected_action())
		if error == OK:
			_action.disabled = true
			_rebind_button.text = "Press a key / button (Esc cancels)"
		else:
			_report(error))
	add_child(_rebind_button)
	var reset := Button.new()
	reset.text = "Restore default controls"
	reset.pressed.connect(func(): _report(InputManager.reset_bindings()))
	add_child(reset)
	InputManager.bindings_changed.connect(func(_changed_action: StringName): _refresh_binding())
	InputManager.capture_finished.connect(func(_captured_action: StringName, error: int):
		_action.disabled = false
		_refresh_binding()
		if error != ERR_SKIP:
			_report(error))
	_refresh_binding()

func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)

func _row(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 125
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	add_child(row)

func _refresh_display() -> void:
	var options := WindowManager.current_options()
	_mode.selected = maxi(0, MODES.find(options.window_mode))
	var size_index := -1
	for index in _resolution.item_count:
		if _resolution.get_item_metadata(index) == options.window_size:
			size_index = index
	if size_index == -1:
		_resolution.add_item("%d × %d (custom)" % [options.window_size.x, options.window_size.y])
		size_index = _resolution.item_count - 1
		_resolution.set_item_metadata(size_index, options.window_size)
	_resolution.selected = size_index
	_vsync.button_pressed = bool(options.vsync)
	var fps_index := -1
	for index in _fps.item_count:
		if _fps.get_item_metadata(index) == options.max_fps:
			fps_index = index
	if fps_index == -1:
		_fps.add_item("%d FPS" % options.max_fps)
		fps_index = _fps.item_count - 1
		_fps.set_item_metadata(fps_index, options.max_fps)
	_fps.selected = fps_index

func _preview_display() -> void:
	_report(WindowManager.preview_options({"window_mode": MODES[_mode.selected],
		"window_size": _resolution.get_item_metadata(_resolution.selected), "vsync": _vsync.button_pressed,
		"max_fps": _fps.get_item_metadata(_fps.selected)}))

func _refresh_binding() -> void:
	_binding_label.text = "Binding: " + InputManager.binding_text(_selected_action())
	_rebind_button.text = "Rebind " + str(_selected_action()).replace("_", " ")

func _selected_action() -> StringName:
	return _action.get_item_metadata(_action.selected)

func _report(error: Error) -> void:
	if error != OK:
		operation_failed.emit(error)

func _exit_tree() -> void:
	InputManager.cancel_capture()
