## 논리 ID, 요청 직렬화, timeout을 관리하며 ESD가 없어도 게임을 실행할 수 있게 한다.
class_name StoreService
extends Node

signal request_succeeded(operation: String, logical_id: String, result: Dictionary)
signal request_failed(operation: String, logical_id: String, error: int, message: String)
signal overlay_changed(open: bool)
var channel := "standalone"
var available := false
var adapter: StoreAdapter
var _achievement_ids: Dictionary = {}
var _leaderboard_ids: Dictionary = {}
var _next_request := 0
var _pending: Dictionary = {}
var _timer := Timer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

## App이 선택한 Adapter를 연결한다. 기능 off이면 SDK 초기화를 생략한다.
func initialize(selected_channel: String, enabled: bool, selected_adapter: StoreAdapter,
		achievement_ids: Dictionary, leaderboard_ids: Dictionary, timeout: float = 15.0) -> void:
	channel = selected_channel
	adapter = selected_adapter
	_achievement_ids = achievement_ids.duplicate(true)
	_leaderboard_ids = leaderboard_ids.duplicate(true)
	_timer.wait_time = maxf(1.0, timeout)
	adapter.completed.connect(_on_completed)
	adapter.overlay_changed.connect(func(open: bool): overlay_changed.emit(open))
	available = enabled and (OS.is_debug_build() or not adapter.is_mock()) and adapter.initialize()

## 현재 사용 가능한 기능을 조회한다. 성공 호출 전에 이 값을 확인할 수 있다.
func supports(feature: String) -> bool:
	return available and bool(adapter.capabilities().get(feature, false))

## 실제 SDK 또는 Mock 사용 여부를 UI에 표시할 수 있다.
func is_mock() -> bool:
	return adapter != null and adapter.is_mock()

## 게임이 정의한 논리 업적 ID를 스토어 ID로 변환하여 요청한다.
func unlock_achievement(logical_id: String) -> Error:
	var native_id := str(_achievement_ids.get(logical_id, ""))
	if native_id.is_empty():
		return _reject("achievement", logical_id, ERR_INVALID_PARAMETER, "Unknown achievement ID")
	return _request("achievement", logical_id, "achievements", {"id": native_id})

## 정수 점수를 제출한다. 정렬·갱신·최댓값 정책은 구체 Adapter가 정의한다.
func submit_score(logical_id: String, score: int) -> Error:
	var native_id := str(_leaderboard_ids.get(logical_id, ""))
	if native_id.is_empty():
		return _reject("score", logical_id, ERR_INVALID_PARAMETER, "Unknown leaderboard ID")
	return _request("score", logical_id, "leaderboards", {"id": native_id, "score": score})

## 오버레이 표시 요청이다. 실제 표시 완료 또는 리뷰 작성을 의미하지 않는다.
func open_overlay(page: String = "achievements") -> Error:
	if not page in ["achievements", "friends"]:
		return _reject("overlay", page, ERR_INVALID_PARAMETER, "Unsupported overlay page")
	return _request("overlay", page, "overlay", {"page": page})

func _request(operation: String, logical_id: String, capability: String, payload: Dictionary) -> Error:
	if not supports(capability):
		return _reject(operation, logical_id, ERR_UNAVAILABLE, "Store feature unavailable")
	if not _pending.is_empty():
		return _reject(operation, logical_id, ERR_BUSY, "Another store request is pending")
	_next_request += 1
	_pending = {"id": _next_request, "operation": operation, "logical_id": logical_id}
	_timer.start()
	adapter.execute.call_deferred(_next_request, operation, payload)
	return OK

func _reject(operation: String, logical_id: String, error: Error, message: String) -> Error:
	request_failed.emit(operation, logical_id, error, message)
	return error

func _on_completed(request_id: int, result: Dictionary) -> void:
	if _pending.is_empty() or request_id != _pending.id:
		return
	var request := _pending.duplicate()
	_pending.clear()
	_timer.stop()
	var raw_error: Variant = result.get("error", ERR_INVALID_DATA)
	var error := int(raw_error) if raw_error is int else ERR_INVALID_DATA
	if error == OK:
		var normalized := result.duplicate(true)
		normalized["mock"] = adapter.is_mock()
		request_succeeded.emit(request.operation, request.logical_id, normalized)
	else:
		request_failed.emit(request.operation, request.logical_id, error, str(result.get("message", "Store request failed")))

func _on_timeout() -> void:
	if _pending.is_empty():
		return
	var request := _pending.duplicate()
	_pending.clear()
	request_failed.emit(request.operation, request.logical_id, ERR_TIMEOUT, "Store request timed out")

func _process(delta: float) -> void:
	if available:
		adapter.poll(delta)

func _exit_tree() -> void:
	if available:
		adapter.shutdown()
