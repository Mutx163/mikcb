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

    【两段编译：共享面独立成段 + 内容 hash 缓存（R07，2026-11-11）】
    第 1 段只编**共享面**：`app` / `core` / `calendar` / `course` / `infra` / `statistics` /
    `share` / `transfer` / `sync` / `weather` / `widgetdata` / `theme`（现 157 个 .kt）
    + 根包白名单文件 + 按需 JVM 桩。产物按「共享文件相对路径 + 内容 + kotlinc 指纹」的
    SHA256 缓存到 `%TEMP%\mikcb-l0-shared\<hash>\classes`：共享面没改动就整段跳过——
    这是把每次重复编译那 ~160 个 .kt 从 L0 里拿掉的主要收益。
    第 2 段拿第 1 段的 classes 当 `-cp`，只编本域 main+test+testutil+模块白名单文件。

    失败语义分开（**关键纪律**）：
      · 共享面红 → **点名报错的共享文件** + **exit 78（EX_CONFIG）**，语义是「不是你这一域的问题」：
        别在本域瞎改去绕，先通知共享件所有者；跨域共编同一文件按 AGENTS.md 避让。
      · 本域红 → 原样透传 kotlinc 退出码（1），语义与旧版一致。
    缓存只存成功产物（编译失败不落盘）；落盘先写本次运行私有目录、再整体改名，
    读方不会读到半个 classes。同机多 Agent 冷启动由 `Global\Mikcb_KotlinSharedCache_Mutex`
    串行化（锁序固定：先模块锁、后缓存锁，不成环），没抢到锁的等它编完直接命中，不重复烧 CPU。
    缓存不自动清理（每个 hash 只一份 classes，量很小）；换 kotlinc 或改共享面自然产生新 hash。

    【main 源集里的 Compose/miuix 文件：排除 + WARN，不是静默放过】（2026-11-10）
    渲染层在 `composeP1`，纯 JVM 的 L0 编译面解析不了 `androidx.compose` / `miuix`
    （没有这两个 AAR）。历史上 `pages/timetable/TimetableBandUnderlap.kt`（`ebf87bac5`）
    误落 main，导致**整个域** L0 一片 `unresolved reference 'ui'`，同域所有人失去
    「交活前自测」通道（实测 245 文件全红）。

    现在的语义（**纪律，不是方便**）：
    1. 只把「自己 import 了 Compose/miuix」的那个文件踢出本次编译面，**逐个打印路径**；
       整目录不过滤，`Easing` 这类有 JVM 桩的纯接口不放行（放行见 $jvmStubs）。
    2. 引用被排除声明的测试类同样退出并点名（判据只看代码、剥注释与字符串）。
    3. **被排除文件数 > 0 时，本次 L0 结果不得声明为「该域全绿」**——汇总行会打醒目
       WARN；正式结论以 L1/L2 为准。别拿黄字当绿灯用。
    4. 排除是**过渡手段**：正解是把误落的渲染层文件挪回 `composeP1`（纯数学部分拆回
       main 让测试回 L0）。挪动涉及 main 代码，要单独授权。

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
    [string[]]$ExcludeShared = @(),

    # 显式指定 kotlinc 可执行文件（优先级最高）。
    # 不给时按顺序探测：仓库便携 kotlinc（.tools/kotlinc/bin）→ PATH → Android Studio 内置。
    [Parameter(Mandatory = $false)]
    [string]$KotlincPath
)

$ErrorActionPreference = "Stop"

# 本脚本按仓库既定「全程 pwsh 7」运行：PS 5.1 会把 UTF-8 无 BOM 脚本按 GBK(936) 解析，
# 中文注释/字符串被截断后会报莫名其妙的语法错（如「200:67 缺少 ]」）。
# 这里显式拒绝 5.1，避免用一份看不懂的报错误导排查。
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "[test-kotlin-module] 本脚本要求 PowerShell 7+（当前 $($PSVersionTable.PSVersion)）。请用 C:\dev\pwsh\pwsh.exe -File scripts/test-kotlin-module.ps1 ... 运行。"
    exit 1
}

# 统一规整模块路径（去掉前缀 pages/ 或 android/app/src/...）
$cleanModule = $Module -replace "^android/app/src/(main|test)/kotlin/com/mutx163/qingyu/pages/", "" `
                       -replace "^pages/", "" `
                       -replace "[\\/]+$", ""

