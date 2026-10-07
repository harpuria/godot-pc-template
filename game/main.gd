## 게임의 첫 장면 골격이다. 이 장면에 게임을 만들기 시작한다. pause 메뉴와 창 닫기 확인이 연결되어 있다.
extends Node

func _ready() -> void:
	# Esc / 게임패드 Start로 여는 공통 pause 메뉴(계속하기·설정·종료).
	add_child(PauseMenu.new())
	# 창 닫기(X)를 누르면 저장 후 종료를 확인한다. 연결하지 않으면 확인 없이 저장 후 종료한다.
	App.quit_requested.connect(_on_quit_requested)

func _on_quit_requested() -> void:
	App.dialogs.confirm_quit()
