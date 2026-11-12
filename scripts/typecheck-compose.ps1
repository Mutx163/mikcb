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

    每次运行约 **1 GB** 内存（kotlinc JVM），耗时热跑 1~3 分钟。它**不占** `safe-gradle.ps1`
    的全机互斥锁。2026-11-10 起**每次运行用独立临时目录**（pid + guid，含解出的 AAR jar 与
    `sources.txt` / `out/` / `stubs/` / `kotlinc-raw.txt`）⇒ 并发实例之间零共享写盘点，
    结果不会互相踩；但每个实例约 1 GB 内存，**同刻仍建议不超过 2~3 个**，否则会把机器压满、
    连带把别人正在跑的 gradle/L0 拖死。运行结束的目录不自动删（raw 日志是排查证据），路径在
    每次输出首行打印。

    ## 2026-11-10 修复：把「假错」从源头消掉（数字：657 → 1 条已知类别）

    旧版早筛被大面积假错淹没（不容错的口径下无法当门禁信号）。这次逐类修在源头：
    - **包根顶层 `.kt` 纳入源集**：去 Flutter 化后那层已无 `io.flutter` 依赖，不纳入会让
      compose 页面引用 `WeeklyReportScheduler` / `LiveUpdateScheduler` 等宿主件被报 unresolved；
    - **R / BuildConfig 生成桩**：AGP 构建期才有的类，从真实 `res/` 与 `build.gradle` 生成
      （新增资源/字段不会漏），消掉旧基线里 R/BuildConfig 两类假错；
    - **classpath 补齐**：`ui-tooling-preview`（`@Preview`，实测 422 条假错）、CameraX + ML Kit
      （扫码页整页）、WorkManager / 友盟（纳入包根后）、`org.jspecify`（ML Kit 签名注解）、
      `androidx.core` 抬到 app 实际解析口径（1.19.1，缺 `PictureInPictureProvider` 会连锁报）；
    - **宿主 Activity 重新纳入**（`$SkipFiles` 清空）：它们已不依赖 Flutter/资源，而且包根
      `NotificationLaunchTarget` / `ScheduleReminderScheduler` 会引用 `PagesShellActivity`。
    剩余的**结构上消不掉**的缺口登记在 `scripts/typecheck-compose-known.txt`（每条必须写原因）。

    ## 基线（棘轮）怎么用

    基线文件：`scripts/typecheck-compose-baseline.txt`（进 git，一行一条：
    `相对路径|<error 消息>`，**不含行列号**——这样上面的行位移不会让基线整片漂）。
    修复后基线目标**长期保持 0 条**：已知类别进 `known.txt`，基线只收「还没修的真错」。

    ```powershell
    pwsh -File scripts/typecheck-compose.ps1              # 只报新增/消失；新增则以 exit 1 结束
    pwsh -File scripts/typecheck-compose.ps1 -Write       # 只许删行；有任何新增则**拒绝写入**（exit 3）
    pwsh -File scripts/typecheck-compose.ps1 -Init        # 基线不存在时首次落盘（唯一放行通道）
    pwsh -File scripts/typecheck-compose.ps1 -Full        # 连「未变化」的 error 一起打印
    pwsh -File scripts/typecheck-compose.ps1 -ExtraSources "..."
    ```

    ## `-Write` 的语义（2026-11-12 收口，与 CJK / copy-gap 两个 `--write` 同一套）

    **基线只许降不许升。** 旧版 `-Write` 是「把当前所有 error 整段写回基线」——红了顺手跑一跑，
    diff 与正常收敛长得一模一样，事后查不出来（force-write 同族开关）。

    现在的两阶段：

    1. 先把「本次待处理」与旧基线做**多重集**比对；
    2. **任何新增 / 上调 ⇒ 拒绝写入**：一个字节不动、打印新增条目、`exit 3`；
    3. 只有「只删不增」才落盘（error 被修掉了 ⇒ 基线可以缩）。

    口径写死在这里：**要消掉新增，只能修代码，或登记到 `typecheck-compose-known.txt` 并写清原因**；
    `-Write` 不是收编工具。基线文件被删掉时同样拒绝（`-Init` 是显式重建通道，必须人工确认）。

    规矩与 CJK 棘轮、copy_style 三份基线一致：**不许为了让提交变绿往基线里加行**；
    基线少了行要跟着**删掉**（脚本会报「消失」，确认后 `-Write` 收敛）。


    ## 退出码 / 什么时候不能信它

    - `0` = 没有新增 error（可能有「消失」，会顺带提示收敛基线）；
    - `1` = 有新增 error（看红色 `+` 行）；
    - `2` = **kotlinc 自己崩了**（OOM / 栈溢出），本次结果不可信：既不写基线、也不当通过。
      崩掉的输出里 often 一条 error 都没有，**不要当成全绿**。崩了就调大 `$env:JAVA_OPTS` 的 `-Xmx`
      （脚本默认已设 `-Xmx4096m`；注意 `-J-Xmx…` 写在 argfile 里不生效，只能走环境变量）。
    - `3` = **`-Write` 被拒绝**（基线只许降不许升：出现新增，或基线不存在且没带 `-Init`）。
      基线文件一个字节都没动，`sha256` 前后一致。
    - 每次运行的原始 kotlinc 输出落在**本次实例的临时目录**（`$env:TEMP\mikcb-compose-typecheck-<pid>-<guid>\kotlinc-raw.txt`，
      首行会打印完整路径），怀疑漏报就去翻它。实例目录结束**不自动删**（raw 是排查证据）；
      会随运行次数累积，嫌占空间可手动清理 `%TEMP%\mikcb-compose-typecheck-*`。
    - 基线里出现 `<raw>|…` 行 = 有含 `error:` 但解析不出文件位置的输出（说明解析正则要更新），**不是噪音**。

    ## 已知缺口（会产出「假错」，别当成真 bug）

    - 未挂的第三方库 / 生成件：先补 classpath 或桩（`$wanted` / `$plainWanted` / 生成桩），
      不要再走「把文件踢出编译面」的老路（2026-11-10 有人的无主改动正是这么做的，已定性坏做法）；
    - 未挂的源码目录同理——所以 `$SourceRoots` 里必须包含**被扫文件所引用的域**；
      查不住就补 `-ExtraSources`，不要改脚本里的写死部分；
    - 结构上确实消不掉的才登记到 `scripts/typecheck-compose-known.txt`（格式见文件头，必须写原因）。

