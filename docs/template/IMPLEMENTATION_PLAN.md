# PC 템플릿 구현 기록

작성: 2026-10-04 · Template 0.1.0 · Godot 4.7.2 Standard.

## 목적과 기준

Windows/macOS의 여러 장르 게임을 시작하는 공통 Godot 프로젝트다. Steam·itch.io·ESD 없는 실행을 지원할 구조를 준비하고 mobile과 엔진 버전·공통 관리자·문서 구성을 맞춘다.

| 단계 | 구현 결과 |
| --- | --- |
| 모바일 조사 | 0.2.0 / Godot 4.7.2 확인; 참조 commit은 DEPENDENCIES에 기록 |
| 공통 기반 | GameConfig·Settings·SaveManager·AudioManager·SceneManager·App 및 bootstrap hook |
| PC 기능 | WindowManager·InputManager, 사용자 설정 UI, focus/pause/quit lifecycle |
| ESD 경계 | StoreService·기본 unavailable Adapter·Debug Mock·검증한 Adapter 등록 API |
| 빌드 구성 | 여섯 preset, 설정 반영·게임 자산/데모/Steam 전용 export 필터 |
| 실행 예제 | 저장·오디오·장면·화면·입력·스토어 요청 데모 |
| 문서 | README, AI 규칙, 코드 지도, 설계, 개발, BOM, Steam/배포, 적용/이력/검증 |
| 검증 | import·headless 공통 검사·macOS 실제 렌더링과 GUI 화면 복구; 실제 결과는 VALIDATION |

## 설계 결정

기본 렌더러는 Compatibility와 1280×720 landscape다. 화면비를 확장하고 resizable·고DPI 창을 사용한다. 게임별 3D renderer·카메라·장르는 `game/`에서 선택한다.

공통 singleton을 중복 생성하지 않고 App이 StoreService만 소유한다. Store SDK는 런타임 필수 dependency가 아니다. native 조합이 검증되기 전에는 unavailable/Mock 계약으로 개발하며 release Mock은 차단한다.

추가 native 플러그인·장르별 UI·멀티플레이·DLC·DRM·자동 updater·설치 프로그램은 실제 게임 요구가 생긴 뒤 구현한다. 최종 OS 실행 파일·서명·스토어 서버 기능은 배포 환경에서 확인할 별도 범위다.
