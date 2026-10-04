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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var timer := Timer.new()
	timer.wait_time = maxf(1.0, float(GameConfig.value("save", "autosave_seconds", 30.0)))
	timer.timeout.connect(flush)
	add_child(timer)
	timer.start()

## from_version에서 다음 버전으로 변환하는 Callable(Dictionary)->Dictionary를 등록한다.
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
		if not next is Dictionary:
			return _load_error(ERR_INVALID_DATA)
		candidate = next
		version += 1
	data = candidate
	dirty = migrated
	write_blocked = false
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