# 模块 slug：同时用作互斥锁名与临时目录名，所以必须只含 [A-Za-z0-9_.-]
# （互斥锁名里不能出现反斜杠等字符，临时目录名也不能带路径分隔符）。
$slug = $cleanModule -replace "[^A-Za-z0-9_.\-]", "_"

$repoRoot = Split-Path -Parent $PSScriptRoot

# 1. 定位 kotlinc（顺序：显式参数 → 仓库便携 → PATH → Android Studio 内置）
#    旧版把「Android Studio 内置」当默认、PATH 当兜底，本机没装 Studio 就直接红灯，
#    逼得各代理手搓包装脚本（不可复现）。现在以仓库便携工具链为首选。
$kotlinc = $null
$probed = @()

if ($KotlincPath) {
    $probed += "显式 -KotlincPath: $KotlincPath"
    if (Test-Path $KotlincPath) { $kotlinc = (Resolve-Path $KotlincPath).Path }
}

if (-not $kotlinc) {
    $portable = Join-Path (Split-Path -Parent $repoRoot) ".tools\kotlinc\bin\kotlinc.bat"
    $probed += "仓库便携: $portable"
    if (Test-Path $portable) { $kotlinc = $portable }
}

if (-not $kotlinc) {
    $found = Get-Command kotlinc -ErrorAction SilentlyContinue
    $probed += "PATH: $(if ($found) { $found.Source } else { '<未找到>' })"
    if ($found) { $kotlinc = $found.Source }
}

if (-not $kotlinc) {
    $studio = "C:\Program Files\Android\Android Studio\plugins\Kotlin\kotlinc\bin\kotlinc.bat"
    $probed += "Android Studio 内置: $studio"
    if (Test-Path $studio) { $kotlinc = $studio }
}

if (-not $kotlinc) {
    Write-Error ("[test-kotlin-module] 未找到 kotlinc。探测顺序：-KotlincPath → 仓库便携 → PATH → Android Studio。`n已尝试：`n  - " + ($probed -join "`n  - ") + "`n修法：用 -KotlincPath 显式指定，或把便携 kotlinc 放到 <repo 的上一级>/.tools/kotlinc/bin/kotlinc.bat。")
    exit 1
}

Write-Host ">>> [test-kotlin-module] 使用 kotlinc: $kotlinc" -ForegroundColor DarkCyan

# 2. 定位依赖 JAR
$gradleCache = Join-Path $env:USERPROFILE ".gradle\caches\modules-2\files-2.1"
$junitJar = (Get-ChildItem -Path (Join-Path $gradleCache "junit\junit\4.13.2") -Filter "junit-4.13.2.jar" -Recurse)[0].FullName
$hamcrestJar = (Get-ChildItem -Path (Join-Path $gradleCache "org.hamcrest\hamcrest-core\1.3") -Filter "hamcrest-core-1.3.jar" -Recurse)[0].FullName

