## 선택적 ESD SDK의 수명과 콜백을 공통 형태로 연결하는 기본 Adapter이다.
class_name StoreAdapter
extends RefCounted

signal completed(request_id: int, result: Dictionary)
signal overlay_changed(open: bool)

## 외부 SDK가 없을 때 false를 반환한다. 구체 Adapter가 초기화를 구현한다.
func initialize() -> bool:
	return false

## 현재 Adapter가 지원하는 기능을 반환한다.
func capabilities() -> Dictionary:
	return {"achievements": false, "leaderboards": false, "overlay": false}

## 사용자 식별 정보가 필요하면 구체 Adapter가 제공한다. 기본 구현은 비어 있다.
func user_id() -> String:
	return ""

## 요청 결과를 같은 request_id로 전달한다. 성공은 실제 SDK의 완료 시점에만 보낸다.
func execute(request_id: int, _operation: String, _payload: Dictionary) -> void:
	completed.emit(request_id, {"error": ERR_UNAVAILABLE, "message": "Store SDK unavailable"})

## SDK별 콜백을 처리한다. 직접 GodotSteam을 붙이면 이 지점에서 run_callbacks 등을 호출한다.
func poll(_delta: float) -> void:
	pass

## 종료 전에 연결을 정리한다.
func shutdown() -> void:
	pass

## Mock 결과를 실제 스토어 결과와 구분한다.
func is_mock() -> bool:
	return false
