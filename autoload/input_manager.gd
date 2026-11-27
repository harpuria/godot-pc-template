## 키보드·마우스·게임패드 바인딩을 저장하고 입력 캡처와 장치 변경을 전달한다.
extends Node

signal bindings_changed(action: StringName)
signal capture_finished(action: StringName, error: int)
signal device_changed(device: String)
signal controller_connection_changed(device_id: int, connected: bool)
signal save_failed(error: int)
signal load_failed(error: int)
## 템플릿이 기본 제공하는 공통 action이다. 게임 action은 register_action()으로 추가한다.
const COMMON_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"primary_action", &"pause", &"toggle_fullscreen"]
## 장치 종류마다 설정 UI에서 바꿀 수 있는 칸 수다. 0은 주 입력, 1은 보조 입력이다.
const SLOTS := 2
const CATEGORIES: Array[String] = ["keyboard_mouse", "controller"]
const _AXIS_NAMES := ["UI_AXIS_LEFT_X", "UI_AXIS_LEFT_Y", "UI_AXIS_RIGHT_X", "UI_AXIS_RIGHT_Y", "UI_AXIS_LEFT_TRIGGER", "UI_AXIS_RIGHT_TRIGGER"]
var storage_path := "user://input.cfg"
var active_device := "keyboard_mouse"
var capturing: StringName = &""
var capture_slot := 0
var write_blocked := false
var _actions: Array[StringName] = []
var _defaults: Dictionary = {}
# 파일에는 있지만 아직 등록되지 않은 action의 바인딩. 등록 시 적용하고 저장 시 보존한다.
var _stored: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var baseline := DefaultInput.actions()
	for action in COMMON_ACTIONS:
		_add_action(action, baseline[action])
	Input.joy_connection_changed.connect(func(id: int, connected: bool): controller_connection_changed.emit(id, connected))
	load_bindings()

## 재설정·저장 대상 action을 등록 순서대로 반환한다.
func actions() -> Array[StringName]:
	return _actions.duplicate()

## 게임 action을 재설정·저장 대상에 추가한다. init hook에서 호출하는 것을 권장한다.
## InputMap(Project Settings)에 이미 있는 action은 그 입력을 기본값으로 쓰고, 없으면 defaults로 만든다.
## 저장된 사용자 바인딩이 있으면 등록 즉시 적용한다.
func register_action(action: StringName, defaults: Array = []) -> Error:
	if action.is_empty() or str(action).begins_with("ui_"):
		return ERR_INVALID_PARAMETER
	if action in _actions:
		return ERR_ALREADY_EXISTS
	for event in defaults:
		if not event is InputEvent or encode_event(event).is_empty():
			return ERR_INVALID_PARAMETER
	_add_action(action, defaults)
	if _stored.has(action):
		_apply_events(action, _stored[action])
		_stored.erase(action)
	bindings_changed.emit(action)
	return OK

## JSON 호환 Dictionary로만 바인딩을 읽는다. 손상된 파일은 교체를 차단한다.
func load_bindings() -> Error:
	var file := ConfigFile.new()
	var error := file.load(storage_path)
	var recovered_temp := false
	if error == ERR_FILE_NOT_FOUND:
		# Windows에서 교체가 중단되어 완성된 .tmp만 남은 경우에만 복구하고, 미완성 첫 쓰기 .tmp는 새 사용자로 시작한다.
		if not FileAccess.file_exists(storage_path + ".tmp") or file.load(storage_path + ".tmp") != OK \
				or not file.has_section("bindings") or file.get_section_keys("bindings").is_empty():
			write_blocked = false
			return OK
		recovered_temp = true
		error = OK
	if error != OK or not file.has_section("bindings"):
		return _load_error(error if error != OK else ERR_INVALID_DATA)
	var staged: Dictionary = {}
	for key in file.get_section_keys("bindings"):
		var raw: Variant = file.get_value("bindings", key)
		if not raw is Array or raw.is_empty():
			if recovered_temp:
				write_blocked = false
				return OK
			return _load_error(ERR_INVALID_DATA)
		var events: Array[InputEvent] = []
		for item in raw:
			var event := decode_event(item)
			if event == null:
				if recovered_temp:
					write_blocked = false
					return OK
				return _load_error(ERR_INVALID_DATA)
			events.append(event)
		staged[StringName(key)] = events
	_stored.clear()
	for action in staged:
		if action in _actions:
			_apply_events(action, staged[action])
		else:
			_stored[action] = staged[action]
	write_blocked = false
	if recovered_temp:
		push_warning("Bindings restored from an interrupted replace: %s.tmp" % storage_path)
		save_bindings()
	return OK

