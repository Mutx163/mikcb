<#
.SYNOPSIS
    跨 Agent 轻量 Kotlin 模块级单测运行脚本（免 Gradle；同模块互斥 + 每次运行独立临时目录）。

.DESCRIPTION
    为了解决多 Agent 并发开发时频繁拉起 Gradle 导致内存雪崩与死锁的问题，
    本脚本直接利用 Android Studio 内置的 kotlinc 与 JUnitCore，仅针对当前模块的模型层与
    单元测试进行编译与运行。

    【实测口径（2026-10-27/28，替换旧版「0.2 秒 / <150MB」的错说法）】
    采样方法：`pwsh -File scripts/probe-kotlin-module-perf.ps1 -Module pages/<域>`——启动一次
    本脚本，100ms 轮询「本次运行进程树里的 kotlinc JVM」的 WorkingSetSize，只统计自己派生的进程，
    不会把别的 Agent 的 kotlinc 算进来。
    实测（本机 Windows / mutx，`-Module pages/feedback`，收进 classpath 的 .kt 共 81 个）：
      · 单次调用墙钟 22.5~24.3 s；其中 kotlinc 编译段约 21 s，JUnit 本体只占 0.15~0.25 s
      · kotlinc JVM 峰值 RSS 802~849 MB（命令行写的是 -Xmx512M，RSS 还要算 Metaspace/JIT/原生）
      · 两个**不同**模块并行跑时，峰值仍是每个 JVM 各 ~848 MB（2 个模块并发 ≈ 1.7 GB）
    旁证：2026-10-27 22:17 现场抓到两个并存的 kotlinc 编同一模块，RSS 829 MB / 616 MB。
    ⇒ L0 比 Gradle 便宜一个数量级，但**不是免费操作**：别在循环里无脑刷，模块越大越慢。

    【咬合探针】`scripts/probe-kotlin-module-lock.ps1` 证明「同模块并发被串行化、且不互删输出」，
    `-SecondModule` 跨模块模式证明锁**不是全局锁**；它做过反向验证（把锁去掉 → 探针必须红）。

    【同模块互斥】锁名 `Local\Mikcb_KotlinModule_<slug>_Mutex`（Global 建不出来时降级到 Local，
    与 scripts/safe-gradle.ps1 同一套写法 + AbandonedMutexException 兜底）。
    粒度是**模块**：两个 Agent 同时跑同一个模块时后者排队（上限 10 分钟，超时放弃 exit 1），
    跑**不同**模块互不阻塞——不同模块本来就是独立编译，做成全局锁只会把多 Agent 拖成串行。

    【每次运行独立临时目录】kotlinc 的 @argfile 与编译输出都在
    `%TEMP%\mikcb-l0-<slug>-<pid>-<guid>\` 下，finally 里整目录删掉，不留垃圾。
    旧版用的是按模块名固定的共享路径 `build/tmp/kotlinc_<slug>.args` /
    `build/tmp/test_classes_<slug>`，而且每次开头 `Remove-Item -Recurse -Force $outDir`：
    同模块并发时后启动者会删掉先启动者的输出目录、覆盖同一份 args 文件
    ⇒ 假失败/假通过 + 重复劳动（2026-10-27 22:17 实测复现）。

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
    [string[]]$ExtraSources = @(),

    # 临时排除某个共享模型目录（如 `transfer`），默认空 = 全收。
    #
    # 用途：某条泳道在共享目录里留了半成品时，**别的**泳道仍能自测自己那部分。
    # 2026-10-28 一天之内，`sync/` 与 `transfer/` 各挡了全队一次 L0（一次是漏 import，
    # 一次是「只留函数签名、把函数体删掉」导致花括号不闭合）。
    #
    # ⚠️ 这是**逃生门，不是默认姿势**：
    # 1. 用了它，本次结果**不覆盖**被排除的目录——绿了也不能当成「全绿」；
    # 2. 交付证据里必须写明用了它、排除了哪个目录（否则等于悄悄缩小了验证面）；
    # 3. 排除掉的是**别人**的半成品；你自己的半成品请自己修完再跑。
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeShared = @()
)

$ErrorActionPreference = "Stop"

# 统一规整模块路径（去掉前缀 pages/ 或 android/app/src/...）
$cleanModule = $Module -replace "^android/app/src/(main|test)/kotlin/com/mutx163/qingyu/pages/", "" `
                       -replace "^pages/", "" `
                       -replace "[\\/]+$", ""

# 模块 slug：同时用作互斥锁名与临时目录名，所以必须只含 [A-Za-z0-9_.-]
# （互斥锁名里不能出现反斜杠等字符，临时目录名也不能带路径分隔符）。
$slug = $cleanModule -replace "[^A-Za-z0-9_.\-]", "_"

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
# 这些目录全部无 Android/Compose 依赖；但叠加后源文件数会明显变多（例：pages/feedback
# 本身只有 2 个 .kt，实收 81 个），这也是单次编译要 ~20 s 而不是「0.2 秒」的主因。
# 若将来某目录混入 Android 依赖，脚本会自动跳过并打印提示。
# 注：theme/ 的 QingyuTheme.kt 只放槽位数据类与种子色常量，Compose 接线在 composeP1/，
# 故 theme/ 始终可进 JVM 单测 classpath；真正踩到 androidx.compose/miuix 时下方过滤会拦。
# 注 2（2026-10-28）：`app/` 是 Phase 3.5 接线阶段的**纯逻辑**层（存储抽象 / 领域存储 /
# 仓储）。它必须保持纯 Kotlin——**Android 胶水放 `platform/`，不要放这里**：
# 本脚本的判定是「整目录只要有一个 .kt 引 android.* 就跳过整个目录」，
# 一旦 app/ 混进 android import，全队的 app/ 都会被静默跳过，
# 表现为「测试里 app 的符号全都 Unresolved」。
$sharedModelDirs = @("app", "core", "calendar", "course", "infrastructure", "infra", "statistics", "share", "transfer", "sync", "weather", "widgetdata", "theme")
foreach ($sharedDir in $sharedModelDirs) {
    if ($ExcludeShared -contains $sharedDir) {
        Write-Host ">>> [test-kotlin-module] ⚠️ 按 -ExcludeShared 跳过 $sharedDir/ —— 本次结果**不覆盖**该目录，报告里必须写明" -ForegroundColor Yellow
        continue
    }
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

# 顶层单文件白名单（2026-10-28 新增）。
#
# 有些纯 Kotlin 文件放在包根（`com/mutx163/qingyu/`）而不是共享子目录里，
# 但确实被共享模型层引用——典型是 `FlutterPrefsCodec.kt`（Phase 0 冻结件，
# Phase 3.5 的 `app/` 存储层要拿它编解码）。包根整体不能收（那里有 MainActivity、
# 各种 WidgetProvider 等 Android 文件，纯 Kotlin 判定会整目录跳过），
# 所以这里按**单个文件**点名收。
#
# 收录条件（两个都满足才加）：① 文件本身零 `android.*` / `androidx.compose` / miuix 导入；
# ② 它被共享模型层真实引用。加之前先确认这两条，否则会把 Android 依赖带进 JVM classpath。
$sharedModelFiles = @("FlutterPrefsCodec.kt")
foreach ($sharedFile in $sharedModelFiles) {
    $absSharedFile = Join-Path $repoRoot "android/app/src/main/kotlin/com/mutx163/qingyu/$sharedFile"
    if (-not (Test-Path $absSharedFile)) {
        Write-Host ">>> [test-kotlin-module] 白名单文件不存在，已跳过：$sharedFile" -ForegroundColor DarkYellow
        continue
    }
    if ($sources -notcontains $absSharedFile) { $sources += $absSharedFile }
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

# 5. 同模块互斥锁（粒度 = 模块；不同模块互不阻塞）
#    与 scripts/safe-gradle.ps1 同一套写法：先试 Global\，建不出来降级 Local\；
#    AbandonedMutexException 表示前一个持有者异常退出，锁归当前进程。
#    注意：同一台机器上所有调用方必须落到同一个命名空间才互斥——同一用户、同一会话的
#    进程权限一致，所以这里「都成功建 Global」或「都降级到 Local」，不会一半一半。
$mutexBase = "Mikcb_KotlinModule_${slug}_Mutex"
$mutexName = "Global\$mutexBase"
$mutex = $null
$acquired = $false

try {
    $mutex = [System.Threading.Mutex]::new($false, $mutexName)
} catch {
    $mutexName = "Local\$mutexBase"
    try {
        $mutex = [System.Threading.Mutex]::new($false, $mutexName)
    } catch {
        Write-Error "[test-kotlin-module] 无法创建模块互斥锁（$mutexBase）：$($_.Exception.Message)"
        exit 1
    }
}

$timeoutMs = 600000 # 同模块排队上限 10 分钟
$workRoot = $null

try {
    Write-Host ">>> [test-kotlin-module] 请求同模块锁 [$mutexName] ..." -ForegroundColor Cyan
    try {
        $acquired = $mutex.WaitOne($timeoutMs)
    } catch [System.Threading.AbandonedMutexException] {
        $acquired = $true
    }

    if (-not $acquired) {
        Write-Error "[test-kotlin-module] 等待同模块锁超时（已等 10 分钟）：模块 [$cleanModule] 有另一个 Agent 长期占用，放弃本次执行。"
        exit 1
    }

    # 6. 每次运行独立的临时目录（不再用 build/tmp 下按模块名固定的共享路径）
    #    放系统临时目录而不是仓库 build/：`gradle clean` / 别的会话清 build/ 时不会把
    #    正在编译的输出目录连锅端走（那会变成莫名其妙的「假失败」）。
    $runId = "{0}-{1}-{2}" -f $slug, $PID, ([Guid]::NewGuid().ToString("N").Substring(0, 8))
    $workRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mikcb-l0-$runId"
    $outDir = Join-Path $workRoot "classes"
    $argFile = Join-Path $workRoot "kotlinc.args"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    Write-Host ">>> [test-kotlin-module] 编译模块 [$cleanModule] (文件数: $($sources.Count))，工作目录 $workRoot" -ForegroundColor Cyan

    $classpath = "$junitJar;$hamcrestJar"

    # 大模块（叠上公共模型层后 >100 个 .kt）拼成一条命令行会撞 Windows 32k 上限，
    # 报 "The command line is too long."。改为写 kotlinc 的 @argfile（每行一个参数），
    # 命令行长度与源文件数解耦；argfile 内路径用双引号包住，兼容空格。
    # argfile 是本次运行私有的，别的 Agent 不会覆盖它。
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
    # 先删本次运行私有的临时目录，再放锁：清理也留在锁内，排队者不会和清理抢同一块盘。
    if ($workRoot -and (Test-Path $workRoot)) {
        Remove-Item -Recurse -Force $workRoot -ErrorAction SilentlyContinue
    }
    if ($acquired -and $mutex -ne $null) {
        try { $mutex.ReleaseMutex() } catch { }
    }
    if ($mutex -ne $null) {
        $mutex.Dispose()
    }
}
