<#
.SYNOPSIS
    composeP1（Compose 渲染层）的**免 Gradle 类型检查通道**：没人抢全机编译锁也能发现
    「悬空引用 / 签名不匹配 / import 缺失」这三类编译错。

.DESCRIPTION
    ## 它是什么

    用 **真实 classpath**（compose 1.12 / miuix 0.9.4 / activity / lifecycle / android.jar）
    直接跑 `kotlinc` 编一遍指定源码根，再把 kotlinc 的 error 与一份**基线**做差量，
    只报「**新增 / 消失**」。不是语法解析——类型检查、重载解析、可见性都走真编译器。

    ## ⚠️ 硬边界：它**永远不等于 L1**

    - 没有 Compose 编译器插件（`org.jetbrains.kotlin.plugin.compose`）：`@Composable` 的
      一部分检查（可组合性、`remember` 用法、lambda 捕获等）它看不见；反过来**缺插件也可能
      产出假错**（某个 `@Composable` 函数在它眼里就是普通函数）。
    - 没有资源 / 变体 / Flutter 资源链 / AGP 任务图：`R.*`、manifest、变体专属源集全都缺席。
    - 所以它的定位是 **L0 之外的「composeP1 早筛」**：只用来**压低整包 L1 的失败率**，
      **不能替代整包门禁**。绿了不等于能编过，还是要等 L1。

    ## 资源纪律（多人并行时）

    每次运行约 **1 GB** 内存（kotlinc JVM），耗时热跑 ~1.5 分钟。它**不占** `safe-gradle.ps1`
    的全机互斥锁，所以可以并行——但**同刻建议不超过 2~3 个实例**，否则会把 32 GB 的机器压满、
    连带把别人正在跑的 gradle/L0 拖死。

    ## 基线（棘轮）怎么用

    基线文件：`scripts/typecheck-compose-baseline.txt`（进 git，一行一条：
    `相对路径|<error 消息>`，**不含行列号**——这样上面的行位移不会让基线整片漂）。

    ```powershell
    pwsh -File scripts/typecheck-compose.ps1              # 只报新增/消失；新增则以 exit 1 结束
    pwsh -File scripts/typecheck-compose.ps1 -Write       # 重写基线（收编当前所有 error）
    pwsh -File scripts/typecheck-compose.ps1 -Full        # 连「未变化」的 error 一起打印
    pwsh -File scripts/typecheck-compose.ps1 -ExtraSources "android/app/src/main/kotlin/com/mutx163/qingyu/pages/exam"
    ```

    规矩与 CJK 棘轮、copy_style 三份基线一致：**不许为了让提交变绿往基线里加行**；
    确需收编（例如别人半成品带来的既有 error）时，改动原因写进提交说明，并在 PR/回报里点明。
    基线少了行也要跟着**删掉**（脚本会报「消失」，确认后 `-Write` 收敛）。

    ## 退出码 / 什么时候不能信它

    - `0` = 没有新增 error（可能有「消失」，会顺带提示收敛基线）；
    - `1` = 有新增 error（看红色 `+` 行）；
    - `2` = **kotlinc 自己崩了**（OOM / 栈溢出），本次结果不可信：既不写基线、也不当通过。
      崩掉的输出里 often 一条 error 都没有，**不要当成全绿**。崩了就调大 `$env:JAVA_OPTS` 的 `-Xmx`
      （脚本默认已设 `-Xmx4096m`；注意 `-J-Xmx…` 写在 argfile 里不生效，只能走环境变量）。
    - 每次运行的原始 kotlinc 输出落在 `$env:TEMP\mikcb-compose-typecheck\kotlinc-raw.txt`，怀疑漏报就去翻它。
    - 基线里出现 `<raw>|…` 行 = 有含 `error:` 但解析不出文件位置的输出（说明解析正则要更新），**不是噪音**。

    ## 已知缺口（会产出「假错」，别当成真 bug）

    - 未挂的第三方库（datastore / okhttp / flutter embedding 等）会报 unresolved；
    - 未挂的源码目录同理——所以 `$SourceRoots` 里必须包含**被扫文件所引用的域**；
      查不住就补 `-ExtraSources`，不要改脚本里的写死部分。

.PARAMETER ExtraSources
    额外的源码根或单个 .kt（相对仓库根，可多个）。用来把某个域临时纳入扫描。

