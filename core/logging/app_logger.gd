## 서비스 동작을 태그와 함께 출력한다. 구매 영수증이나 개인정보는 기록하지 않는다.
class_name AppLogger
extends RefCounted

## 디버그 환경에서만 개발용 메시지를 출력한다.
static func info(tag: String, message: String) -> void:
	if OS.is_debug_build():
		print("[%s] %s" % [tag, message])
