# 선택적 Steam 연결 안내

Steam 플러그인과 Steamworks SDK는 **설치되어 있지 않다**. 게임 코드는 배포 채널과 관계없이 `App.store`를 사용하고, 실제 Steam 업적·리더보드·오버레이는 아래 절차로 검증한 Adapter를 등록해야 동작한다. 등록 전에는 Debug에서 Mock, Release에서 "사용 불가"로 동작한다.

## 현재 API와 결과 의미

| API | 의미 |
| --- | --- |
| `App.store.channel` | standalone / itch / steam 배포 채널 |
| `available`, `supports(feature)` | 초기화된 Adapter와 현재 기능 지원 여부 |
| `is_mock()` | Debug 연습 결과 구분 |
| `unlock_achievement(logical_id)` | 논리 업적 해제 요청 |
| `submit_score(logical_id, score)` | 논리 리더보드에 정수 점수 제출 요청 |
| `open_overlay("achievements"/"friends")` | SDK UI 표시 요청 |
| `request_succeeded`, `request_failed` | 요청별 실제 완료·오류 |
| `overlay_changed(open)` | SDK가 전달한 overlay 열림/닫힘; App의 독립 pause 이유 |

동기 반환값 OK는 수락이다. 요청은 한 번에 하나씩 처리하고 timeout과 request_id로 연결한다. 중복·늦은 callback은 무시한다. 오버레이 요청 성공이 창 표시 완료나 사용자 행동 완료를 보장하지 않는다. Mock은 실제 overlay 창을 열지 않는다.

Debug `mode=mock`에서만 Mock이 성공한다. Release에서는 기본 Adapter가 unavailable을 반환하고 로컬 게임 기능은 계속 동작한다. itch.io/Standalone SDK 연결은 기본 API의 필수 요건이 아니다.

## 논리 ID

`config/game.cfg`의 `[store]`에서 게임이 사용하는 ID를 실제 Steamworks ID에 연결한다.

```ini
[store]
achievement_ids={"FIRST_WIN": "ACH_FIRST_WIN"}
leaderboard_ids={"BEST_SCORE": "BestScore"}
timeout_seconds=15.0
```

게임 보상·영구 진행은 SaveManager로 관리한다. Mock 업적 또는 SDK callback을 게임 진행의 유일한 근거로 사용하지 않는다. DLC·구매·DRM·멀티플레이·통계 일반화는 이 초기 API에 포함하지 않는다.

## 실제 Adapter 붙이기

1. Godot **4.7.2 Standard**, Windows x86_64, macOS universal, Linux x86_64에 맞는 플러그인과 native SDK 조합을 고른다. GodotSteam 같은 후보의 **정확한 release/tag/commit**, 라이선스, SDK 버전과 platform별 바이너리를 조사한다. 현재 선택·설치한 후보는 없다.
2. `docs/DEPENDENCIES.md`와 README BOM에 고른 조합의 정확한 버전과 호환성 근거를 기록한다.
3. `game/platform/steam_adapter.gd`가 `StoreAdapter`를 상속하여 SDK 초기화·capabilities·poll·execute·shutdown을 구현하게 한다. 여러 게임이 공유할 검증된 구현이 된 경우 `services/store/`로 옮길 수 있다.
4. 이미 있는 `game/game_init.gd`의 hook에 Steam 채널에서만 Adapter를 등록하는 코드를 추가한다(기존 등록 코드와 합친다).

```gdscript
## Steam 채널에서만 게임이 검증한 SDK Adapter를 등록한다.
extends RefCounted

func before_app_initialize() -> Dictionary:
	if GameConfig.distribution_channel() == "steam":
		var script := load("res://game/platform/steam_adapter.gd") as Script
		if script == null or not script.can_instantiate():
			return {"error": ERR_CANT_CREATE}
		var adapter := script.new() as StoreAdapter
		return {"error": App.register_store_adapter(adapter)}
	return {"error": OK}
```

