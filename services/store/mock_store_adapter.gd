## Debug에서만 업적·점수·오버레이 요청을 연습한다. 실제 서버에 기록하지 않는다.
class_name MockStoreAdapter
extends StoreAdapter

var achievements: Dictionary = {}
var scores: Dictionary = {}

## Release에서는 직접 생성해도 Mock을 초기화하지 않는다.
func initialize() -> bool:
	return OS.is_debug_build()

## Debug에서만 연습 가능한 기능을 반환한다.
func capabilities() -> Dictionary:
	var allowed := OS.is_debug_build()
	return {"achievements": allowed, "leaderboards": allowed, "overlay": allowed}

## 세션용 식별자이다. 실제 Steam 계정 ID로 사용하지 않는다.
func user_id() -> String:
	return "mock-user" if OS.is_debug_build() else ""

## 세션 메모리에만 결과를 기록하고 mock 표시를 포함하여 완료한다.
func execute(request_id: int, operation: String, payload: Dictionary) -> void:
	if not OS.is_debug_build():
		completed.emit(request_id, {"error": ERR_UNAVAILABLE, "message": "Mocks are disabled in release"})
		return
	match operation:
		"achievement": achievements[payload.id] = true
		"score": scores[payload.id] = payload.score
		"overlay": pass
		_:
			completed.emit(request_id, {"error": ERR_INVALID_PARAMETER})
			return
	completed.emit(request_id, {"error": OK, "mock": true, "operation": operation, "payload": payload.duplicate(true)})

## 항상 개발용 Adapter임을 표시한다.
func is_mock() -> bool:
	return true
