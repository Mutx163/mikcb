# tool/android_cli_install.ps1
# 用途：使用 Android CLI 的 delta install（增量安装）快速构建并部署轻屿课表到真机
# 说明：编译仍由 Flutter/Gradle 完成；Android CLI 只负责"更快地装 APK"（只传输变化部分）
# 用法：pwsh -NoProfile -ExecutionPolicy Bypass -File tool/android_cli_install.ps1 [-Mode debug|profile|release] [-Device <serial>] [-SkipBuild]
#
# -Mode release（正式版）：
#   * flavor=prod、applicationId=com.mutx163.qingyu（无后缀），与 GitHub 发布同源；
#   * 构建参数与 .github/workflows/android-build.yml 逐字对齐
#     （--release --flavor prod --target-platform android-arm64）；
#   * 用**同一把** android/app/upload-keystore.jks 签名 —— 已实测该 keystore 的证书
#     SHA-256 与「已安装正式版」和「GitHub 发布的 APK」完全一致，因此可以覆盖安装；
#   * 安装走 `adb install -r`（**绝不 uninstall**）：签名一致且 versionCode 不降级时
#     正式版数据完整保留；万一不一致，Android 只会让安装失败并保留原应用，不会清数据。
param(
    [ValidateSet("debug", "profile", "release")]
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

switch ($Mode) {
    "debug" {
        $flavor = "dev"
        $buildMode = "debug"
        $appId = "com.mutx163.qingyu.debug"
        $apk = Join-Path $root "build/app/outputs/flutter-apk/app-dev-debug.apk"
    }
    "profile" {
        $flavor = "perf"
        $buildMode = "profile"
        $appId = "com.mutx163.qingyu.profile"
        $apk = Join-Path $root "build/app/outputs/flutter-apk/app-perf-profile.apk"
    }
    "release" {
        # 正式版：flavor prod 不带 applicationIdSuffix → 与商店/GitHub 正式版同一个包名
        $flavor = "prod"
        $buildMode = "release"
        $appId = "com.mutx163.qingyu"
        $apk = Join-Path $root "build/app/outputs/flutter-apk/app-prod-release.apk"
    }
}

if (-not $Device) {
    $Device = (& $adb devices 2>$null | Select-String -Pattern "\sdevice$" | ForEach-Object { ($_ -split "\s+")[0] } | Select-Object -First 1)
    if (-not $Device) {
        Write-Host "未发现在线设备，请先连接手机（无线调试）或启动模拟器" -ForegroundColor Red
        exit 1
    }
}
Write-Host "==> 设备: $Device | 模式: $Mode (flavor=$flavor) | 开始时间: $(Get-Date -Format 'HH:mm:ss')"

# 正式版必须能签名，否则 Gradle 会产出未签名/失败产物；这里先拦一道，
# 免得构建几分钟后才发现装不上。这两份与 GitHub 发布用的是同一把钥匙。
if ($Mode -eq "release") {
    $kpFile = Join-Path $root "android/key.properties"
    $ksFile = Join-Path $root "android/app/upload-keystore.jks"
    if (-not (Test-Path $kpFile) -or -not (Test-Path $ksFile)) {
        Write-Host "正式版必须签名：缺少 android/key.properties 或 android/app/upload-keystore.jks" -ForegroundColor Red
        Write-Host "  缺失时无法签名，也就无法覆盖安装到已发布的正式版上。" -ForegroundColor Yellow
        exit 1
    }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
if (-not $SkipBuild) {
    Write-Host "==> [1/3] 构建 $buildMode APK (flavor=$flavor) ..."
    if ($Mode -eq "release") {
        # 与 .github/workflows/android-build.yml 的发布构建逐参数对齐，产物与线上同源
        & flutter build apk --release --flavor prod --target-platform android-arm64
    } else {
        & flutter build apk "--$buildMode" --flavor $flavor
    }
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
$sw.Restart()
if ($Mode -eq "release") {
    # 正式版：**只用覆盖安装（adb install -r）**，绝不 uninstall —— 卸载会清掉正式版数据。
    # 签名与已发布正式版一致（同一把 keystore）时数据完整保留。
    Write-Host "==> [2/3] adb install -r（覆盖安装，保留数据）APK: $(Split-Path $apk -Leaf) ($sizeMB MB) ..."
    & $adb -s $Device install -r $apk
} else {
    Write-Host "==> [2/3] android install（delta 增量安装）APK: $(Split-Path $apk -Leaf) ($sizeMB MB) ..."
    & android install --device $Device --apks $apk
}
if ($LASTEXITCODE -ne 0) {
    Write-Host "安装失败" -ForegroundColor Red
    if ($Mode -eq "release") {
        Write-Host "  ⚠ 切勿 uninstall（会清数据）。签名不一致或 versionCode 低于已装版本都会导致失败，" -ForegroundColor Yellow
        Write-Host "    失败时原应用与数据都还在，先查签名/版本再重试。" -ForegroundColor Yellow
    }
    exit 1
}
Write-Host ("    安装阶段耗时: {0:N1}s" -f $sw.Elapsed.TotalSeconds)

Write-Host "==> [3/3] 启动 $appId ..."
$activity = "com.mutx163.qingyu.MainActivity"  # Kotlin 包名（flavor 只改 applicationId，不改类包）
& $adb -s $Device shell am start -n "$appId/$activity" 2>$null | Out-Null
Write-Host "==> 完成（总耗时: $([math]::Round($sw.Elapsed.TotalSeconds, 1))s）"
