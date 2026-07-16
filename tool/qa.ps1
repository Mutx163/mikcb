# mikcb lightweight device QA helper (debug / profile packages only)
# Requires: adb + a connected device with the debug or profile build installed.
#
# Examples:
#   .\tool\qa.ps1 open settings/live
#   .\tool\qa.ps1 seed-soon 15
#   .\tool\qa.ps1 resume-cycle -SleepSeconds 5
#   .\tool\qa.ps1 dump-live
#   .\tool\qa.ps1 screenshot
#   .\tool\qa.ps1 list

param(
    [Parameter(Position = 0)]
    [ValidateSet(
        "open",
        "seed-soon",
        "resume",
        "resume-cycle",
        "dump-live",
        "home",
        "launch",
        "screenshot",
        "list",
        "help"
    )]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$Target = "",

    [int]$SleepSeconds = 3,

    [int]$Minutes = 15,

    [string]$Package = "",

    [string]$OutDir = "tmp/qa"
)

$ErrorActionPreference = "Stop"

$adbCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"),
    "adb"
)
$adb = $null
foreach ($candidate in $adbCandidates) {
    if ($candidate -eq "adb") {
        $resolved = Get-Command adb -ErrorAction SilentlyContinue
        if ($resolved) {
            $adb = $resolved.Source
            break
        }
    } elseif (Test-Path $candidate) {
        $adb = $candidate
        break
    }
}
if (-not $adb) {
    Write-Error "adb not found. Install Android SDK platform-tools or add adb to PATH."
    exit 1
}

function Assert-Device {
    $devices = & $adb devices | Select-String "device$"
    if (-not $devices) {
        Write-Error "No Android device connected. Plug USB or adb connect first."
        exit 1
    }
}

function Resolve-Package {
    param([string]$Preferred)
    if ($Preferred) {
        return $Preferred
    }
    foreach ($candidate in @(
        "com.mutx163.qingyu.debug",
        "com.mutx163.qingyu.profile"
    )) {
        $path = (& $adb shell pm path $candidate 2>$null)
        if ($path -and $path.Trim().Length -gt 0) {
            return $candidate
        }
    }
    Write-Error "debug/profile package not found. Install with: flutter run --flavor dev"
    exit 1
}

function Invoke-DeepLink {
    param(
        [string]$PackageName,
        [string]$Uri
    )
    # Use path-absolute form (mikcb-debug:///...) so host is empty and the full
    # path is preserved for both Kotlin and Flutter route parsing.
    Write-Host ">> am start -a VIEW -d $Uri ($PackageName)" -ForegroundColor Cyan
    & $adb shell am start `
        -a android.intent.action.VIEW `
        -c android.intent.category.BROWSABLE `
        -d $Uri `
        -n "$PackageName/com.mutx163.qingyu.MainActivity" | Out-Host
}

function Show-Help {
    Write-Host "mikcb QA (lightweight)"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\tool\qa.ps1 open PATH"
    Write-Host "  .\tool\qa.ps1 seed-soon [minutes]"
    Write-Host "  .\tool\qa.ps1 resume"
    Write-Host "  .\tool\qa.ps1 resume-cycle -SleepSeconds 5"
    Write-Host "  .\tool\qa.ps1 dump-live"
    Write-Host "  .\tool\qa.ps1 home"
    Write-Host "  .\tool\qa.ps1 launch"
    Write-Host "  .\tool\qa.ps1 screenshot"
    Write-Host "  .\tool\qa.ps1 list"
    Write-Host ""
    Write-Host "Paths for open:"
    Write-Host "  home, settings, settings/live, settings/live/testing,"
    Write-Host "  settings/live/keep-alive, settings/couple, settings/lan-edit,"
    Write-Host "  courses/import"
}

Assert-Device
$packageName = Resolve-Package -Preferred $Package

switch ($Command) {
    "help" {
        Show-Help
    }
    "list" {
        @(
            "home",
            "settings",
            "settings/live",
            "settings/live/testing",
            "settings/live/keep-alive",
            "settings/couple",
            "settings/lan-edit",
            "courses/import",
            "action/resume",
            "action/seed-soon?minutes=N",
            "action/dump-live-status"
        ) | ForEach-Object { Write-Host $_ }
    }
    "launch" {
        Write-Host ">> launching $packageName" -ForegroundColor Cyan
        & $adb shell monkey -p $packageName -c android.intent.category.LAUNCHER 1 | Out-Host
    }
    "home" {
        Invoke-DeepLink -PackageName $packageName -Uri "mikcb-debug:///home"
    }
    "open" {
        if (-not $Target) {
            Write-Error "open needs a path, e.g. .\tool\qa.ps1 open settings/live"
            exit 1
        }
        $path = $Target.TrimStart('/')
        Invoke-DeepLink -PackageName $packageName -Uri "mikcb-debug:///$path"
    }
    "seed-soon" {
        $lead = if ($Target) { [int]$Target } else { $Minutes }
        Invoke-DeepLink -PackageName $packageName -Uri "mikcb-debug:///action/seed-soon?minutes=$lead"
    }
    "resume" {
        Invoke-DeepLink -PackageName $packageName -Uri "mikcb-debug:///action/resume"
    }
    "resume-cycle" {
        Write-Host ">> KEYCODE_HOME" -ForegroundColor Cyan
        & $adb shell input keyevent KEYCODE_HOME | Out-Host
        Write-Host ">> sleep ${SleepSeconds}s" -ForegroundColor Cyan
        Start-Sleep -Seconds $SleepSeconds
        Write-Host ">> bring app to front" -ForegroundColor Cyan
        & $adb shell monkey -p $packageName -c android.intent.category.LAUNCHER 1 | Out-Host
        Start-Sleep -Seconds 1
        Invoke-DeepLink -PackageName $packageName -Uri "mikcb-debug:///action/resume"
    }
    "dump-live" {
        Invoke-DeepLink -PackageName $packageName -Uri "mikcb-debug:///action/dump-live-status"
        Write-Host "Requested dump. Check: adb logcat -d | findstr DEBUG_LIVE_STATUS" -ForegroundColor Yellow
    }
    "screenshot" {
        if (-not (Test-Path $OutDir)) {
            New-Item -ItemType Directory -Path $OutDir | Out-Null
        }
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $remote = "/sdcard/mikcb-qa-$stamp.png"
        $local = Join-Path $OutDir "screen-$stamp.png"
        & $adb shell screencap -p $remote
        & $adb pull $remote $local | Out-Host
        & $adb shell rm $remote
        Write-Host "Screenshot saved: $local" -ForegroundColor Green
    }
    default {
        Show-Help
    }
}
