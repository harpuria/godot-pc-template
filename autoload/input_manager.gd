## 키보드·마우스·게임패드 바인딩을 저장하고 입력 캡처와 장치 변경을 전달한다.
extends Node

signal bindings_changed(action: StringName)
signal capture_finished(action: StringName, error: int)
signal device_changed(device: String)
signal controller_connection_changed(device_id: int, connected: bool)
signal save_failed(error: int)
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"primary_action", &"pause", &"toggle_fullscreen"]
var storage_path := "user://input.cfg"
var active_device := "keyboard_mouse"
var capturing: StringName = &""
var write_blocked := false
var _defaults: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var baseline := DefaultInput.actions()
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for event in baseline[action]:
				InputMap.action_add_event(action, event)
		_defaults[action] = InputMap.action_get_events(action)
		InputMap.action_set_deadzone(action, clampf(float(GameConfig.value("input", "controller_deadzone", 0.2)), 0.05, 0.95))
	Input.joy_connection_changed.connect(func(id: int, connected: bool): controller_connection_changed.emit(id, connected))
	load_bindings()

## JSON 호환 Dictionary로만 바인딩을 읽는다. 손상된 파일은 교체를 차단한다.
func load_bindings() -> Error:
	var file := ConfigFile.new()
	var error := file.load(storage_path)
	if error == ERR_FILE_NOT_FOUND:
		write_blocked = false
		return OK
	if error != OK or not file.has_section("bindings"):
		write_blocked = true
		return (error if error != OK else ERR_INVALID_DATA) as Error
	var staged: Dictionary = {}
	for action in ACTIONS:
		if not file.has_section_key("bindings", action):
			continue
		var raw: Variant = file.get_value("bindings", action)
		if not raw is Array or raw.is_empty():
			write_blocked = true
			return ERR_INVALID_DATA
		var events: Array[InputEvent] = []
		for item in raw:
			var event := decode_event(item)
			if event == null:
				write_blocked = true
				return ERR_INVALID_DATA
			events.append(event)
		staged[action] = events
	for action in staged:
		InputMap.action_erase_events(action)
		for event in staged[action]:
			InputMap.action_add_event(action, event)
	write_blocked = false
	return OK

## 다음 입력을 지정 action에 할당한다. 수정키 단독 입력은 기다리고 Escape는 취소한다.
func start_capture(action: StringName) -> Error:
	if not action in ACTIONS:
		return ERR_INVALID_PARAMETER
	if not capturing.is_empty():
		return ERR_BUSY
	capturing = action
	return OK

## 캡처를 취소하여 UI 탐색과 전역 단축키를 재개한다.
func cancel_capture() -> void:
	if capturing.is_empty():
		return
	var action := capturing
	capturing = &""
	capture_finished.emit(action, ERR_SKIP)

## 같은 장치 종류의 입력을 교체하고 다른 종류의 바인딩은 유지한다.
## 같은 장치에서 중복된 action 바인딩은 ERR_ALREADY_IN_USE로 거절한다.
func rebind(action: StringName, event: InputEvent) -> Error:
	if not action in ACTIONS or encode_event(event).is_empty():
		return ERR_INVALID_PARAMETER
	if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE) and action != &"pause":
		return ERR_INVALID_PARAMETER
	var normalized := decode_event(encode_event(event))
	if normalized == null:
		return ERR_INVALID_PARAMETER
	var category := _category(normalized)
	for other in ACTIONS:
		if other == action:
			continue
		for existing in InputMap.action_get_events(other):
			if _category(existing) == category and existing.is_match(normalized):
				return ERR_ALREADY_IN_USE
	var before := InputMap.action_get_events(action)
	for existing in before:
		if _category(existing) == category:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, normalized)
	var error := save_bindings()
	if error != OK:
		InputMap.action_erase_events(action)
		for existing in before:
			InputMap.action_add_event(action, existing)
		return error
	bindings_changed.emit(action)
	return OK

## 확인된 복구 또는 사용자 요청 후 프로젝트의 기본 바인딩으로 되돌린다.
func reset_bindings() -> Error:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		for event in _defaults[action]:
			InputMap.action_add_event(action, event)
	write_blocked = false
	var error := save_bindings()
	bindings_changed.emit(&"")
	return error

