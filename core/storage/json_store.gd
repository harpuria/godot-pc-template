## JSON 파일을 임시 파일에 기록한 뒤 교체하여 불완전한 쓰기를 줄인다.
class_name JsonStore
extends RefCounted

## 같은 디렉터리 내 rename으로 교체한다. 실패 시 기존 파일을 보존한다.
static func write(path: String, document: Dictionary) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(temp, path)

## 파싱 오류와 파일 부재를 구분해서 반환한다.
## 원본이 없고 완성된 임시 파일만 남아 있으면 그 내용을 읽고 결과에 recovered=true를 넣는다.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		# Windows의 DirAccess.rename은 기존 파일을 지운 뒤 이동한다. 그 사이에 중단되면 .tmp만 남는다.
		var recovered := _read_file(path + ".tmp") if FileAccess.file_exists(path + ".tmp") else {}
		if recovered.get("error", FAILED) == OK:
			recovered["recovered"] = true
			return recovered
		return {"error": ERR_FILE_NOT_FOUND}
	return _read_file(path)

static func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error()}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"error": read_error}
	if error != OK or not parser.data is Dictionary:
		return {"error": ERR_PARSE_ERROR}
	return {"error": OK, "document": parser.data}
