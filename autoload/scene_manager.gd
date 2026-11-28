## 장면 로드와 전환 중복 방지, 선택적 로딩 화면을 제공한다.
extends Node

signal transition_started(path: String)
signal transition_completed(path: String)
signal transition_failed(path: String, error: int)
var transitioning := false
var overlay: CanvasLayer
var pending_path := ""
var frames_before_load := 0

## 요청이 수락되면 OK를 반환한다. 실제 완료와 실패는 lifecycle 신호로 받는다.
func change_scene(path: String, show_loading: bool = true) -> Error:
	if transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(path, "PackedScene"):
		transition_failed.emit(path, ERR_FILE_NOT_FOUND)
		return ERR_FILE_NOT_FOUND
	InputManager.cancel_capture()
	transitioning = true
	if show_loading:
		overlay = preload("res://ui/loading/loading.tscn").instantiate()
		add_child(overlay)
	transition_started.emit(path)
	frames_before_load = 2
	pending_path = path
	set_process(true)
	return OK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

## 로딩 화면을 먼저 그린 뒤 메인 스레드에서 장면을 읽는다. 대형 리소스 streaming은 범위 밖이다.
func _process(_delta: float) -> void:
	frames_before_load -= 1
	if frames_before_load > 0:
		return
	set_process(false)
	var scene := ResourceLoader.load(pending_path, "PackedScene") as PackedScene
	if scene == null:
		_complete(ERR_INVALID_DATA)
		return
	get_tree().scene_changed.connect(_scene_changed, CONNECT_ONE_SHOT)
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		get_tree().scene_changed.disconnect(_scene_changed)
		_complete(error)

func _scene_changed() -> void:
	_complete(OK)

func _complete(error: Error) -> void:
	var path := pending_path
	pending_path = ""
	if is_instance_valid(overlay):
		overlay.queue_free()
	transitioning = false
	if error == OK:
		transition_completed.emit(path)
	else:
		transition_failed.emit(path, error)
