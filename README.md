# godot-pc-template

Project: godot-pc-template  
Godot: **4.7.2 Standard**  
Language: GDScript  
Targets: Windows / macOS / Linux (Steam Deck)  
Distribution: Steam / itch.io / 단독 배포  
Template Version: **0.1.0**

PC 게임을 시작할 때 쓰는 공통 프로젝트다. 저장, 설정, 오디오, 장면 이동, 화면 옵션, 입력 재설정, pause 메뉴와 종료 확인이 들어 있다. 게임은 `game/`에 만든다.

기본 렌더러는 Compatibility이며 2D/3D 게임 모두 시작할 수 있다. 실제로 확인한 범위는 [검증 기록](docs/template/VALIDATION.md)에 있다.

## 1. 먼저 실행하기

1. [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) **Standard**를 설치한다.
2. Godot에서 **Import**를 누르고 이 폴더의 `project.godot`를 선택한다.
3. **F5**를 누른다. `PC TEMPLATE` 화면이 나오면 준비가 끝났다.

Steam 클라이언트나 외부 플러그인은 필요하지 않다.

## 2. 공통 기능 눌러 보기

화면 오른쪽 설정과 아래쪽 버튼은 스크롤하면 보인다. **Mock**은 Steam 계정·서버 없이 업적·점수 요청을 연습하는 개발용 가짜 구현이다.

| 해 볼 것 | 조작 | 결과 |
| --- | --- | --- |
| 진행 저장 | `Save test` → `Load test` | 같은 `demo_count`를 읽는다 |
| 저장 위치 확인 | `Open save folder` | 설치 폴더와 분리된 사용자 폴더가 열린다 |
| 소리 | `Play BGM`, `Play SFX`, `Play UI sound` | 버스별 재생; 오른쪽 슬라이더로 음량 조절 |
| 화면 변경 | 모드·크기·VSync·FPS 선택 → `Preview display settings`(화면 설정 미리보기) | `Keep settings`(유지)로 저장; 15초 안에 확인하지 않으면 복구 |
| 전체 화면 단축키 | `F11` 또는 `Alt+Enter` | 창 / 테두리 없는 전체 화면을 확인창 없이 바로 전환하고 저장 |
| 언어 | 설정의 `Language`(언어) 선택 | pause 메뉴·설정·대화상자 문구가 English / 한국어로 바로 바뀐다. 처음 실행은 OS 언어 |
| 입력 변경 | 오른쪽 Action 선택 → `Rebind primary` / `Rebind secondary` / 보조 비우기(`key/mouse` · `controller`) | 누른 장치 종류의 해당 칸만 교체하거나 장치별 보조 칸 해제; `Esc`로 취소 |
| 입력 복구 | `Restore default controls` | 기본 바인딩으로 돌아간다 |
| pause 메뉴 | `Esc`, 게임패드 Start 또는 `Open pause menu` | 게임이 멈추고 계속하기·설정·종료 메뉴가 열린다 |
| 종료 | `Quit` 또는 창 닫기(X) | 저장 후 종료를 확인한다. 저장 실패 시 머무르기·재시도·저장 없이 종료 선택 |
| 장면 이동 | `Scene transition` → `Back to demo` | 저장·설정·오디오 관리자가 유지된다 |
| 업적·점수 연습 | `Unlock demo achievement`, `Submit demo score` | Debug에서 `mock=true` 결과를 받는다 |

기본 입력은 WASD/방향키/왼쪽 스틱 이동, Space/마우스 왼쪽/게임패드 A 주 행동이다. UI 버튼·목록·대화상자는 방향키·Tab·게임패드(D-pad/스틱, A 선택, B 취소)로 탐색한다.

## 3. 내 게임 시작하기

1. [템플릿 적용 절차](docs/template/APPLYING.md)에 따라 새 게임 저장소를 만든다.
2. [config/game.cfg](config/game.cfg)의 `[app]` 값을 게임에 맞게 바꾼다. 첫 장면은 이미 준비된 `game/main.tscn`이다.

```ini
name="My First PC Game"
version="0.1.0"
data_directory="MyStudio/MyFirstPCGame"
executable_name="my-first-pc-game"
macos_bundle="com.mystudio.myfirstpcgame"
main_scene="res://game/main.tscn"
```

`data_directory`는 저장 위치다. 출시한 뒤에는 바꾸지 않는다. `executable_name`은 영문·숫자·하이픈·밑줄만 쓴다.

3. 프로젝트 폴더에서 설정을 프로젝트와 export preset에 반영한다. `godot`가 PATH에 없으면 macOS는 `/Applications/Godot.app/Contents/MacOS/Godot`를 쓴다.

```bash
godot --headless --path . --script res://tools/configure.gd
```

4. 프로젝트를 다시 열고 **F5**를 누른다. `game/main.tscn` 화면이 나오고 `Esc`로 pause 메뉴가 열리면 성공이다. 이제 이 장면에 게임을 만든다.

