# Game Layer

게임의 장면, 스크립트, 리소스, 저장 데이터 구조를 이 폴더에 둔다. 템플릿을 업데이트할 때 이 폴더는 덮어쓰지 않는다.

## 준비된 파일

| 파일 | 역할 |
| --- | --- |
| `main.tscn`, `main.gd` | 첫 장면 골격. pause 메뉴(Esc / Start)와 창 닫기 확인이 연결되어 있다. `config/game.cfg`의 `main_scene`으로 지정한다 |
| `game_init.gd` | 초기화 hook. 게임 시작 시 저장 읽기 전에 한 번 실행된다. `config/game.cfg`의 `init_script`로 이미 연결되어 있다 |

## 초기화 hook 규칙

`game_init.gd`에서 저장 구조 버전·변환 함수, 설정 화면에서 바꿀 게임 입력 action, 검증한 스토어 Adapter를 등록한다.

- `RefCounted`를 상속하고 인수 없는 `before_app_initialize() -> Dictionary`를 둔다.
- 성공하면 `{"error": OK}`, 실패하면 `{"error": ERR_...}`를 반환한다. 내부에서 호출한 함수의 오류도 이 값으로 전달한다.
- `await`는 쓰지 않는다. 실패하거나 오류가 나면 게임 진입이 막히고 화면에 오류 메시지가 표시된다.

계약의 근거는 [설계 설명](../docs/ARCHITECTURE.md#초기화와-수명)에 있다.

## 공통 기능 사용법

입력 action 추가, pause·종료, 저장, 설정, 소리, 장면 이동, 번역 등은 [자주 하는 작업](../docs/HOWTO.md)에 예제와 함께 있다. 게임 코드는 Steam SDK를 직접 호출하지 않고 `App.store`를 사용한다.
