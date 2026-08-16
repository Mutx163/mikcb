# tool/android_cli_install.ps1
# 用途：使用 Android CLI 的 delta install（增量安装）快速构建并部署轻屿课表到真机
# 说明：编译仍由 Flutter/Gradle 完成；Android CLI 只负责"更快地装 APK"（只传输变化部分）
# 用法：pwsh -NoProfile -ExecutionPolicy Bypass -File tool/android_cli_install.ps1 [-Mode debug|profile] [-Device <serial>] [-SkipBuild]
param(
    [ValidateSet("debug", "profile")]
    [string]$Mode = "debug",
    [string]$Device = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# adb 不在 PATH 时用 ANDROID_HOME 推导完整路径
$adb = if (Get-Command adb -ErrorAction SilentlyContinue) { "adb" } elseif ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME "platform-tools\adb.exe" } else { "D:\Cache\Android\Sdk\platform-tools\adb.exe" }
if (-not (Test-Path $adb)) { Write-Host "找不到 adb（ANDROID_HOME=$env:ANDROID_HOME）" -ForegroundColor Red; exit 1 }

if ($Mode -eq "debug") {
    $flavor = "dev"
    $buildMode = "debug"
    $appId = "com.mutx163.qingyu.debug"
    $apk = Join-Path $root "build/app/outputs/flutter-apk/app-dev-debug.apk"
} else {
    $flavor = "perf"
    $buildMode = "profile"
    $appId = "com.mutx163.qingyu.profile"
    $apk = Join-Path $root "build/app/outputs/flutter-apk/app-perf-profile.apk"
}

if (-not $Device) {
    $Device = (& $adb devices 2>$null | Select-String -Pattern "\sdevice$" | ForEach-Object { ($_ -split "\s+")[0] } | Select-Object -First 1)
    if (-not $Device) {
        Write-Host "未发现在线设备，请先连接手机（无线调试）或启动模拟器" -ForegroundColor Red
        exit 1
    }
}
Write-Host "==> 设备: $Device | 模式: $Mode (flavor=$flavor) | 开始时间: $(Get-Date -Format 'HH:mm:ss')"

$sw = [System.Diagnostics.Stopwatch]::StartNew()
if (-not $SkipBuild) {
    Write-Host "==> [1/3] 构建 $buildMode APK (flavor=$flavor) ..."
    & flutter build apk "--$buildMode" --flavor $flavor
    if ($LASTEXITCODE -ne 0) { Write-Host "flutter build 失败" -ForegroundColor Red; exit 1 }
} else {
    Write-Host "==> [1/3] 跳过构建（-SkipBuild），使用现有 APK"
}
Write-Host ("    构建阶段耗时: {0:N1}s" -f $sw.Elapsed.TotalSeconds)

if (-not (Test-Path $apk)) {
    Write-Host "APK 不存在: $apk（请去掉 -SkipBuild 重新构建）" -ForegroundColor Red
    exit 1
}
$sizeMB = [math]::Round((Get-Item $apk).Length / 1MB, 1)
Write-Host "==> [2/3] android install（delta 增量安装）APK: $(Split-Path $apk -Leaf) ($sizeMB MB) ..."
$sw.Restart()
& android install --device $Device --apks $apk
if ($LASTEXITCODE -ne 0) { Write-Host "android install 失败" -ForegroundColor Red; exit 1 }
Write-Host ("    安装阶段耗时: {0:N1}s" -f $sw.Elapsed.TotalSeconds)

Write-Host "==> [3/3] 启动 $appId ..."
$activity = "com.mutx163.qingyu.MainActivity"  # Kotlin 包名（flavor 只改 applicationId，不改类包）
& $adb -s $Device shell am start -n "$appId/$activity" 2>$null | Out-Null
Write-Host "==> 完成（总耗时: $([math]::Round($sw.Elapsed.TotalSeconds, 1))s）"
