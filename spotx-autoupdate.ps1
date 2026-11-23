<#
.SYNOPSIS
    SpotX(Windows) 자동 설치 / 자동 재패치 러너.

.DESCRIPTION
    GitHub의 SpotX run.ps1을 주기적으로 새로 받아서, SpotX가 "지원한다"고 표시한
    최신 클라이언트 버전($latest_full)과 현재 설치된 Spotify 버전을 비교합니다.
    다르면 run.ps1에 무인 옵션을 붙여 실행해서 지원 버전 설치 + 패치 적용까지 합니다.

    상태는 %LOCALAPPDATA%\SpotX-AutoUpdate\state.json 에, 로그는 같은 폴더에 남습니다.

.PARAMETER InstallTask
    작업 스케줄러에 "SpotX Auto Update" 작업을 등록합니다. (매일 지정 시각 + 로그온 시)

.PARAMETER UninstallTask
    위 예약 작업을 제거합니다.

.PARAMETER CheckOnly
    비교만 하고 실제 패치는 하지 않습니다.

.PARAMETER Force
    버전이 같아도 강제로 다시 패치합니다.

.PARAMETER Premium
    Spotify Premium 계정용 모드(-premium). 기본은 광고 차단 모드입니다.

.PARAMETER HidePodcasts
    홈 화면에서 팟캐스트/에피소드/오디오북을 숨깁니다. 기본은 유지입니다.

.PARAMETER AllowSpotifyUpdates
    Spotify 자체 자동 업데이트를 막지 않습니다. 기본은 차단입니다.
    (차단해야 SpotX가 지원하는 버전보다 앞서 올라가서 패치가 깨지는 걸 막을 수 있습니다.)

.PARAMETER KeepMsStoreSpotify
    Microsoft Store 버전 Spotify가 있어도 제거하지 않습니다. 기본은 제거입니다.

.PARAMETER UseMirror
    SpotX 리소스 다운로드에 github.io 미러를 씁니다.

.PARAMETER RepatchOnScriptUpdate
    지원 버전이 같아도 run.ps1 내용이 바뀌면 다시 패치합니다.

.PARAMETER SkipIfSpotifyRunning
    Spotify가 실행 중이면 이번 체크를 건너뜁니다. (기본은 종료하고 적용)

.PARAMETER TaskTime
    예약 작업 실행 시각. 기본 03:00.
