<#
.SYNOPSIS
    跨 Agent 超轻量 Kotlin 模块级单测运行脚本（免 Gradle、内存 <150MB、执行 0.2 秒）。

.DESCRIPTION
    为了解决多 Agent 并发开发时频繁拉起 Gradle 导致 10~40GB 内存雪崩与死锁的问题，
    本脚本直接利用 Android Studio 内置的 kotlinc 与 JUnitCore，仅针对当前模块的模型层与
    单元测试进行极速编译与运行。

.EXAMPLE
    pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/showcase"
    pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/live"
    pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/import/warehouse"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Module,

    [Parameter(Mandatory = $false)]
    [string[]]$ExtraSources = @()
)

$ErrorActionPreference = "Stop"

# 统一规整模块路径（去掉前缀 pages/ 或 android/app/src/...）
$cleanModule = $Module -replace "^android/app/src/(main|test)/kotlin/com/mutx163/qingyu/pages/", "" `
                       -replace "^pages/", "" `
                       -replace "[\\/]+$", ""

$repoRoot = Split-Path -Parent $PSScriptRoot

# 1. 定位 kotlinc
$kotlinc = "C:\Program Files\Android\Android Studio\plugins\Kotlin\kotlinc\bin\kotlinc.bat"
if (-not (Test-Path $kotlinc)) {
    $found = Get-Command kotlinc -ErrorAction SilentlyContinue
    if ($found) {
        $kotlinc = $found.Source
    } else {
        Write-Error "[test-kotlin-module] 未在默认路径找到 Android Studio 内置 kotlinc，请确认已安装 Android Studio。"
        exit 1
    }
}

# 2. 定位依赖 JAR
$gradleCache = Join-Path $env:USERPROFILE ".gradle\caches\modules-2\files-2.1"
$junitJar = (Get-ChildItem -Path (Join-Path $gradleCache "junit\junit\4.13.2") -Filter "junit-4.13.2.jar" -Recurse)[0].FullName
$hamcrestJar = (Get-ChildItem -Path (Join-Path $gradleCache "org.hamcrest\hamcrest-core\1.3") -Filter "hamcrest-core-1.3.jar" -Recurse)[0].FullName

$asPluginDir = "C:\Program Files\Android\Android Studio\plugins\Kotlin\kotlinc\lib"
$stdlibJar = Join-Path $asPluginDir "kotlin-stdlib.jar"
if (-not (Test-Path $stdlibJar)) {
    $stdlibJar = (Get-ChildItem -Path (Join-Path $gradleCache "org.jetbrains.kotlin\kotlin-stdlib") -Filter "kotlin-stdlib-2.*.jar" -Recurse)[0].FullName
}

# 3. 收集目标源码与测试代码
$mainDir = Join-Path $repoRoot "android/app/src/main/kotlin/com/mutx163/qingyu/pages/$cleanModule"
$testDir = Join-Path $repoRoot "android/app/src/test/kotlin/com/mutx163/qingyu/pages/$cleanModule"

if (-not (Test-Path $mainDir) -and -not (Test-Path $testDir)) {
    Write-Error "[test-kotlin-module] 未找到模块源码目录：$mainDir 或测试目录：$testDir"
    exit 1
}

$sources = @()
if (Test-Path $mainDir) {
    $sources += (Get-ChildItem -Path $mainDir -Filter "*.kt" -Recurse).FullName
}
if (Test-Path $testDir) {
    $sources += (Get-ChildItem -Path $testDir -Filter "*.kt" -Recurse).FullName
}

# 默认带上公共模型层：绝大多页面模型都依赖 core 里的 Course / Exam / CourseTask /
# TimetableSettings 等值类型，以及 statistics / share / transfer / sync / infra /
# widgetdata / theme（色板与形状等 Int ARGB / 数值常量）等纯 Kotlin 数据层，
# 只收本模块目录会报一堆 unresolved reference。
# 这些目录全部无 Android/Compose 依赖，体积仍很小，不影响 0.2s 极速目标。
# 若将来某目录混入 Android 依赖，脚本会自动跳过并打印提示。
# 注：theme/ 的 QingyuTheme.kt 只放槽位数据类与种子色常量，Compose 接线在 composeP1/，
# 故 theme/ 始终可进 JVM 单测 classpath；真正踩到 androidx.compose/miuix 时下方过滤会拦。
$sharedModelDirs = @("core", "calendar", "course", "infrastructure", "infra", "statistics", "share", "transfer", "sync", "weather", "widgetdata", "theme")
foreach ($sharedDir in $sharedModelDirs) {
    $absSharedDir = Join-Path $repoRoot "android/app/src/main/kotlin/com/mutx163/qingyu/$sharedDir"
    if (-not (Test-Path $absSharedDir)) { continue }
    # 纯 Kotlin 判定：android.* 框架类、androidx.compose.*、miuix 都进不了 JVM 单测 classpath
    # （androidx.annotation / kotlin 等纯 JVM 依赖不在此列，允许通过）。
    $androidImports = @(Get-ChildItem -Path $absSharedDir -Filter "*.kt" -Recurse |
            Select-String -Pattern "^\s*import\s+(android[\.\:]|androidx\.compose|top\.yukonga\.miuix)" -List)
    if ($androidImports.Count -gt 0) {
        Write-Host ">>> [test-kotlin-module] 跳过 $sharedDir/（含 Android 依赖，不属于纯 Kotlin 模型层）" -ForegroundColor DarkYellow
        continue
    }
    $sharedSources = (Get-ChildItem -Path $absSharedDir -Filter "*.kt" -Recurse).FullName
    foreach ($src in $sharedSources) {
        if ($sources -notcontains $src) { $sources += $src }
    }
}

