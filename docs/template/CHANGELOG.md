# Changelog

## 미출시 — 검증 후 보완 (2026-10-04)

- 초기화 hook을 `before_app_initialize() -> Dictionary` / `{"error": OK}` 계약으로 변경. 서명·결과·런타임 실패 시 App·저장·장면 진입 차단.
- 잘못된 설정 값의 전체 파일 검증과 원본·메모리 보호. 설정 변경은 저장 성공 후에만 반영.
- focus pause와 오디오 옵션 분리, 정지 중 새 BGM/SFX/UI에도 suspend 유지.
- Ctrl·Shift·Alt·Meta 조합 키 캡처와 저장·복원.
- 화면 확인의 저장 실패를 `preview_failed` → 설정 UI까지 전달하고 후보를 복구.
- 6건의 회귀 검사 및 실제 bootstrap 실패 주입 장면 추가.

기존 게임 hook은 void 반환형을 Dictionary로 바꾸고 끝에 `return {"error": OK}`를 추가한다. 실패 반환값도 `{"error": error}`로 전달한다. 검증 결과와 미확인 플랫폼은 [VALIDATION](VALIDATION.md)을 따른다.

## 0.1.0 — 2026-10-04

Godot **4.7.2 Standard**를 사용하는 첫 PC 공통 템플릿이다. 모바일 템플릿 0.2.0의 공통 저장·오디오·장면 구조와 문서 구성을 기반으로 한다.

- Windows x86_64 / macOS universal용 Steam·itch.io·Standalone 여섯 export preset.
- 고정 user data directory, JSON version/migration, 자동 저장과 손상·미래 schema 원본 보호.
- 별도 사용자 설정, Master/BGM/SFX/UI 버스, 장면 전환·중복 방지·로딩 화면.
- 화면 모드·창 크기·VSync·FPS와 15초 확인·자동 복구.
- 키보드·마우스·게임패드 입력, deadzone·바인딩 저장·중복 감지·재설정.
- 이유별 pause, focus/overlay lifecycle, 저장 실패 시 종료 보류.
- 선택적 StoreService/Adapter와 Debug 전용 Mock; 외부 Steam SDK 미설치.
- 게임 초기화 hook, 설정 반영·배포 필터·엔진 고지 생성 도구.
- 실행 데모, 공통 SceneTree 통합 검사, 모바일과 대응하는 설계·개발·적용·검증 문서.

### 파생 게임 적용 시 주의

표시 이름·게임 version·bundle ID·executable_name·main_scene을 바꾸고 `data_directory`는 출시 후 고정한다. 게임 schema는 init hook에 등록한다. 게임 배포에서 데모를 제외하고 실제 Windows/macOS export와 서명·ESD를 검증한다. 첫 버전은 외부 native 기능과 스토어 출시까지 확인한 상태가 아니다.

원격 repository·tag·commit 생성은 이 로컬 프로젝트 제작 범위에 포함하지 않았다.
