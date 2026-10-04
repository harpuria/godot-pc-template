## 데스크톱 OS와 창 지원 여부를 조회한다. ESD 채널은 GameConfig가 담당한다.
class_name DesktopPlatform
extends RefCounted

## 실제 운영체제 이름을 반환한다.
static func current() -> String:
	return OS.get_name()

## headless 환경에서는 창 제어를 생략한다.
static func has_window() -> bool:
	return DisplayServer.get_name() != "headless"

## 저장 파일의 실제 위치를 반환한다. 설치 디렉터리에 저장하지 않는다.
static func user_data_directory() -> String:
	return OS.get_user_data_dir()