foreach ($extra in $ExtraSources) {
    $resolved = (Resolve-Path (Join-Path $repoRoot $extra)).Path
    if ($sources -notcontains $resolved) {
        $sources += $resolved
    }
}

if ($sources.Count -eq 0) {
    Write-Error "[test-kotlin-module] 模块 $cleanModule 下未找到任何 .kt 文件。"
    exit 1
}

# 4. 解析测试类全限定名
$testClasses = @()
$testFiles = $sources | Where-Object { $_ -match "Test\.kt$" }
foreach ($file in $testFiles) {
    $lines = Get-Content $file
    $pkgLine = $lines | Where-Object { $_ -match "^\s*package\s+([a-zA-Z0-9_\.]+)" } | Select-Object -First 1
    $pkg = if ($pkgLine -match "package\s+([a-zA-Z0-9_\.]+)") { $matches[1] } else { "" }
    
    $clsMatches = $lines | Select-String -Pattern "^\s*(?:@\w+\s+)*(?:open\s+|final\s+|internal\s+)*class\s+([a-zA-Z0-9_]+Test)"
    foreach ($m in $clsMatches) {
        $cls = $m.Matches.Groups[1].Value
        if ($pkg) {
            $testClasses += "$pkg.$cls"
        } else {
            $testClasses += $cls
        }
    }
}

# 5. 准备编译输出目录
$slug = ($cleanModule -replace "[\\/]", "_")
$outDir = Join-Path $repoRoot "build/tmp/test_classes_$slug"
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Write-Host ">>> [test-kotlin-module] 编译模块 [$cleanModule] (文件数: $($sources.Count))..." -ForegroundColor Cyan

$classpath = "$junitJar;$hamcrestJar"
$compileSuccess = $false

try {
    # 大模块（叠上公共模型层后 >100 个 .kt）拼成一条命令行会撞 Windows 32k 上限，
    # 报 "The command line is too long."。改为写 kotlinc 的 @argfile（每行一个参数），
    # 命令行长度与源文件数解耦；argfile 内路径用双引号包住，兼容空格。
    $argFile = Join-Path $repoRoot "build/tmp/kotlinc_$slug.args"
    New-Item -ItemType Directory -Path (Split-Path -Parent $argFile) -Force | Out-Null
    # kotlinc 的 argfile 解析器会把引号内的反斜杠当转义符吃掉（C:\xy\... 变成 C:xy...），
    # 因此 argfile 里统一写正斜杠路径；JVM 在 Windows 上接受正斜杠。
    $toSlash = { param($p) $p -replace '\\', '/' }
    $argLines = @("-cp", "`"$(& $toSlash $classpath)`"", "-d", "`"$(& $toSlash $outDir)`"")
    foreach ($src in $sources) { $argLines += "`"$(& $toSlash $src)`"" }
    Set-Content -Path $argFile -Value $argLines -Encoding UTF8
    & $kotlinc "@$argFile"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[test-kotlin-module] kotlinc 编译失败 (exit code: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    $compileSuccess = $true

    if ($testClasses.Count -eq 0) {
        Write-Host ">>> [test-kotlin-module] 编译通过，但未找到任何 *Test 类。" -ForegroundColor Yellow
        exit 0
    }

    Write-Host ">>> [test-kotlin-module] 运行 JUnit 单元测试 (测试类: $($testClasses -join ', '))..." -ForegroundColor Green
    $runClasspath = "$outDir;$junitJar;$hamcrestJar;$stdlibJar"
    
    java -cp $runClasspath org.junit.runner.JUnitCore @testClasses
    $testExitCode = $LASTEXITCODE

    if ($testExitCode -ne 0) {
        exit $testExitCode
    }
} finally {
    if (Test-Path $outDir) {
        Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    }
}
