## 공통 입력의 최초 바인딩과 입력 이벤트 생성 함수를 제공한다. configure는 게임이 수정한 action을 보존한다.
class_name DefaultInput
extends RefCounted

## 기본 게임 action과 키보드·마우스·게임패드 입력을 반환한다.
static func actions() -> Dictionary:
	return {
		&"move_left": [key(KEY_A), key(KEY_LEFT), axis(JOY_AXIS_LEFT_X, -1.0), button(JOY_BUTTON_DPAD_LEFT)],
		&"move_right": [key(KEY_D), key(KEY_RIGHT), axis(JOY_AXIS_LEFT_X, 1.0), button(JOY_BUTTON_DPAD_RIGHT)],
		&"move_up": [key(KEY_W), key(KEY_UP), axis(JOY_AXIS_LEFT_Y, -1.0), button(JOY_BUTTON_DPAD_UP)],
		&"move_down": [key(KEY_S), key(KEY_DOWN), axis(JOY_AXIS_LEFT_Y, 1.0), button(JOY_BUTTON_DPAD_DOWN)],
		&"primary_action": [key(KEY_SPACE), mouse(MOUSE_BUTTON_LEFT), button(JOY_BUTTON_A)],
		&"pause": [key(KEY_ESCAPE), button(JOY_BUTTON_START)],
		&"toggle_fullscreen": [key(KEY_F11), key(KEY_ENTER, true)]
	}

## 물리 키 위치 기준의 키보드 입력을 만든다.
static func key(code: Key, alt: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.alt_pressed = alt
	return event

## 마우스 버튼 입력을 만든다.
static func mouse(index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	return event

## 모든 컨트롤러에서 받는 게임패드 버튼 입력을 만든다.
static func button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = index
	return event

## 모든 컨트롤러에서 받는 게임패드 축 방향 입력을 만든다.
static func axis(index: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = index
	event.axis_value = value
	return event
