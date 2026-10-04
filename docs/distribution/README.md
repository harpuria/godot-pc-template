# SteamPipe 예시

이 폴더의 VDF는 실제 게임에 맞게 복사·수정하는 입력 예시다. 유효한 App ID·depot ID·계정이 없으므로 현재 그대로 실행할 수 없다. 네이티브 SDK와 steamcmd는 설치되어 있지 않다.

1. `app_build.example.vdf`, `depot_windows.example.vdf`, `depot_macos.example.vdf`를 로컬 작업 폴더로 복사한다.
2. `APP_ID`, `WINDOWS_DEPOT_ID`, `MACOS_DEPOT_ID`를 실제 Steamworks 값으로 교체한다.
3. Windows Steam export 폴더의 파일 전체를 `build/steam-content/windows/`에 준비한다.
4. macOS Steam ZIP을 풀고 `.app` 번들을 `build/steam-content/macos/`에 준비한다. ZIP 자체를 launch executable로 지정하지 않는다.
5. VDF를 이동했다면 `ContentRoot`, `BuildOutput`과 depot VDF 경로를 새 위치 기준으로 고친다.
6. `Preview="1"`로 SteamPipe 입력을 확인한 후 실제 업로드를 수행할 때 `0`으로 변경한다. Preview도 Steam 계정 접근이 필요하다.
7. Steamworks의 OS별 launch option·depot·비공개 branch를 설정하고 실제 Steam 설치로 확인한다.

예시에는 `SetLive`가 없어 공개 branch를 자동 게시하지 않는다. 인증 정보는 VDF에 쓰지 않는다. `FileMapping`은 OS별 content 폴더에서 재귀적으로 복사하고 `.pck`, native 라이브러리와 macOS 번들 파일을 포함한다.

구체적인 steamcmd 실행·로그인과 branch 게시 방법은 [SteamPipe 공식 문서](https://partner.steamgames.com/doc/sdk/uploading)를 따른다. [PC 배포 안내](../DISTRIBUTION.md)의 라이선스·서명·실행 검증을 완료한 결과물로 진행한다.