.PARAMETER ExtraSources
    额外的源码根或单个 .kt（相对仓库根，可多个）。用来把某个域临时纳入扫描。

.PARAMETER Write
    收敛基线：**只允许删行**（error 被修掉）。任何新增 / 上调 ⇒ 拒绝写入、整份文件不动、exit 3。
    要消掉新增只能修代码或登记到 `scripts/typecheck-compose-known.txt`，本开关不是收编工具。

.PARAMETER Init
    基线不存在时首次落盘（唯一允许「凭空建基线」的通道，必须人工显式确认）。
    不带 `-Init` 时，缺基线一律拒绝（否则删掉基线再 `-Write` 就等于放行所有已知 error）。

.PARAMETER Full
    除了差量，还把「未变化」的 error 全打出来（排查用）。

.PARAMETER BaselinePath
    自定义基线文件路径（默认 `scripts/typecheck-compose-baseline.txt`）。
#>
param(
    [string[]]$ExtraSources = @(),
    [switch]$Write,
    [switch]$Init,
    [switch]$Full,
    [string]$BaselinePath
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "[typecheck-compose] 本脚本要求 PowerShell 7+（当前 $($PSVersionTable.PSVersion)）。"
    exit 1
}

$repo = Split-Path -Parent $PSScriptRoot
# 并发隔离（2026-11-10 复核必修）：旧版 workDir / libDir 是固定路径，两个实例同时跑会互相
# 覆盖 `sources.txt` / `out/` / `stubs/` / `kotlinc-raw.txt`（复核员 实跑被踩过一次）。
# 现在每次运行开一个带 pid + guid 的独立临时目录，**实例之间零共享写盘点**：
#   - 解出的 AAR jar 也放本实例目录（多花几秒解包，换掉整个竞态面，值得）；
#   - 结束不删：`kotlinc-raw.txt` 是排查证据，路径随每次输出打印（临时目录由系统清理）。
$runId = "{0}-{1}" -f $PID, ([guid]::NewGuid().ToString("N").Substring(0, 8))
$libDir = Join-Path $env:TEMP "mikcb-compose-typecheck-lib-$runId"
$workDir = Join-Path $env:TEMP "mikcb-compose-typecheck-$runId"
foreach ($d in @($libDir, $workDir)) {
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}
Write-Host ">>> 本次运行临时目录（并发隔离，互不覆盖）：$workDir" -ForegroundColor DarkCyan
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
        "app", "core", "calendar", "course", "infra", "statistics",
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

