# SpotX 자동 업데이터

SpotX가 지원하는 가장 최신 Spotify 클라이언트를 찾아서 설치하고 패치까지 적용합니다.
나중에 더 높은 버전을 지원하기 시작하면 알아서 따라갑니다.

## 빠른 시작

```powershell
git clone https://github.com/spidychoipro/spotx-auto-updater.git
cd spotx-autoupdate

.\spotx-autoupdate.ps1 -CheckOnly     # 무엇이 바뀔지 먼저 확인
.\spotx-autoupdate.ps1 -Force         # 지금 설치 + 패치
.\spotx-autoupdate.ps1 -InstallTask   # 매일 자동 체크 등록
```

이미 폴더가 있으면 clone은 건너뛰고 아래 명령만 실행하면 됩니다. 관리자 권한은 필요 없습니다.

`run.bat`을 더블클릭해도 같은 스크립트가 실행됩니다. 옵션을 붙이려면 `run.bat -CheckOnly`처럼 `.cmd`에서 실행하세요.

## 필요한 것

- Windows 7~11, PowerShell 5.1 이상
- Spotify 공식 데스크톱 버전 (Microsoft Store 버전은 지원하지 않음)
- GitHub에서 SpotX 스크립트를 받아올 수 있는 인터넷 연결

## 동작 방식

```text
GitHub run.ps1 받기 → 지원 버전 확인 → 설치 버전과 비교 → 다르면 설치 + 패치 → 상태 기록
```

1. GitHub에서 SpotX의 최신 `run.ps1`을 매번 새로 받습니다. `raw.githubusercontent.com`이
   막히면 `spotx-official.github.io` 미러로 재시도합니다.
2. 스크립트에 적힌 `$latest_full`을 읽습니다. SpotX가 테스트를 마친 **호환되는 최신 버전**입니다.
3. `%APPDATA%\Spotify\Spotify.exe`의 버전과 비교합니다.
4. 다르면 `run.ps1`을 무인 옵션으로 실행해 지원 버전 설치와 패치를 한 번에 합니다.
   - `-confirm_spoti_recomended_over` : 지원 버전으로 덮어쓰기 설치
   - `-block_update_on` : Spotify 자체 업데이트 차단
   - `-defender_exclusions_off`, `-no_pause` : 예약 실행 중 프롬프트가 뜨지 않게
5. 결과를 상태 파일과 로그에 남깁니다.

버전이 같으면 아무 것도 하지 않고 끝납니다. 매일 실행해도 부담이 없는 이유입니다.

## 예약 작업

```powershell
.\spotx-autoupdate.ps1 -InstallTask                  # 매일 03:00 + 로그온 시
.\spotx-autoupdate.ps1 -InstallTask -TaskTime "20:30" # 원하는 시각으로 변경
.\spotx-autoupdate.ps1 -UninstallTask                 # 등록 해제
```

작업 이름은 `SpotX Auto Update`입니다. PC가 꺼져 있어야 할 시간을 놓치면 다음 로그온 때 실행됩니다.

## 옵션

| 옵션 | 설명 | 기본값 |
|---|---|---|
| `-CheckOnly` | 비교만 하고 적용하지 않음 | 꺼짐 |
| `-Force` | 버전이 같아도 다시 패치 | 꺼짐 |
| `-InstallTask` / `-UninstallTask` | 예약 작업 등록 / 해제 | - |
| `-TaskTime` | 예약 실행 시각 | `03:00` |
| `-Premium` | Premium 계정용 모드 | 꺼짐 (광고 차단 모드) |
| `-HidePodcasts` | 홈에서 팟캐스트·에피소드·오디오북 숨김 | 꺼짐 |
| `-UseMirror` | SpotX 리소스 다운로드에 github.io 미러 사용 | 꺼짐 |
| `-AllowSpotifyUpdates` | Spotify 자동 업데이트를 막지 않음 | 꺼짐 (차단함) |
| `-KeepMsStoreSpotify` | Microsoft Store 버전 Spotify를 제거하지 않음 | 꺼짐 (제거함) |
| `-RepatchOnScriptUpdate` | 버전이 같아도 SpotX 스크립트가 바뀌면 다시 패치 | 꺼짐 |
| `-SkipIfSpotifyRunning` | Spotify 실행 중이면 건너뜀 | 꺼짐 (종료하고 적용) |

## 상태 확인

```powershell
Get-ScheduledTask -TaskName "SpotX Auto Update" | Select-Object TaskName, State
Get-Content "$env:LOCALAPPDATA\SpotX-AutoUpdate\autoupdate.log" -Encoding UTF8 -Tail 30
Get-Content "$env:LOCALAPPDATA\SpotX-AutoUpdate\state.json" -Encoding UTF8
```

## 파일 위치

- 스크립트: `spotx-autoupdate` 폴더 (복사한 곳 기준)
- 상태와 로그: `%LOCALAPPDATA%\SpotX-AutoUpdate\`

| 파일 | 내용 |
|---|---|
| `state.json` | 마지막으로 적용한 버전과 SpotX 스크립트 해시 |
| `autoupdate.log` | 전체 실행 기록 |
| `spotx-*.out.log` | SpotX 자체 출력, 최근 10개만 보관 |
| `run.ps1` | 마지막으로 받아 둔 SpotX 스크립트 |

## 알아둘 점

- SpotX는 공식 Spotify 클라이언트 파일을 직접 수정합니다. Microsoft Store 버전은 지원하지
  않으므로 기본적으로 제거하고 공식 버전을 설치합니다.
- Spotify 자동 업데이트를 기본으로 막습니다. 풀어두면 Spotify가 먼저 올라가서 SpotX가 아직
  지원하지 않는 버전이 되고, 다음 실행 때 지원 버전으로 되돌립니다.
- 매 실행마다 GitHub 코드를 내려받아 실행합니다. 저장소를 신뢰하고 쓰세요.
- Spicetify와 함께 쓰면 SpotX가 프롬프트를 띄우고 멈출 수 있습니다. 이때는 `autoupdate.log`에
  관련 메시지가 남습니다.

## 원복하기

```powershell
.\spotx-autoupdate.ps1 -UninstallTask
```

예약 작업만 해제됩니다. SpotX 패치 자체를 지우려면 [SpotX 공식 `Uninstall.bat`](https://github.com/SpotX-Official/SpotX/blob/main/Uninstall.bat)을 실행하세요.
