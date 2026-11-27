## 공개 설정을 프로젝트와 아홉 PC export preset(Windows·macOS·Linux × 세 채널)에 반영하고 수동 SDK·서명 옵션을 보존한다.
extends SceneTree

const DEFAULT_INPUT := preload("res://core/input/default_input.gd")
const GAME_CONFIG := preload("res://autoload/game_config.gd")
# [preset 이름 접두어, Godot platform, 출력 폴더, 실행 파일 확장자]. 순서가 preset 번호를 정한다.
const PLATFORMS := [
	["Windows", "Windows Desktop", "windows", "exe"],
	["macOS", "macOS", "macos", "zip"],
	["Linux", "Linux", "linux", "x86_64"],
]
const CHANNELS := ["standalone", "itch", "steam"]
# 공통 UI(pause 메뉴·설정 패널·대화상자) 번역. 게임이 추가한 번역은 유지하고 빠진 항목만 추가한다.
const UI_TRANSLATIONS := ["res://ui/i18n/ui.en.translation", "res://ui/i18n/ui.ko.translation"]

func _initialize() -> void:
	var actual := Engine.get_version_info()
	var pinned := FileAccess.get_file_as_string("res://.godot-version").strip_edges()
	if pinned != GAME_CONFIG.ENGINE_VERSION or "%s.%s.%s" % [actual.major, actual.minor, actual.patch] != GAME_CONFIG.ENGINE_VERSION:
		_fail("Use Godot " + GAME_CONFIG.ENGINE_VERSION + " and keep .godot-version aligned")
		return
	var config := ConfigFile.new()
	if config.load("res://config/game.cfg") != OK:
		_fail("Cannot read config/game.cfg")
		return
	var name := str(config.get_value("app", "name", ""))
	var data_dir := str(config.get_value("app", "data_directory", ""))
	var executable := str(config.get_value("app", "executable_name", ""))
	var bundle := str(config.get_value("app", "macos_bundle", ""))
	var version := str(config.get_value("app", "version", ""))
	var exclude_demo := bool(config.get_value("export", "exclude_demo", false))
	if exclude_demo and str(config.get_value("app", "main_scene", "")).begins_with("res://scenes/"):
		_fail("Set a game/main_scene before excluding the demo")
		return
	if name.is_empty() or not _safe_relative_directory(data_dir) or not _identifier(executable, false) or not _identifier(bundle, true):
		_fail("Invalid app name, data_directory, executable_name or macos_bundle")
		return
	var parts := version.split(".")
	if parts.size() < 3 or parts.size() > 4:
		_fail("Use a numeric app version: major.minor.patch[.build]")
		return
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 65535:
			_fail("Invalid numeric app version")
			return
	var width := int(config.get_value("display", "viewport_width", 1280))
	var height := int(config.get_value("display", "viewport_height", 720))
	var min_width := int(config.get_value("display", "minimum_width", 960))
	var min_height := int(config.get_value("display", "minimum_height", 540))
	var window_width := int(config.get_value("display", "window_width", 1280))
	var window_height := int(config.get_value("display", "window_height", 720))
	if mini(width, min_width) < 320 or mini(height, min_height) < 180 or window_width < min_width or window_height < min_height:
		_fail("Invalid viewport / window / minimum dimensions")
		return
	var presets := ConfigFile.new()
	var preset_error := presets.load("res://export_presets.cfg")
	if preset_error != OK and preset_error != ERR_FILE_NOT_FOUND:
		_fail("Cannot parse export_presets.cfg; existing file preserved")
		return
	ProjectSettings.set_setting("application/config/name", name)
	ProjectSettings.set_setting("application/config/version", version)
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", data_dir)
	# macOS universal/arm64 exporter가 ASTC import를 요구하므로 두 PC 포맷을 준비한다.
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_s3tc_bptc", true)
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	for pair in [["viewport_width", width], ["viewport_height", height], ["window_width_override", window_width],
		["window_height_override", window_height], ["min_width", min_width], ["min_height", min_height]]:
		ProjectSettings.set_setting("display/window/size/" + pair[0], pair[1])
	var deadzone := clampf(float(config.get_value("input", "controller_deadzone", 0.2)), 0.05, 0.95)
	var inputs: Dictionary = DEFAULT_INPUT.actions()
	for action in inputs:
		var key := "input/" + str(action)
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, {"deadzone": deadzone, "events": inputs[action]})
		else:
			var current: Dictionary = ProjectSettings.get_setting(key)
			if not is_equal_approx(float(current.get("deadzone", 0.2)), deadzone):
				var updated := current.duplicate()
				updated["deadzone"] = deadzone
				ProjectSettings.set_setting(key, updated)
	var translations := PackedStringArray(ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()))
	for path: String in UI_TRANSLATIONS:
		if not path in translations:
			translations.append(path)
	ProjectSettings.set_setting("internationalization/locale/translations", translations)
	var index := 0
	for platform_info in PLATFORMS:
		var platform: String = platform_info[0]
		for channel: String in CHANNELS:
			var section := "preset.%d" % index
			var options := section + ".options"
			var windows: bool = platform == "Windows"
			var macos: bool = platform == "macOS"
			var preset_name := platform + " " + channel.capitalize()
			# 도구가 소유하지 않는 preset을 덮어쓰지 않는다. 직접 만든 preset은 마지막 번호 뒤로 옮긴다.
			var existing := str(presets.get_value(section, "name", preset_name))
			if existing != preset_name:
				_fail("export preset %d is \"%s\", expected \"%s\". Move custom presets after index %d" % [index, existing, preset_name, PLATFORMS.size() * CHANNELS.size() - 1])
				return
			presets.set_value(section, "name", preset_name)
			presets.set_value(section, "platform", platform_info[1])
			presets.set_value(section, "runnable", channel == "standalone")
			presets.set_value(section, "advanced_options", true)
			# 배포 채널만 교체하며 수동으로 추가한 SDK feature는 유지한다.
			var custom := PackedStringArray([channel])
			for feature in str(presets.get_value(section, "custom_features", "")).split(",", false):
				if not feature in CHANNELS:
					custom.append(feature)
			presets.set_value(section, "custom_features", ",".join(custom))
			presets.set_value(section, "export_filter", "all_resources")
			var include_filter := "config/game.cfg,third_party/*.txt"
			var exclude_filter := "docs/*,tests/*,tools/*,*.md,config/*.local.cfg,steam_appid.txt,build/*,dist/*"
			include_filter = _append_filter(include_filter, str(config.get_value("export", "extra_include_filter", "")))
			exclude_filter = _append_filter(exclude_filter, str(config.get_value("export", "extra_exclude_filter", "")))
			if exclude_demo:
				exclude_filter += ",scenes/main.tscn,scenes/demo.gd,scenes/transition_demo.*,assets/demo/*"
			if channel != "steam":
				exclude_filter = _append_filter(exclude_filter, str(config.get_value("export", "steam_only_filter", "")))
			presets.set_value(section, "include_filter", include_filter)
			presets.set_value(section, "exclude_filter", exclude_filter)
			var path := "build/%s/%s/%s.%s" % [platform_info[2], channel, executable, platform_info[3]]
			presets.set_value(section, "export_path", path)
			_set_default(presets, section, "script_export_mode", 2)
			_set_default(presets, section, "encrypt_pck", false)
			_set_default(presets, section, "encrypt_directory", false)
			_set_default(presets, options, "binary_format/architecture", "universal" if macos else "x86_64")
			_set_default(presets, options, "texture_format/s3tc_bptc", true)
			presets.set_value(options, "texture_format/etc2_astc", macos)
			if windows:
				presets.set_value(options, "application/product_name", name)
				presets.set_value(options, "application/file_description", name)
				presets.set_value(options, "application/file_version", version)
				presets.set_value(options, "application/product_version", version)
				_set_default(presets, options, "binary_format/embed_pck", false)
				_set_default(presets, options, "codesign/enable", false)
				_set_default(presets, options, "debug/export_console_wrapper", 1)
			elif macos:
				presets.set_value(options, "application/bundle_identifier", bundle)
				presets.set_value(options, "application/short_version", version)
				presets.set_value(options, "application/version", version)
				_set_default(presets, options, "codesign/codesign", 1)
				_set_default(presets, options, "notarization/notarization", 0)
			else:
				_set_default(presets, options, "binary_format/embed_pck", false)
			DirAccess.make_dir_recursive_absolute("res://" + path.get_base_dir())
			index += 1
	if ProjectSettings.save() != OK or presets.save("res://export_presets.cfg") != OK:
		_fail("Could not save project settings or presets; inspect both files")
		return
	print("CONFIGURE: %s %s; %d PC presets; UI translations registered; existing input and signing options preserved" % [name, version, index])
	quit(0)

