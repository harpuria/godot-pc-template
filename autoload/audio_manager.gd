## BGM, SFX, UI 버스와 재생기를 관리하며 사용자 볼륨을 적용한다.
extends Node

var bgm := AudioStreamPlayer.new()
var effect_players: Array[AudioStreamPlayer] = []
var _suspended := false
var _ui_suspended := false
const MAX_EFFECTS = 16

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["BGM", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	bgm.bus = "BGM"
	add_child(bgm)
	Settings.changed.connect(_apply_setting)
	for bus in ["master", "bgm", "sfx", "ui"]:
		_apply_setting(bus + "_volume", Settings.get_setting(bus + "_volume", 0.8))

## 전달받은 BGM 스트림을 재생한다. 이미 같은 스트림이 재생(또는 일시 정지 유지) 중이면 restart가 true일 때만 처음부터 다시 시작한다.
func play_bgm(stream: AudioStream, restart: bool = false) -> void:
	if stream == null:
		return
	var active := bgm.playing or (bgm.stream_paused and bgm.has_stream_playback())
	if bgm.stream == stream and active and not restart:
		bgm.stream_paused = _suspended
		return
	bgm.stream = stream
	bgm.play()
	bgm.stream_paused = _suspended

## 현재 배경 음악 재생을 중단한다.
func stop_bgm() -> void:
	bgm.stop()

## 동시 재생 수를 제한한 SFX를 재생한다.
func play_sfx(stream: AudioStream) -> void:
	_play_effect(stream, "SFX")

## UI 전용 버스로 효과음을 재생한다.
func play_ui(stream: AudioStream) -> void:
	_play_effect(stream, "UI")

func _play_effect(stream: AudioStream, bus: String) -> void:
	if stream == null or _bus_player_count(bus) >= MAX_EFFECTS:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	effect_players.append(player)
	add_child(player)
	player.finished.connect(func():
		effect_players.erase(player)
		player.queue_free())
	player.play()
	player.stream_paused = _ui_suspended if bus == "UI" else _suspended

func _bus_player_count(bus: String) -> int:
	var target := StringName(bus)
	var count := 0
	for player in effect_players:
		if player.bus == target:
			count += 1
	return count

func _apply_setting(key: String, value: Variant) -> void:
	var bus_key := key.trim_suffix("_volume")
	var bus := "Master" if bus_key == "master" else bus_key.to_upper()
	var index := AudioServer.get_bus_index(bus)
	if key.ends_with("_volume") and index >= 0:
		var volume := clampf(float(value), 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, volume == 0.0)

## 슬라이더 드래그 중 디스크 저장 전에 오디오 버스 음량만 즉시 반영한다.
func preview_volume(key: String, value: float) -> void:
	_apply_setting(key, value)

## 재생 위치를 유지한 채 오디오를 일시 정지한다. 메뉴 pause처럼 UI 효과음을 남길 때는 include_ui를 false로 둔다.
func set_suspended(suspended: bool, include_ui: bool = true) -> void:
	_suspended = suspended
	_ui_suspended = suspended and include_ui
	bgm.stream_paused = _suspended
	for player in effect_players:
		player.stream_paused = _ui_suspended if player.bus == &"UI" else _suspended
