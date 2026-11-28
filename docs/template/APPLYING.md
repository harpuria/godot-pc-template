# 템플릿 적용 절차

PC 템플릿으로 새 게임을 시작하거나, 기존 게임에 가져오거나, 이후 템플릿 버전을 반영할 때 쓰는 절차다. 게임의 설계·검증 문서는 게임의 `docs/`에 쓰고, 이 폴더(`docs/template/`)는 템플릿 출처 기록으로 유지한다.

템플릿 저장소: <https://github.com/harpuria/godot-pc-template>

## 1. 새 게임 만들기

GitHub에서 템플릿 저장소의 **Use this template → Create a new repository**를 누른다. 템플릿의 커밋 기록 없이 새 저장소가 만들어진다. 그 저장소를 clone한 뒤 [3. 게임 설정](#3-게임-설정)으로 간다.

GitHub 템플릿 기능을 쓰지 않는다면 clone한 뒤 기록을 새로 시작한다.

```bash
git clone https://github.com/harpuria/godot-pc-template.git my-game
cd my-game
git rev-parse HEAD        # 출처 기록용으로 적어 둔다
rm -rf .git
git init
```

## 2. 기존 게임에 가져오기

템플릿을 임시 폴더에 받은 뒤, 기존 파일을 덮어쓰지 않도록 복사하고 겹치는 파일은 직접 병합한다. 기존 `.git`, remote, 게임 코드와 설정은 보존된다.

```bash
git clone https://github.com/harpuria/godot-pc-template.git /tmp/godot-pc-template
rsync -a --ignore-existing --exclude .git --exclude .godot --exclude build --exclude dist \
  /tmp/godot-pc-template/ /path/to/existing-game/
```

| 파일 / 경로 | 처리 |
| --- | --- |
| `autoload/`, `core/`, `services/`, `tools/` | 공통 프레임워크로 유지 |
| `.codex/config.toml`, `.mcp.json` | 새 게임은 프로젝트 단위 Godot AI 연결을 상속한다. 기존 게임은 사용하는 MCP 항목을 보존하고 필요한 항목만 병합한다. [연결 및 교체](../../README.md#ai-클라이언트-연결-및-교체) |
| `addons/godot_ai/` | 기본 활성화된 에디터 MCP 플러그인(export 제외). 버전 업그레이드는 파일을 덮어쓰지 않고 에디터 **Godot AI** 독의 **Update**를 사용한 뒤 위의 프로젝트 연결 설정도 새 버전에 맞춘다 |
| `ui/` (`menus`, `dialogs`, `settings`, `loading`, `theme`, `i18n`) | 공통 UI로 유지. Theme과 `ui/i18n/ui.csv`의 문구·언어 열은 게임에 맞게 수정해도 된다 |
| `scenes/bootstrap.*` | 진입점으로 유지; 게임 초기화는 hook에서 |
| `scenes/main.tscn`, `scenes/demo.gd`, `scenes/transition_demo.*`, `assets/demo/` | 예제·회귀 검사용으로 유지; 배포에서는 `exclude_demo=true`로 제외 |
| `tests/`, `tools/validate.sh` | 공통 회귀 검사로 유지; 게임 검사는 별도로 둔다 |
| `game/` | 새 게임은 골격(`main.tscn`, `game_init.gd`)에서 시작. 기존 게임은 자기 파일을 유지한다 |
| `project.godot`, `export_presets.cfg`, `default_bus_layout.tres` | 기존 프로젝트는 Autoload·입력·renderer·theme·preset·오디오 버스를 직접 병합 |
| `config/game.cfg` | 게임 값으로 수정 |
| `AGENTS.md` / `CLAUDE.md` | 공통 작업 규칙을 게임 지침에 병합 / `@AGENTS.md` import 유지 |
| `README.md` | 게임 소개로 바꿔도 된다. BOM과 문서 링크는 유지 |
| `docs/*.md`, `docs/distribution/` | 프레임워크 문서와 SteamPipe 예시로 유지 |
| `docs/template/` | 템플릿 출처·변경·검증 기록으로 유지 |
| `third_party/`, `.github/`, `.gitignore`, `.gitattributes`, `.editorconfig`, `.godot-version` | 배포 고지·CI·cache/secret 제외·버전 기준으로 유지 |

템플릿 전체 복사는 기존 게임의 자동 migration이 아니다. 일부 기능만 가져오면 기존 API와 초기화 순서에 맞게 연결하고 적용 범위를 기록한다.

## 3. 게임 설정

1. `config/game.cfg`의 `[app]`에서 게임 이름, 숫자 version, 고정 `data_directory`, `executable_name`, 고유 `macos_bundle`을 바꾸고 `main_scene="res://game/main.tscn"`으로 지정한다.
2. 저장 구조·게임 입력 action은 `game/game_init.gd`에서 등록한다([자주 하는 작업](../HOWTO.md)).
3. 스토어 기능을 쓰지 않으면 `store_enabled=false`, 실제 Steam은 검증한 Adapter와 `mode="native"`로 연결한다([Steam 안내](../STEAM.md)).
4. 출시 준비가 되면 `[export] exclude_demo=true`로 두고, JSON·CSV 같은 추가 파일은 `extra_include_filter`로 지정한다.
5. import로 클래스와 자산을 등록한 뒤 configure를 실행한다. 결과 diff에서 게임이 수정한 Input Map과 기존 서명·SDK 옵션이 유지되었는지 확인한다.

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/configure.gd
```

## 4. 출처 기록

게임 `AGENTS.md`의 프로젝트 정보에 다음 형태로 남긴다.

```text
Template: godot-pc-template 0.1.0, source https://github.com/harpuria/godot-pc-template,
tag <tag or none>, commit <git rev-parse HEAD 결과>, applied <YYYY-MM-DD>.
```

일부 파일을 제외하거나 의도적으로 바꿨다면 적용 범위도 함께 적는다.

## 5. 검증

[코드 안내서의 변경 후 검증](../CODEBASE_MAP.md#변경-후-검증)을 실행하고, F5로 게임의 `main_scene`과 init hook 진입을 확인한다. 공통 검사는 `init_script`의 계약 통과 여부를 확인한 뒤 자체 기준값으로 프레임워크 계약을 검증하므로, 게임 `config/game.cfg`와 `game/game_init.gd`를 바꾼 뒤에도 `scenes/`와 `assets/demo/`를 유지하면 그대로 실행할 수 있다. 게임 고유 규칙·ID 검사는 별도로 추가한다.

Windows/macOS export·서명·실행·스토어 기능의 실제 결과는 게임의 `docs/VALIDATION.md` 등에 기록한다. 템플릿의 검증 결과를 게임의 실행 파일 검증으로 재사용하지 않는다.

## 템플릿 버전 업데이트

1. 현재 버전과 목표 버전 사이의 [CHANGELOG](CHANGELOG.md)를 읽는다. "기존 게임 적용" 항목의 변경을 확인한다.
2. 템플릿 저장소에서 두 tag/commit을 비교하여 공통 파일 변경만 확인한다(`git diff <old> <new> -- addons/godot_ai autoload core services ui tools scenes tests`).
3. 게임의 `game/`, 게임 config, 사용자 데이터와 게임 문서를 보존하며 프레임워크 변경을 병합한다. config에는 새 키만 추가한다.
4. configure와 영향받는 공통·게임 검사를 실행한다.
5. 출처의 버전·tag·commit·적용일을 갱신한다.
