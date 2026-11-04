## 언어·화면·음량·입력 설정을 제공하며 게임 메뉴에서도 재사용할 수 있는 패널이다.
## 문구는 ui/i18n/ui.csv의 번역 키를 사용하고 언어가 바뀌면 즉시 다시 표시한다.
class_name SettingsPanel
extends VBoxContainer

signal operation_failed(error: int)
var _language := OptionButton.new()
var _mode := OptionButton.new()
var _resolution := OptionButton.new()
var _vsync := CheckButton.new()
var _fps := OptionButton.new()
var _binding_label := Label.new()
var _action := OptionButton.new()
var _slot_buttons: Array[Button] = []
const MODES := ["windowed", "borderless", "fullscreen"]
const SIZES := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]
const SLOT_KEYS := ["UI_REBIND_PRIMARY", "UI_REBIND_SECONDARY"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 10)
	# 계산한 문구는 코드에서 번역하므로 자동 번역을 끈다.
	for control in [_language, _resolution, _fps, _action, _binding_label]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_language.item_selected.connect(_on_language_selected)
	_row("UI_LANGUAGE", _language)
	_refresh_languages()
	_heading("UI_HEADING_DISPLAY")
	for label in ["UI_MODE_WINDOWED", "UI_MODE_BORDERLESS", "UI_MODE_FULLSCREEN"]:
		_mode.add_item(label)
	_row("UI_WINDOW_MODE", _mode)
	for size in SIZES:
		_resolution.add_item("%d × %d" % [size.x, size.y])
		_resolution.set_item_metadata(_resolution.item_count - 1, size)
	_row("UI_WINDOW_SIZE", _resolution)
	_vsync.text = "UI_VSYNC"
	add_child(_vsync)
	for fps in FPS_LIMITS:
		_fps.add_item("")
		_fps.set_item_metadata(_fps.item_count - 1, fps)
	_row("UI_FRAME_LIMIT", _fps)
	var apply := Button.new()
	apply.text = "UI_PREVIEW_DISPLAY"
	apply.pressed.connect(_preview_display)
	add_child(apply)
	WindowManager.preview_finished.connect(func(_confirmed: bool): _refresh_display())
	# 단축키(F11 / Alt+Enter)처럼 패널 밖에서 바뀐 화면 모드도 표시에 반영한다.
	WindowManager.options_applied.connect(func(_options: Dictionary): _refresh_display())
	WindowManager.preview_failed.connect(_report)
	_refresh_display()
	_heading("UI_HEADING_AUDIO")
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
		_row("UI_VOLUME_" + bus.to_upper(), slider)
	_heading("UI_HEADING_INPUT")
	_action.item_selected.connect(func(_index: int): _refresh_binding())
	_row("UI_ACTION", _action)
	_refresh_actions()
	_binding_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_binding_label.add_theme_font_size_override("font_size", 14)
	add_child(_binding_label)
	var slots := HBoxContainer.new()
	for slot in InputManager.SLOTS:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _start_capture(slot))
		slots.add_child(button)
		_slot_buttons.append(button)
	add_child(slots)
	var reset := Button.new()
	reset.text = "UI_RESTORE_CONTROLS"
	reset.pressed.connect(func(): _report(InputManager.reset_bindings()))
	add_child(reset)
	InputManager.bindings_changed.connect(func(changed_action: StringName):
		if not changed_action.is_empty() and _action_index(changed_action) == -1:
			_refresh_actions()
		_refresh_binding())
	InputManager.capture_finished.connect(func(_captured_action: StringName, error: int):
		_set_capturing(-1)
		_refresh_binding()
		if error != ERR_SKIP:
			_report(error))
	_refresh_binding()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_languages()
		_refresh_display()
		_refresh_actions()
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
		_resolution.add_item("")
		size_index = _resolution.item_count - 1
		_resolution.set_item_metadata(size_index, options.window_size)
	for index in range(SIZES.size(), _resolution.item_count):
		var custom: Vector2i = _resolution.get_item_metadata(index)
		_resolution.set_item_text(index, tr("UI_WINDOW_SIZE_CUSTOM") % [custom.x, custom.y])
	_resolution.selected = size_index
	_vsync.button_pressed = bool(options.vsync)
	for index in _fps.item_count:
		var limit: int = _fps.get_item_metadata(index)
		_fps.set_item_text(index, tr("UI_FPS_UNLIMITED") if limit == 0 else "%d FPS" % limit)
	var fps_index := -1
	for index in _fps.item_count:
		if _fps.get_item_metadata(index) == options.max_fps:
			fps_index = index
	if fps_index == -1:
		_fps.add_item("%d FPS" % options.max_fps if options.max_fps > 0 else tr("UI_FPS_UNLIMITED"))
		fps_index = _fps.item_count - 1
		_fps.set_item_metadata(fps_index, options.max_fps)
	_fps.selected = fps_index

