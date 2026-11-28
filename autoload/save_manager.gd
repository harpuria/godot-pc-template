## 게임 저장 데이터와 버전 migration을 관리한다. 사용자 설정은 Settings가 담당한다.
extends Node

signal saved
signal loaded
signal save_failed(error: int)
signal load_failed(error: int)
var data: Dictionary = {}
var schema_version: int = 1
var storage_path: String = "user://saves/slot_1.json"
var dirty := false
var write_blocked := false
var migrations: Dictionary = {}
var _autosave_timer := Timer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave_timer.wait_time = maxf(1.0, float(GameConfig.value("save", "autosave_seconds", 30.0)))
	_autosave_timer.timeout.connect(flush)
	add_child(_autosave_timer)

## App 초기화가 완료된 뒤 주기적 자동 저장을 시작한다.
func start_autosave() -> void:
	_autosave_timer.wait_time = maxf(1.0, float(GameConfig.value("save", "autosave_seconds", 30.0)))
	if _autosave_timer.is_stopped():
		_autosave_timer.start()

## 다음 버전의 Dictionary를 반환한다. 데이터를 모두 지울 때는 인수의 clear() 후 같은 Dictionary를 반환한다.
func register_migration(from_version: int, migration: Callable) -> void:
	migrations[from_version] = migration

## 게임이 정의한 JSON 호환 값을 저장한다. 직접 data를 수정한 경우 mark_dirty를 호출한다.
func set_value(key: String, value: Variant) -> void:
	data[key] = value
	mark_dirty()

## 직접 수정한 게임 데이터를 다음 자동 저장 대상으로 표시한다.
func mark_dirty() -> void:
	dirty = true

## 변경된 데이터만 자동 저장한다.
func flush() -> Error:
	return save_slot() if dirty else OK

## 기본 슬롯에 버전과 데이터를 함께 기록하고 실패를 신호로 알린다.
func save_slot() -> Error:
	var error := ERR_UNAUTHORIZED if write_blocked else JsonStore.write(storage_path, {"version": schema_version, "data": data})
	if error != OK:
		save_failed.emit(error)
		return error
	dirty = false
	saved.emit()
	return OK

## 읽기 실패 시 메모리와 원본 파일을 보존하고 자동 덮어쓰기를 차단한다.
func load_slot() -> Error:
	var result := JsonStore.read(storage_path)
	var error: int = result.error
	if error == ERR_FILE_NOT_FOUND:
		data = {}
		dirty = false
		write_blocked = false
		loaded.emit()
		return OK
	if error != OK:
		return _load_error(error)
	if result.get("recovered", false):
		push_warning("Save restored from an interrupted replace: %s.tmp" % storage_path)
	var document: Dictionary = result.document
	if not document.get("data") is Dictionary:
		return _load_error(ERR_INVALID_DATA)
	var raw_version: Variant = document.get("version", -1)
	if not (raw_version is int or raw_version is float):
		return _load_error(ERR_INVALID_DATA)
	if float(raw_version) != floorf(float(raw_version)):
		return _load_error(ERR_INVALID_DATA)
	var version := int(raw_version)
	if version < 1 or version > schema_version:
		return _load_error(ERR_INVALID_DATA)
	var candidate: Dictionary = document.data.duplicate(true)
	var migrated := version != schema_version
	while version < schema_version:
		if not migrations.has(version):
			return _load_error(ERR_UNAVAILABLE)
		var migration: Callable = migrations[version]
		if not migration.is_valid():
			return _load_error(ERR_INVALID_PARAMETER)
		var next: Variant = migration.call(candidate)
		# GDScript의 Dictionary 반환 함수는 런타임 오류 때 새 빈 Dictionary를 돌려준다.
		# 의도적인 빈 결과는 변환 함수가 받은 객체를 직접 반환했을 때만 식별할 수 있다.
		if not next is Dictionary or (next.is_empty() and not is_same(next, candidate)):
			return _load_error(ERR_INVALID_DATA)
		candidate = next
		version += 1
	data = candidate
	write_blocked = false
	# 임시 파일 복구는 먼저 rename으로 무손실 승격하고, migration이나 승격 실패 시에만 새 .tmp로 기록한다.
	var promoted := true
	if bool(result.get("recovered", false)):
		promoted = DirAccess.rename_absolute(storage_path + ".tmp", storage_path) == OK
	if migrated or not promoted:
		dirty = save_slot() != OK
	else:
		dirty = false
	loaded.emit()
	return OK

func _load_error(error: int) -> Error:
	write_blocked = true
	load_failed.emit(error)
	return error as Error

## 게임이 사용자 확인 후 새 저장을 시작할 때만 호출한다. 다음 저장 시 기존 파일을 교체한다.
func reset_slot(initial_data: Dictionary = {}) -> void:
	data = initial_data.duplicate(true)
	write_blocked = false
	dirty = true