# stdlib 优先取 kotlinc 自带的 lib/kotlin-stdlib.jar（与编译器版本一致），
# 落空才退回 Gradle 缓存（旧版写死 Android Studio 的 lib 路径）。
$stdlibJar = Join-Path (Split-Path -Parent (Split-Path -Parent $kotlinc)) "lib\kotlin-stdlib.jar"
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
# 共享面（第 1 段的输入）：与「本域」严格分开收集，两段各编各的。
$sharedSources = @()
# 排除清单与跳过清单的**初值**放在块外：两个 if 分支各自才赋值，缺了初值时无 main 目录的
# 模块（如 `pages/sheetguard` 只有 test/）在读汇总行时会拿到 $null。
$composeMainFiles = @()
$skippedTests = @()
if (Test-Path $mainDir) {
    # main 源集里的 Compose/miuix 文件（2026-11-10 新增过滤）。
    #
    # 本脚本的编译面是**纯 JVM**（JUnit + stdlib + 纯接口桩），而 main 源集按约定只放
    # Android 壳与模型层——渲染层在 composeP1。历史上有人把 Compose 文件写进了
    # `main/.../pages/<模块>/`（活例：`pages/timetable/TimetableBandUnderlap.kt`，`ebf87bac5`
    # 带入），于是整域 L0 在这一个文件上编译失败、同域所有人失去「交活前自测」通道
    # （实测 245 文件、一片 `unresolved reference 'ui'`）。
    #
    # 这里按**文件**过滤（不是整目录）：只有自己 import 了 Compose/miuix 的那个文件退出本次
    # 编译面，并逐个打印出来——不静默跳过。文件的正身等 L1 后的迁移批次再挪进 composeP1，
    # 本脚本不替它做决定。
    #
    # 连带处理：若某个测试类引用的正是被排除文件里的顶层声明（例：`TimetableBandUnderlapTest`
    # 直接调用 `timetableBandStripPx` / `dayPanelHeightPx`），它会编译不过——这类测试同样退出
    # 本次编译面，并单独点名（"测试对象已被排除"），绝不静默吞掉。
    $composeImportPattern = "^\s*import\s+(androidx\.compose|top\.yukonga\.miuix)"
    # 例外：`androidx.compose.animation.core.Easing` 是**纯接口**，脚本已有 JVM 桩
    # （见下方「纯接口 JVM 桩」一节）——只 import 它的纯数学文件（`HomeViewExpandMotion.kt`）
    # 必须留在编译面上，否则它那批纯函数单测会被误伤。
    $stubbedImportPattern = "^\s*import\s+androidx\.compose\.animation\.core\.Easing\s*$"
    $mainFiles = @(Get-ChildItem -Path $mainDir -Filter "*.kt" -Recurse)
    $composeMainFiles = @()
    foreach ($file in $mainFiles) {
        $imports = @(Select-String -Path $file.FullName -Pattern $composeImportPattern -List)
        $onlyStubbed = $imports.Count -gt 0 -and @(
            Select-String -Path $file.FullName -Pattern "^\s*import\s+(?!androidx\.compose\.animation\.core\.Easing\s*$)(androidx\.compose|top\.yukonga\.miuix)" -List
        ).Count -eq 0
        if ($imports.Count -gt 0 -and -not $onlyStubbed) {
            $composeMainFiles += $file.FullName
        } else {
            $sources += $file.FullName
        }
    }
    if ($composeMainFiles.Count -gt 0) {
        Write-Host ">>> [test-kotlin-module] main 源集含 Compose/miuix 导入，退出本次编译面（渲染层文件应放 composeP1）：" -ForegroundColor DarkYellow
        foreach ($file in $composeMainFiles) {
            Write-Host "      · $($file.Substring($repoRoot.Length + 1))" -ForegroundColor DarkYellow
        }
    }
}
if (Test-Path $testDir) {
    # 依赖「已被排除的 main 文件」的测试类同样退出编译面（否则 unresolved reference）。
    # 判据：同包里，测试文件正文引用了被排除文件里的**顶层声明名 + 调用括号**。
    $excludedDeclsByPackage = @{}
    foreach ($file in $composeMainFiles) {
        $raw = Get-Content -Path $file -Raw
        $pkgMatch = [regex]::Match($raw, "(?m)^\s*package\s+([a-zA-Z0-9_\.]+)")
        $pkg = if ($pkgMatch.Success) { $pkgMatch.Groups[1].Value } else { "" }
        $decls = @()
        $decls += [regex]::Matches($raw, "(?m)^\s*(?:internal\s+|public\s+)?(?:const\s+)?fun\s+([A-Za-z0-9_]+)\s*[\(<]") |
            ForEach-Object { $_.Groups[1].Value }
        $decls += [regex]::Matches($raw, "(?m)^\s*(?:internal\s+|public\s+)?(?:const\s+)?val\s+([A-Za-z0-9_]+)") |
            ForEach-Object { $_.Groups[1].Value }
        if (-not $excludedDeclsByPackage.ContainsKey($pkg)) { $excludedDeclsByPackage[$pkg] = @() }
        $excludedDeclsByPackage[$pkg] += @($decls | Select-Object -Unique)
    }
    $skippedTests = @()
    foreach ($file in @(Get-ChildItem -Path $testDir -Filter "*.kt" -Recurse)) {
        $raw = Get-Content -Path $file.FullName -Raw
        $pkgMatch = [regex]::Match($raw, "(?m)^\s*package\s+([a-zA-Z0-9_\.]+)")
        $pkg = if ($pkgMatch.Success) { $pkgMatch.Groups[1].Value } else { "" }
        $decls = if ($excludedDeclsByPackage.ContainsKey($pkg)) { $excludedDeclsByPackage[$pkg] } else { @() }
        # 判据只看**代码**：守卫类测试常把调用写法写在字符串里做断言
        # （如 `s.contains("dayPanelHeightPx(")`），按原文匹配会把它们误判成依赖。
        $code = [regex]::Replace($raw, "(?s)/\*.*?\*/", "")
        $code = [regex]::Replace($code, "(?m)//.*$", "")
        $code = [regex]::Replace($code, '"(\\\\|\\"|[^"\n])*"', '""')
        $referenced = @($decls | Where-Object { $code -match ("\b" + [regex]::Escape($_) + "\s*\(") })
        if ($referenced.Count -gt 0) {
            $skippedTests += "$($file.Name)（引用 $($referenced -join '、')）"
        } else {
            $sources += $file.FullName
        }
    }
    if ($skippedTests.Count -gt 0) {
        Write-Host ">>> [test-kotlin-module] 以下测试类的被测声明在已排除的 Compose 文件里，本次同样不跑（不是静默跳过，报告里要点名）：" -ForegroundColor DarkYellow
        foreach ($item in $skippedTests) { Write-Host "      · $item" -ForegroundColor DarkYellow }
    }
}

