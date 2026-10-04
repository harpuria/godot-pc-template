# 템플릿 적용 절차

PC 템플릿을 새 게임·기존 게임에 가져오고 이후 버전을 갱신할 때 사용하는 문서다. 게임별 설계·검증은 `docs/`의 게임 문서에 기록하고 이 폴더는 템플릿 출처 기록으로 유지한다.

## 1. 사용할 출처 고르기

현재 이 프로젝트는 로컬 폴더에 생성했으며 원격 repository·tag·commit은 만들지 않았다. 로컬 복사 또는 실제 사용자가 준비한 repository를 출처로 삼는다. 존재하지 않는 GitHub URL이나 tag를 가정하지 않는다.

로컬 복사 예시의 `/path/to/new-game`은 새 게임 폴더로 바꾼다. Git과 Editor cache, export 결과는 복사하지 않는다.

```bash
rtk proxy rsync -a --exclude .git --exclude .godot --exclude build --exclude dist --exclude .DS_Store /Users/yhh/Workspace/godot-pc-template/ /path/to/new-game/
```

실제 원격 저장소에서 받는 경우 원하는 tag/commit을 선택하고 `rtk git rev-parse HEAD` 결과를 기록한다. 저장소 인증이 필요하면 해당 접근 권한으로 읽는다.

## 2. 새 게임과 기존 게임

새 게임은 빈 폴더에 복사한다. 기존 저장소는 `rsync`에 `--ignore-existing`을 추가하고 겹치는 파일을 직접 병합한다. 기존 `.git`, remote, 게임 코드와 기존 설정은 보존한다.

| 파일 / 경로 | 처리 |
| --- | --- |
| `autoload/`, `core/`, `services/`, `ui/`, `tools/` | 공통 프레임워크로 유지 |
| `scenes/bootstrap.*` | 진입점으로 유지; 게임 초기화는 hook |
| `scenes/main.tscn`, `scenes/demo.gd`, `scenes/transition_demo.*`, `assets/demo/` | 개발 예제·회귀용으로 유지; 게임 배포는 exclude_demo |
| `tests/` | 공통 회귀 검사 유지; 게임 검사와 분리 |
| `project.godot`, `export_presets.cfg` | 기존 Godot 프로젝트는 Autoload·입력·renderer·preset을 직접 병합 |
| `config/game.cfg` | 게임 값으로 수정 |
| `game/` | 게임 코드·리소스·schema 작성 |
| `AGENTS.md` | 공통 작업 경계와 검증 규칙을 게임 지침에 병합 |
| `CLAUDE.md` | `@AGENTS.md` import 유지; 규칙을 중복하지 않음 |
| `README.md` | 게임 소개로 교체 가능; BOM과 개발 문서 링크 유지 |
| `docs/ARCHITECTURE.md`, `CODEBASE_MAP.md`, `DEVELOPMENT.md`, `DEPENDENCIES.md`, `DISTRIBUTION.md`, `STEAM.md` | 프레임워크 문서 유지 |
| `docs/distribution/` | 실제 게임에 맞는 SteamPipe 입력 예시로 사용 |
| `docs/template/` | 템플릿 출처·변경·검증 참고로 유지 |
| `third_party/`, `.gitignore`, `.gitattributes`, `.editorconfig`, `.godot-version` | 배포 고지·cache/secret 제외·버전 기준 유지 |

템플릿 전체 복사는 기존 게임의 자동 migration이 아니다. 필요한 공통 기능만 가져오는 경우 기존 public API와 초기화 순서에 맞게 연결하고 적용 범위를 기록한다.

## 3. 게임 설정

1. `[app]`의 게임 이름·숫자 version·고정 data_directory·executable_name·고유 macos_bundle·main_scene을 바꾼다.
2. 게임별 schema가 있으면 `game/` init script와 `app/init_script`를 연결한다.
3. 사용하지 않는 store 기능은 `store_enabled=false`; 실제 Steam은 검증한 Adapter와 `mode=native`로 연결한다.
4. 게임이 완성되면 `[export] exclude_demo=true`; JSON·CSV 등 추가 자산은 include filter로 지정한다.
5. 새 복사본은 먼저 Editor import로 전역 클래스와 자산을 등록한 뒤 configure를 실행한다. 결과 diff에서 게임이 수정한 InputMap과 기존 SDK·서명 옵션을 보존했는지 확인한다.

```bash
rtk proxy godot --headless --path . --editor --import --quit
rtk proxy godot --headless --path . --script res://tools/configure.gd
```

## 4. 출처 기록

게임 `AGENTS.md`의 프로젝트 정보에 다음 형태로 남긴다.

```text
Template: godot-pc-template 0.1.0, source <local path or repository URL>,
tag <actual tag or none>, commit <actual hash or unversioned>, applied <YYYY-MM-DD>.
```

일부 파일을 제외하거나 의도적으로 바꿨다면 적용 범위도 함께 기록한다. 공개 저장소와 tag가 생기면 local path 대신 실제 URL·tag·hash를 사용한다.

## 5. 검증

[CODEBASE_MAP](../CODEBASE_MAP.md#변경-후-검증)의 import·통합·disabled·native 명령을 실행한다. F5로 실제 게임 main_scene과 hook 진입도 확인한다. 공통 검사는 데모와 기본 logical ID를 사용하는데, 게임 config를 바꾼 경우 해당 ID/Mock 가정을 맞춘 별도 검사 구성을 준비한다.

Windows/macOS export·서명·실행·스토어 기능은 게임 문서 `docs/VALIDATION.md` 등에 실제 결과를 기록한다. 템플릿의 macOS Editor 검사 결과를 자신의 게임 또는 Windows binary 검증으로 재사용하지 않는다.

## 버전 업데이트

1. 현재 버전과 목표 버전 사이 [CHANGELOG](CHANGELOG.md)을 읽는다.
2. 실제 출처의 두 tag/commit을 비교하여 공통 파일 변경만 확인한다.
3. 게임의 `game/`, 게임 config, 사용자 데이터와 게임 문서를 보존하며 프레임워크 변경을 병합한다. 새 config 키만 추가한다.
4. configure와 영향받는 공통·게임 검증을 실행한다.
5. 출처 버전·tag·hash·적용일을 갱신한다.
