# SpotX 자동 설치 / 자동 업데이트

SpotX가 공식적으로 "이 버전까지 지원한다"고 표시한 최신 Spotify 클라이언트를 찾아서,
지금 깔려 있는 버전과 다르면 **설치 + 패치 적용까지 자동으로** 하는 스크립트입니다.

## 동작 방식

1. GitHub에서 SpotX의 최신 `run.ps1`을 매번 새로 받습니다.
   - `raw.githubusercontent.com` 실패 시 `spotx-official.github.io` 미러로 재시도합니다.
2. 스크립트 안의 `$latest_full` 값을 읽습니다. 이 값이 SpotX가 테스트를 마친
   **호환되는 최신 버전**입니다. (예: 현재 `1.3.11`)
3. `%APPDATA%\Spotify\Spotify.exe`의 버전과 비교합니다.
4. 다르면 `run.ps1`을 무인 옵션으로 실행합니다.
   - `-confirm_spoti_recomended_over` : 지원 버전으로 덮어쓰기 설치
   - `-block_update_on` : Spotify 자체 업데이트 차단 (지원 버전보다 앞으로 올라가지 않게)
   - `-defender_exclusions_off`, `-no_pause` 등 : 예약 실행 중 프롬프트가 뜨지 않게
5. 결과를 `%LOCALAPPDATA%\SpotX-AutoUpdate\state.json`에 기록하고 로그를 남깁니다.

버전이 같으면 아무 것도 하지 않고 넘어갑니다. 그래서 매일 실행해도 부담이 없습니다.

## 사용법

PowerShell을 관리자 권한 없이 열고 스크립트 폴더에서 실행합니다.

```powershell
# 1) 먼저 무엇이 바뀔지 확인만
.\spotx-autoupdate.ps1 -CheckOnly

# 2) 지금 바로 설치/패치
.\spotx-autoupdate.ps1 -Force

# 3) 예약 작업 등록 (매일 03:00 + 로그온 시)
.\spotx-autoupdate.ps1 -InstallTask

# 3-1) 시간 바꾸고 싶을 때
.\spotx-autoupdate.ps1 -InstallTask -TaskTime "20:30"

# 예약 작업 제거
.\spotx-autoupdate.ps1 -UninstallTask
```

`run.bat`을 더블클릭하면 같은 스크립트가 실행됩니다. 인자를 넘기려면
`run.bat -CheckOnly`처럼.cmd에서 실행하세요.

## 자주 쓰는 옵션

| 옵션 | 설명 |
|---|---|
| `-CheckOnly` | 비교만 하고 적용하지 않음 |
| `-Force` | 버전이 같아도 다시 패치 |
| `-Premium` | Premium 계정용 모드. 기본은 광고 차단 모드 |
| `-HidePodcasts` | 홈에서 팟캐스트/에피소드/오디오북 숨김 |
| `-AllowSpotifyUpdates` | Spotify 자동 업데이트를 막지 않음 (권장하지 않음) |
| `-KeepMsStoreSpotify` | Microsoft Store 버전 Spotify를 제거하지 않음 |
| `-RepatchOnScriptUpdate` | 버전이 같아도 SpotX 스크립트가 바뀌면 다시 패치 |
| `-SkipIfSpotifyRunning` | Spotify 실행 중이면 건너뜀 |

## 파일 위치

- 스크립트: `C:\Users\<사용자>\spotx-autoupdate\`
- 상태 / 로그: `%LOCALAPPDATA%\SpotX-AutoUpdate\`
  - `state.json` — 마지막으로 적용한 버전과 스크립트 해시
  - `autoupdate.log` — 실행 기록
  - `spotx-*.out.log` — SpotX 자체 출력 (최근 10개만 보관)
  - `run.ps1` — 마지막으로 받아 둔 SpotX 스크립트

## 알아둘 점

- SpotX는 공식 Spotify 클라이언트를 직접 수정합니다. Microsoft Store 버전은
  지원하지 않으므로 기본적으로 제거하고 공식 버전을 설치합니다.
- Spotify 자동 업데이트를 기본으로 막습니다. 이걸 풀면 Spotify가 먼저 올라가서
  SpotX가 아직 지원하지 않는 버전이 되고, 다음 실행 때 지원 버전으로 되돌립니다.
- 매 실행마다 GitHub 코드를 내려받아 실행합니다. GitHub 저장소를 신뢰할 수 있는지
  확인하고 쓰세요. 문제가 생기면 `-UninstallTask`로 예약만 해제하고
  SpotX 공식 `Uninstall.bat`으로 원복할 수 있습니다.
- Spicetify를 같이 쓰면 SpotX가 프롬프트를 띄우고 중단할 수 있습니다. 이 경우
  로그(`autoupdate.log`)에 Spicetify 관련 메시지가 남습니다.
