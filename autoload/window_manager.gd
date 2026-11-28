## 창 모드와 성능 옵션을 적용하며 화면 변경을 확인하지 않으면 자동 복구한다.
extends Node

signal preview_started(seconds: float)
signal preview_finished(confirmed: bool)
signal preview_failed(error: int)
signal options_applied(options: Dictionary)
const OPTION_KEYS := ["window_mode", "window_size", "vsync", "max_fps"]
var previewing := false
var _previous: Dictionary = {}
var _candidate: Dictionary = {}
var _preview_timer := Timer.new()
var _resize_timer := Timer.new()
var _confirmation := ConfirmationDialog.new()
var _applied_window_size := Vector2i.ZERO
var _last_requested_size := Vector2i.ZERO
var _windowed_position := Vector2i.ZERO
var _has_windowed_position := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_timer.one_shot = true
	_preview_timer.timeout.connect(revert_preview)
	add_child(_preview_timer)
	_resize_timer.one_shot = true
	_resize_timer.wait_time = 0.5
	_resize_timer.timeout.connect(_remember_window_size)
	add_child(_resize_timer)
	_confirmation.title = "UI_DISPLAY_KEEP_TITLE"
	_confirmation.ok_button_text = "UI_DISPLAY_KEEP"
	_confirmation.cancel_button_text = "UI_DISPLAY_REVERT"
	_confirmation.confirmed.connect(confirm_preview)
	_confirmation.canceled.connect(revert_preview)
	add_child(_confirmation)
	apply_saved_options.call_deferred()
	if DesktopPlatform.has_window():
		get_tree().root.size_changed.connect(_on_resize)

## 확인 전 후보가 있으면 그 값을, 없으면 저장된 화면 옵션을 반환한다.
func current_options() -> Dictionary:
	if previewing:
		return _candidate.duplicate()
	var options: Dictionary = {}
	for key in OPTION_KEYS:
		options[key] = Settings.get_setting(key)
	return options

## 저장된 화면 설정을 적용한다. headless에서는 FPS 설정만 적용한다.
func apply_saved_options() -> void:
	_apply(current_options())

## 화면 옵션을 임시 적용한다. 지정 시간 안에 확인하지 않으면 원래 설정으로 돌아간다.
func preview_options(updates: Dictionary, seconds: float = 15.0) -> Error:
	if previewing:
		return ERR_BUSY
	if not DesktopPlatform.has_window():
		return ERR_UNAVAILABLE
	var options := current_options()
	for key in updates:
		if not key in OPTION_KEYS:
			return ERR_INVALID_PARAMETER
		options[key] = updates[key]
	if not _valid_options(options) or not is_finite(seconds) or seconds < 1.0:
		return ERR_INVALID_PARAMETER
	InputManager.cancel_capture()
	_previous = current_options()
	_candidate = options
	previewing = true
	_resize_timer.stop()
	_apply(_candidate)
	_preview_timer.start(seconds)
	_confirmation.popup_centered(Vector2i(420, 180))
	preview_started.emit(seconds)
	return OK

## 미리보기 값을 영구 저장한다. 저장 실패 시 창을 원래 상태로 복구한다.
func confirm_preview() -> Error:
	if not previewing:
		return ERR_UNCONFIGURED
	var error := Settings.set_many(_candidate)
	if error != OK:
		revert_preview()
		preview_failed.emit(error)
		return error
	_preview_timer.stop()
	_confirmation.hide()
	previewing = false
	preview_finished.emit(true)
	return OK

## 저장하지 않은 화면 변경을 되돌린다.
func revert_preview() -> void:
	if not previewing:
		return
	_preview_timer.stop()
	_confirmation.hide()
	previewing = false
	_apply(_previous)
	preview_finished.emit(false)

## 확인까지 남은 시간을 반환한다.
func preview_seconds_left() -> float:
	return _preview_timer.time_left

