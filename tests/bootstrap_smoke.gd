## 프로젝트 기본 진입점으로 부팅해 설정된 첫 장면의 실제 전환 완료를 확인한다.
class_name BootstrapSmokeTest
extends SceneTree

var _storage: DirAccess

## 게임 hook을 실행하기 전에 테스트 저장 경로와 장면 완료 관찰자를 준비한다.
func _initialize() -> void:
	_storage = DirAccess.create_temp("godot-pc-bootstrap-")
	if _storage == null:
		push_error("Could not create temporary bootstrap storage")
		quit(1)
		return
	for pair in [["SaveManager", "slot.json"], ["Settings", "settings.cfg"], ["InputManager", "input.cfg"]]:
		root.get_node(pair[0]).storage_path = _storage.get_current_dir().path_join(pair[1])
	var manager := root.get_node("SceneManager")
	manager.transition_completed.connect(_on_transition_completed, CONNECT_ONE_SHOT)
	manager.transition_failed.connect(func(path: String, error: int):
		push_error("Bootstrap could not enter %s (%s)" % [path, error_string(error)])
		quit(1), CONNECT_ONE_SHOT)
	create_timer(5.0).timeout.connect(func():
		push_error("Bootstrap did not enter the configured main scene")
		quit(1))

func _on_transition_completed(_path: String) -> void:
	var config := root.get_node("GameConfig")
	var expected := str(config.value("app", "main_scene", config.DEFAULT_MAIN_SCENE))
	var scene := ResourceLoader.load(expected, "PackedScene") as PackedScene
	var entered := scene != null and current_scene != null and current_scene.scene_file_path == scene.resource_path
	if not entered or not root.get_node("App").ready_for_game:
		push_error("Expected initialized game in %s" % expected)
		quit(1)
		return
	print("BOOTSTRAP: entered ", current_scene.scene_file_path)
	quit(0)