5. `config/game.cfg`에서 `[services] mode="native"`를 설정한다(`init_script`는 이미 `game/game_init.gd`로 연결되어 있다). Editor에서 연결을 확인하려면 `[distribution] channel="steam"`을 사용한다. export에서는 preset feature가 우선한다.
6. `steam_only_filter`에 Steam addon 경로를 지정하고 Standalone/Itch 결과물에 SDK가 들어가지 않는지 확인한다. plugin autoload·GDExtension의 초기화도 채널을 확인하도록 구성한다.
7. 실제 계정과 배포하는 각 OS의 Debug/Release에서 초기화·콜백·오프라인·overlay·종료를 확인한다.

## Adapter 계약

`initialize()`는 현재 사용할 수 있을 때 true를 반환한다. feature off에서는 호출되지 않는다. `capabilities()`는 실제 지원 상태를 반환한다. `execute(id, operation, payload)`의 `operation`은 `achievement`, `score`, `overlay`이고 payload에는 매핑된 ID·점수·page가 전달된다.

실제 완료 시 `completed.emit(id, {"error": OK, ...})`, 실패 시 `{"error": ERR_..., "message": ...}`를 보낸다. 즉시 SDK 호출이 성공했다고 async 작업을 완료 처리하지 않는다. Service timeout 이후 도착한 OS callback을 새로운 요청 ID로 재사용하지 않는다. SDK가 callback에 ID를 주지 않으면 Adapter가 작업 handle/상태로 연결한다.

업적은 해당 SDK의 user stats 준비·set·store 완료를, 점수는 leaderboard 조회·업로드 완료와 score 범위를 구현한다. `poll(delta)`는 pause 상태에서도 실행된다. overlay callback은 `overlay_changed`로 전달하고, `shutdown()`에서 사용한 SDK 연결을 정리한다. Steam API 초기화의 App ID·Steam 실행·사용자 라이선스 요건은 [Steamworks 시작 안내](https://partner.steamgames.com/doc/sdk/api#initialization_and_shutdown)를 확인한다.

개발용 `steam_appid.txt`는 Git과 export에서 제외된다. 실제 Steam 설치본의 App ID/launch 정책은 Steamworks와 검증한 plugin 문서에 맞춘다. 로그인 정보나 Steam token을 런타임 설정에 저장하지 않는다.

## Steam Cloud

현재 저장은 로컬 JSON이며 Cloud API는 구현하지 않았다. Steam Auto-Cloud를 선택하면 SDK 없이도 지정한 저장 파일의 동기화를 구성할 수 있다. 게임별 Steamworks quota, root와 OS override를 직접 설정하고 검증한다. [Steam Cloud 문서](https://partner.steamgames.com/doc/features/cloud)

예를 들어 `app/data_directory="MyStudio/MyGame"`이면 저장 파일 위치는 다음과 같다(템플릿 기본값은 `godot-pc-template`):

| OS | 실제 저장 파일 경로 |
| --- | --- |
| Windows | `%APPDATA%/MyStudio/MyGame/saves/slot_1.json` |
| macOS | `~/Library/Application Support/MyStudio/MyGame/saves/slot_1.json` |
| Linux / Steam Deck | `~/.local/share/MyStudio/MyGame/saves/slot_1.json` |

이는 Godot의 custom user directory 설정에 따른다. `data_directory`가 달라지면 경로도 달라진다. [Godot 사용자 저장 경로](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

Auto-Cloud에서는 Windows의 AppData Roaming root에 `MyStudio/MyGame/saves`와 `*.json`을 연결하고, macOS는 같은 logical root의 override를 `MacAppSupport`에, Linux는 `LinuxXdgDataHome`에 연결한다. cross-platform 저장은 OS별 독립 root만 추가하면 자동 공유되지 않으므로 **하나의 root와 OS override**를 구성한다. 최종 설정은 실제 출력 경로와 Steamworks UI에서 확인한다. [Root Overrides](https://partner.steamgames.com/doc/features/cloud#root_overrides)

`settings.cfg`, `input.cfg`, `.tmp`는 Cloud 대상에서 제외하여 해상도·장치 설정을 PC마다 유지한다. 기본 저장은 Steam 계정별로 분리되지 않는다. 여러 계정이 같은 OS 사용자로 실행한다면 Steam user ID별 profile과 Cloud path를 게임에서 정의해야 한다. 충돌 선택, 오프라인 변경, Windows↔macOS 전환, 기존 schema migration을 검증한 뒤 Cloud 지원을 게시한다.
