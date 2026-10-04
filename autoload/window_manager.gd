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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_timer.one_shot = true
	_preview_timer.timeout.connect(revert_preview)
	add_child(_preview_timer)
	_resize_timer.one_shot = true
	_resize_timer.wait_time = 0.5
	_resize_timer.timeout.connect(_remember_window_size)
	add_child(_resize_timer)
	_confirmation.title = "Keep display settings?"
	_confirmation.ok_button_text = "Keep settings"
	_confirmation.cancel_button_text = "Revert"
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

## 단축키로 창 모드와 테두리 없는 전체 화면을 전환한다. 기존 preview 중에는 무시한다.
func toggle_fullscreen() -> Error:
	return preview_options({"window_mode": "borderless" if Settings.get_setting("window_mode") == "windowed" else "windowed"})

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
		DisplayServer.window_set_mode(modes.get(options.window_mode, DisplayServer.WINDOW_MODE_WINDOWED))
		if options.window_mode == "windowed":
			var minimum := Vector2i(GameConfig.value("display", "minimum_width", 960), GameConfig.value("display", "minimum_height", 540))
			var usable := DisplayServer.screen_get_usable_rect()
			var size: Vector2i = options.window_size
			size = Vector2i(maxi(minimum.x, size.x), maxi(minimum.y, size.y))
			size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if options.vsync else DisplayServer.VSYNC_DISABLED)
	options_applied.emit(options.duplicate())

func _on_resize() -> void:
	if not previewing and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_resize_timer.start()

func _remember_window_size() -> void:
	if not previewing and DesktopPlatform.has_window() and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		Settings.set_setting("window_size", DisplayServer.window_get_size())

func _process(_delta: float) -> void:
	if previewing:
		_confirmation.dialog_text = "Reverting in %d seconds.\nConfirm only if the display looks correct." % ceili(_preview_timer.time_left)
