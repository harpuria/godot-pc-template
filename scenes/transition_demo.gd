## 공통 관리자가 장면 이동 뒤에도 유지되는 것을 보여 주는 데모 장면이다.
extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)
	var label := Label.new()
	label.text = "Scene transition complete\nSave, settings and audio remain available."
	panel.add_child(label)
	var back := Button.new()
	back.text = "Back to demo"
	back.pressed.connect(func(): SceneManager.change_scene("res://scenes/main.tscn"))
	panel.add_child(back)
	back.grab_focus()
