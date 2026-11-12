<#
.SYNOPSIS
    跨 Agent 安全 Gradle 构建包装脚本（带全局排队互斥锁）。

.DESCRIPTION
    当多个 Agent 并发工作时，并发执行 Gradle 会瞬间拉起多个 JVM（每个 2~4GB），
    造成系统内存枯竭、CPU 剧烈抖动与缓存文件锁冲突。
    本脚本利用 Windows 内核级命名互斥锁（Mutex），确保本机同一时刻最多只有 1 个
    Gradle 构建在运行，其余 Agent 自动排队，杜绝内存雪崩。

    本脚本**显式**追加 `--daemon`，让每次构建都复用常驻 daemon（实测 `:app:help`：
    28s → 7s（daemon 热）→ 收敛后 3s）。CI / CNB 直接调 gradlew、不经过本脚本，不受影响。
    ⚠️ 2026-11-11 复核：`android/gradle.properties` **已不再**写 `org.gradle.daemon=false`
    （本地/IDE 默认复用 daemon），所以这条现在是显式冗余、不是「覆盖某行配置」。
    留着是防回退：哪天配置又被改回 daemon=false，闸门内的构建不会退回冷 JVM
    （2026-10-27 那种情形：每次调用固定开销 ~27s，当天本机累计启动一次性 JVM
    ≥577 个、构建耗时 8.2 小时）。

    daemon 的**空闲退出时间不在这里传**，而是写在 `android/gradle.properties` 的
    `org.gradle.daemon.idletimeout=600000`。别改成命令行 `-D`：daemon 的复用判据包含
    `idleTimeout`，多一个 `-D` 就会造出「只有走本闸门的客户端才认」的第二个 daemon，
    与 Android Studio / 裸 gradlew 各占一份内存（2026-10-27 实测同机因此并存 2 个 daemon、
    4 个 JVM 合计 6803 MB，可用内存从 9.39 GB 掉到 4.02 GB）。

    不显式传 `-Pkotlin.incremental`：2026-10-27 曾因 4 个 Flutter 插件模块
    （dynamic_color / device_info_plus / image_picker_android / file_picker，源码位于
    PUB_CACHE 的 D:\Cache\Pub\hosted\pub.dev\...）报
      Could not close incremental caches in ...\build\kotlin\compileDebugKotlin\cacheable\caches-jvm\jvm\kotlin
    而刻意关掉增量（同命令改回 `-Pkotlin.incremental=false` 立即 BUILD SUCCESSFUL，
    对照实验原始输出见 `.agents/diag/perf-2026-10-27/opt/verify.md`）。
    ⚠️ 2026-11-11 复核：去 Flutter 化 P4-B（2026-11-07）删掉 Flutter Gradle 插件后，
    这 4 个插件模块已不在构建图里，**该前提已不存在**；`android/gradle.properties`
    现在保持增量默认开启，闸门也不传这个参数。

    2026-11-11 删除：此前还有「请求的任务全是 `:app:compile*Kotlin` 时，按变体名追加
    `-x :app:compileFlutterBuild<变体>`」的逻辑与 `-WithFlutterAssets` 开关（2026-10-29
    从写死 composeUi 改为按变体推导）。Flutter Gradle 插件移除后，收集列表恒空、
    开关无任何效果，两样都成了死代码，本版整段删除。**现在闸门不追加任何 `-x`。**

.EXAMPLE
    pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin
    pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest
#>