func _set_default(file: ConfigFile, section: String, key: String, value: Variant) -> void:
	if not file.has_section_key(section, key):
		file.set_value(section, key, value)

func _append_filter(base: String, extra: String) -> String:
	var parts := PackedStringArray()
	for source in [base, extra]:
		for token in str(source).split(",", false):
			var trimmed := token.strip_edges()
			if not trimmed.is_empty() and not trimmed in parts:
				parts.append(trimmed)
	return ",".join(parts)

func _safe_relative_directory(value: String) -> bool:
	if value.is_empty() or value.is_absolute_path() or value.contains("\\") or value.contains(":"):
		return false
	for part in value.split("/"):
		if part in ["", ".", ".."] or part.ends_with(".") or part.ends_with(" "):
			return false
		for invalid in ["<", ">", ":", "\"", "|", "?", "*"]:
			if part.contains(invalid):
				return false
		if _windows_reserved(part):
			return false
	return true

func _identifier(value: String, bundle: bool) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9][A-Za-z0-9.-]*$" if bundle else "^[A-Za-z0-9][A-Za-z0-9_-]*$")
	if regex.search(value) == null or _windows_reserved(value):
		return false
	if bundle:
		if not value.contains("."):
			return false
		for part in value.split("."):
			if part.is_empty() or part.begins_with("-"):
				return false
	return true

func _windows_reserved(value: String) -> bool:
	var part := value.get_slice(".", 0).to_upper()
	return part in ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
