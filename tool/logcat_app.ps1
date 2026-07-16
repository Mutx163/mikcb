# 轻屿课表 — 本应用 logcat（默认 Warn+，调试可用 -MinLevel I）
param(
    [switch]$IncludeProd,

    # W=Warn+（默认，噪音少） I=Info+（调试更全） D=Debug+ V=Verbose
    [ValidateSet("W", "I", "D", "V")]
    [string]$MinLevel = "W"
)

$ErrorActionPreference = "SilentlyContinue"

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    Write-Error "找不到 adb：$adb`n请确认已安装 Android SDK platform-tools。"
    exit 1
}

$debugPackages = @(
    "com.mutx163.qingyu.debug",
    "com.mutx163.qingyu.profile"
)
$prodPackage = "com.mutx163.qingyu"

$devices = & $adb devices | Select-String "device$"
if (-not $devices) {
    Write-Error "未检测到已连接的 Android 设备。请插线或 adb connect 后重试。"
    exit 1
}

function Get-RunningPid([string]$packageName) {
    $candidate = (& $adb shell pidof -s $packageName 2>$null).Trim()
    if ($candidate -match '^\d+$') { return $candidate }
    return $null
}

Write-Host "等待轻屿课表进程…（先 flutter run --flavor dev / debug_run.ps1）" -ForegroundColor Cyan
$appPid = $null
$activePkg = $null
while (-not $appPid) {
    foreach ($pkg in $debugPackages) {
        $candidate = Get-RunningPid $pkg
        if ($candidate) {
            $appPid = $candidate
            $activePkg = $pkg
            break
        }
    }
    if (-not $appPid -and $IncludeProd) {
        $candidate = Get-RunningPid $prodPackage
        if ($candidate) {
            $appPid = $candidate
            $activePkg = $prodPackage
        }
    }
    if (-not $appPid) {
        Start-Sleep -Milliseconds 400
    }
}

Write-Host ""
if ($activePkg -eq $prodPackage) {
    Write-Host "已附着：$activePkg (PID $appPid) [正式版]" -ForegroundColor Yellow
    Write-Host "提示：正式版无 JDWP。调试请用 --flavor dev。" -ForegroundColor Yellow
} else {
    Write-Host "已附着：$activePkg (PID $appPid)" -ForegroundColor Green
}
Write-Host "级别：*:$MinLevel  |  按 Ctrl+C 停止" -ForegroundColor DarkGray
Write-Host "常见 tag：MainActivity、flutter、LiveUpdate、KeepAliveAccessibility、UmengDiagnostic" -ForegroundColor DarkGray
Write-Host ""

& $adb logcat --pid=$appPid -v color *:$MinLevel