#>
[CmdletBinding()]
param(
    [switch]$InstallTask,
    [switch]$UninstallTask,
    [switch]$CheckOnly,
    [switch]$Force,
    [switch]$Premium,
    [switch]$HidePodcasts,
    [switch]$AllowSpotifyUpdates,
    [switch]$KeepMsStoreSpotify,
    [switch]$UseMirror,
    [switch]$RepatchOnScriptUpdate,
    [switch]$SkipIfSpotifyRunning,
    [string]$TaskTime = '03:00'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root       = Join-Path $env:LOCALAPPDATA 'SpotX-AutoUpdate'
$StatePath  = Join-Path $Root 'state.json'
$LogPath    = Join-Path $Root 'autoupdate.log'
$RunScript  = Join-Path $Root 'run.ps1'
$ScriptPath = $PSCommandPath
$TaskName   = 'SpotX Auto Update'

$RunScriptUrls = @(
    'https://raw.githubusercontent.com/SpotX-Official/SpotX/main/run.ps1',
    'https://spotx-official.github.io/SpotX/run.ps1'
)

$null = New-Item -ItemType Directory -Path $Root -Force

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')] [string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-CleanVersion {
    param([AllowNull()] [string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    if ($Version -match '(\d+\.\d+(?:\.\d+){0,2})') {
        try { return [version]$Matches[1] } catch { return $null }
    }
    return $null
}

function Read-State {
    if (!(Test-Path -LiteralPath $StatePath)) { return $null }
    try {
        return (Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        Write-Log "상태 파일을 읽을 수 없어 처음 실행으로 처리합니다: $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Save-State {
    param(
        [Parameter(Mandatory)] [AllowNull()] [string]$Recommended,
        [Parameter(Mandatory)] [AllowNull()] [string]$Applied,
        [Parameter(Mandatory)] [AllowNull()] [string]$Hash,
        [string]$LastApply
    )
    $old = Read-State
    $lastApplyValue = if ($LastApply) { $LastApply } else { $old.LastApply }
    $object = [ordered]@{
        RecommendedVersion = $Recommended
        AppliedVersion     = $Applied
        InstalledVersion   = $Applied
        ScriptSha256       = $Hash
        LastCheck          = (Get-Date).ToString('o')
        LastApply          = $lastApplyValue
        LastResult         = 'ok'
    }
    $object | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Get-LatestRunScript {
    $temp = "$RunScript.tmp"
    $lastError = $null
    foreach ($url in $RunScriptUrls) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $temp -TimeoutSec 30 -ErrorAction Stop
            $content = Get-Content -LiteralPath $temp -Raw -Encoding UTF8
            if ($content -notmatch '(?m)^\s*\[string\]\$latest_full\s*=\s*"([^"]+)"') {
                throw 'run.ps1에서 $latest_full을 찾지 못했습니다.'
            }
            $recommended = $Matches[1]
            if (!(Get-CleanVersion $recommended)) { throw "이상한 버전 형식: $recommended" }
            Move-Item -LiteralPath $temp -Destination $RunScript -Force
            $hash = (Get-FileHash -LiteralPath $RunScript -Algorithm SHA256).Hash
            return [pscustomobject]@{
                Recommended = $recommended
                Hash        = $hash
                Source      = $url
            }
        }
        catch {
            $lastError = $_
            Write-Log "받기 실패: $url - $($_.Exception.Message)" 'WARN'
        }
    }
    throw "SpotX run.ps1을 가져오지 못했습니다: $($lastError.Exception.Message)"
}

function Get-InstalledSpotifyVersion {
    $exe = Join-Path $env:APPDATA 'Spotify\Spotify.exe'
    if (!(Test-Path -LiteralPath $exe)) { return $null }
    return Get-CleanVersion (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
}

function Install-SpotX {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outLog = Join-Path $Root "spotx-$stamp.out.log"
    $errLog = Join-Path $Root "spotx-$stamp.err.log"

    $spotxArgs = @(
        '-no_pause',
        '-defender_exclusions_off',
        '-confirm_spoti_recomended_over',
        '-new_theme',
        '-podcasts_on'
    )
    if ($HidePodcasts) { $spotxArgs = @($spotxArgs | Where-Object { $_ -ne '-podcasts_on' }) + '-podcasts_off' }
    if ($Premium) { $spotxArgs += '-premium' }
    if ($AllowSpotifyUpdates) { $spotxArgs += '-block_update_off' } else { $spotxArgs += '-block_update_on' }
    if (!$KeepMsStoreSpotify) { $spotxArgs += '-confirm_uninstall_ms_spoti' }
    if ($UseMirror) { $spotxArgs += '-m' }

    $argList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $RunScript)) + $spotxArgs

    Write-Log "SpotX 실행: $(($spotxArgs | Where-Object { $_ }) -join ' ')"
    $proc = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList $argList `
        -Wait -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $outLog `
        -RedirectStandardError $errLog

    $stdout = Get-Content -LiteralPath $outLog -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content -LiteralPath $errLog -Raw -ErrorAction SilentlyContinue
    if ($stdout) { Add-Content -LiteralPath $LogPath -Value $stdout -Encoding UTF8 }
    if ($stderr) { Add-Content -LiteralPath $LogPath -Value "STDERR: $stderr" -Encoding UTF8 }

    Get-ChildItem -LiteralPath $Root -Filter 'spotx-*.log' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 10 |
        Remove-Item -Force -ErrorAction SilentlyContinue

    if ($proc.ExitCode -ne 0) {
        throw "SpotX가 오류 코드 $($proc.ExitCode) 로 끝났습니다. 로그: $outLog"
    }
}

function Install-ScheduledTask {
    $user = "$env:USERDOMAIN\$env:USERNAME"
    if (!$ScriptPath) { throw '이 스크립트는 파일로 저장한 뒤 실행해야 합니다.' }

    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $ScriptPath
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $daily = New-ScheduledTaskTrigger -Daily -At $TaskTime
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

    Register-ScheduledTask -TaskName $TaskName `
        -Action $action -Trigger @($daily, $logon) `
        -Principal $principal -Settings $settings `
        -Description 'SpotX 지원 버전 확인 및 자동 설치/패치' -Force | Out-Null

    Write-Log "예약 작업 등록 완료: $TaskName (매일 $TaskTime, 로그온 시)"
}

if ($InstallTask) { Install-ScheduledTask; return }
if ($UninstallTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "예약 작업 제거: $TaskName"
    return
}

Write-Log '=== 확인 시작 ==='

$latest = Get-LatestRunScript
$recommended = Get-CleanVersion $latest.Recommended
$installed = Get-InstalledSpotifyVersion
$state = Read-State

Write-Log "지원 버전=$recommended / 설치 버전=$installed / 출처=$($latest.Source)"

$reasons = @()
if (!$state) {
    $reasons += '첫 실행'
}
else {
    $applied = Get-CleanVersion $state.AppliedVersion
    if (!$applied -or $recommended -gt $applied) {
        $reasons += "지원 버전 상승: $applied -> $recommended"
    }
    if ($installed -and $applied -and $installed -ne $applied) {
        $reasons += "설치 버전 불일치: $installed (기록: $applied)"
    }
    if ($RepatchOnScriptUpdate -and $state.ScriptSha256 -ne $latest.Hash) {
        $reasons += 'SpotX 스크립트 내용 변경'
    }
}
if (!$installed) { $reasons += 'Spotify 미설치' }
if ($Force) { $reasons += '-Force' }

if ($reasons.Count -eq 0) {
    Write-Log '변경 없음. 패치를 건너뜁니다.'
    Save-State -Recommended $latest.Recommended -Applied $state.AppliedVersion `
        -Hash $latest.Hash -LastApply $state.LastApply
    return
}

Write-Log "적용 필요: $($reasons -join ' / ')"

if ($CheckOnly) {
    Write-Log '체크 전용 모드라 실제 적용은 하지 않았습니다.'
    return
}

if ($SkipIfSpotifyRunning -and (Get-Process -Name 'Spotify' -ErrorAction SilentlyContinue)) {
    Write-Log 'Spotify가 실행 중이라 이번에는 건너뜁니다.' 'WARN'
    return
}

try {
    Install-SpotX
    $after = Get-InstalledSpotifyVersion
    if (!$after -or $after -lt $recommended) {
        throw "패치 후 버전 확인 실패: $after (기대: $recommended)"
    }
    Save-State -Recommended $latest.Recommended -Applied $after.ToString() -Hash $latest.Hash `
        -LastApply ((Get-Date).ToString('o'))
    Write-Log "완료: Spotify $after 에 SpotX 적용됨"
}
catch {
    Write-Log "실패: $($_.Exception.Message)" 'ERROR'
    throw
}
