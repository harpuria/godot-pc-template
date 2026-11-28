# Architecture — PC Template 0.1.0

## 레이어와 책임

```text
Game (game/)
  ├─ 공통 Autoload: SaveManager, Settings, AudioManager, WindowManager,
  │                InputManager, SceneManager, App
  ├─ 재사용 UI: PauseMenu, SettingsPanel, App.dialogs (QuitDialogs)
  └─ App.store (StoreService)
       └─ StoreAdapter / Debug Mock / 게임이 등록한 선택적 SDK Adapter
            └─ Steam 등 외부 Plugin / Native SDK
```

게임 규칙·보상·저장 schema는 `game/` 소유다. App은 구성과 앱 수명만 관리한다. 스토어(ESD) 연결은 Adapter가 담당하며 게임에서 네이티브 singleton을 직접 호출하지 않는다. itch.io와 standalone은 SDK 없이 실행한다.

## 초기화와 수명

Autoload 순서는 [CODEBASE_MAP](CODEBASE_MAP.md)의 실행 흐름을 따른다. bootstrap은 `app/init_script`(기본 `game/game_init.gd`) hook을 App 초기화 전에 실행한다. hook은 저장 schema·migration, 재설정할 게임 입력 action, 검증한 스토어 Adapter를 등록한다.

hook 계약:

- `RefCounted`를 상속하고, 필수 인수 없는 생성자와 인수 없는 동기 `before_app_initialize() -> Dictionary`를 둔다.
- 성공 결과는 `{"error": OK}`, 실패는 `{"error": ERR_...}`다.
- 서명 오류, 결과 누락, 명시적 실패, 런타임 오류는 App 초기화·저장 읽기·게임 진입을 차단한다. 이때 bootstrap은 화면에 오류 문구를 표시하고 창 닫기는 허용한다.
- 반환형을 `Dictionary`로 정한 이유: `int`/`Error` 반환형은 런타임 오류 시 기본값 `0`이 `OK`와 같아 실패를 성공으로 오인할 수 있다.

`App.initialize()`는 한 번만 수행한다. 서비스 feature가 꺼져 있으면 SDK 초기화를 생략한다. Debug의 명시적 `mode=mock`은 Mock, `mode=native`와 init hook에서 등록한 Adapter 조합은 실제 연결을 선택한다(Steam 등 배포 채널 분기는 init hook에서 결정한다). 나머지는 unavailable이며 게임 로컬 기능을 계속 사용할 수 있다. release에서는 Mock을 선택하거나 초기화하지 않는다.

공통 관리자는 앱 수명이다. 장면 이동 뒤에도 살아 있으며 SceneManager는 전환 중복을 `ERR_BUSY`로 거절한다. 로딩 화면을 그릴 두 프레임 뒤에 메인 스레드에서 장면을 읽는다. 첫 장면이 로딩 중 실패하면 bootstrap이 장면 경로와 함께 시작 실패 문구를 표시한다. 대형 리소스의 streaming은 별도 구현 범위다.

## 저장 데이터와 설정

- SaveManager: `user://saves/slot_1.json`의 `{version, data}` envelope, dirty 자동 저장과 순차 migration. JSON 호환 게임 데이터만 저장한다.
- Settings: `user://settings.cfg`의 음량·언어·화면 옵션과 게임별 추가 설정.
- InputManager: `user://input.cfg`의 입력 종류와 숫자 필드. arbitrary Object를 역직렬화하지 않는다.
- JsonStore: 디렉터리 생성 → 같은 디렉터리의 `.tmp` 기록·flush → rename 교체. Windows의 rename은 기존 파일을 지운 뒤 이동하므로, 원본이 없고 유효한 완성 `.tmp`만 남아 있으면 SaveManager·Settings·InputManager 모두 먼저 rename으로 원본 경로에 무손실 승격한 뒤 필요할 때만(예: 저장 migration) 새 `.tmp`를 기록한다. 원본 없이 미완성 첫 쓰기 `.tmp`(빈 파일·불완전 값)만 남은 경우에는 쓰기를 차단하지 않고 새 사용자로 시작한다.