## 단축키로 창 모드와 테두리 없는 전체 화면을 전환한다. 모니터 해상도를 바꾸지 않으므로 확인창 없이 저장하고 적용한다.
## 화면 미리보기 중에는 ERR_BUSY, 창이 없으면 ERR_UNAVAILABLE이다. 저장에 실패하면 화면을 바꾸지 않고 오류를 반환한다.
func toggle_fullscreen() -> Error:
	if previewing:
		return ERR_BUSY
	if not DesktopPlatform.has_window():
		return ERR_UNAVAILABLE
	var mode := "borderless" if Settings.get_setting("window_mode") == "windowed" else "windowed"
	var error := Settings.set_setting("window_mode", mode)
	if error != OK:
		return error
	apply_saved_options()
	return OK

func _valid_options(options: Dictionary) -> bool:
	var size: Variant = options.get("window_size")
	return options.get("window_mode") in ["windowed", "borderless", "fullscreen"] \
		and size is Vector2i and size.x >= 320 and size.y >= 180 \
		and options.get("vsync") is bool and options.get("max_fps") is int \
		and options.max_fps >= 0 and options.max_fps <= 1000

func _apply(options: Dictionary) -> void:
	Engine.max_fps = int(options.max_fps)
	if DesktopPlatform.has_window():
		var modes := {"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
			"borderless": DisplayServer.WINDOW_MODE_FULLSCREEN,
			"fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN}
		var target_mode: DisplayServer.WindowMode = modes.get(options.window_mode, DisplayServer.WINDOW_MODE_WINDOWED)
		var current_mode := DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_WINDOWED and target_mode != DisplayServer.WINDOW_MODE_WINDOWED:
			_windowed_position = DisplayServer.window_get_position()
			_has_windowed_position = true
		var mode_changed := current_mode != target_mode
		if mode_changed:
			DisplayServer.window_set_mode(target_mode)
		if options.window_mode == "windowed":
			var minimum := Vector2i(GameConfig.value("display", "minimum_width", 960), GameConfig.value("display", "minimum_height", 540))
			var usable := DisplayServer.screen_get_usable_rect()
			var requested: Vector2i = options.window_size
			var size := Vector2i(maxi(minimum.x, requested.x), maxi(minimum.y, requested.y))
			size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
			var requested_changed := requested != _last_requested_size
			var size_changed := DisplayServer.window_get_size() != size
			_applied_window_size = size
			_last_requested_size = requested
			_resize_timer.stop()
			if mode_changed or requested_changed or size_changed:
				DisplayServer.window_set_size(size)
				if not requested_changed and mode_changed and _has_windowed_position:
					DisplayServer.window_set_position(_clamp_window_position(_windowed_position, size, usable))
				else:
					var centered := usable.position + (usable.size - size) / 2
					DisplayServer.window_set_position(centered)
					_windowed_position = centered
					_has_windowed_position = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if options.vsync else DisplayServer.VSYNC_DISABLED)
	options_applied.emit(options.duplicate())

func _clamp_window_position(pos: Vector2i, size: Vector2i, usable: Rect2i) -> Vector2i:
	var max_x := maxi(usable.position.x, usable.position.x + usable.size.x - size.x)
	var max_y := maxi(usable.position.y, usable.position.y + usable.size.y - size.y)
	return Vector2i(clampi(pos.x, usable.position.x, max_x), clampi(pos.y, usable.position.y, max_y))

func _on_resize() -> void:
	if previewing or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	if DisplayServer.window_get_size() == _applied_window_size:
		return
	_resize_timer.start()

func _remember_window_size() -> void:
	if previewing or not DesktopPlatform.has_window() or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var actual := DisplayServer.window_get_size()
	if actual == _applied_window_size or actual == Settings.get_setting("window_size"):
		return
	_applied_window_size = actual
	_last_requested_size = actual
	Settings.set_setting("window_size", actual)

func _process(_delta: float) -> void:
	if previewing:
		_confirmation.dialog_text = tr("UI_DISPLAY_COUNTDOWN") % ceili(_preview_timer.time_left)