## 다음 입력을 지정 action의 slot 칸에 할당한다. 수정키 단독 입력은 기다리고 Escape는 취소한다.
func start_capture(action: StringName, slot: int = 0) -> Error:
	if not action in _actions or slot < 0 or slot >= SLOTS:
		return ERR_INVALID_PARAMETER
	if not capturing.is_empty():
		return ERR_BUSY
	capturing = action
	capture_slot = slot
	return OK

## 캡처를 취소하여 UI 탐색과 전역 단축키를 재개한다.
func cancel_capture() -> void:
	if capturing.is_empty():
		return
	var action := capturing
	capturing = &""
	capture_finished.emit(action, ERR_SKIP)

## 같은 장치 종류의 slot번째 입력을 교체한다. 다른 칸과 다른 장치 종류의 바인딩은 유지한다.
## 같은 장치 종류에서 다른 action이나 같은 action의 다른 칸이 쓰는 입력은 ERR_ALREADY_IN_USE로 거절한다.
func rebind(action: StringName, event: InputEvent, slot: int = 0) -> Error:
	if not action in _actions or slot < 0 or slot >= SLOTS or event == null or encode_event(event).is_empty():
		return ERR_INVALID_PARAMETER
	if _is_escape(event) and (action != &"pause" or _has_modifiers(event as InputEventKey)):
		return ERR_INVALID_PARAMETER
	var normalized := decode_event(encode_event(event))
	if normalized == null:
		return ERR_INVALID_PARAMETER
	var category := _category(normalized)
	for other in _actions:
		var used := slot_events(other, category)
		for index in used.size():
			if not (other == action and index == slot) and used[index].is_match(normalized):
				return ERR_ALREADY_IN_USE
	var before := InputMap.action_get_events(action)
	var after: Array[InputEvent] = []
	var index := 0
	var replaced := false
	for existing in before:
		if _category(existing) == category:
			after.append(normalized if index == slot else existing)
			replaced = replaced or index == slot
			index += 1
		else:
			after.append(existing)
	if not replaced:
		after.append(normalized)
	_apply_events(action, after)
	var error := save_bindings()
	if error != OK:
		_apply_events(action, before)
		return error
	bindings_changed.emit(action)
	return OK

## 지정 장치 종류의 slot번째 바인딩을 비운다. action의 마지막 남은 입력이나 pause의 유일한 키보드 입력은 지우지 않는다.
func clear_slot(action: StringName, category: String, slot: int = 1) -> Error:
	if not action in _actions or not category in CATEGORIES or slot < 0 or slot >= SLOTS:
		return ERR_INVALID_PARAMETER
	var current_category := slot_events(action, category)
	if slot >= current_category.size():
		return OK
	if action == &"pause" and category == "keyboard_mouse" and current_category.size() <= 1:
		return ERR_INVALID_PARAMETER
	var before := InputMap.action_get_events(action)
	var after: Array[InputEvent] = []
	var index := 0
	for existing in before:
		if _category(existing) == category:
			if index != slot:
				after.append(existing)
			index += 1
		else:
			after.append(existing)
	if after.is_empty():
		return ERR_INVALID_PARAMETER
	_apply_events(action, after)
	var error := save_bindings()
	if error != OK:
		_apply_events(action, before)
		return error
	bindings_changed.emit(action)
	return OK

## 확인된 복구 또는 사용자 요청 후 프로젝트의 기본 바인딩으로 되돌린다.
func reset_bindings() -> Error:
	for action in _actions:
		_apply_events(action, _defaults[action])
	_stored.clear()
	write_blocked = false
	var error := save_bindings()
	bindings_changed.emit(&"")
	return error

