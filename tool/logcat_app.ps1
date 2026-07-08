# 轻屿课表 — 仅显示本应用 Warn/Error 日志（过滤系统 AssetManager2、MIUI 输入等噪音）
param(
    [switch]$IncludeProd
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

Write-Host "等待轻屿课表调试/性能进程…（请先在 Cursor 用 mikcb (debug) 或 mikcb (profile) 按 F5）" -ForegroundColor Cyan
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
    Write-Host "已附着：$activePkg (PID $appPid) [正式版 · 不可 F5 调试]" -ForegroundColor Yellow
    Write-Host "提示：正式版没有 JDWP，Cursor 热重载无效。请改用 mikcb (debug) 启动。" -ForegroundColor Yellow
} else {
    Write-Host "已附着：$activePkg (PID $appPid)" -ForegroundColor Green
}
Write-Host "级别：Warn / Error  |  按 Ctrl+C 停止" -ForegroundColor DarkGray
Write-Host "常见 tag：MainActivity、flutter、LiveUpdate、KeepAliveAccessibility、UmengDiagnostic" -ForegroundColor DarkGray
Write-Host ""

& $adb logcat --pid=$appPid -v color *:W
