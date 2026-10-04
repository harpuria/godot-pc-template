# godot-pc-template

Project: godot-pc-template  
Godot: **4.7.2 Standard**  
Language: GDScript  
Targets: Windows / macOS  
Distribution: Steam / itch.io / 단독 배포  
Template Version: **0.1.0**

PC 게임을 시작할 때 쓰는 공통 프로젝트다. 저장, 설정, 오디오, 장면 이동, 화면 옵션과 입력 재설정이 들어 있다. 게임은 `game/`에 만들면 된다.

모바일 템플릿과 같은 Godot 버전과 공통 관리자·문서 구조를 사용한다. 기본 렌더러는 Compatibility이며 2D/3D 게임 모두 시작할 수 있다. 실제 검증 범위는 [검증 기록](docs/template/VALIDATION.md)에 적는다.

## 1. 먼저 실행하기

1. 모바일과 동일한 [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) **Standard**를 사용한다.
2. Godot에서 **Import**를 누르고 이 폴더의 `project.godot`를 선택한다.
3. **F5**를 누른다. `PC TEMPLATE` 화면이 나오면 시작 준비가 끝났다.

Windows와 macOS에서 같은 프로젝트를 연다. 별도 Steam 클라이언트나 외부 플러그인은 필요하지 않다.

## 2. 공통 기능 눌러 보기

화면 오른쪽 설정과 아래쪽 버튼은 스크롤하면 보인다. **Mock은 실제 Steam 계정과 서버 없이 기능을 연습하는 개발용 구현**이다.

| 해 볼 것 | 조작 | 결과 |
| --- | --- | --- |
| 진행 저장 | `Save test` → `Load test` | 같은 `demo_count`를 읽는다 |
| 저장 위치 확인 | `Open save folder` | 설치 폴더와 분리된 사용자 폴더가 열린다 |
| 소리 | `Play BGM`, `Play SFX`, `Play UI sound` | 버스별 소리 재생; 오른쪽 슬라이더로 음량 조절 |
| 화면 변경 | 모드·크기·VSync·FPS 선택 → `Preview display settings` | `Keep settings`로 저장; 15초 동안 확인하지 않으면 복구 |
| 전체 화면 단축키 | `F11` 또는 `Alt+Enter` | 창 / 테두리 없는 전체 화면 전환 및 확인 |
| 입력 변경 | 오른쪽 Action 선택 → `Rebind ...` → 키·마우스·게임패드 입력 | 해당 장치 종류의 입력만 교체; `Esc`로 취소 |
| 입력 복구 | `Restore default controls` | 기본 바인딩으로 돌아간다 |
| 일시 정지 | `Esc`, 게임패드 Start 또는 `Pause / resume` | 게임을 멈추고 다시 실행한다 |
| 장면 이동 | `Scene transition` → `Back to demo` | 저장·설정·오디오 관리자가 유지된다 |
| 업적·점수 연습 | `Unlock demo achievement`, `Submit demo score` | Debug에서 `mock=true` 결과를 받는다 |

기본 입력은 WASD/방향키/왼쪽 스틱 이동, Space/마우스 왼쪽/게임패드 A 주 행동이다. UI 버튼은 방향키·Tab·게임패드로 탐색한다.

## 3. 내 게임 시작하기

1. [템플릿 적용 절차](docs/template/APPLYING.md)에 따라 새 게임 폴더에 가져온다.
2. Godot에서 장면을 만들고 `game/main.tscn`으로 저장한다. 2D나 3D 중 게임에 맞는 루트를 선택한다.
3. [config/game.cfg](config/game.cfg)의 기존 `[app]` 값을 게임에 맞게 바꾼다.

```ini
name="My First PC Game"
version="0.1.0"
data_directory="MyStudio/MyFirstPCGame"
executable_name="my-first-pc-game"
macos_bundle="com.mystudio.myfirstpcgame"
main_scene="res://game/main.tscn"
```

`data_directory`는 저장 위치다. 배포를 시작한 뒤에는 고정한다. `executable_name`은 영문·숫자·하이픈·밑줄로 지정한다.

4. 프로젝트 폴더에서 설정을 반영한다. macOS 예시:

```bash
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/configure.gd
```

`godot`가 PATH에 있다면 `rtk proxy godot ...`으로 바꾼다. RTK가 설치되지 않은 일반 개발 환경은 앞의 `rtk proxy`만 생략한다. AI에게 “config/game.cfg를 프로젝트에 반영해 줘”라고 요청해도 된다.