# 包根顶层 .kt：去 Flutter 化后由下方「包根顶层 .kt 纳入」一段统一纳入（含 R/BuildConfig 桩）；
# 这里只放**必须显式加入**的单个文件（当前：纯 Kotlin 的偏好编解码 + miuix fork 的 DialogGlass）。
$Files = @(
    "android/app/src/main/kotlin/com/mutx163/qingyu/FlutterPrefsCodec.kt",
    # 本仓 fork 的 miuix 新增件（上游 0.9.4 AAR 里没有）：纯 Kotlin data class，不带
    # @Composable，能直接进早筛源集；否则 `AddCoursePage.kt` 的两处 `DialogGlass(...)`
    # 会被报 unresolved（同族的 `glass =` 具名参数仍解不了，见已知类别）。
    "android/third_party/miuix-ui/src/main/kotlin/top/yukonga/miuix/kmp/layout/DialogGlass.kt"
)

# 排除表：**需要生成资源 / 外部 embedding 的宿主壳文件**。
#
# 2026-11-10 早筛修复后这里清空：去 Flutter 化 P4-B/P4-C 已把 `FlutterActivity` 父类、
# `GeneratedPluginRegistrant`、Dart 资源链全部移走，两个现存 Activity
# （`pages/PagesShellActivity.kt` / `pages/ShellExternalEntryActivity.kt`）已不 import
# `io.flutter`，也不引用 `R.*`；而且包根纯 Kotlin 件（`NotificationLaunchTarget` /
# `ScheduleReminderScheduler`）会 `Intent(context, PagesShellActivity::class.java)`，
# 不纳入它们反而制造 unresolved 假错（2026-11-10 实测 7 条）。
# 将来若有 Activity 重新依赖生成资源/外部 SDK，把路径加回这里并在回报里写原因。
$SkipFiles = @()

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
    # 版本跟 app 实际解析口径（activity-compose 1.13.0 拉的是 core 1.18+）：
    # 1.15.0 缺 `PictureInPictureProvider`，会连锁报「cannot access … supertype」
    # （2026-11-10 实测：纳入宿主 Activity 后 44 条）。
    @{ g = "androidx.core"; a = "core"; v = "1.19.1" },
    @{ g = "androidx.core"; a = "core-ktx"; v = "1.19.1" },
    @{ g = "androidx.lifecycle"; a = "lifecycle-viewmodel-android"; v = "2.9.4" },
    @{ g = "androidx.lifecycle"; a = "lifecycle-viewmodel-savedstate-android"; v = "2.9.4" },
    @{ g = "androidx.savedstate"; a = "savedstate-android"; v = "1.3.3" },
    @{ g = "androidx.navigationevent"; a = "navigationevent-android"; v = "1.1.2" },
    # ---- 2026-11-10 早筛修复（用户/Chief 派工）----
    # `@Preview` 注解与 `androidx.compose.ui.tooling.*` 在页面里大量使用（main 源集里的
    # 预览批 2026-11-08 铺开），缺这个 AAR 时每条 import + 每个 @Preview 都报
    # unresolved（实测 422 条假错，占全部报错 64%）。
    @{ g = "androidx.compose.ui"; a = "ui-tooling-preview-android"; v = "1.12.1" },
    # 扫码页（`pages/transfer/QrCameraHost.kt`）：CameraX + ML Kit 条码扫描。
    # 这些都是 app 真实 implementation 依赖（`android/app/build.gradle`），缓存里是 AAR；
    # 不挂就会把整页 63 条报成 unresolved（含 `camera` / `Barcode` / `google` 包）。
    @{ g = "androidx.camera"; a = "camera-core"; v = "1.6.1" },
    @{ g = "androidx.camera"; a = "camera-camera2"; v = "1.6.1" },
    @{ g = "androidx.camera"; a = "camera-lifecycle"; v = "1.6.1" },
    @{ g = "androidx.camera"; a = "camera-view"; v = "1.6.1" },
    @{ g = "com.google.mlkit"; a = "barcode-scanning"; v = "17.3.0" },
    @{ g = "com.google.mlkit"; a = "barcode-scanning-common"; v = "17.0.0" },
    @{ g = "com.google.mlkit"; a = "common"; v = "18.11.0" },
    @{ g = "com.google.mlkit"; a = "vision-common"; v = "17.3.0" },
    @{ g = "com.google.mlkit"; a = "vision-interfaces"; v = "16.3.0" },
    @{ g = "com.google.android.gms"; a = "play-services-mlkit-barcode-scanning"; v = "18.3.1" },
    @{ g = "com.google.android.gms"; a = "play-services-tasks"; v = "18.2.0" },
    @{ g = "com.google.android.gms"; a = "play-services-base"; v = "18.5.0" },
    @{ g = "com.google.android.gms"; a = "play-services-basement"; v = "18.4.0" },
    # 包根顶层 .kt 纳入后才需要的宿主依赖：WorkManager（`*Worker.kt`）、友盟 SDK
    # （`UmengApplication.kt` 的 `UMConfigure`）。不挂就是「挂源根换一批新假错」。
    @{ g = "androidx.work"; a = "work-runtime-ktx"; v = "2.10.1" },
    @{ g = "androidx.work"; a = "work-runtime"; v = "2.10.1" },
    @{ g = "com.umeng.umsdk"; a = "common"; v = "9.6.3" }
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
        # 部分构件是纯 jar（不是 AAR）：直接拷进 lib 目录，同一条通道处理。
        $jar = Get-ChildItem -Path $dir -Filter "*.jar" -Recurse |
            Where-Object { $_.Name -notlike "*sources*" -and $_.Name -notlike "*javadoc*" } |
            Select-Object -First 1
        if ($jar) {
            Copy-Item $jar.FullName $out -Force
        } else {
            Write-Host "MISSING aar/jar: $($w.g):$($w.a):$($w.v)" -ForegroundColor DarkYellow
        }
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
    @{ g = "androidx.lifecycle"; a = "lifecycle-common-jvm" },
    # WorkManager 的 `ListenableWorker` 父类型是 guava 的 `ListenableFuture`；
    # 缓存里 9999.0-empty 那个 jar 是空壳（只用来压依赖冲突），要钉 1.0 那个真实现。
    @{ g = "com.google.guava"; a = "listenablefuture"; v = "1.0" },
    # ML Kit 的 API 签名带 `org.jspecify.annotations.NonNull`：缺这个注解 jar 时
    # `QrCameraHost` 会报「type annotation ... is inaccessible」。
    @{ g = "org.jspecify"; a = "jspecify"; v = "1.0.0" }
)
foreach ($w in $plainWanted) {
    $dir = Join-Path $cache $w.g
    if (-not (Test-Path $dir)) { continue }
    $artifactDir = Join-Path $dir $w.a
    if (-not (Test-Path $artifactDir)) { Write-Host "no plain artifact dir for $($w.a)" -ForegroundColor DarkYellow; continue }
    $searchDir = if ($w.v) { Join-Path $artifactDir $w.v } else { $artifactDir }
    $hit = Get-ChildItem -Path $searchDir -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue |
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
# ── 包根顶层 .kt 纳入（2026-11-10 早筛修复，用户派工）─────────────────────────
#
# 旧版整层不纳入（原因见上方注释）：那时候包根是 Flutter 宿主胶水，普遍引用 `R.*` 与
# Flutter 桥，一纳入就多出约 900 条纯假错。去 Flutter 化 P4 之后前提变了：
#   - 包根顶层已无 `import io.flutter.*`（2026-11-10 逐个核对；仍是 Flutter 依赖的会走
#     下面的运行时跳过并打印，不会静默吞掉）；
#   - R / BuildConfig 改由下方**生成桩**提供（`$stubDir`），不再是「没有 R 就全红」。
# 不纳入的后果是反的：compose 页面引用包根的纯 Kotlin 宿主件
# （`WeeklyReportScheduler` / `LiveUpdateScheduler` / `WidgetSystemActions` …）会被报成
# unresolved，看着像真悬空——2026-11-10 用户实报的 `ShellPageIndex.kt` 就是这类。
# 宿主 Activity 也已纳入（`$SkipFiles` 现为空）；只有仍 import `io.flutter` 的文件会被运行时跳过并打印。
$pkgRootFiles = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem -Path $mainRoot -Filter *.kt) {
    if ($skipFull.ContainsKey($f.FullName)) { continue }
    $text = [IO.File]::ReadAllText($f.FullName)
    if ($text -match '(?m)^\s*import\s+io\.flutter') {
        Write-Host ">>> 跳过引用 Flutter embedding 的包根文件：$($f.Name)（classpath 不含 embedding，属已登记盲区）" -ForegroundColor DarkYellow
        continue
    }
    $fileList.Add($f.FullName)
    $pkgRootFiles.Add($f.Name)
}
Write-Host ">>> 包根顶层 .kt 纳入 $($pkgRootFiles.Count) 个（宿主 Activity 与 Flutter 依赖除外，见上）" -ForegroundColor DarkCyan

