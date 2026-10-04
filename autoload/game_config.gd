## 공개 설정과 배포 채널을 읽는다. 비밀 키와 서명 정보는 보관하지 않는다.
extends Node

const ENGINE_VERSION := "4.7.2"
const TEMPLATE_VERSION := "0.1.0"
const CHANNELS := ["standalone", "itch", "steam"]
var config := ConfigFile.new()

func _ready() -> void:
	var error := config.load("res://config/game.cfg")
	if error != OK:
		push_error("Configuration load failed: %s" % error_string(error))

## 설정 키가 없으면 호출자가 지정한 기본값을 반환한다.
func value(section: String, key: String, fallback: Variant = null) -> Variant:
	return config.get_value(section, key, fallback)

## 기능 플래그를 조회한다. 미정의 기능은 비활성화한다.
func enabled(feature: String) -> bool:
	return bool(value("features", feature + "_enabled", false))

## SDK 기능을 대신하는 Mock은 Debug 빌드에서만 선택할 수 있다.
func use_mocks() -> bool:
	return OS.is_debug_build() and value("services", "mode", "disabled") == "mock"

## 배포 preset의 feature를 우선하고 Editor에서는 공개 설정을 사용한다.
func distribution_channel() -> String:
	for channel in CHANNELS:
		if OS.has_feature(channel):
			return channel
	var configured := str(value("distribution", "channel", "auto"))
	return configured if configured in CHANNELS else "standalone"