[CmdletBinding()]
param(
    # 重新看到 Gradle 弃用警告（默认压制：AGP 9 下每个 Flutter 插件模块各打一条
    # 「Deprecated 'org.jetbrains.kotlin.android' plugin usage」，~19 条纯噪音；
    # 走 Gradle 警告通道，--warning-mode none 能压掉；AGP 自己的 7 条 WARNING 走
    # android.sync.suppressAgpWarnings（gradle.properties），与此开关无关。
    # CI / AS / 裸 gradlew 不经过本闸门，不受影响。）
    [switch]$ShowDeprecations,

    # 输出留档：不占参数位（否则会跟 ValueFromRemainingArguments 抢位置参数，实测会把
    # `:app:help` 这类任务名当成日志路径吃掉）。用环境变量 `MIKCB_GRADLE_LOG` 覆盖；
    # **省略时自动落** `.agents/diag/auto-<时间>-<sha>.log`。
    # 为什么默认也落：2026-11-12 出现过「测试结果写盘了、日志却没有」的入口——
    # 一次 smoke 跑（`:app:testDevDebugUnitTest --tests ...`）直接用变量接输出、没 tee，
    # 于是 `build/app/test-results` 更新了，`.agents/diag` 里什么都没有。
    # 那是「8057 只在屏幕上活过」的同一个病换个入口又出现。闸门自己默认留档，绕不过去。
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GradleArgs
)

$mutexName = "Global\Mikcb_Gradle_Build_Mutex"
$acquired = $false
$mutex = $null

try {
    # 尝试创建或打开全局互斥体
    $mutex = [System.Threading.Mutex]::new($false, $mutexName)
} catch {
    # 降级为本地互斥体（非管理员无 Global 命名空间权限时）
    $mutexName = "Local\Mikcb_Gradle_Build_Mutex"
    $mutex = [System.Threading.Mutex]::new($false, $mutexName)
}

$timeoutMs = 600000 # 最大排队 10 分钟