## 객체 대신 입력 종류와 숫자 필드만 저장한다.
func save_bindings() -> Error:
	var error: Error = ERR_UNAUTHORIZED if write_blocked else DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var file := ConfigFile.new()
	for action in _stored:
		file.set_value("bindings", action, _encode_all(_stored[action]))
	for action in _actions:
		file.set_value("bindings", action, _encode_all(InputMap.action_get_events(action)))
	if error == OK:
		error = file.save(storage_path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(storage_path + ".tmp", storage_path)
	if error != OK:
		save_failed.emit(error)
	return error

## action에서 지정 장치 종류("keyboard_mouse" / "controller")의 입력을 칸 순서대로 반환한다.
func slot_events(action: StringName, category: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if _category(event) == category:
				events.append(event)
	return events

## 설정 화면에 표시할 한 칸의 입력 이름을 반환한다. 비어 있으면 "—"이다.
func slot_text(action: StringName, category: String, slot: int) -> String:
	var events := slot_events(action, category)
	return event_text(events[slot]) if slot >= 0 and slot < events.size() else "—"

## 설정 화면에 표시할 action 이름이다. 번역 키 UI_ACTION_<ACTION>이 있으면 번역하고, 없으면 이름을 읽기 쉽게 바꾼다.
static func action_text(action: StringName) -> String:
	var key := "UI_ACTION_" + str(action).to_upper()
	var translated := str(TranslationServer.translate(key))
	return str(action).capitalize() if translated == key else translated

## 설정 화면에서 표시할 바인딩 문자열을 반환한다.
func binding_text(action: StringName) -> String:
	var descriptions := PackedStringArray()
	for event in InputMap.action_get_events(action):
		descriptions.append(event_text(event))
	return " / ".join(descriptions)

## 입력 이벤트를 짧은 표시 이름으로 바꾼다. 창이 있으면 물리 키를 현재 키보드 배열 글자로 표시한다.
static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		if event.physical_keycode != 0:
			var mapped: Key = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode) \
				if DesktopPlatform.has_window() else KEY_NONE
			var display_key: Key = mapped if mapped != KEY_NONE else event.physical_keycode
			return OS.get_keycode_string((int(display_key) | int(event.get_modifiers_mask())) as Key)
		if event.keycode != 0:
			return OS.get_keycode_string(event.get_keycode_with_modifiers())
	if event is InputEventJoypadMotion:
		var axis_name := str(TranslationServer.translate(_AXIS_NAMES[event.axis])) if event.axis < _AXIS_NAMES.size() \
			else str(TranslationServer.translate("UI_AXIS_OTHER")) % event.axis
		return "%s %s" % [axis_name, "+" if event.axis_value > 0.0 else "-"]
	return event.as_text()

## 지원하는 이벤트를 설정 파일용 Dictionary로 변환한다. 물리 키코드가 있으면 물리 위치를 기준으로 저장한다.
static func encode_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey and (event.physical_keycode > 0 or event.keycode > 0):
		var physical := int(event.physical_keycode) if event.physical_keycode > 0 else 0
		var keycode := 0 if physical > 0 else int(event.keycode)
		return {"type": "key", "physical": physical, "key": keycode,
			"shift": event.shift_pressed, "alt": event.alt_pressed, "ctrl": event.ctrl_pressed, "meta": event.meta_pressed}
	if event is InputEventMouseButton and event.button_index >= 1 and event.button_index <= 9:
		return {"type": "mouse", "button": event.button_index}
	if event is InputEventJoypadButton and event.button_index >= 0 and event.button_index < JOY_BUTTON_MAX:
		return {"type": "joy_button", "button": event.button_index}
	if event is InputEventJoypadMotion and event.axis >= 0 and event.axis < JOY_AXIS_MAX and absf(event.axis_value) >= 0.8:
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
			var physical := int(raw.get("physical", 0))
			var keycode := int(raw.get("key", 0))
			if physical == 0 and keycode == 0:
				return null
			var event := InputEventKey.new()
			event.physical_keycode = physical as Key
			event.keycode = (0 if physical != 0 else keycode) as Key
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
		if _is_escape(event):
			if not event.is_pressed() or event.is_echo():
				get_viewport().set_input_as_handled()
				return
			if capturing != &"pause" or _has_modifiers(event as InputEventKey) or not _can_capture_escape(capture_slot):
				cancel_capture()
				get_viewport().set_input_as_handled()
				return
		if _pressed_binding(event):
			var action := capturing
			capturing = &""
			var error := rebind(action, event, capture_slot)
			get_viewport().set_input_as_handled()
			capture_finished.emit(action, error)
		return
	var device := "controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard_mouse"
	if _pressed_binding(event) and device != active_device:
		active_device = device
		device_changed.emit(active_device)

func _can_capture_escape(slot: int) -> bool:
	for other in _actions:
		var used := slot_events(other, "keyboard_mouse")
		for index in used.size():
			if not (other == &"pause" and index == slot) and _is_escape(used[index]):
				return false
	return true

static func _is_escape(event: InputEvent) -> bool:
	return event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)

static func _has_modifiers(event: InputEventKey) -> bool:
	return event.shift_pressed or event.alt_pressed or event.ctrl_pressed or event.meta_pressed

func _unhandled_input(event: InputEvent) -> void:
	if not capturing.is_empty():
		return
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		WindowManager.toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _add_action(action: StringName, fallback: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for event in fallback:
			InputMap.action_add_event(action, event)
	_actions.append(action)
	_defaults[action] = InputMap.action_get_events(action)
	InputMap.action_set_deadzone(action, clampf(float(GameConfig.value("input", "controller_deadzone", 0.2)), 0.05, 0.95))

func _apply_events(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)

func _encode_all(events: Array) -> Array:
	var serialized: Array = []
	for event in events:
		serialized.append(encode_event(event))
	return serialized

func _load_error(error: int) -> Error:
	write_blocked = true
	load_failed.emit(error)
	return error as Error

func _pressed_binding(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= 0.8
	return event.is_pressed() and not event.is_echo() and not encode_event(event).is_empty()

static func _category(event: InputEvent) -> String:
	return "controller" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard_mouse"
