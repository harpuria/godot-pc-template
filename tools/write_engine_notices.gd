## 현재 고정 엔진이 제공하는 Godot·제3자 라이선스 고지를 배포 리소스로 기록한다.
extends SceneTree

func _initialize() -> void:
	var version := Engine.get_version_info()
	if "%s.%s.%s" % [version.major, version.minor, version.patch] != "4.7.2":
		push_error("Generate notices with Godot 4.7.2")
		quit(1)
		return
	var license_file := FileAccess.open("res://third_party/GODOT_LICENSE.txt", FileAccess.WRITE)
	var notices := FileAccess.open("res://third_party/GODOT_THIRD_PARTY.txt", FileAccess.WRITE)
	if license_file == null or notices == null:
		push_error("Cannot write third_party notices")
		quit(1)
		return
	license_file.store_string(Engine.get_license_text() + "\n")
	var licenses := Engine.get_license_info()
	for component in Engine.get_copyright_info():
		notices.store_line(str(component.name))
		for part in component.parts:
			for copyright in part.copyright:
				notices.store_line(str(copyright))
			notices.store_line("License: " + str(part.license))
			notices.store_line("")
	for key in licenses:
		notices.store_line("----- " + str(key) + " -----")
		notices.store_line(str(licenses[key]))
		notices.store_line("")
	license_file.close()
	notices.close()
	print("NOTICES: Godot 4.7.2 license and bundled third-party licenses written")
	quit(0)