try {
    Write-Host ">>> [safe-gradle] 正在请求 Gradle 构建互斥锁（排队防爆内存）..." -ForegroundColor Cyan
    try {
        $acquired = $mutex.WaitOne($timeoutMs)
    } catch [System.Threading.AbandonedMutexException] {
        # 前一个持有者异常退出时，锁仍视为被当前进程获取
        $acquired = $true
    }

    if (-not $acquired) {
        Write-Error "[safe-gradle] 排队超时（已等待 10 分钟），已有其他构建长期占用，放弃本次执行。"
        exit 1
    }

    Write-Host ">>> [safe-gradle] 成功获得构建锁，开始执行 Gradle 构建..." -ForegroundColor Green
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $androidDir = Join-Path $repoRoot "android"
    $gradlew = Join-Path $androidDir "gradlew.bat"

    # ── 证据自证（2026-11-12 监察要求）──────────────────────────────────────────
    # 目的：**任何人拿到这份日志就能独立判定「这次跑覆盖的是哪一版树、跑了多少用例」**，
    # 不需要问人、也不用从文件名猜。所以跑前跑后各打一行 HEAD 与树状态；
    # Gradle 只在失败时打「N tests completed」，绿的时候一个字不打，所以成功路径
    # 自己从 JUnit XML 汇总一行 RESULT。
    # 注意：产物在仓库根 `build/app/test-results/`（android/build.gradle:28-36 把
    # buildDir 重定向过去了），**不是** `android/app/build/test-results/`。
    $gitExe = Get-Command git -ErrorAction SilentlyContinue
    $statusLines = @()
    if ($gitExe) {
        $headBefore = (& git -C $repoRoot rev-parse HEAD 2>$null | Select-Object -First 1)
        $statusLines = @(& git -C $repoRoot status --porcelain 2>$null)
        Write-Host "=== HEAD before: $headBefore"
        Write-Host "=== STATUS before: $(if ($statusLines.Count -eq 0) { '<clean>' } else { "$($statusLines.Count) 条" })"
        if ($statusLines.Count -gt 0) { $statusLines | ForEach-Object { Write-Host "=== STATUS before: $_" } }
    } else {
        Write-Host "=== HEAD before: <git 不可用，无法记录>"
    }
    $runStartedAt = Get-Date

    Push-Location $androidDir
    try {
        # 显式 --daemon（见 .DESCRIPTION）：即使 android/gradle.properties 哪天又写回
        # daemon=false，走闸门的构建仍复用常驻 daemon；CI 不经闸门、不受影响。
        # 注意：**不要**在这里加 -D 之类的 JVM/上下文参数。daemon 的复用判据包含
        # DefaultDaemonContext（javaHome + daemonOpts + idleTimeout …），多一个 -D 就会
        # 造出一个「只有走本闸门的客户端才认」的独立 daemon，与 Android Studio / 裸 gradlew
        # 各占一份内存（2026-10-27 实测：同机因此并存 2 个 daemon、4 个 JVM 合计 6.8 GB）。
        # idle 超时统一写在 android/gradle.properties 里，让所有客户端收敛到同一个 daemon。
        $effective = @('--daemon') + @($GradleArgs)

        # 默认压掉 Gradle 通道的弃用警告（见 $ShowDeprecations 注释）。
        if (-not $ShowDeprecations) {
            $effective += @('--warning-mode', 'none')
        }

        Write-Host ">>> [safe-gradle] 实际参数: $($effective -join ' ')" -ForegroundColor DarkGray
        # 输出留档：默认就落盘（见参数块注释），调用方漏 tee 也不会再出现「结果写盘无日志」。
        $logPath = $env:MIKCB_GRADLE_LOG
        if (-not $logPath) {
            $shaShort = if ($headBefore) { $headBefore.Substring(0, [Math]::Min(9, $headBefore.Length)) } else { "nogit" }
            $logPath = Join-Path $repoRoot (".agents/diag/auto-{0}-{1}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $shaShort)
        }
        $logDir = Split-Path -Parent $logPath
        if ($logDir) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        Write-Host ">>> [safe-gradle] 输出留档: $logPath" -ForegroundColor DarkGray
        & $gradlew @effective *>&1 | Tee-Object -FilePath $logPath | ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($gitExe) {
        $headAfter = (& git -C $repoRoot rev-parse HEAD 2>$null | Select-Object -First 1)
        $statusAfter = @(& git -C $repoRoot status --porcelain 2>$null)
        Write-Host "=== HEAD after: $headAfter"
        Write-Host "=== STATUS after: $(if ($statusAfter.Count -eq 0) { '<clean>' } else { "$($statusAfter.Count) 条" })"
        if ($statusAfter.Count -gt 0) { $statusAfter | ForEach-Object { Write-Host "=== STATUS after: $_" } }
        if ($headBefore -ne $headAfter) {
            Write-Host "=== WARN: 跑期间 HEAD 变了（$headBefore → $headAfter），本次结果归属需重新判定" -ForegroundColor Yellow
        }
    }

    # 成功路径的用例数：只认本次跑期间更新过的变体目录，避免把上一轮的旧结果当成本次成绩。
    $resultsRoot = Join-Path $repoRoot "build/app/test-results"
    if (Test-Path $resultsRoot) {
        foreach ($dir in @(Get-ChildItem $resultsRoot -Directory | Sort-Object LastWriteTime -Descending)) {
            if ($dir.LastWriteTime -lt $runStartedAt.AddSeconds(-2)) { continue }
            $xmlFiles = @(Get-ChildItem $dir.FullName -Filter "*.xml" -File)
            if ($xmlFiles.Count -eq 0) { continue }
            $tests = 0; $failures = 0; $errors = 0; $skipped = 0
            foreach ($f in $xmlFiles) {
                try {
                    [xml]$doc = Get-Content $f.FullName -Raw
                    $tests += [int]$doc.testsuite.tests
                    $failures += [int]$doc.testsuite.failures
                    $errors += [int]$doc.testsuite.errors
                    $skipped += [int]$doc.testsuite.skipped
                } catch { }
            }
            Write-Host "=== RESULT[$($dir.Name)]: $tests tests, $failures failures, $errors errors, $skipped skipped (XML 文件 $($xmlFiles.Count))"
            Write-Host "=== RESULT-DIR: $($dir.FullName)"
        }
    }

    if ($exitCode -ne 0) {
        exit $exitCode
    }
} finally {
    if ($acquired -and $mutex -ne $null) {
        $mutex.ReleaseMutex()
        Write-Host ">>> [safe-gradle] 构建完成，已释放全局排队锁。" -ForegroundColor Cyan
    }
    if ($mutex -ne $null) {
        $mutex.Dispose()
    }
}