# 公共测试工具（testutil/）：跨模块复用的测试侧工具（如 readSourceNormalized 行尾归一化）。
# 它不属于任何页面模块，按模块取源时收不到 ⇒ 这里整目录并入，保证 `-Module pages/<域>` 也能引用。
# 该目录必须保持纯 JVM（只用 java.io），与上面对 main 源集的 Compose 过滤同一纪律。
$testUtilDir = Join-Path $repoRoot "android/app/src/test/kotlin/com/mutx163/qingyu/testutil"
if (Test-Path $testUtilDir) {
    $sources += (Get-ChildItem -Path $testUtilDir -Filter "*.kt" -Recurse).FullName
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
    $dirSources = @(Get-ChildItem -Path $absSharedDir -Filter "*.kt" -Recurse).FullName
    foreach ($src in $dirSources) {
        if ($sharedSources -notcontains $src) { $sharedSources += $src }
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
#
# 2026-10-28 补收录 `WidgetRefreshDecisionLogic.kt`：`833c3484` 新增了它（根包纯逻辑，只有
# `package` 一行、零导入），同时新增的 `app/WidgetRefreshBridge.kt` 直接引用它。上一版白名单
# 没跟上，导致**任何模块**的 L0 都在这两个文件上红（实测 `pages/course` 87 个 error，其中 4 个
# 是这里，另 83 个见下方说明），把整个轻量自测通道拖成摆设。
#
# 仍未修：`app/AddTaskFormReducer.kt` 引用了 `pages/task/TaskModel.kt` 里的类型（同一个
# `833c3484` 批次引入）。`app/` 是**每个模块都收**的共享目录，一旦它反向依赖某个页面域，
# 除该域以外的模块都会红（`pages/course` 那 83 个 error 就是它）。这个只能由来源 `app/`
# 的改动解耦，脚本侧无解——不要用「把所有 pages/ 都收进来」绕，那会让 L0 失去隔离意义。
$sharedModelFiles = @("FlutterPrefsCodec.kt", "WidgetRefreshDecisionLogic.kt")
foreach ($sharedFile in $sharedModelFiles) {
    $absSharedFile = Join-Path $repoRoot "android/app/src/main/kotlin/com/mutx163/qingyu/$sharedFile"
    if (-not (Test-Path $absSharedFile)) {
        Write-Host ">>> [test-kotlin-module] 白名单文件不存在，已跳过：$sharedFile" -ForegroundColor DarkYellow
        continue
    }
    if ($sharedSources -notcontains $absSharedFile) { $sharedSources += $absSharedFile }
}

# 模块专属补充源（2026-11-04 新增）。
#
# 模块目录内的生产代码/用例会引用模块目录之外的**纯 Kotlin**文件，只收本模块
# 目录会报 unresolved。这里按模块列**具体文件**，不整目录收：
# - `pages/sync` 的 `CloudSyncController.kt` 引用 `pages/transfer/` 的快照差异与
#   导入预览逻辑（两个文件，均零 Android import）；
# - `pages/sync` 的 `CouplePartnerUnlinkTest` / `LocaleHashAsciiTest` 直接构造
#   `platform.CouplePartnerPortImpl`（纯 Kotlin 端口实现）。
# `platform/` 整目录不能收——里面还有 Context / AndroidKeyStore 适配层；
# `pages/transfer/` 也不整目录收，避免以后某个页面文件引入 Compose 后把本模块带红。
# 收录条件与上面的根包白名单一致：① 文件零 `android.*` / `androidx.compose` / miuix 导入；
# ② 被本模块真实引用。
$moduleSourceFiles = @{
    "sync" = @(
        "pages/transfer/DataTransferApplyLogic.kt",
        "pages/transfer/DataTransferDiffLogic.kt",
        "pages/transfer/DataTransferImportLogic.kt",
        "pages/transfer/DataTransferModel.kt",
        "pages/transfer/TransferStrings.kt",
        "platform/CouplePartnerPortImpl.kt"
    )
}
if ($moduleSourceFiles.ContainsKey($cleanModule)) {
    foreach ($moduleFile in $moduleSourceFiles[$cleanModule]) {
        $absModuleFile = Join-Path $repoRoot "android/app/src/main/kotlin/com/mutx163/qingyu/$moduleFile"
        if (-not (Test-Path $absModuleFile)) {
            Write-Host ">>> [test-kotlin-module] 模块白名单文件不存在，已跳过：$moduleFile" -ForegroundColor DarkYellow
            continue
        }
        if ($sources -notcontains $absModuleFile) { $sources += $absModuleFile }
    }
}

# 纯接口 JVM 桩（2026-11-05 新增，**按需加载**）。
#
# 背景：模块目录里的源码是**整目录收、不做 Android 判定**的（第 3 步），所以只要目录里有一个
# 文件随手实现了 Compose 的纯接口，整个模块的 L0 就编不过。活例：
# `pages/timetable/HomeViewExpandMotion.kt` 是「时长 + 三次贝塞尔求值」的纯数学文件
# （自述「本文件只放纯函数/纯常量」），只为交给渲染层而 `: Easing` 一下，结果
# `import androidx.compose.animation.core.Easing` 在纯 JVM classpath 下解析不了，
# 同模块所有人都失去「交活前自测」的通道。
#
# 做法：**只在本次收集到的源码真的 import 了某个纯接口时**才把它对应的桩文件加进去。
# `Easing` 在 Compose 里就是 `fun interface Easing { fun transform(fraction: Float): Float }`，
# 无状态、无 Android 依赖，桩与真实签名逐字一致；被 `override` 的实现照常编译、照常被测。
#
# 安全性（为什么不会影响别的模块）：
# 1. 不 import 就不加 —— 其它模块的编译面**一字不变**；
# 2. 只加桩，不改任何收集/过滤规则，`-ExtraSources` / `-ExcludeShared` 语义不变；
# 3. 桩目录只放**纯接口**：模块若真用了 `Modifier` / `Color` / 组合函数，仍然照旧报红
#    （那种文件本来就该待在渲染层，不该靠桩糊过去）。
$jvmStubs = @(
    @{ Path = "scripts/jvm-stubs/ComposeAnimationEasingStub.kt"; Pattern = "^\s*import\s+androidx\.compose\.animation\.core\.Easing\s*$" }
)
foreach ($stub in $jvmStubs) {
    $absStub = Join-Path $repoRoot $stub.Path
    if (-not (Test-Path $absStub)) { continue }
    if ($sources -contains $absStub -or $sharedSources -contains $absStub) { continue }
    # 桩进哪一段有讲究：只塞共享面会让每个域的缓存键都不一样（各域需要的桩不同），
    # 「跨域复用同一份共享 classes」当场失效。所以：共享面需要 → 第 1 段；只有本域需要 → 第 2 段。
    $sharedNeedsStub = if ($sharedSources.Count -gt 0) { @(Select-String -Path $sharedSources -Pattern $stub.Pattern -List) } else { @() }
    if ($sharedNeedsStub.Count -gt 0) {
        Write-Host ">>> [test-kotlin-module] 共享面引用了纯接口 Easing，桩进第 1 段：$($stub.Path)" -ForegroundColor DarkYellow
        $sharedSources += $absStub
        continue
    }
    $domainNeedsStub = if ($sources.Count -gt 0) { @(Select-String -Path $sources -Pattern $stub.Pattern -List) } else { @() }
    if ($domainNeedsStub.Count -gt 0) {
        Write-Host ">>> [test-kotlin-module] 本域引用了纯接口 Easing，桩进第 2 段：$($stub.Path)" -ForegroundColor DarkYellow
        $sources += $absStub
    }
}

$allSources = @($sources) + @($sharedSources)

if ($allSources.Count -eq 0) {
    Write-Error "[test-kotlin-module] 模块 $cleanModule 下未找到任何 .kt 文件。"
    exit 1
}

# 4. 解析测试类全限定名
$testClasses = @()
$testFiles = $allSources | Where-Object { $_ -match "Test\.kt$" }
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

    # 大模块（叠上公共模型层后 >100 个 .kt）拼成一条命令行会撞 Windows 32k 上限，
    # 报 "The command line is too long."。改为写 kotlinc 的 @argfile（每行一个参数），
    # 命令行长度与源文件数解耦；argfile 内路径用双引号包住，兼容空格。
    # argfile 是本次运行私有的，别的 Agent 不会覆盖它。
    # kotlinc 的 argfile 解析器会把引号内的反斜杠当转义符吃掉（C:\xy\... 变成 C:xy...），
    # 因此 argfile 里统一写正斜杠路径；JVM 在 Windows 上接受正斜杠。
    $toSlash = { param($p) $p -replace '\\', '/' }
    $classpath = "$junitJar;$hamcrestJar"

    # ── 第 1 段：共享面独立编译 + 内容 hash 缓存（R07 两段编译，2026-11-11）─────────────
    # 这一段只喂 $sharedSources（共享目录 + 根包白名单 + 按需桩），不含任何本域文件：
    #   · 红了 = 共享件的锅，点名 + exit 78（EX_CONFIG），别在本域瞎改去绕；
    #   · 绿了 = 其 classes 进 -cp，交给第 2 段；同时按内容 hash 落缓存，共享面没动就整段跳过。
    $sharedClassesDir = $null
    if ($sharedSources.Count -gt 0) {
        # 缓存键 = kotlinc 指纹 + 每个共享文件的「相对路径 + 内容」。
        # 用 IncrementalHash 一把算完（157 个文件几十毫秒），不逐个起 Get-FileHash 管道。
        $sha = [System.Security.Cryptography.IncrementalHash]::CreateHash("SHA256")
        $kotlincItem = Get-Item -LiteralPath $kotlinc
        $null = $sha.AppendData([System.Text.Encoding]::UTF8.GetBytes("kotlinc|$kotlinc|$($kotlincItem.Length)|$($kotlincItem.LastWriteTimeUtc.Ticks)"))
        foreach ($src in @($sharedSources | Sort-Object)) {
            $rel = ($src.Substring($repoRoot.Length + 1)) -replace '\\', '/'
            $null = $sha.AppendData([System.Text.Encoding]::UTF8.GetBytes("`nfile|$rel|"))
            $null = $sha.AppendData([System.IO.File]::ReadAllBytes($src))
        }
        $sharedHash = ([System.Convert]::ToHexString($sha.GetHashAndReset())).ToLowerInvariant()
        $sha.Dispose()

        $sharedCacheRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mikcb-l0-shared"
        $sharedCacheDir = Join-Path $sharedCacheRoot $sharedHash
        $sharedCacheClasses = Join-Path $sharedCacheDir "classes"
        $sharedCacheStamp = Join-Path $sharedCacheDir "ok.txt"

        # 冷启动串行化：同机多 Agent 同时没命中缓存时，只让一个真去编，其余等完直接命中。
        # 锁序固定「先模块锁、后缓存锁」，且全局只此一处取缓存锁，不成环。
        # 抢不到（等满 $timeoutMs）就降级为「本次不复用缓存」，绝不把 L0 卡死。
        $sharedMutex = $null
        $sharedLocked = $false
        $sharedMutexName = "Global\Mikcb_KotlinSharedCache_Mutex"
        try {
            try { $sharedMutex = [System.Threading.Mutex]::new($false, $sharedMutexName) }
            catch {
                $sharedMutexName = "Local\Mikcb_KotlinSharedCache_Mutex"
                $sharedMutex = [System.Threading.Mutex]::new($false, $sharedMutexName)
            }
            try { $sharedLocked = $sharedMutex.WaitOne($timeoutMs) }
            catch [System.Threading.AbandonedMutexException] { $sharedLocked = $true }
        } catch {
            $sharedMutex = $null
            Write-Host ">>> [test-kotlin-module] ⚠️ 共享缓存锁建不出来（$($_.Exception.Message)），本次不复用缓存" -ForegroundColor DarkYellow
        }

        try {
            if ((Test-Path -LiteralPath $sharedCacheStamp) -and (Test-Path -LiteralPath $sharedCacheClasses)) {
                $sharedClassesDir = $sharedCacheClasses
                Write-Host ">>> [test-kotlin-module] 第 1 段：共享面 $($sharedSources.Count) 个 .kt 命中缓存 [$($sharedHash.Substring(0,12))]，跳过编译" -ForegroundColor DarkGreen
            } else {
                $sharedOut = Join-Path $workRoot "shared-classes"
                $sharedArgFile = Join-Path $workRoot "kotlinc-shared.args"
                New-Item -ItemType Directory -Path $sharedOut -Force | Out-Null
                $sharedArgLines = @("-cp", "`"$(& $toSlash $classpath)`"", "-d", "`"$(& $toSlash $sharedOut)`"")
                foreach ($src in @($sharedSources | Sort-Object)) { $sharedArgLines += "`"$(& $toSlash $src)`"" }
                Set-Content -Path $sharedArgFile -Value $sharedArgLines -Encoding utf8NoBOM

                $swShared = [System.Diagnostics.Stopwatch]::StartNew()
                Write-Host ">>> [test-kotlin-module] 第 1 段：编译共享面 $($sharedSources.Count) 个 .kt（缓存未命中 [$($sharedHash.Substring(0,12))]）..." -ForegroundColor Cyan
                $sharedLog = & $kotlinc "@$sharedArgFile" 2>&1
                $sharedExit = $LASTEXITCODE
                $swShared.Stop()
                foreach ($line in $sharedLog) { Write-Host $line }

                if ($sharedExit -ne 0) {
                    # 点名：只认带 `.kt:<行>:` 的 error，且只收共享面文件——本域文件不在这段里。
                    $named = @()
                    foreach ($line in $sharedLog) {
                        $m = [regex]::Match([string]$line, "(?i)^\s*(.+?\.kt):(\d+):(?:\d+:)?\s*error:")
                        if (-not $m.Success) { continue }
                        $abs = $m.Groups[1].Value.Trim()
                        if ($abs.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $abs = $abs.Substring($repoRoot.Length).TrimStart('\', '/')
                        }
                        $named += ("{0}:{1}" -f ($abs -replace '\\', '/'), $m.Groups[2].Value)
                    }
                    $named = @($named | Select-Object -Unique)
                    Write-Host ""
                    Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor Red
                    Write-Host "✗ 共享面编译失败：不是 [$cleanModule] 这一域的问题（exit 78 = EX_CONFIG）。" -ForegroundColor Red
                    Write-Host "  先别在本域瞎改去绕；共享件归所有者，跨域共编同一文件按 AGENTS.md 避让。" -ForegroundColor Red
                    if ($named.Count -gt 0) {
                        Write-Host "  报错的共享面文件（$($named.Count) 处，点名如下）：" -ForegroundColor Red
                        foreach ($n in $named) { Write-Host "    · $n" -ForegroundColor Red }
                    } else {
                        Write-Host "  kotlinc 没吐可解析的「文件:行」error，原始输出见上。" -ForegroundColor Red
                    }
                    Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor Red
                    exit 78
                }

                # 只把**成功产物**落缓存：先编进本次运行私有目录，再整体改名进缓存目录，
                # 读方永远看不到半个 classes；失败不写，坏产物不会污染下次。
                New-Item -ItemType Directory -Path $sharedCacheDir -Force | Out-Null
                if (Test-Path -LiteralPath $sharedCacheClasses) {
                    Remove-Item -LiteralPath $sharedCacheClasses -Recurse -Force -ErrorAction SilentlyContinue
                }
                try {
                    Move-Item -LiteralPath $sharedOut -Destination $sharedCacheClasses -ErrorAction Stop
                    Set-Content -LiteralPath $sharedCacheStamp -Value $sharedHash -Encoding utf8NoBOM
                    Write-Host ">>> [test-kotlin-module] 第 1 段通过（$([math]::Round($swShared.Elapsed.TotalSeconds,1)) s），已缓存 [$($sharedHash.Substring(0,12))]" -ForegroundColor DarkGreen
                } catch {
                    Write-Host ">>> [test-kotlin-module] ⚠️ 缓存落盘失败（$($_.Exception.Message)），本次直接用临时产物" -ForegroundColor DarkYellow
                }
                $sharedClassesDir = if (Test-Path -LiteralPath $sharedCacheClasses) { $sharedCacheClasses } else { $sharedOut }
            }
        } finally {
            if ($sharedLocked -and $sharedMutex -ne $null) { try { $sharedMutex.ReleaseMutex() } catch { } }
            if ($sharedMutex -ne $null) { $sharedMutex.Dispose() }
        }
    } else {
        Write-Host ">>> [test-kotlin-module] 共享面为空（被 -ExcludeShared 排除了？），直接编本域" -ForegroundColor DarkYellow
    }

    # ── 第 2 段：本域 main+test+testutil+模块白名单，用共享面 classes 当 -cp ────────────
    $domainCp = if ($sharedClassesDir) { "$sharedClassesDir;$classpath" } else { $classpath }
    if ($sources.Count -eq 0) {
        Write-Host ">>> [test-kotlin-module] 本域没有可编译源（全部被 Compose 过滤或跳过），共享面已通过，无测试可跑。" -ForegroundColor Yellow
        exit 0
    }
    $argLines = @("-cp", "`"$(& $toSlash $domainCp)`"", "-d", "`"$(& $toSlash $outDir)`"")
    foreach ($src in $sources) { $argLines += "`"$(& $toSlash $src)`"" }
    Set-Content -Path $argFile -Value $argLines -Encoding utf8NoBOM
    Write-Host ">>> [test-kotlin-module] 第 2 段：编译本域 [$cleanModule]（本域 $($sources.Count) 个 .kt，共享面 $($sharedSources.Count) 个已就绪），工作目录 $workRoot" -ForegroundColor Cyan
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
    # 共享面的 classes 必须在运行期 classpath 上：本域 classes 只是引用它，不重复打包。
    $runClasspath = if ($sharedClassesDir) { "$outDir;$sharedClassesDir;$junitJar;$hamcrestJar;$stdlibJar" } else { "$outDir;$junitJar;$hamcrestJar;$stdlibJar" }
    
    java -cp $runClasspath org.junit.runner.JUnitCore @testClasses
    $testExitCode = $LASTEXITCODE

    # 汇总 WARN（2026-11-10，Chief 要求）：只要本次排除了 main 源集里的 Compose/miuix 文件，
    # 这一跑就**不是**「该域全绿」——黄字必须醒目到不能当绿灯用。正式结论以 L1/L2 为准。
    if (@($composeMainFiles).Count -gt 0) {
        Write-Host ""
        Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor Yellow
        Write-Host "WARN ⚠ 本次 L0 排除了 $(@($composeMainFiles).Count) 个 main 源集里的 Compose/miuix 文件：" -ForegroundColor Yellow
        foreach ($file in $composeMainFiles) {
            Write-Host "      · $($file.Substring($repoRoot.Length + 1))" -ForegroundColor Yellow
        }
        if (@($skippedTests).Count -gt 0) {
            Write-Host "WARN ⚠ 同时跳过了 $(@($skippedTests).Count) 个测试类：$($skippedTests -join '；')" -ForegroundColor Yellow
        }
        Write-Host "WARN ⚠ 因此本域 L0 结果**不得**声明为「全绿」（被排除文件数 > 0）。" -ForegroundColor Yellow
        Write-Host "      路过的 JUnit 条数只代表剩下那部分源码；正式结论以 safe-gradle L1/L2 为准。" -ForegroundColor Yellow
        Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor Yellow
        Write-Host ""
    }

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