저장 migration 함수는 다음 버전의 데이터를 `Dictionary`로 반환한다. 데이터를 모두 비우려면 인수로 받은 사본에 `clear()`를 호출하고 그 사본을 반환한다. GDScript의 런타임 오류도 새 빈 Dictionary를 반환할 수 있으므로 `return {}`는 `ERR_INVALID_DATA`로 처리한다. 모든 단계가 끝난 뒤에만 메모리와 파일에 결과를 반영한다.

진행 저장의 parse·schema·migration 실패는 메모리와 원본을 보존하고 이후 쓰기를 차단한다. 미래 버전·분수 version도 거절한다. 정상 load(migration 시 즉시 재기록) 또는 사용자 선택 이후 `reset_slot()`로 차단을 해제한다. 설정과 바인딩도 원본 손상 시 교체를 차단하고 명시적 reset을 제공하며, reset 시 디스크 기록이 실패하면 이전 메모리 상태와 차단 여부를 유지한다.

Settings는 파일의 모든 값을 먼저 검증한다. 알려진 키의 타입·범위가 잘못되면 파일과 현재 메모리를 보존하고 변경 신호 없이 쓰기를 차단한다. `set_many()`도 디스크 저장 성공 후에만 메모리·locale·`changed`를 반영하여 실패한 후보가 활성 설정으로 남지 않는다.

임시 파일 교체는 불완전한 쓰기를 줄이는 장치다. 여러 프로세스 동시 실행, 전원 차단의 완전한 복구, 암호화, 다중 슬롯, 서버 동기화, Steam 계정별 저장 분리는 제공하지 않는다. 게임이 이 요구를 가지면 별도 정책을 정의한다. 기본 autosave 30초 타이머는 `App.initialize()` 이후 시작되며 pause와 정상 종료 때 dirty 값을 flush한다.

`app/data_directory`로 안정된 저장 위치를 사용한다. 표시 이름을 바꿔도 이 값은 유지한다. 기본 저장 형식은 양 OS가 공유할 수 있지만 Cloud 설정과 충돌 처리는 자동 구현이 아니다.

## 화면 설정과 입력

WindowManager는 windowed / borderless / exclusive fullscreen, 창 크기, VSync, FPS 제한을 담당한다. 후보는 저장 전에 적용하고 15초 뒤 자동 복구한다. 단축키 전환(`toggle_fullscreen()`, F11 / Alt+Enter)은 모니터 해상도를 바꾸지 않는 창 ↔ 테두리 없는 전체 화면 전환이므로 확인창 없이 Settings에 저장한 뒤 적용하고, 저장에 실패하면 화면을 바꾸지 않고 오류를 반환한다. VSync·FPS만 바꿀 때는 창 위치를 다시 중앙으로 옮기지 않고, 전체 화면에서 창 모드로 돌아오면 이전 창 위치를 복원한다. 앱 수명의 확인창을 사용하므로 게임 장면과 독립적으로 확인할 수 있다. 확인 시 Settings 저장이 실패하면 이전 값으로 복구하고 `preview_failed(error)`를 보낸다. SettingsPanel은 `Settings.changed`로 외부 변경을 동기화하고, 사용자 지정 창 크기·FPS 항목을 단일 항목으로 유지하며, 음량 슬라이더 드래그 중에는 오디오 버스만 먼저 반영한 뒤 드래그 종료 시 디스크에 기록한다. 창 모드 사용자 resize는 0.5초 뒤 기록하되, 사용 가능 화면 영역(`usable`)에 맞춰 클램핑된 크기로는 저장된 `window_size`를 덮어쓰지 않는다. 화면 설정은 모니터·OS가 실제 지원하는 범위에 제약을 받는다.