# ── R / BuildConfig 生成桩（2026-11-10 早筛修复）──────────────────────────────
#
# 为什么是生成而不是挂 classpath：R 与 BuildConfig 由 AGP **构建期生成**，早筛不跑 AGP，
# 原本根本没有这两个类——旧基线里的 `R` 17 条 / `BuildConfig` 13 条假错就是这么来的。
# 数据源取**真实资源目录与 build.gradle**，所以新增资源/字段不会漏：
#   - `R.string/drawable/layout/mipmap/xml/raw/color/attr/id/style` ← `android/app/src/main/res`
#   - `BuildConfig.UMENG_*` ← `build.gradle` 的 `buildConfigField`
#   - 固定几个 AGP 必生成项（DEBUG / BUILD_TYPE / FLAVOR / APPLICATION_ID / VERSION_*）
# 桩只有常量、不参与行为；早筛只做类型检查，常量值不影响判定。
$stubDir = Join-Path $workDir "stubs"
if (Test-Path $stubDir) { Remove-Item -Recurse -Force $stubDir }
New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
$resRoot = Join-Path $repo "android/app/src/main/res"
$resNames = @{}
foreach ($kind in @('string', 'drawable', 'layout', 'mipmap', 'xml', 'raw', 'color', 'attr', 'id', 'style')) {
    $resNames[$kind] = New-Object System.Collections.Generic.List[string]
}
if (Test-Path $resRoot) {
    foreach ($f in (Get-ChildItem -Path $resRoot -Recurse -Filter *.xml)) {
        $t = [IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($t, '<string\s+name="([^"]+)"')) { $resNames['string'].Add($m.Groups[1].Value) }
        foreach ($m in [regex]::Matches($t, '<color\s+name="([^"]+)"')) { $resNames['color'].Add($m.Groups[1].Value) }
        foreach ($m in [regex]::Matches($t, '<attr\s+name="([^"]+)"')) { $resNames['attr'].Add($m.Groups[1].Value) }
        foreach ($m in [regex]::Matches($t, '<style\s+name="([^"]+)"')) { $resNames['style'].Add($m.Groups[1].Value) }
        foreach ($m in [regex]::Matches($t, '@\+id/([A-Za-z_][A-Za-z0-9_]*)')) { $resNames['id'].Add($m.Groups[1].Value) }
        foreach ($m in [regex]::Matches($t, '<item\b[^>]*\btype="id"[^>]*>')) {
            $nm = [regex]::Match($m.Value, 'name="([^"]+)"')
            if ($nm.Success) { $resNames['id'].Add($nm.Groups[1].Value) }
        }
    }
    # 文件型资源：drawable*/layout*/mipmap*/xml*/raw*（`.9.png` 去掉 .9 后缀才是资源名）
    foreach ($dir in (Get-ChildItem -Path $resRoot -Directory)) {
        $kind = $null
        switch -Regex ($dir.Name) {
            '^drawable' { $kind = 'drawable' }
            '^layout' { $kind = 'layout' }
            '^mipmap' { $kind = 'mipmap' }
            '^xml' { $kind = 'xml' }
            '^raw' { $kind = 'raw' }
        }
        if (-not $kind) { continue }
        foreach ($f in (Get-ChildItem -Path $dir.FullName -File)) {
            $name = $f.Name -replace '\.9\.png$', '' -replace '\.[^.]+$', ''
            if ($name) { $resNames[$kind].Add($name) }
        }
    }
}
$rSb = New-Object System.Text.StringBuilder
[void]$rSb.AppendLine("// 由 scripts/typecheck-compose.ps1 生成（早筛桩），不提交、不入包。")
[void]$rSb.AppendLine("package com.mutx163.qingyu")
[void]$rSb.AppendLine()
[void]$rSb.AppendLine("object R {")
foreach ($kind in @('string', 'drawable', 'layout', 'mipmap', 'xml', 'raw', 'color', 'attr', 'id', 'style')) {
    $names = @($resNames[$kind] | Sort-Object -Unique)
    if ($names.Count -eq 0) { continue }
    [void]$rSb.AppendLine("    object $kind {")
    foreach ($n in $names) { [void]$rSb.AppendLine("        const val ${n}: Int = 0") }
    [void]$rSb.AppendLine("    }")
}
[void]$rSb.AppendLine("}")
$rStubPath = Join-Path $stubDir "RStub.kt"
[IO.File]::WriteAllText($rStubPath, $rSb.ToString(), (New-Object Text.UTF8Encoding($false)))
$fileList.Add($rStubPath)