func _preview_display() -> void:
	_report(WindowManager.preview_options({"window_mode": MODES[_mode.selected],
		"window_size": _resolution.get_item_metadata(_resolution.selected), "vsync": _vsync.button_pressed,
		"max_fps": _fps.get_item_metadata(_fps.selected)}))

func _refresh_actions() -> void:
	var previous: StringName = _selected_action() if _action.item_count > 0 else &"primary_action"
	_action.clear()
	for action in InputManager.actions():
		_action.add_item(InputManager.action_text(action))
		_action.set_item_metadata(_action.item_count - 1, action)
	_action.selected = maxi(0, _action_index(previous))

func _action_index(action: StringName) -> int:
	for index in _action.item_count:
		if _action.get_item_metadata(index) == action:
			return index
	return -1

func _refresh_binding() -> void:
	var action := _selected_action()
	var lines := PackedStringArray()
	for category in InputManager.CATEGORIES:
		var names := PackedStringArray()
		for slot in InputManager.SLOTS:
			names.append(InputManager.slot_text(action, category, slot))
		lines.append("%s: %s" % [tr("UI_KEYBOARD_MOUSE" if category == "keyboard_mouse" else "UI_CONTROLLER"), "  ·  ".join(names)])
	_binding_label.text = "\n".join(lines)
	if InputManager.capturing.is_empty():
		_set_capturing(-1)

func _start_capture(slot: int) -> void:
	var error := InputManager.start_capture(_selected_action(), slot)
	if error == OK:
		_set_capturing(slot)
	else:
		_report(error)

func _set_capturing(slot: int) -> void:
	_action.disabled = slot >= 0
	for index in _slot_buttons.size():
		_slot_buttons[index].disabled = slot >= 0 and index != slot
		_slot_buttons[index].text = "UI_PRESS_INPUT" if index == slot else SLOT_KEYS[index]

## 불러온 번역의 언어를 각 언어 이름(UI_LANGUAGE_NAME)으로 표시하고 현재 설정을 선택한다.
func _refresh_languages() -> void:
	_language.clear()
	var locales := Array(TranslationServer.get_loaded_locales())
	locales.sort()
	var current := str(Settings.get_setting("language", TranslationServer.get_locale()))
	var best := -1
	var best_score := 0
	for locale: String in locales:
		if _language_index(locale) != -1:
			continue
		var translation := TranslationServer.get_translation_object(locale)
		var label := str(translation.get_message("UI_LANGUAGE_NAME")) if translation != null else ""
		_language.add_item(label if not label.is_empty() else TranslationServer.get_locale_name(locale))
		_language.set_item_metadata(_language.item_count - 1, locale)
		var score := TranslationServer.compare_locales(current, locale)
		if score > best_score:
			best_score = score
			best = _language.item_count - 1
	_language.selected = best

func _language_index(locale: String) -> int:
	for index in _language.item_count:
		if _language.get_item_metadata(index) == locale:
			return index
	return -1

func _on_language_selected(index: int) -> void:
	var error := Settings.set_setting("language", _language.get_item_metadata(index))
	if error != OK:
		_refresh_languages()
	_report(error)

func _selected_action() -> StringName:
	return _action.get_item_metadata(_action.selected)

func _report(error: Error) -> void:
	if error != OK:
		operation_failed.emit(error)

func _exit_tree() -> void:
	InputManager.cancel_capture()