InputManager는 공통 action(`COMMON_ACTIONS`)과 게임이 `register_action()`으로 등록한 action을 재설정·저장한다. 기본 바인딩은 Input Map(Project Settings)이 기준이고, 없는 action은 등록 시 넘긴 기본값으로 만든다. configure는 기존 action의 바인딩을 덮어쓰지 않되 `controller_deadzone`이 바뀌면 기본 action의 deadzone을 갱신한다. 또한 `ui_accept`·`ui_cancel`에 게임패드 A/B 버튼이 없으면 시작 시 보강하여 패드만으로 메뉴·목록·대화상자를 조작할 수 있게 한다(`ScrollContainer`는 `follow_focus`를 켠다).

- 바인딩은 장치 종류(`keyboard_mouse` / `controller`)마다 칸으로 다룬다. `rebind(action, event, slot)`은 그 장치 종류의 slot번째 입력만 교체하고 다른 칸·다른 장치 종류는 유지한다. `clear_slot(action, category, slot)`은 지정 칸을 비우되 action의 마지막 남은 입력이나 `pause`의 유일한 키보드 입력은 지우지 않는다. 설정 UI는 주(0)·보조(1) 변경과 장치 종류별 보조 비우기 버튼 두 개를 제공한다. 키보드 입력은 `physical_keycode`가 있으면 물리 위치를 기준으로 정규화(`keycode=0`)하여 저장·비교하고, 창 환경에서는 현재 키보드 배열의 키 이름으로 표시한다.
- 같은 장치 종류에서 다른 action이나 같은 action의 다른 칸이 쓰는 입력은 `ERR_ALREADY_IN_USE`로 거절한다. `ui_*` action은 등록·재설정 대상이 아니다.
- 입력이 없는 action은 빈 배열로 저장·복원한다. 파일에 있지만 아직 등록되지 않은 action의 바인딩은 보존했다가 등록 시 적용한다. 손상된 파일은 `load_failed`를 보내고 쓰기를 차단한다.
- 컨트롤 표시 아이콘과 로컬 다인 입력의 장치 배정은 게임이 추가한다. 게임패드 이벤트는 `device=-1`로 모든 컨트롤러를 받는다.

캡처 중 Ctrl·Shift·Alt·Meta 단독 press/release는 소비하고 다음 조합 키를 기다린다. 수정키 단독 바인딩은 캡처 UI에서 제공하지 않는다. Escape는 캡처를 취소하지만, `pause` action 캡처 중 다른 칸에 Escape가 없을 때는 수정키 없는 단독 Escape로 다시 할당할 수 있다. 장면 전환·포커스 상실·화면 미리보기 확인·종료 대화상자 표시 시 진행 중인 캡처는 자동 취소된다.

## 공통 UI 문구

PauseMenu, SettingsPanel, QuitDialogs, 화면 확인창, 로딩·시작 실패 문구는 `ui/i18n/ui.csv`의 `UI_*` 번역 키를 쓴다(English / 한국어). Control의 자동 번역과 `tr()`을 사용하므로 `Settings`의 `language`를 바꾸면 열린 UI도 바로 바뀐다. 새 사용자의 초기 언어는 `OS.get_locale()`과 등록된 번역을 비교해 지역·스크립트가 가장 잘 맞는 로케일을 고르고, 일치하는 번역이 없으면 프로젝트 fallback 로케일을 선택한다. configure가 두 번역 파일을 Project Settings에 등록하며 게임이 추가한 번역은 유지한다. 설정 패널의 언어 목록은 불러온 번역 리소스 전체를 순회해 각 언어의 `UI_LANGUAGE_NAME`을 표시한다. action 이름은 `UI_ACTION_<ACTION>` 키가 있으면 번역하고 없으면 이름을 읽기 쉽게 바꿔 표시한다.

## Pause·포커스·종료

