# PC 배포 안내

이 문서는 빌드와 배포 준비 절차다. 현재 실행한 검증 범위는 [template/VALIDATION](template/VALIDATION.md)이 기준이다. 실제 스토어 업로드·서명·공증은 게임별 계정과 식별자를 준비한 뒤 수행한다.

## 공통 설정

1. Godot **4.7.2 Standard**와 **4.7.2 PC export templates**를 준비한다. 메뉴는 **Editor → Manage Export Templates**다.
2. `config/game.cfg`의 게임 이름, 숫자 버전, 고정 저장 경로, 실행 파일 이름, macOS bundle ID와 `main_scene="res://game/main.tscn"`을 설정한다. 아이콘은 [자주 하는 작업](HOWTO.md#앱-아이콘-바꾸기)을 따른다.
3. 공개 게임 배포는 `[export] exclude_demo=true`로 두고, 게임 JSON·CSV 등의 파일은 `extra_include_filter`로 지정한다. 데모 장면·음원을 개발 저장소에서 지울 필요는 없다.
4. 설정을 반영한다.

```bash
godot --headless --path . --script res://tools/configure.gd
```

5. export된 파일로 각 OS의 새 사용자, 저장·불러오기·입력·화면 설정과 종료를 확인한다.

configure는 `build/` 아래 출력 폴더도 만든다. 새로 받은 저장소에서 configure 없이 export하면 "The given export path doesn't exist" 오류가 난다.

템플릿 기본값은 데모를 포함한 시작 프로젝트다. 실행 파일 생성 자체와 게임의 최종 출시는 별도의 완료 조건이다.

## Preset

| 이름 | feature | 기본 출력 |
| --- | --- | --- |
| Windows Standalone | standalone | `build/windows/standalone/pc-template.exe` 및 `.pck` |
| Windows Itch | itch | `build/windows/itch/pc-template.exe` 및 `.pck` |
| Windows Steam | steam | `build/windows/steam/pc-template.exe` 및 `.pck` |
| macOS Standalone | standalone | `build/macos/standalone/pc-template.zip` |
| macOS Itch | itch | `build/macos/itch/pc-template.zip` |
| macOS Steam | steam | `build/macos/steam/pc-template.zip` |
| Linux Standalone | standalone | `build/linux/standalone/pc-template.x86_64` 및 `.pck` |
| Linux Itch | itch | `build/linux/itch/pc-template.x86_64` 및 `.pck` |
| Linux Steam | steam | `build/linux/steam/pc-template.x86_64` 및 `.pck` |

`executable_name`을 바꾸면 출력 파일명도 configure가 갱신한다. Windows·Linux는 `.pck`를 별도로 두므로 폴더 전체를 배포한다. 실행 파일만 복사하지 않는다. 추가 native 라이브러리를 설치했다면 exporter가 만든 라이브러리도 함께 배포한다. [Godot Windows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)

## Windows

기본 대상은 x86_64다. Windows ARM native가 필요하면 별도 preset을 만들고 해당 엔진 template과 라이브러리 조합을 검증한다.

```bash
godot --headless --path . --export-debug "Windows Standalone"
godot --headless --path . --export-release "Windows Standalone"
godot --headless --path . --export-release "Windows Itch"
godot --headless --path . --export-release "Windows Steam"
```

Editor와 export binary는 별개다. 사용자 PC에는 Godot 설치가 필요 없다. 실제 exe의 실행·파일 경로·종료와 게임패드를 Windows 기기에서 확인한다. 최저 OS·GPU 사양은 게임과 renderer에 맞춰 정하고 실제 검증한 값만 스토어에 게시한다.

서명하지 않은 exe를 브라우저로 받으면(itch.io·단독 배포) SmartScreen이 "Windows의 PC 보호" 경고를 띄울 수 있다. 서명 전에는 게임 페이지에 실행 방법을 안내한다.

기본 `codesign/enable=false`다. 공개 배포의 Authenticode 서명은 인증서와 Windows SDK SignTool 또는 지원하는 도구를 별도로 준비하여 preset에 설정한다. 인증서와 암호는 환경변수·Godot credential 저장소를 사용하며 Git에 넣지 않는다. 정확한 설정은 [Godot Windows 서명](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html#code-signing)을 따른다.

## macOS

기본 대상은 `universal`이다. 공식 templates의 Universal 2 `.app`은 Intel x86_64와 Apple Silicon arm64를 지원한다. ZIP 출력은 앱 번들의 실행 권한을 보존하는 배포 경로다. [Godot macOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)

```bash
godot --headless --path . --export-debug "macOS Standalone"
godot --headless --path . --export-release "macOS Standalone"
godot --headless --path . --export-release "macOS Itch"
godot --headless --path . --export-release "macOS Steam"
```

기본 preset은 **Built-in ad-hoc 서명**, **공증 꺼짐**이다. 로컬 개발에 쓰는 초기값이며 공개 다운로드 배포용 Developer ID 서명·공증이 아니다. 공개 배포에서는 Apple Developer ID, 서명 도구와 notarization을 설정하고 결과를 확인한다. 인증서·토큰은 저장소 밖에 두며 native 라이브러리도 서명과 architecture 일치를 검증한다.

브라우저로 받은 ZIP(itch.io 브라우저 다운로드·단독 배포)은 quarantine 속성이 붙는다. ad-hoc 서명·미공증 앱은 Gatekeeper가 차단하고, 최근 macOS에서는 Finder의 우클릭 → 열기로도 열리지 않아 **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**를 거쳐야 한다. macOS를 공개 다운로드로 배포한다면 Developer ID 서명과 공증을 출시 조건으로 둔다.

`.app` 번들과 내부 실행 파일 이름은 `executable_name`이 아니라 `[app] name`(프로젝트 이름)을 따른다. Steam macOS launch option은 이 `.app` 이름을 가리킨다.

Godot 메뉴에서 서명 도구와 `Notarization`을 선택하고 배포 entitlement를 점검한다. 공증 완료 후 ticket stapling까지 수행한다. 전달된 ZIP을 다른 macOS 사용자 환경에서 내려받아 Gatekeeper 상태와 `.app` 실행을 확인한다. [Godot 서명·공증 절차](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html#code-signing-and-notarization)

## Linux / Steam Deck

기본 대상은 x86_64다. Steam Deck도 x86_64 Linux이므로 같은 빌드를 사용한다(Windows 빌드를 Proton으로 실행하는 방법도 있지만, Linux 빌드는 별도 호환 계층 없이 실행된다).

```bash
godot --headless --path . --export-debug "Linux Standalone"
godot --headless --path . --export-release "Linux Standalone"
godot --headless --path . --export-release "Linux Itch"
godot --headless --path . --export-release "Linux Steam"
```

Steam 배포는 Steamworks의 Linux launch option과 Linux 런타임(Steam Linux Runtime) 설정을 확인한다.

압축할 때 실행 권한이 유지되도록 `tar.gz`를 쓰거나, 받는 쪽에서 `chmod +x`가 필요할 수 있음을 안내한다. 실제 Linux 데스크톱과 Steam Deck(게임 모드·게임패드·화면 크기 1280×800)에서 실행을 확인한다. 저장 위치는 `~/.local/share/<data_directory>`다.

## 스토어 없는 단독 배포

Standalone preset의 Windows·Linux 폴더 전체 또는 macOS ZIP을 웹사이트·다운로드 링크·물리 매체로 전달한다. 게임은 StoreService의 unavailable 상태를 허용하고 로컬 저장·설정·입력으로 동작한다. 설치 위치는 쓰기 가능하지 않아도 되며 `user://`에 데이터를 기록한다.

게임 README·조작법·Godot 및 추가 라이브러리 고지를 패키지에 함께 제공한다. 자동 업데이트·설치 프로그램·DRM은 포함되어 있지 않으므로 필요할 때 게임 배포 방식에 맞게 추가한다.

## itch.io

itch.io 배포는 별도 런타임 SDK가 필요 없다. Itch preset을 사용하고 게임 페이지에서 플랫폼과 다운로드 파일을 지정한다. Windows·Linux는 export 폴더를 올리고, macOS는 기본 ZIP을 그대로 업로드할 수 있다.

butler를 사용하는 예시는 다음과 같다. `user/game`은 자신의 프로젝트로 교체한다. 이 명령은 실제 업로드하므로 배포 준비가 끝난 뒤 실행한다.

```bash
butler push build/windows/itch user/game:windows --userversion 0.1.0
butler push build/macos/itch/pc-template.zip user/game:mac --userversion 0.1.0
butler push build/linux/itch user/game:linux --userversion 0.1.0
```

`--userversion`은 `config/game.cfg`의 `[app] version`과 맞춘다. 채널 이름과 업로드 버전은 게임의 배포 정책으로 정한다. 업로드 후 itch.io 앱 설치와 브라우저 다운로드를 각각 확인한다. butler는 폴더·ZIP을 받고 채널 이름에서 OS를 판별하므로 `windows`, `mac`, `linux`처럼 플랫폼이 분명한 이름을 사용한다. [butler 업로드 문서](https://itch.io/docs/butler/pushing.html)

## Steam

Steam preset으로 export하고 Windows/macOS/Linux depot과 launch option을 Steamworks에 설정한다. Steam에서 판매·설치하는 것과 게임 내부 Steamworks API 연결은 별개의 설정이다. 업적·리더보드·overlay API가 필요할 때 [STEAM](STEAM.md)의 Adapter를 추가한다.

SteamPipe 입력 예시는 [docs/distribution/README.md](distribution/README.md)를 따른다. 각 OS 결과물을 준비하고 template의 App ID·depot ID placeholder를 실제 값으로 바꾼다. macOS ZIP은 먼저 `.app`으로 풀어 depot content root에 배치한다. native SDK를 넣었다면 해당 플랫폼 라이브러리와 배포 고지를 포함한다.

Steam Deck 호환성 검토를 받으려면 다음을 게임에서 준비한다. 템플릿은 1280×800 화면 확장, 게임패드 UI 탐색, pause·종료 흐름까지만 제공한다.

- 게임패드만으로 모든 메뉴·설정·텍스트 입력을 조작할 수 있다. 텍스트 입력이 있다면 Steam의 화상 키보드 API를 Adapter에 추가한다.
- 게임패드를 쓰는 중에는 키보드 이름 대신 컨트롤러 버튼 아이콘을 표시한다(`InputManager.device_changed`, `slot_events()` 활용).
- 1280×800에서 기본 글자가 작지 않게 Theme 글꼴 크기를 정한다.
- 별도 런처나 첫 실행 시 키보드 입력을 요구하지 않는다.

비공개 beta branch에서 설치·실행·업데이트·Cloud와 오프라인 동작을 확인한 뒤 배포 정책에 따라 게시한다. 업로드·게시를 템플릿 도구가 자동 수행하지 않는다. [SteamPipe 공식 안내](https://partner.steamgames.com/doc/sdk/uploading)

## 최종 결과물 확인

- Debug와 Release 각각을 실제 OS에서 실행한다. Release Mock은 성공할 수 없어야 한다.
- Windows exe/pck/native 라이브러리, macOS `.app` 권한·서명·공증과 Intel/Apple Silicon 지원, Linux 실행 권한과 Steam Deck 실행을 확인한다.
- 새 사용자 및 기존 저장 schema의 load·migration·종료 실패 UI를 확인한다.
- `config/game.cfg`, 게임 JSON·CSV, 음원과 엔진 고지가 포함되고 tests/tools/문서/로컬 비밀 파일은 제외되어야 한다.
- ESD API는 실제 테스트 계정으로, Cloud는 OS 간 동기화·충돌·오프라인 재접속으로 확인한다.

모든 preset은 `all_resources`를 사용한다. 게임에 불필요한 다른 자산도 자동 제거되는 것은 아니므로 `extra_exclude_filter`와 패키지 내용을 검토한다. Steam 전용 addon은 `steam_only_filter="addons/godotsteam/*"` 같은 경로로 다른 채널에서 제외하고, 해당 SDK의 전역 초기화도 Steam feature로 제한한다.
