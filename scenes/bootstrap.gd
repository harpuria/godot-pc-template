## 게임 초기화 hook과 App을 준비하고 config에서 지정한 첫 장면으로 진입한다.
extends Node

const INIT_METHOD := "before_app_initialize"

func _ready() -> void:
	var path := str(GameConfig.value("app", "init_script", ""))
	var error := run_init_script(path)
	if error != OK:
		push_error("Game init script failed (%s): %s" % [error_string(error), path])
		# 저장 schema나 Adapter 등록이 빠진 상태로 게임을 시작하지 않는다.
		return
	App.initialize()
	var scene := str(GameConfig.value("app", "main_scene", "res://scenes/main.tscn"))
	error = SceneManager.change_scene(scene)
	if error != OK:
		push_error("Cannot open main scene: %s" % scene)

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