.PARAMETER Write
    把本次的 error 全集写回基线（棘轮收编）。

.PARAMETER Full
    除了差量，还把「未变化」的 error 全打出来（排查用）。

.PARAMETER BaselinePath
    自定义基线文件路径（默认 `scripts/typecheck-compose-baseline.txt`）。
#>
param(
    [string[]]$ExtraSources = @(),
    [switch]$Write,
    [switch]$Full,
    [string]$BaselinePath
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "[typecheck-compose] 本脚本要求 PowerShell 7+（当前 $($PSVersionTable.PSVersion)）。"
    exit 1
}

$repo = Split-Path -Parent $PSScriptRoot
$libDir = Join-Path $env:TEMP "mikcb-compose-typecheck-lib"
$workDir = Join-Path $env:TEMP "mikcb-compose-typecheck"
foreach ($d in @($libDir, $workDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
if (-not $BaselinePath) { $BaselinePath = Join-Path $repo "scripts/typecheck-compose-baseline.txt" }

$mainRoot = Join-Path $repo "android/app/src/main/kotlin/com/mutx163/qingyu"
$composeRoot = Join-Path $repo "android/app/src/composeP1/kotlin/com/mutx163/qingyu"

# 源码根：**页面渲染层 + 它依赖的纯 Kotlin 域**。
#
# 1) 共享纯目录表与 `scripts/test-kotlin-module.ps1` 的 `$sharedModelDirs` **同一张**
#    （那批目录在 L0 里能纯 JVM 编，纯度已被实践证实）。历史上漏了 calendar/course 等，
#    直接导致 1508 条「假错」——新增目录时先确认它没有 Android/Compose 依赖之外的东西。
# 2) `platform/` 单独挂：面壁纸、Preference、KeyValueStore 等宿主适配层，页面到处引用它。
# 3) 页面目录**整目录挂**，不要只挂子目录：旧版只挂了 `composeP1/.../pages/timetable/day`，
#    结果 `composeP1/.../pages/timetable` 根目录的文件（首页下拉等）**一次都没被扫到**。
$SourceRoots = @()
foreach ($shared in @(
        "app", "core", "calendar", "course", "infrastructure", "infra", "statistics",
        "share", "transfer", "sync", "weather", "widgetdata", "theme", "platform"
    )) {
    $SourceRoots += (Join-Path $mainRoot $shared)
}
$SourceRoots += @(
    (Join-Path $mainRoot "pages"),
    (Join-Path $composeRoot "app"),
    (Join-Path $composeRoot "components"),
    (Join-Path $composeRoot "pages")
)

# 包根的顶层 .kt **不纳入**：那一层是宿主胶水（`MainActivity`、各 `*WidgetProvider`、
# `LiveUpdateService`…），普遍引用 `R.*`（构建期由 AGP 生成，这里永远没有）和 Flutter 桥
# （`MethodChannel` / `dartExecutor`），实测一纳入就多出约 900 条纯假错（705 条是 `R`）。
# 唯一例外是下面这个纯 Kotlin 的偏好编解码，引用方在 app/ 里。
$Files = @(
    "android/app/src/main/kotlin/com/mutx163/qingyu/FlutterPrefsCodec.kt"
)

# 显式排除：**需要生成资源 / Flutter embedding 的宿主壳文件**。
# 它们不是页面渲染层，改它们的是 Lead（Activity / manifest 链路），而且在这里必然报假错
# （`FlutterActivity` 父类、`R.*`、`GeneratedPluginRegistrant` 都不在 classpath 里）。
# 要放宽就先确认上面那几类依赖能从 jar 补上，别为了「扫得全」把假错灌进基线。
$SkipFiles = @(
    "android/app/src/main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt",
    "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellExternalEntryActivity.kt",
    "android/app/src/main/kotlin/com/mutx163/qingyu/PagesShellActivity.kt",
    "android/app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt"
)

$cache = Join-Path $env:USERPROFILE ".gradle/caches/modules-2/files-2.1"
$wanted = @(
    @{ g = "androidx.compose.runtime"; a = "runtime-android"; v = "1.12.0" },
    @{ g = "androidx.compose.runtime"; a = "runtime-annotation-android"; v = "1.12.0" },
    @{ g = "androidx.compose.runtime"; a = "runtime-saveable-android"; v = "1.12.0" },
    @{ g = "androidx.compose.ui"; a = "ui-android"; v = "1.12.0" },
    @{ g = "androidx.compose.ui"; a = "ui-graphics-android"; v = "1.12.0" },
    @{ g = "androidx.compose.ui"; a = "ui-geometry-android"; v = "1.12.0" },
    @{ g = "androidx.compose.ui"; a = "ui-text-android"; v = "1.12.0" },
    @{ g = "androidx.compose.ui"; a = "ui-unit-android"; v = "1.12.0" },
    @{ g = "androidx.compose.ui"; a = "ui-util-android"; v = "1.12.0" },
    @{ g = "androidx.compose.foundation"; a = "foundation-android"; v = "1.12.0" },
    @{ g = "androidx.compose.foundation"; a = "foundation-layout-android"; v = "1.12.0" },
    @{ g = "androidx.compose.animation"; a = "animation-android"; v = "1.12.0" },
    @{ g = "androidx.compose.animation"; a = "animation-core-android"; v = "1.12.0" },
    @{ g = "androidx.activity"; a = "activity"; v = "1.13.0" },
    @{ g = "androidx.activity"; a = "activity-compose"; v = "1.13.0" },
    # 页面里普遍用 `androidx.lifecycle.compose.LocalLifecycleOwner`（AppearanceEditorHost 等），
    # 旧的通道没挂这个 jar，把真引用报成 unresolved。
    @{ g = "androidx.lifecycle"; a = "lifecycle-runtime-compose-android"; v = "2.9.4" },
    @{ g = "androidx.lifecycle"; a = "lifecycle-viewmodel-compose-android"; v = "2.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-ui-android"; v = "0.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-preference-android"; v = "0.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-icons-android"; v = "0.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-core-android"; v = "0.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-squircle-android"; v = "0.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-blur-android"; v = "0.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-nav-android"; v = "0.9.4" },
    @{ g = "top.yukonga.miuix.kmp"; a = "miuix-shader-android"; v = "0.9.4" },
    @{ g = "androidx.lifecycle"; a = "lifecycle-runtime-android"; v = "2.9.4" },
    # 宿主 Activity / ComponentActivity 的父类链：缺一个就会连锁报
    # 「cannot access 'androidx.core.app.ComponentActivity' which is a supertype of …」几十条。
    @{ g = "androidx.core"; a = "core"; v = "1.15.0" },
    @{ g = "androidx.core"; a = "core-ktx"; v = "1.15.0" },
    @{ g = "androidx.lifecycle"; a = "lifecycle-viewmodel-android"; v = "2.9.4" },
    @{ g = "androidx.lifecycle"; a = "lifecycle-viewmodel-savedstate-android"; v = "2.9.4" },
    @{ g = "androidx.savedstate"; a = "savedstate-android"; v = "1.3.3" },
    @{ g = "androidx.navigationevent"; a = "navigationevent-android"; v = "1.1.2" }
)

foreach ($w in $wanted) {
    $dir = Join-Path $cache "$($w.g)/$($w.a)/$($w.v)"
    if (-not (Test-Path $dir)) { Write-Host "MISSING artifact dir: $dir" -ForegroundColor DarkYellow; continue }
    $aar = (Get-ChildItem -Path $dir -Filter "*.aar" -Recurse | Select-Object -First 1)
    $out = Join-Path $libDir ("{0}-{1}.jar" -f $w.a, $w.v)
    if (Test-Path $out) { continue }
    if ($aar) {
        $tmp = Join-Path $env:TEMP ("aar-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Copy-Item $aar.FullName (Join-Path $tmp "a.zip")
        Expand-Archive -Path (Join-Path $tmp "a.zip") -DestinationPath $tmp -Force
        $cj = Join-Path $tmp "classes.jar"
        if (Test-Path $cj) {
            Copy-Item $cj $out -Force
        } else {
            Write-Host "no classes.jar in $($aar.Name)" -ForegroundColor DarkYellow
        }
        Remove-Item -Recurse -Force $tmp
    } else {
        Write-Host "MISSING aar: $($w.g):$($w.a):$($w.v)" -ForegroundColor DarkYellow
    }
}

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA "Android/Sdk" }
if (-not (Test-Path $sdk)) { throw "[typecheck-compose] 找不到 Android SDK：$sdk" }
$androidJar = Get-ChildItem -Path (Join-Path $sdk "platforms") -Filter "android.jar" -Recurse |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $androidJar) { throw "[typecheck-compose] $sdk 下找不到 platforms/*/android.jar" }

# kotlinc：仓库便携工具链优先，其次 PATH，最后 Android Studio 内置（与 L0 同一探测顺序）。
$kotlinc = $null
$portable = Join-Path (Split-Path -Parent $repo) ".tools\kotlinc\bin\kotlinc.bat"
if (Test-Path $portable) {
    $kotlinc = $portable
} else {
    $found = Get-Command kotlinc -ErrorAction SilentlyContinue
    if ($found) {
        $kotlinc = $found.Source
    } else {
        $studio = "C:\Program Files\Android\Android Studio\plugins\Kotlin\kotlinc\bin\kotlinc.bat"
        if (Test-Path $studio) { $kotlinc = $studio }
    }
}
if (-not $kotlinc) { throw "[typecheck-compose] 未找到 kotlinc（探测了便携 / PATH / Android Studio）" }

$jarList = New-Object System.Collections.Generic.List[string]
foreach ($j in (Get-ChildItem -Path $libDir -Filter *.jar).FullName) { $jarList.Add($j) }

# 纯 jar 依赖（不是 aar）：协程 / 注解 / collection
$plainWanted = @(
    @{ g = "org.jetbrains.kotlinx"; a = "kotlinx-coroutines-core-jvm" },
    @{ g = "org.jetbrains.kotlinx"; a = "kotlinx-coroutines-android" },
    @{ g = "androidx.annotation"; a = "annotation-jvm" },
    @{ g = "androidx.collection"; a = "collection-jvm" },
    @{ g = "androidx.lifecycle"; a = "lifecycle-common-jvm" }
)
foreach ($w in $plainWanted) {
    $dir = Join-Path $cache $w.g
    if (-not (Test-Path $dir)) { continue }
    $hit = Get-ChildItem -Path (Join-Path $dir $w.a) -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*sources*" -and $_.Name -notlike "*javadoc*" } |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($hit) { $jarList.Add($hit.FullName) } else { Write-Host "no plain jar for $($w.a)" -ForegroundColor DarkYellow }
}
$cp = (($jarList + $androidJar.FullName) -join ";")
function To-Slash([string]$p) { return $p -replace '\\', '/' }

$fileList = New-Object System.Collections.Generic.List[string]
foreach ($dir in $SourceRoots) {
    if (-not (Test-Path $dir)) {
        Write-Host "MISSING source root: $dir" -ForegroundColor DarkYellow
        continue
    }
    Get-ChildItem -Path $dir -Filter *.kt -Recurse | ForEach-Object { $fileList.Add($_.FullName) }
}
foreach ($f in $Files) {
    $abs = Join-Path $repo $f
    if (Test-Path $abs) { $fileList.Add($abs) }
}
# 排除宿主壳文件（原因见上面 $SkipFiles 的注释）。
$skipFull = @{}
foreach ($s in $SkipFiles) { $skipFull[(Join-Path $repo $s)] = $true }
if ($skipFull.Count -gt 0) {
    $before = $fileList.Count
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($f in $fileList) { if (-not $skipFull.ContainsKey($f)) { $kept.Add($f) } }
    $fileList = $kept
    $skipped = $before - $fileList.Count
    if ($skipped -gt 0) { Write-Host ">>> 已排除 $skipped 个宿主壳文件（需生成资源/Flutter embedding，见脚本注释）" -ForegroundColor DarkCyan }
}
# `-ExtraSources`：相对仓库根的目录或单个 .kt（真正的生效点——旧版声明了却没用）。
foreach ($extra in $ExtraSources) {
    $abs = (Resolve-Path (Join-Path $repo $extra)).Path
    if (-not (Test-Path $abs)) {
        Write-Host "MISSING -ExtraSources: $extra" -ForegroundColor DarkYellow
        continue
    }
    if ((Get-Item $abs).PSIsContainer) {
        Get-ChildItem -Path $abs -Filter *.kt -Recurse | ForEach-Object { $fileList.Add($_.FullName) }
    } else {
        $fileList.Add($abs)
    }
}

$outDir = Join-Path $workDir "out"
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
$argFile = Join-Path $workDir "sources.txt"
$argLines = @(
    "-cp", "`"$(& To-Slash $cp)`"",
    "-jvm-target", "21",
    "-nowarn",
    "-d", "`"$(& To-Slash $outDir)`""
)
$uniqueSources = $fileList | Sort-Object -Unique
foreach ($f in $uniqueSources) { $argLines += "`"$(& To-Slash $f)`"" }
Set-Content -Path $argFile -Value $argLines -Encoding UTF8

Write-Host ">>> [typecheck-compose] 源码 $($uniqueSources.Count) 个 / jar $($jarList.Count) 个，开始编译…" -ForegroundColor DarkCyan
# ⚠️ `kotlinc.bat` 在 `JAVA_OPTS` 未设置时只给 **-Xmx512M**，700+ 源文件会**随机** OutOfMemoryError
# （同一份代码有时能过、有时 43 秒就崩），崩掉的那次输出里一条 error 都没有，会被误读成「全绿」。
# 所以这里显式抬高堆；注意 `-J-Xmx…` 写在 @argfile 里**不生效**，只能走环境变量。
$env:JAVA_OPTS = "-Xmx4096m -Xms512m -Dfile.encoding=UTF-8"
$sw = [Diagnostics.Stopwatch]::StartNew()
$raw = & $kotlinc "@$argFile" 2>&1
$sw.Stop()
if ($env:TEMP) {
    Set-Content -Path (Join-Path $workDir "kotlinc-raw.txt") -Value $raw -Encoding UTF8
}

# 编译器自己崩了（OOM / 栈溢出）：这次的结果**不可信**，既不写基线也不算通过。
$crashed = @($raw | Where-Object { $_.ToString() -match 'exception: java\.|OutOfMemoryError|StackOverflowError' })
if ($crashed.Count -gt 0) {
    Write-Host ">>> kotlinc 崩了，本次结果不可信（不写基线、不算通过）：" -ForegroundColor Red
    $crashed | Select-Object -Unique | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Write-Host ">>> 调大 `$env:JAVA_OPTS 的 -Xmx（当前脚本设的是 4096m）后重跑；raw 输出在 $(Join-Path $workDir 'kotlinc-raw.txt')" -ForegroundColor DarkYellow
    exit 2
}

# ── 归一化：`路径:行:列: error: 消息` → `相对路径|消息` ──
# 故意**丢掉行列号**：任何一次编辑都会让后面的行整体位移，按行列做基线会整片漂。
#
# ⚠️ 两处曾经踩过的坑（改这段前先看）：
# 1) 路径不能用 `[^:]+\.kt` 匹配——Windows 盘符 `C:` 里就有冒号，正则会一条都匹配不上，
#    而落不到任何分支的 error 行会被**静默丢掉**，输出看着是「0 条 error」的假绿。所以用贪婪 `.+\.kt`。
# 2) kotlinc 拿到的是 `To-Slash` 后的正斜杠路径，所以剥仓库前缀也要用正斜杠版本，
#    否则基线里会存下 `C:/cursor/...` 这种换台机器就失效的绝对路径。
$repoSlash = To-Slash $repo
$rel = {
    param($p)
    $s = $p.Replace("\", "/")
    if ($s.StartsWith($repoSlash + "/")) { $s = $s.Substring($repoSlash.Length + 1) }
    return $s
}
$current = New-Object System.Collections.Generic.List[string]
$unparsed = New-Object System.Collections.Generic.List[string]
$dropped = New-Object System.Collections.Generic.List[string]
foreach ($line in $raw) {
    $text = $line.ToString()
    $m = [regex]::Match($text, '^(?<path>.+\.kt):(?<line>\d+):(?<col>\d+): error: (?<msg>.*)$')
    if ($m.Success) {
        $current.Add((& $rel $m.Groups['path'].Value) + "|" + $m.Groups['msg'].Value.Trim())
        continue
    }
    if ($text -match '^\s*error: (?<msg>.*)$') {
        $unparsed.Add($Matches['msg'].Trim())
        $current.Add("<no-file>|" + $Matches['msg'].Trim())
        continue
    }
    # 兜底：任何含 `error:` 却没被上面两条吃下的行都不许丢（宁可多报，不能假绿）。
    if ($text -match 'error:') { $dropped.Add($text.Trim()) }
}
if ($dropped.Count -gt 0) {
    Write-Host ">>> 有 $($dropped.Count) 行含 error 但没解析出文件位置，按 <raw> 记入（脚本解析 regex 需要更新）：" -ForegroundColor DarkYellow
    $dropped | Select-Object -Unique | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
    foreach ($d in $dropped) { $current.Add("<raw>|" + $d) }
}
$current = @($current | Sort-Object)

$baseline = @()
if (Test-Path $BaselinePath) {
    # 注释行以 `#` 开头（文件头说明），不算条目。
    $baseline = @(Get-Content -Path $BaselinePath |
            Where-Object { $_.Trim() -ne "" -and $_.Trim() -notmatch '^#' } |
            ForEach-Object { $_.Trim() } | Sort-Object)
}

function Compare-Multiset {
    param([string[]]$Left, [string[]]$Right)
    # 多重集差分：同一条 error 可能在多个文件重复出现，不能用 Set 差集。
    $rightCount = @{}
    foreach ($item in $Right) { if ($rightCount.ContainsKey($item)) { $rightCount[$item]++ } else { $rightCount[$item] = 1 } }
    $added = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Left) {
        if ($rightCount.ContainsKey($item) -and $rightCount[$item] -gt 0) { $rightCount[$item]-- } else { $added.Add($item) }
    }
    return $added
}

$added = @(Compare-Multiset -Left $current -Right $baseline)
$removed = @(Compare-Multiset -Left $baseline -Right $current)

Write-Host (">>> [typecheck-compose] 编译完成：{0} 个源文件，耗时 {1:N1}s，error 去重后 {2} 条（基线 {3} 条）" -f `
        $uniqueSources.Count, $sw.Elapsed.TotalSeconds, $current.Count, $baseline.Count) -ForegroundColor DarkCyan
if ($unparsed.Count -gt 0) {
    Write-Host ">>> 其中 $($unparsed.Count) 条是**没有文件位置**的 error（多半是 classpath / 插件级问题），已记为 <no-file>：" -ForegroundColor DarkYellow
    $unparsed | Select-Object -Unique | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkYellow }
}

function Write-BaselineFile {
    param([string[]]$Entries)
    $dir = Split-Path -Parent $BaselinePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $header = @(
        "# composeP1 早筛基线（scripts/typecheck-compose.ps1 用；一行一条 `相对路径|error 消息`，不含行列）",
        "# 这是**棘轮**不是豁免清单：清掉的要删行（跑 -Write 收敛），不许为了让提交变绿往里加行。",
        "# 它 != L1：没有 Compose 编译器插件/资源/变体，只能压整包门禁失败率，不能替门禁。"
    )
    # 行尾统一 LF、UTF-8 无 BOM（仓库口径；`Set-Content` 默认会写 CRLF 带不留 BOM 的差别）。
    $text = (($header + $Entries) -join "`n") + "`n"
    [IO.File]::WriteAllText($BaselinePath, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Host ">>> 基线已写入：$BaselinePath（$($Entries.Count) 条）" -ForegroundColor Green
}

if ($Write) {
    Write-BaselineFile -Entries $current
    exit 0
}

if (-not (Test-Path $BaselinePath)) {
    Write-Host ">>> 基线不存在，先落一份（等同于 -Write）" -ForegroundColor DarkYellow
    Write-BaselineFile -Entries $current
    Write-Host ">>> 重跑一次即可看到干净的差量。" -ForegroundColor Green
    exit 0
}

if ($Full) {
    Write-Host ">>> 全部 error（含未变化）：" -ForegroundColor DarkCyan
    $current | ForEach-Object { Write-Host "    $_" }
}

if ($added.Count -eq 0) {
    if ($removed.Count -gt 0) {
        Write-Host ">>> 没有新增；基线里 $($removed.Count) 条已消失（顺手跑一次 -Write 收敛基线）：" -ForegroundColor Yellow
        $removed | Select-Object -First 20 | ForEach-Object { Write-Host "    - $_" }
    } else {
        Write-Host ">>> 与基线一致，没有新增 error。" -ForegroundColor Green
    }
    exit 0
}

Write-Host ">>> 新增 $($added.Count) 条 error（基线 $($baseline.Count) 条 → 现在 $($current.Count) 条）：" -ForegroundColor Red
$added | ForEach-Object { Write-Host "    + $_" -ForegroundColor Red }
Write-Host ">>> 提示：确认是你引入的就修；若是别人半成品/未挂的库，先别往基线里加，找 Chief 报备。" -ForegroundColor DarkYellow
exit 1