입력 action 추가, 저장 구조 변경, 번역, 아이콘 교체 같은 다음 작업은 [자주 하는 작업](docs/HOWTO.md)에 단계별로 있다.

## 4. PC 실행 파일 만들기

Godot의 **Editor → Manage Export Templates**에서 **4.7.2** templates를 설치한다. **Project → Export**에 다음 preset이 준비되어 있다.

| 배포 | Windows | macOS | Linux |
| --- | --- | --- | --- |
| 스토어 없이 단독 배포 | `Windows Standalone` | `macOS Standalone` | `Linux Standalone` |
| itch.io | `Windows Itch` | `macOS Itch` | `Linux Itch` |
| Steam | `Windows Steam` | `macOS Steam` | `Linux Steam` |

Windows는 x86_64 `.exe`와 `.pck`, macOS는 Intel/Apple Silicon 공용 Universal `.app`을 담은 ZIP, Linux는 x86_64 실행 파일과 `.pck`가 나온다. Windows·Linux는 폴더 안의 파일을 함께 전달하고, macOS는 ZIP을 풀어 `.app`을 실행한다. Steam Deck은 Linux 빌드를 그대로 실행한다.

처음 export하기 전에 [3단계의 configure](#3-내-게임-시작하기)를 한 번 실행한다. 출력 폴더(`build/...`)를 configure가 만든다.

**Steam SDK는 포함되어 있지 않다.** Steam 업적·리더보드·오버레이는 [Steam 안내](docs/STEAM.md)에 따라 연결한다. SDK 없이 만든 Release도 로컬 게임으로 정상 실행된다. macOS preset은 개발용 ad-hoc 서명이며, 공개 배포용 서명·공증은 [배포 안내](docs/DISTRIBUTION.md)를 따른다.

## 잘 안 될 때

| 문제 | 확인할 것 |
| --- | --- |
| 새 게임 대신 데모 실행 | `config/game.cfg`의 `main_scene` 경로와 장면 저장 여부 |
| 시작 화면에 "The game could not start" | `game/game_init.gd`가 `{"error": OK}`를 반환하는지, 로그의 `Game init script failed` |
| 화면 옵션이 다시 돌아옴 | 15초 안에 `Keep settings`(유지)로 확인 |
| 키 변경 실패 | 다른 action이나 같은 action의 다른 칸이 이미 그 입력을 쓰는지 확인; Esc는 취소용 |
| 앱 전환 뒤 멈춤 | 창으로 돌아오면 포커스 pause가 풀린다. pause 메뉴는 Esc/Start로 닫는다 |
| Steam 기능 `Unavailable` | SDK가 없는 Release에서는 정상. [Steam 안내](docs/STEAM.md) 확인 |
| 저장 실패·쓰기 차단 | 손상되었거나 더 새로운 버전의 저장 원본을 보호하는 상태. [저장 계약](docs/ARCHITECTURE.md#저장-데이터와-설정) 확인 |
| export 시 "export path doesn't exist" | configure를 실행하여 `build/` 출력 폴더를 만든다 |
| 실행 파일 export 실패 | 4.7.2 export templates 설치; [배포 안내](docs/DISTRIBUTION.md) 확인 |

## Dependency BOM

| 구성 | 버전 / 상태 |
| --- | --- |
| Godot / 내장 GDScript | **4.7.2** 고정, MIT |
| PC 템플릿 | **0.1.0**, 자체 GDScript, [MIT](LICENSE) |
| 외부 Godot addon / 네이티브 SDK | 없음 |
| 선택적 스토어 서비스(StoreService) / Adapter / Mock | 저장소 내 구현; Mock은 Debug 전용 |
| PC export templates | 엔진과 같은 4.7.2를 개발 환경에 설치 |
| 데모 WAV / SVG 아이콘 | 자체 생성 자산, 외부 자산 패키지 없음 |

출처와 배포 고지는 [의존성과 라이선스](docs/DEPENDENCIES.md)에 있다.

## 문서

게임을 만들 때:

- [자주 하는 작업](docs/HOWTO.md): 입력 action 추가, pause·종료, 저장 구조 변경, 번역, 아이콘 등 단계별 안내
- [개발 참고](docs/DEVELOPMENT.md): 요구 환경, 폴더 구조, 용어, `config/game.cfg` 설정 표
- [게임 폴더 안내](game/README.md) · [설계 설명](docs/ARCHITECTURE.md)
- [배포 안내](docs/DISTRIBUTION.md) · [Steam 안내](docs/STEAM.md)

템플릿 자체를 관리할 때:

- [템플릿 적용 절차](docs/template/APPLYING.md) · [변경 기록](docs/template/CHANGELOG.md) · [검증 기록](docs/template/VALIDATION.md) · [구현 기록](docs/template/IMPLEMENTATION_PLAN.md)
- [코드 안내서](docs/CODEBASE_MAP.md) · [AI 작업 규칙](AGENTS.md)
