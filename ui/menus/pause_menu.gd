## pause action으로 여는 재사용 메뉴다. 계속하기·설정·종료를 제공하고 App의 "menu" pause 이유를 관리한다.
class_name PauseMenu
extends CanvasLayer

signal opened
signal closed
signal operation_failed(error: int)
const PAUSE_REASON := "menu"
## false이면 pause action을 직접 처리하지 않는다. 게임이 open()/close()를 호출한다.
@export var handle_pause_action := true
## 종료 버튼을 표시한다. 종료는 App.dialogs의 확인창을 거친다.
@export var show_quit_button := true
var _root := Control.new()
var _settings_scroll := ScrollContainer.new()
var _resume: Button
var _open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "UI_PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	_resume = _button(layout, "UI_RESUME", close)
	_button(layout, "UI_SETTINGS", _toggle_settings)
	if show_quit_button:
		_button(layout, "UI_QUIT", App.dialogs.confirm_quit)
	_settings_scroll.custom_minimum_size = Vector2(520, 360)
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.visible = false
	layout.add_child(_settings_scroll)
	var settings := SettingsPanel.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.operation_failed.connect(func(error: int): operation_failed.emit(error))
	_settings_scroll.add_child(settings)
	App.pause_reason_changed.connect(_on_pause_reason_changed)
	_sync(App.has_pause_reason(PAUSE_REASON))

## 메뉴를 열고 게임을 멈춘다.
func open() -> void:
	App.set_paused(PAUSE_REASON, true)

## 메뉴를 닫는다. 다른 pause 이유가 남아 있으면 게임은 계속 멈춰 있다.
func close() -> void:
	App.set_paused(PAUSE_REASON, false)

## 메뉴 열림 상태를 전환한다.
func toggle() -> void:
	if _open:
		close()
	else:
		open()

## 메뉴가 열려 있는지 반환한다.
func is_open() -> bool:
	return _open

func _unhandled_input(event: InputEvent) -> void:
	if not handle_pause_action or SceneManager.transitioning or not InputManager.capturing.is_empty() \
			or App.dialogs.is_open() or WindowManager.previewing:
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		if _open and _settings_scroll.visible:
			_toggle_settings()
		else:
			toggle()
		get_viewport().set_input_as_handled()

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 36)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _toggle_settings() -> void:
	_settings_scroll.visible = not _settings_scroll.visible
	if not _settings_scroll.visible:
		_resume.grab_focus()

func _on_pause_reason_changed(reason: String, active: bool) -> void:
	if reason == PAUSE_REASON:
		_sync(active)

func _sync(active: bool) -> void:
	if active == _open:
		return
	_open = active
	_root.visible = active
	_settings_scroll.visible = false
	if active:
		_resume.grab_focus()
		opened.emit()
	else:
		closed.emit()

func _exit_tree() -> void:
	if _open and is_instance_valid(App) and App.is_inside_tree():
		_open = false
		App.set_paused(PAUSE_REASON, false)