5. 프로젝트를 다시 열고 **F5**로 새 장면을 실행한다. 공통 API와 저장 schema 등록 예시는 [game/README.md](game/README.md)를 참고한다.

초기화 hook은 `before_app_initialize() -> Dictionary`에서 `{"error": OK}`를 명시적으로 반환한다. 이전 void hook을 가져오는 경우 [변경 기록](docs/template/CHANGELOG.md)의 계약 변경을 적용한다.

## 4. PC 실행 파일 만들기

Godot의 **Editor → Manage Export Templates**에서 **4.7.2** templates를 설치한다. **Project → Export**에 다음 preset이 준비되어 있다.

| 배포 | Windows | macOS |
| --- | --- | --- |
| ESD 없는 실행 | `Windows Standalone` | `macOS Standalone` |
| itch.io | `Windows Itch` | `macOS Itch` |
| Steam | `Windows Steam` | `macOS Steam` |

Windows는 x86_64 `.exe`와 `.pck`, macOS는 Intel/Apple Silicon용 Universal `.app`을 담은 ZIP이 기본이다. Windows 결과물은 같은 폴더의 파일을 함께 전달한다. macOS 결과물은 ZIP을 풀어 `.app`을 실행한다.

Steam·itch.io preset은 배포 채널을 구분한다. **Steam SDK는 포함되어 있지 않다.** Steam 업적·리더보드·오버레이는 검증한 Adapter를 붙인 뒤 사용한다. SDK 없는 Release도 로컬 게임으로 실행되며 Mock 성공을 반환하지 않는다.

빌드·서명·업로드 절차는 [배포 안내](docs/DISTRIBUTION.md), Steam 연결은 [Steam 안내](docs/STEAM.md)를 따른다. macOS의 현재 preset은 개발용 ad-hoc 서명이며 공개 다운로드 배포의 Developer ID 서명·공증은 별도로 설정한다. [Godot macOS 배포 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)

## 잘 안 될 때

| 문제 | 확인할 것 |
| --- | --- |
| 새 게임 대신 데모 실행 | `app/main_scene` 경로와 장면 저장 여부 |
| 화면 옵션이 다시 돌아옴 | 15초 안에 `Keep settings`로 확인 |
| 키 변경 실패 | 다른 공통 action이 같은 키를 사용하는지 확인; Esc는 취소용 |
| 앱 전환 뒤 멈춤 | 창으로 돌아오면 포커스 pause가 풀린다. 메뉴 pause는 Esc/Start로 해제 |
| Steam 기능 `Unavailable` | Release의 SDK 없는 상태에서 정상. [Steam 연결 절차](docs/STEAM.md) 확인 |
| 저장 실패·쓰기 차단 | 손상·미래 버전 원본을 보존한 상태. 게임에 복구 UI를 제공; [저장 계약](docs/ARCHITECTURE.md#저장-데이터와-설정) 확인 |
| 실행 파일 export 실패 | 4.7.2 PC export templates 설치; [배포 안내](docs/DISTRIBUTION.md) 확인 |

## Dependency BOM

| 구성 | 버전 / 상태 |
| --- | --- |
| Godot / 내장 GDScript | **4.7.2** 고정, MIT |
| PC 템플릿 | **0.1.0**, 자체 GDScript |
| 외부 Godot addon / 네이티브 SDK | 없음 |
| 선택적 ESD Service / Adapter / Mock | 저장소 내 구현; Mock은 Debug 전용 |
| PC export templates | 엔진과 같은 4.7.2를 개발 환경에 설치 |
| 데모 WAV / SVG 아이콘 | 자체 생성 자산, 외부 자산 패키지 없음 |

[의존성과 라이선스](docs/DEPENDENCIES.md)에 출처, 배포 고지와 추가 dependency 기록 방법을 적었다.

## 문서

- [개발 상세 안내](docs/DEVELOPMENT.md): 설정, API, 입력, 실행 명령
- [배포 안내](docs/DISTRIBUTION.md): Windows/macOS, Steam/itch.io/단독 배포
- [Steam 안내](docs/STEAM.md): 선택적 SDK Adapter, 업적·점수·오버레이와 Cloud
- [설계 설명](docs/ARCHITECTURE.md) · [코드 안내서](docs/CODEBASE_MAP.md)
- [템플릿 적용 절차](docs/template/APPLYING.md) · [변경 기록](docs/template/CHANGELOG.md)
- [구현 기록](docs/template/IMPLEMENTATION_PLAN.md) · [검증 기록](docs/template/VALIDATION.md)
- [AI 작업 규칙](AGENTS.md) · [게임 코드 안내](game/README.md)
