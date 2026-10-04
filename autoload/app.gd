## 공통 서비스 초기화, 포커스·pause·오버레이 상태와 저장 후 종료를 관리한다.
extends Node

signal initialized
signal paused
signal resumed
signal quit_requested
signal quit_failed(error: int)
signal quitting
var ready_for_game := false
var store: StoreService
var _registered_store_adapter: StoreAdapter
var _pause_reasons: Dictionary = {}
var _audio_reasons: Dictionary = {}
var _owns_tree_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 게임 init hook에서 검증한 Adapter를 등록한다. App 초기화 뒤에는 교체하지 않는다.
func register_store_adapter(adapter: StoreAdapter) -> Error:
	if ready_for_game or adapter == null:
		return ERR_INVALID_PARAMETER
	_registered_store_adapter = adapter
	return OK

## bootstrap에서 한 번 호출한다. SDK 없는 PC 빌드는 기본 Adapter로 실행한다.
func initialize() -> void:
	if ready_for_game:
		return
	var actual := Engine.get_version_info()
	if "%s.%s.%s" % [actual.major, actual.minor, actual.patch] != GameConfig.ENGINE_VERSION:
		push_warning("Template requires Godot " + GameConfig.ENGINE_VERSION)
	var channel := GameConfig.distribution_channel()
	var selected: StoreAdapter = StoreAdapter.new()
	if GameConfig.enabled("store"):
		if GameConfig.use_mocks():
			selected = MockStoreAdapter.new()
		elif channel == "steam" and GameConfig.value("services", "mode", "disabled") == "native" and _registered_store_adapter != null:
			selected = _registered_store_adapter
	store = StoreService.new()
	add_child(store)
	store.initialize(channel, GameConfig.enabled("store"), selected,
		GameConfig.value("store", "achievement_ids", {}), GameConfig.value("store", "leaderboard_ids", {}),
		float(GameConfig.value("store", "timeout_seconds", 15.0)))
	store.overlay_changed.connect(func(open: bool): set_paused("overlay", open))
	var error := SaveManager.load_slot()
	if error != OK:
		push_warning("Save load failed; writes blocked: %s" % error_string(error))
	ready_for_game = true
	AppLogger.info("App", "OS=%s Channel=%s Store=%s Mock=%s" % [DesktopPlatform.current(), channel, store.available, store.is_mock()])
	initialized.emit()

## 게임 메뉴·포커스·오버레이별 pause 이유를 독립적으로 추가하거나 해제한다.
## 다른 코드가 먼저 pause한 SceneTree는 App이 임의로 재개하지 않는다.
func set_paused(reason: String, enabled: bool) -> void:
	var was_paused := not _pause_reasons.is_empty()
	if enabled:
		_pause_reasons[reason] = true
	else:
		_pause_reasons.erase(reason)
	var should_pause := not _pause_reasons.is_empty()
	if should_pause and not was_paused:
		SaveManager.flush()
		_owns_tree_pause = not get_tree().paused
		get_tree().paused = true
		paused.emit()
	elif not should_pause and was_paused:
		if _owns_tree_pause:
			get_tree().paused = false
		_owns_tree_pause = false
		resumed.emit()
	_update_audio()

## 특정 pause 이유가 활성화되어 있는지 반환한다.
func has_pause_reason(reason: String) -> bool:
	return _pause_reasons.has(reason)

func _notification(what: int) -> void:
	if not ready_for_game:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			SaveManager.flush()
			set_paused("focus", bool(GameConfig.value("lifecycle", "pause_on_focus_loss", true)))
			if bool(GameConfig.value("lifecycle", "mute_on_focus_loss", true)):
				_audio_reasons["focus"] = true
			else:
				_audio_reasons.erase("focus")
			_update_audio()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			set_paused("focus", false)
			_audio_reasons.erase("focus")
			_update_audio()
		NOTIFICATION_WM_CLOSE_REQUEST:
			var handled := not quit_requested.get_connections().is_empty()
			quit_requested.emit()
			if not handled:
				request_quit()

func _update_audio() -> void:
	# focus의 오디오는 mute_on_focus_loss만 결정한다. 메뉴·overlay는 계속 정지한다.
	var suspend_for_pause := false
	for reason in _pause_reasons:
		if reason != "focus":
			suspend_for_pause = true
			break
	AudioManager.set_suspended(suspend_for_pause or not _audio_reasons.is_empty())

## 변경된 진행을 저장한 후 종료한다. 실패하면 UI가 복구를 선택할 수 있도록 종료를 보류한다.
func request_quit() -> Error:
	var error := SaveManager.flush()
	if error != OK:
		quit_failed.emit(error)
		return error
	WindowManager.revert_preview()
	quitting.emit()
	get_tree().quit()
	return OK

## 사용자에게 저장 실패를 알리고 명시적으로 선택받은 경우에만 저장 없이 종료한다.
func quit_without_saving() -> void:
	WindowManager.revert_preview()
	quitting.emit()
	get_tree().quit()