# Gradle 的 `buildConfigField "String", "X", "\"v\""` 第三参是 **Java 表达式**：外层是
# 字符串字面量、内层 `\"` 才是值里的引号。直接抄进 Kotlin 桩会生成 `= "\"v\""`（值带引号），
# 与真实 BuildConfig 的 `v` 不一致（2026-11-10 复核必修）。这里统一归一化成 Kotlin 字面量。
function ConvertTo-KotlinLiteral {
    param([string]$KtType, [string]$Raw)
    $value = $Raw.Trim()
    # 第一层：build.gradle 里的 **Groovy 字符串字面量** → Java 表达式
    # （`"\"official\""` 的表达式是 `"official"`）。
    if ($value -match '^"(.*)"$') {
        $expr = $matches[1] -replace '\\"', '"' -replace '\\\\', '\'
    } else {
        $expr = $value
    }
    if ($KtType -eq 'String') {
        # 第二层：Java 字符串表达式 → 真实值，再写成 Kotlin 字面量。
        if ($expr -match '^"(.*)"$') {
            $inner = $matches[1] -replace '\\"', '"' -replace '\\\\', '\'
        } else {
            $inner = $expr
        }
        $escaped = $inner -replace '\\', '\\' -replace '"', '\"'
        return "`"$escaped`""
    }
    if ($KtType -eq 'Boolean') {
        if ($expr -eq 'true' -or $expr -eq 'false') { return $expr }
        return 'false'
    }
    if ($KtType -eq 'Int' -or $KtType -eq 'Long') {
        if ($expr -match '^-?\d+[lL]?$') { return $expr.TrimEnd('l', 'L') }
        return '0'
    }
    return $expr
}

$bcFields = [ordered]@{
    DEBUG            = @{ type = 'Boolean'; value = 'false' }
    BUILD_TYPE       = @{ type = 'String'; value = '"debug"' }
    FLAVOR           = @{ type = 'String'; value = '""' }
    APPLICATION_ID   = @{ type = 'String'; value = '"com.mutx163.qingyu"' }
    VERSION_CODE     = @{ type = 'Int'; value = '0' }
    VERSION_NAME     = @{ type = 'String'; value = '"0.0.0"' }
}
$gradleFile = Get-ChildItem -Path (Join-Path $repo "android/app") -Filter "build.gradle*" -File |
    Select-Object -First 1
if ($gradleFile) {
    $gText = [IO.File]::ReadAllText($gradleFile.FullName)
    foreach ($m in [regex]::Matches($gText, 'buildConfigField\s+"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*("(?:[^"\\]|\\.)*"|[^\r\n]+)')) {
        $type = $m.Groups[1].Value.Trim()
        $name = $m.Groups[2].Value.Trim()
        $value = $m.Groups[3].Value.Trim()
        $ktType = switch ($type) { 'String' { 'String' } 'Boolean' { 'Boolean' } 'int' { 'Int' } 'long' { 'Long' } default { $type } }
        $literal = ConvertTo-KotlinLiteral -KtType $ktType -Raw $value
        if (-not $bcFields.Contains($name)) { $bcFields[$name] = @{ type = $ktType; value = $literal } }
    }
}
$bcSb = New-Object System.Text.StringBuilder
[void]$bcSb.AppendLine("// 由 scripts/typecheck-compose.ps1 生成（早筛桩），不提交、不入包。")
[void]$bcSb.AppendLine("package com.mutx163.qingyu")
[void]$bcSb.AppendLine()
[void]$bcSb.AppendLine("object BuildConfig {")
foreach ($k in $bcFields.Keys) {
    [void]$bcSb.AppendLine("    const val ${k}: $($bcFields[$k].type) = $($bcFields[$k].value)")
}
[void]$bcSb.AppendLine("}")
$bcStubPath = Join-Path $stubDir "BuildConfigStub.kt"
[IO.File]::WriteAllText($bcStubPath, $bcSb.ToString(), (New-Object Text.UTF8Encoding($false)))
$fileList.Add($bcStubPath)
Write-Host ">>> R/BuildConfig 桩已生成（R 去重后 $(($resNames.Values | ForEach-Object { @($_ | Sort-Object -Unique).Count } | Measure-Object -Sum).Sum) 个名字 / BuildConfig $($bcFields.Count) 个字段）" -ForegroundColor DarkCyan

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

# ── 显式登记的已知类别（2026-11-10 早筛修复）─────────────────────────────────
# 验收口径：「每条报错要么是真错、要么是**显式登记的已知类别**」。已知类别单独放一个
# 数据文件（`scripts/typecheck-compose-known.txt`，一行 `路径|消息|原因`），而不是混进基线：
#   1) 每条都必须写原因，脚本会原样打印——不是「看不见就绿」；
#   2) 条目一旦不再复现会提示删行（与 compose 样式例外的「只进不出」纪律同款）；
#   3) 基线保持干净（0 条），新增真错立刻显形。
# 多重集语义：同一 `路径|消息` 可以重复登记多次（同一条 error 在多处重复出现的场景）。
$KnownGapsPath = Join-Path $repo "scripts/typecheck-compose-known.txt"
$knownGaps = New-Object System.Collections.Generic.List[string]
$knownReasons = @{}
if (Test-Path $KnownGapsPath) {
    foreach ($line in (Get-Content -Path $KnownGapsPath)) {
        $trim = $line.Trim()
        if ($trim -eq "" -or $trim.StartsWith("#")) { continue }
        $parts = $trim -split '\|', 3
        if ($parts.Count -lt 3) {
            Write-Host ">>> 已知类别文件行格式不对（要 `路径|消息|原因`）：$trim" -ForegroundColor DarkYellow
            continue
        }
        $entry = "$($parts[0].Trim())|$($parts[1].Trim())"
        $knownGaps.Add($entry)
        $knownReasons[$entry] = $parts[2].Trim()
    }
}
$knownRemaining = @{}
foreach ($g in $knownGaps) {
    if ($knownRemaining.ContainsKey($g)) { $knownRemaining[$g]++ } else { $knownRemaining[$g] = 1 }
}
$knownHit = New-Object System.Collections.Generic.List[string]
$unexplained = New-Object System.Collections.Generic.List[string]
foreach ($item in $current) {
    if ($knownRemaining.ContainsKey($item) -and $knownRemaining[$item] -gt 0) {
        $knownRemaining[$item]--
        $knownHit.Add($item)
    } else {
        $unexplained.Add($item)
    }
}
$unexplained = @($unexplained | Sort-Object)
$staleKnown = @($knownRemaining.Keys | Where-Object { $knownRemaining[$_] -gt 0 } | Sort-Object)

$added = @(Compare-Multiset -Left $unexplained -Right $baseline)
$removed = @(Compare-Multiset -Left $baseline -Right $unexplained)

Write-Host (">>> [typecheck-compose] 编译完成：{0} 个源文件，耗时 {1:N1}s，error 去重后 {2} 条" -f `
        $uniqueSources.Count, $sw.Elapsed.TotalSeconds, $current.Count) -ForegroundColor DarkCyan
Write-Host (">>> 其中：显式登记的已知类别 {0} 条 / 基线（历史遗留）{1} 条 / **待处理 {2} 条**" -f `
        $knownHit.Count, $baseline.Count, $unexplained.Count) -ForegroundColor DarkCyan
if ($knownHit.Count -gt 0) {
    Write-Host ">>> 已知类别明细（每条都带原因；要动它们先读原因）：" -ForegroundColor DarkCyan
    foreach ($g in ($knownHit | Sort-Object -Unique)) {
        Write-Host "    · $g" -ForegroundColor DarkGray
        Write-Host "      原因：$($knownReasons[$g])" -ForegroundColor DarkGray
    }
}
if ($staleKnown.Count -gt 0) {
    Write-Host ">>> 有 $($staleKnown.Count) 条已知类别**不再复现**（顺手删掉 known 文件里的对应行，别只进不出）：" -ForegroundColor Yellow
    $staleKnown | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
}
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

function Get-BaselineSha256 {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return "<不存在>" }
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

if ($Write) {
    # ── 两阶段：先比对新旧基线，任何新增都拒绝写入 ─────────────────────────────
    #
    # 语义（与 i18n-cjk-baseline.py / i18n-copy-gap.py 的 --write 同一套）：
    #   · 基线只许降不许升；新增 / 上调 ⇒ 拒绝，一个字节不动，exit 3；
    #   · 只有「只删不增」才落盘（error 被修掉 ⇒ 基线可以缩）；
    #   · 基线不存在 ⇒ 也拒绝（否则「删掉基线再 -Write」就等于放行所有已知 error）；
    #     重建基线必须显式 -Init。
    $shaBefore = Get-BaselineSha256 $BaselinePath
    $baselineMissing = -not (Test-Path $BaselinePath)
    if ($baselineMissing -and -not $Init) {
        Write-Host ">>> 拒绝写入：基线不存在（$BaselinePath）。" -ForegroundColor Red
        Write-Host ">>> 首次建基线必须显式加 -Init；否则等于把当前所有已知 error 一次性放行。" -ForegroundColor DarkYellow
        Write-Host ">>> 基线 sha256 前后：$shaBefore = $shaBefore（未变动）" -ForegroundColor DarkYellow
        exit 3
    }

    # 基线不存在且带 -Init：所有条目都是「新增」，但这是唯一被允许的一次。
    $writeAdded = if ($baselineMissing) { @() } else { @(Compare-Multiset -Left $unexplained -Right $baseline) }
    $writeRemoved = if ($baselineMissing) { @() } else { @(Compare-Multiset -Left $baseline -Right $unexplained) }

    if ($writeAdded.Count -gt 0) {
        Write-Host ">>> 拒绝写入：基线**只许降不许升**，本次待处理里有 $($writeAdded.Count) 条基线中没有的 error：" -ForegroundColor Red
        $writeAdded | ForEach-Object { Write-Host "    + $_" -ForegroundColor Red }
        Write-Host ">>> 一个字节都没写。新增只能靠修代码，或登记到 scripts/typecheck-compose-known.txt（必须写原因）——-Write 不是收编工具。" -ForegroundColor DarkYellow
        Write-Host ">>> 基线 sha256 前后：$shaBefore = $shaBefore（未变动）" -ForegroundColor DarkYellow
        exit 3
    }

    # 到这里的两种合法情形：只删（收敛） / 完全一致（重写同内容，哈希不变）。
    Write-BaselineFile -Entries $unexplained
    $shaAfter = Get-BaselineSha256 $BaselinePath
    if ($baselineMissing) {
        Write-Host ">>> 已按 -Init 首次落盘基线（$($unexplained.Count) 条）。" -ForegroundColor Green
    } elseif ($writeRemoved.Count -gt 0) {
        Write-Host ">>> 允许写入：只删不增，收敛掉 $($writeRemoved.Count) 条已消失的 error。" -ForegroundColor Green
        $writeRemoved | Select-Object -First 20 | ForEach-Object { Write-Host "    - $_" -ForegroundColor Green }
    } else {
        Write-Host ">>> 允许写入：与基线完全一致（无新增、无消失），基线内容不变。" -ForegroundColor Green
    }
    Write-Host ">>> 基线 sha256 前后：$shaBefore → $shaAfter" -ForegroundColor DarkCyan
    exit 0
}

if (-not (Test-Path $BaselinePath)) {
    # 不再自动落盘：缺基线时必须人工用 -Init 明确重建，否则等于静默放行。
    Write-Host ">>> 基线不存在：$BaselinePath" -ForegroundColor Red
    Write-Host ">>> 没有基线就没有棘轮基准，本次**不算通过**（exit 3）。重建基线请显式加 -Init。" -ForegroundColor DarkYellow
    exit 3
}

if ($Full) {
    Write-Host ">>> 全部 error（含未变化、含已知类别）：" -ForegroundColor DarkCyan
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

Write-Host ">>> 待处理里新增 $($added.Count) 条 error（基线 $($baseline.Count) 条 → 待处理 $($unexplained.Count) 条）：" -ForegroundColor Red
$added | ForEach-Object { Write-Host "    + $_" -ForegroundColor Red }
Write-Host ">>> 提示：先确认是不是你引入的真错；是 classpath/生成件缺口就补脚本（桩或 jar），实在消不掉的才登记到 scripts/typecheck-compose-known.txt（必须写原因），不许往基线里塞。" -ForegroundColor DarkYellow
exit 1
