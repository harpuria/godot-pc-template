## 음량, 언어, 화면 옵션을 진행 저장과 분리하고 잘못된 설정 파일을 보존한다.
extends Node

signal changed(key: String, value: Variant)
signal save_failed(error: int)
signal load_failed(error: int)
var storage_path := "user://settings.cfg"
var values: Dictionary = {}
var write_blocked := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	values = defaults()
	TranslationServer.set_locale(str(values.language))
	load_settings()

## 새 사용자에게 적용할 기본값을 반환한다.
func defaults() -> Dictionary:
	return {
		"master_volume": 0.8, "bgm_volume": 0.8, "sfx_volume": 0.8, "ui_volume": 0.8,
		"language": resolve_language(OS.get_locale()),
		"window_mode": GameConfig.value("display", "default_mode", "windowed"),
		"window_size": Vector2i(GameConfig.value("display", "window_width", 1280), GameConfig.value("display", "window_height", 720)),
		"vsync": GameConfig.value("display", "default_vsync", true),
		"max_fps": GameConfig.value("display", "default_max_fps", 0)
	}

## 선호 로케일과 가장 잘 맞는 등록된 번역 언어를 반환한다. 일치 항목이 없으면 프로젝트 fallback 언어를 고른다.
static func resolve_language(preferred: String) -> String:
	var locales := Array(TranslationServer.get_loaded_locales())
	locales.sort()
	var fallback := str(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))
	for candidate in [preferred, fallback, "en"]:
		if candidate.is_empty():
			continue
		var best := ""
		var best_score := 0
		for locale: String in locales:
			var score := TranslationServer.compare_locales(candidate, locale)
			if score > best_score:
				best_score = score
				best = locale
		if not best.is_empty():
			return best
	return str(locales[0]) if not locales.is_empty() else "en"

## 설정을 읽는다. 파일 손상 시 기본값으로 실행하고 기존 파일의 교체를 차단한다.
func load_settings() -> Error:
	var file := ConfigFile.new()
	var error := file.load(storage_path)
	var recovered_temp := false
	if error == ERR_FILE_NOT_FOUND:
		# Windows에서 교체가 중단되어 완성된 .tmp만 남은 경우에만 복구하고, 미완성 첫 쓰기 .tmp는 새 사용자로 시작한다.
		if not FileAccess.file_exists(storage_path + ".tmp") or file.load(storage_path + ".tmp") != OK \
				or not file.has_section("settings") or file.get_section_keys("settings").is_empty():
			write_blocked = false
			return OK
		recovered_temp = true
		error = OK
	if error != OK or not file.has_section("settings"):
		write_blocked = true
		load_failed.emit(error if error != OK else ERR_INVALID_DATA)
		return (error if error != OK else ERR_INVALID_DATA) as Error
	var staged: Dictionary = {}
	for key in file.get_section_keys("settings"):
		var value: Variant = file.get_value("settings", key)
		if not _valid(key, value):
			if recovered_temp:
				write_blocked = false
				return OK
			write_blocked = true
			load_failed.emit(ERR_INVALID_DATA)
			return ERR_INVALID_DATA
		staged[key] = _normalize(key, value)
	values.merge(staged, true)
	write_blocked = false
	if recovered_temp:
		push_warning("Settings restored from an interrupted replace: %s.tmp" % storage_path)
		_write_values(values)
	TranslationServer.set_locale(str(values.language))
	for key in staged:
		changed.emit(key, values[key])
	return OK

## 설정 값을 조회하며 미정의 키는 fallback을 반환한다.
func get_setting(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)

## 유효한 설정을 적용하고 저장한다. 실패는 반환값과 save_failed 신호로 전달한다.
func set_setting(key: String, value: Variant) -> Error:
	return set_many({key: value})

## 화면 옵션처럼 함께 변경해야 하는 값을 한 번에 기록한다.
func set_many(updates: Dictionary) -> Error:
	var staged := values.duplicate()
	for key in updates:
		if not key is String or not _valid(key, updates[key]):
			return ERR_INVALID_PARAMETER
		staged[key] = _normalize(key, updates[key])
	var error := _write_values(staged)
	if error != OK:
		return error
	values = staged
	for key in updates:
		if key == "language":
			TranslationServer.set_locale(str(values[key]))
		changed.emit(key, values[key])
	return OK

## 임시 ConfigFile을 기록한 후 같은 디렉터리에서 교체한다.
func save_settings() -> Error:
	return _write_values(values)

func _write_values(candidate: Dictionary) -> Error:
	var error: Error = ERR_UNAUTHORIZED if write_blocked else OK
	if error == OK:
		error = DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var file := ConfigFile.new()
	for key in candidate:
		file.set_value("settings", key, candidate[key])
	if error == OK:
		error = file.save(storage_path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(storage_path + ".tmp", storage_path)
	if error != OK:
		save_failed.emit(error)
	return error

## 사용자에게 복구 선택을 받은 뒤 기본값으로 기존 설정을 교체한다.
func reset_to_defaults() -> Error:
	write_blocked = false
	return set_many(defaults())

func _valid(key: String, value: Variant) -> bool:
	if key.ends_with("_volume"):
		return (value is float or value is int) and is_finite(float(value))
	match key:
		"language": return value is String and not value.is_empty()
		"window_mode": return value in ["windowed", "borderless", "fullscreen"]
		"window_size": return value is Vector2i and value.x >= 320 and value.y >= 180
		"vsync": return value is bool
		"max_fps": return value is int and value >= 0 and value <= 1000
	return not value is Object and not value is Callable and not value is Signal

func _normalize(key: String, value: Variant) -> Variant:
	return clampf(float(value), 0.0, 1.0) if key.ends_with("_volume") else value