App은 reason 집합으로 `menu`, `focus`, `overlay`, `quit_dialog` 등을 독립적으로 관리한다. 하나라도 있으면 SceneTree를 pause하고 마지막 이유를 해제할 때 재개한다. 이유가 바뀔 때마다 `pause_reason_changed(reason, active)`를 보낸다. 외부 코드가 먼저 pause한 트리는 App이 재개하지 않는다. 공통 관리자·서비스와 조작할 메뉴는 `PROCESS_MODE_ALWAYS`로 동작한다.

`PauseMenu`는 `menu` 이유를 켜고 끄며, 다른 코드가 `menu` 이유를 바꿔도 표시 상태를 맞춘다. 메뉴가 열려 있을 때는 `pause` action뿐 아니라 `ui_cancel`(게임패드 B 등)로도 설정 화면과 메뉴를 닫을 수 있다. 열린 상태로 트리에서 제거되면(예: 장면 전환) 자신이 활성화한 `menu` 이유를 해제한다. 장면 전환·입력 캡처·화면 미리보기·종료 대화상자가 열려 있는 동안에는 pause action을 처리하지 않는다.

포커스 상실 시 저장한다. `pause_on_focus_loss`는 시뮬레이션 정지, `mute_on_focus_loss`는 전체 오디오(`BGM`·`SFX`·`UI`) 정지를 독립적으로 결정한다. `menu`·`overlay`·`quit_dialog` 등 focus 외 pause는 `BGM`·`SFX`만 정지하고 메뉴 조작을 위한 `UI` 효과음은 유지한다(`SFX`와 `UI` 동시 재생 한도도 분리한다). 포커스 복귀는 다른 pause나 그 오디오 정지를 해제하지 않는다. SDK overlay callback도 별도 이유로 전달한다. AudioManager는 suspend 상태를 보관하여 이후 시작·재시작하는 재생기에도 적용하고, 해제 시 재생을 재개한다. 같은 BGM 스트림이 이미 재생 중이거나 일시 정지 상태로 유지 중이면 `play_bgm(stream, true)`일 때만 처음부터 다시 시작한다.

창 닫기 흐름:

1. `App.quit_requested`를 구독한 게임 UI가 있으면 그 UI가 처리한다(보통 `App.dialogs.confirm_quit()`). 없으면 App이 바로 저장 후 종료한다. 이미 종료 확인이나 저장 실패 창이 열려 있으면 중복 확인창을 띄우지 않는다.
2. `request_quit()`의 저장이 실패하면 종료를 보류하고 `quit_failed(error)`를 보낸다. 구독자가 없으면 `App.dialogs`가 머무르기·재시도·저장 없이 종료를 묻고, 구독자가 있으면(재시도 실패 포함) `quit_dialog` pause를 해제한다. 따라서 게임이 아무것도 연결하지 않아도 창 닫기가 무반응으로 끝나지 않는다.
3. 저장 없이 종료(`quit_without_saving()`)는 사용자가 명시적으로 선택한 경우에만 호출한다.
4. App 초기화 전이나 init hook 실패 후에는 저장할 진행이 없으므로 창 닫기를 바로 허용한다.

OS 강제 종료와 프로세스 중단에서 마지막 flush는 보장하지 않는다.

## 선택적 ESD 요청

StoreService는 논리 업적·리더보드 ID를 변환하고 유한 대기열(`MAX_QUEUE_SIZE`)에 넣어 한 번에 한 요청씩 직렬 처리한다(대기열 한도 초과 시 `ERR_BUSY`). 동기 반환값 OK는 요청 수락이며 실제 완료는 신호로 받는다. Adapter 결과는 request_id로 연결한다. timeout·중복·늦은 callback은 새로운 요청을 성공시키지 않는다.

Mock은 세션 메모리에서만 업적·점수를 기록한다. 실제 계정·서버·UI를 제공하지 않고 결과에 `mock=true`가 붙는다. 실제 Adapter는 인증·stats readiness·점수 정책·callback·shutdown을 SDK 계약에 맞게 구현한다. Steam Cloud, DLC, DRM, 로비·매치메이킹은 현재 API 범위 밖이다. [STEAM](STEAM.md)의 연결 절차를 따른다.
