## 종료 확인과 저장 실패 선택지를 보여 주는 앱 수명 대화상자다. App이 기본 인스턴스를 소유한다.
class_name QuitDialogs
extends Node

const PAUSE_REASON := "quit_dialog"
var _confirm := ConfirmationDialog.new()
var _failure := AcceptDialog.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm.title = "UI_QUIT_TITLE"
	_confirm.dialog_text = "UI_QUIT_TEXT"
	_confirm.ok_button_text = "UI_QUIT_SAVE"
	_confirm.cancel_button_text = "UI_CANCEL"
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.canceled.connect(func(): _on_canceled(_confirm))
	add_child(_confirm)
	_failure.title = "UI_SAVE_FAILED_TITLE"
	_failure.ok_button_text = "UI_STAY"
	_failure.add_button("UI_RETRY", false, "retry")
	_failure.add_button("UI_QUIT_WITHOUT_SAVING", false, "discard")
	_failure.confirmed.connect(_release)
	_failure.canceled.connect(func(): _on_canceled(_failure))
	_failure.custom_action.connect(_on_failure_action)
	add_child(_failure)

## 저장 후 종료할지 묻는다. 이미 종료·저장 실패 대화상자가 열려 있으면 중복으로 띄우지 않는다.
func confirm_quit() -> void:
	InputManager.cancel_capture()
	if is_open():
		return
	App.set_paused(PAUSE_REASON, true)
	_confirm.popup_centered(Vector2i(420, 160))

## 저장 실패를 알리고 머무르기·재시도·저장 없이 종료 중 하나를 선택받는다.
func show_save_failure(error: int) -> void:
	InputManager.cancel_capture()
	if _confirm.visible:
		_confirm.hide()
	App.set_paused(PAUSE_REASON, true)
	_failure.dialog_text = tr("UI_SAVE_FAILED_TEXT") % error_string(error)
	_failure.popup_centered(Vector2i(480, 200))

## 종료 확인 또는 저장 실패 대화상자가 열려 있는지 반환한다.
func is_open() -> bool:
	return _confirm.visible or _failure.visible

func _on_confirmed() -> void:
	# 게임이 quit_failed를 직접 처리하면 실패 대화상자가 열리지 않으므로 pause 이유를 여기서 해제한다.
	if App.request_quit() != OK and not _failure.visible:
		_release()

func _on_failure_action(action: StringName) -> void:
	_failure.hide()
	if action == &"retry":
		if App.request_quit() != OK and not _failure.visible:
			_release()
	elif action == &"discard":
		App.quit_without_saving()

func _on_canceled(dialog: AcceptDialog) -> void:
	dialog.hide()
	_release()

func _release() -> void:
	if not is_open():
		App.set_paused(PAUSE_REASON, false)