## 객체 대신 입력 종류와 숫자 필드만 저장한다.
func save_bindings() -> Error:
	var error: Error = ERR_UNAUTHORIZED if write_blocked else DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var file := ConfigFile.new()
	for action in ACTIONS:
		var serialized: Array = []
		for event in InputMap.action_get_events(action):
			serialized.append(encode_event(event))
		file.set_value("bindings", action, serialized)
	if error == OK:
		error = file.save(storage_path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(storage_path + ".tmp", storage_path)
	if error != OK:
		save_failed.emit(error)
	return error

## 설정 화면에서 표시할 바인딩 문자열을 반환한다.
func binding_text(action: StringName) -> String:
	var descriptions := PackedStringArray()
	for event in InputMap.action_get_events(action):
		descriptions.append(event.as_text())
	return " / ".join(descriptions)

## 지원하는 이벤트를 설정 파일용 Dictionary로 변환한다.
static func encode_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey and (event.physical_keycode != 0 or event.keycode != 0):
		return {"type": "key", "physical": event.physical_keycode, "key": event.keycode,
			"shift": event.shift_pressed, "alt": event.alt_pressed, "ctrl": event.ctrl_pressed, "meta": event.meta_pressed}
	if event is InputEventMouseButton and event.button_index > 0:
		return {"type": "mouse", "button": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": event.button_index}
	if event is InputEventJoypadMotion and absf(event.axis_value) >= 0.8:
		return {"type": "joy_axis", "axis": event.axis, "value": signf(event.axis_value)}
	return {}

## 허용된 필드의 타입과 범위를 검사한 뒤 InputEvent를 생성한다.
static func decode_event(raw: Variant) -> InputEvent:
	if not raw is Dictionary:
		return null
	for key in ["physical", "key", "button", "axis"]:
		if raw.has(key) and (not raw[key] is int or int(raw[key]) < 0):
			return null
	match raw.get("type", ""):
		"key":
			for key in ["shift", "alt", "ctrl", "meta"]:
				if raw.has(key) and not raw[key] is bool:
					return null
			var event := InputEventKey.new()
			event.physical_keycode = int(raw.get("physical", 0))
			event.keycode = int(raw.get("key", 0))
			if event.physical_keycode == 0 and event.keycode == 0:
				return null
			event.shift_pressed = raw.get("shift", false)
			event.alt_pressed = raw.get("alt", false)
			event.ctrl_pressed = raw.get("ctrl", false)
			event.meta_pressed = raw.get("meta", false)
			return event
		"mouse":
			if not raw.has("button") or raw.button < 1 or raw.button > 9:
				return null
			var event := InputEventMouseButton.new()
			event.button_index = raw.button
			return event
		"joy_button":
			if not raw.has("button") or raw.button >= JOY_BUTTON_MAX:
				return null
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = raw.button
			return event
		"joy_axis":
			if not raw.has("axis") or raw.axis >= JOY_AXIS_MAX or not raw.get("value") in [-1.0, 1.0]:
				return null
			var event := InputEventJoypadMotion.new()
			event.device = -1
			event.axis = raw.axis
			event.axis_value = float(raw.value)
			return event
	return null

func _input(event: InputEvent) -> void:
	if not capturing.is_empty():
		if event is InputEventKey and (event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META] \
				or event.physical_keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
			cancel_capture()
			get_viewport().set_input_as_handled()
		elif _pressed_binding(event):
			var action := capturing
			capturing = &""
			var error := rebind(action, event)
			get_viewport().set_input_as_handled()
			capture_finished.emit(action, error)
		return
	var device := "controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard_mouse"
	if _pressed_binding(event) and device != active_device:
		active_device = device
		device_changed.emit(active_device)

func _unhandled_input(event: InputEvent) -> void:
	if not capturing.is_empty():
		return
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		WindowManager.toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _pressed_binding(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= 0.8
	return event.is_pressed() and not event.is_echo() and not encode_event(event).is_empty()

static func _category(event: InputEvent) -> String:
	return "controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard_mouse"
