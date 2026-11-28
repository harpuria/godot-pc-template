## 게임 초기화 hook과 App을 준비하고 config에서 지정한 첫 장면으로 진입한다.
extends Node

const INIT_METHOD := "before_app_initialize"

func _ready() -> void:
	var path := str(GameConfig.value("app", "init_script", ""))
	var error := run_init_script(path)
	if error != OK:
		push_error("Game init script failed (%s): %s" % [error_string(error), path])
		# 저장 schema나 Adapter 등록이 빠진 상태로 게임을 시작하지 않는다. 창은 닫을 수 있다.
		_show_failure(tr("UI_START_FAILED") % error_string(error))
		return
	App.initialize()
	var scene := str(GameConfig.value("app", "main_scene", GameConfig.DEFAULT_MAIN_SCENE))
	error = SceneManager.change_scene(scene)
	if error != OK:
		_main_scene_failed(scene, error)
		return
	# 수락된 요청은 SceneManager가 이후 프레임에서 로드한다.
	SceneManager.transition_failed.connect(_main_scene_failed, CONNECT_ONE_SHOT)

func _main_scene_failed(path: String, error: int) -> void:
	push_error("Cannot open main scene: %s (%s)" % [path, error_string(error)])
	_show_failure(tr("UI_MAIN_SCENE_FAILED") % path)

func _show_failure(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)

## RefCounted 초기화 script의 계약을 검사하고 hook을 한 번 호출한다.
static func run_init_script(path: String) -> Error:
	if path.is_empty():
		return OK
	if not ResourceLoader.exists(path):
		return ERR_FILE_NOT_FOUND
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		return ERR_CANT_CREATE
	if not ClassDB.is_parent_class(script.get_instance_base_type(), "RefCounted"):
		return ERR_INVALID_PARAMETER
	var has_hook := false
	for method in script.get_script_method_list():
		if method.name == "_init" and method.args.size() > method.default_args.size():
			return ERR_INVALID_PARAMETER
		if method.name == INIT_METHOD:
			has_hook = true
			if not method.args.is_empty() or method.return.type != TYPE_DICTIONARY:
				return ERR_INVALID_PARAMETER
	if not has_hook:
		return ERR_METHOD_NOT_FOUND
	var hook: RefCounted = script.new()
	if hook == null:
		return ERR_CANT_CREATE
	# int 반환형은 실행 오류 시 기본값 0(OK)이 될 수 있다. 필수 필드로 완료를 확인한다.
	var result: Variant = hook.call(INIT_METHOD)
	if not result is Dictionary or not result.get("error") is int:
		return ERR_INVALID_DATA
	var error: int = result.error
	if error < OK or error > ERR_PRINTER_ON_FIRE:
		return ERR_INVALID_DATA
	return error as Error
