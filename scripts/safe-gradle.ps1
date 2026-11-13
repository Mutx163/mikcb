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

    【探针生命周期：改仓库的验证必须 `try/finally` 清理】（2026-11-12，两次事故后立的规矩）
    今天的探针事故发生了两次，形状一样——**清理没跑到**：
      · `ZzCanary.kt` 被误放进 `composeP1`，进了 Gradle 编译面，`compilePerfBenchKotlin` 一片
        `Unresolved reference`；它未进 git，手清后 `git status`/历史都不留痕；
      · 验证脚本把 `ZzBrokenGuard.kt` 放进测试源集，中途 `Write-Error` 提前终止，
        **末尾的 `Remove-Item` 没执行** ⇒ 下一轮被当成本域第 8 个 .kt 编进编译面。
    规矩：
      1. **优先不碰仓库**：能在临时目录/参数化纯函数里验的，就别往 `android/app/src` 放文件
         （`CanaryFileGuardTest` 就是改成 `Files.createTempDirectory` + 纯函数后验的）；
      2. 必须碰仓库时，备份→改动→**验证完的还原/删除写在 `try/finally` 里**，不依赖"执行到最后一行"；
         失败分支同样要清理；
      3. 清理后**自证**：`git diff --stat` 为空 + 关键文件 sha256 与基线一致，再报结果；
      4. 探针文件名带上本次任务标记，命中了也能一眼认出是探针（但别用 `probe/canary` 之外的
         白名单外名字，`CanaryFileGuardTest` 会红——那是它该干的）。

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
    }
    $runStartedAt = Get-Date

    # 日志路径先定：后面所有 `===` 证据行都要同时进控制台与**同一份日志**。
    $runStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logPath = $env:MIKCB_GRADLE_LOG
    if (-not $logPath) {
        $shaShort = if ($headBefore) { $headBefore.Substring(0, [Math]::Min(9, $headBefore.Length)) } else { "nogit" }
        $logPath = Join-Path $repoRoot (".agents/diag/auto-{0}-{1}.log" -f $runStamp, $shaShort)
    }
    $logDir = Split-Path -Parent $logPath
    if ($logDir) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    # ⚠️ 关键（2026-11-12 监察实证）：`===` 证据行**不能只用 Write-Host**——它们在 tee 之外，
    # 只活在控制台，日志里 grep 不到（于是"日志自带坐标"变成口头声明）。
    # 统一走这个函数：控制台 + 追加到同一份日志。
    # 并且「能写出日志」本身必须被断言：2026-11-12 实测过 `*>> $logPath` 报
    # `Access to the path ... is denied`、gradle 根本没执行，脚本却沿用残留的
    # `$LASTEXITCODE=0` 报了成功 —— **证据机制可以在没有任何证据的情况下报告成功**。
    $writeEvidence = {
        param([string]$text)
        Write-Host $text
        try {
            Add-Content -LiteralPath $logPath -Value $text -Encoding utf8NoBOM -ErrorAction Stop
        } catch {
            throw "日志写入失败：$logPath（$($_.Exception.Message)）——拒绝把这次跑当成有证据"
        }
    }

    $effective = @('--daemon') + @($GradleArgs)
    if (-not $ShowDeprecations) {
        $effective += @('--warning-mode', 'none')
    }

    # #3 主修法（2026-11-12 监察定案）：跑前**清空该变体的结果目录**。
    # 旧写法只看目录 mtime 判断「这批 XML 是不是本次的」，而编译失败时 Gradle 会碰目录
    # （清理/临时文件），目录 mtime 落进窗口 ⇒ 上一轮旧 XML 被当成本次成绩，于是出现
    # 「编译失败那轮也打 RESULT、聚合 sha 与上一轮真红完全相同」。物证已由归档承担
    # （按时刻分目录），所以直接清空：目录里出现的必然是本次产物，这类陈旧问题整类消失。
    # 代价是「跑前看不到上一次 XML」——正好逼人去看 `.agents/diag/` 的归档。
    $testTaskArg = @($effective | Where-Object { $_ -match ':app:test[A-Za-z0-9_]*UnitTest' }) | Select-Object -First 1
    $resultsRoot = Join-Path $repoRoot "build/app/test-results"
    $resultsDirName = if ($testTaskArg) { $testTaskArg -replace '^:app:', '' } else { $null }
    $resultsDirPath = if ($resultsDirName) { Join-Path $resultsRoot $resultsDirName } else { $null }
    if ($resultsDirPath -and (Test-Path -LiteralPath $resultsDirPath)) {
        & $writeEvidence "=== CLEARED-RESULTS: $resultsDirName（跑前清空；物证看 .agents/diag 归档）"
        Remove-Item -LiteralPath $resultsDirPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ① 请求行：日志里必须能看出这次请求的是什么（含 `--rerun-tasks` 与否）——
    #    否则「真跑 / 吃缓存」只能靠旁证，1 秒的 `help` 日志也能被当成绿。
    & $writeEvidence "=== REQUEST: $($effective -join ' ')"
    # 过滤跑与全量跑共用同一个任务名与结果目录：日志里必须能一眼分开，
    # 否则「8063 用例」和「3 用例」都叫 `:app:testDevDebugUnitTest`，事后无法区分。
    if (($effective -join ' ') -match '--tests') {
        & $writeEvidence "=== FILTERED: --tests 生效（本次不是全量跑，RESULT 用例数不可与全量比较）"
    }
    if ($gitExe) {
        & $writeEvidence "=== HEAD before: $headBefore"
        & $writeEvidence ("=== STATUS before: " + $(if ($statusLines.Count -eq 0) { '<clean>' } else { "$($statusLines.Count) 条" }))
        foreach ($l in $statusLines) { & $writeEvidence "=== STATUS before: $l" }
    } else {
        & $writeEvidence "=== HEAD before: <git 不可用，无法记录>"
    }

    Write-Host ">>> [safe-gradle] 输出留档: $logPath" -ForegroundColor DarkGray
    try {
        Add-Content -LiteralPath $logPath -Value ">>> [safe-gradle] 输出留档: $logPath" -Encoding utf8NoBOM -ErrorAction Stop
    } catch {
        throw "日志写入失败：$logPath（$($_.Exception.Message)）——拒绝把这次跑当成有证据"
    }

    Push-Location $androidDir
    try {
        # 显式 --daemon（见 .DESCRIPTION）：即使 android/gradle.properties 哪天又写回
        # daemon=false，走闸门的构建仍复用常驻 daemon；CI 不经闸门、不受影响。
        # 注意：**不要**在这里加 -D 之类的 JVM/上下文参数。daemon 的复用判据包含
        # DefaultDaemonContext（javaHome + daemonOpts + idleTimeout …），多一个 -D 就会
        # 造出一个「只有走本闸门的客户端才认」的独立 daemon，与 Android Studio / 裸 gradlew
        # 各占一份内存（2026-10-27 实测：同机因此并存 2 个 daemon、4 个 JVM 合计 6.8 GB）。
        # idle 超时统一写在 android/gradle.properties 里，让所有客户端收敛到同一个 daemon。
        Write-Host ">>> [safe-gradle] 实际参数: $($effective -join ' ')" -ForegroundColor DarkGray
        # 直接**重定向追加**进日志，不走 `| Tee-Object` 管道：
        # Gradle daemon 会继承子进程的标准输出句柄，tee 管道因此可能永不关闭，
        # 外层调用会一直等到超时（2026-11-12 实测：跑本身 3m2s 已结束，外层却卡满 600s）。
        # `*>>` 让 daemon 拿到的是文件句柄，不是我们的管道，函数就能及时返回。
        # 退出码只能来自**本次**调用：先置 -1 当哨兵，跑完仍是 -1 就说明 gradle 根本没跑，
        # 绝不能让残留的 `$LASTEXITCODE` 冒充成功（2026-11-12 青禾会话实测到的假绿入口）。
        $LASTEXITCODE = -1
        try {
            & $gradlew @effective *>> $logPath
        } catch {
            throw "Gradle 输出写不进日志：$logPath（$($_.Exception.Message)）——拒绝把这次跑当成有证据"
        }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode -or $exitCode -eq -1) {
            throw "Gradle 未执行或未返回退出码（日志：$logPath）——不把未执行当成功"
        }
        if (-not (Test-Path -LiteralPath $logPath) -or (Get-Item -LiteralPath $logPath).Length -eq 0) {
            throw "日志不存在或为空：$logPath——不把无日志当成功"
        }
    } finally {
        Pop-Location
    }

    $statusChanged = $false
    if ($gitExe) {
        $headAfter = (& git -C $repoRoot rev-parse HEAD 2>$null | Select-Object -First 1)
        $statusAfter = @(& git -C $repoRoot status --porcelain 2>$null)
        # 只比条数不够（改一个再改回去条数相同）：比**集合**——(状态, 路径) 集合是否相等。
        $beforeSet = @($statusLines | ForEach-Object { $_.Trim() } | Sort-Object)
        $afterSet = @($statusAfter | ForEach-Object { $_.Trim() } | Sort-Object)
        $statusChanged = (($beforeSet -join "`n") -ne ($afterSet -join "`n"))
        & $writeEvidence "=== HEAD after: $headAfter"
        & $writeEvidence ("=== STATUS after: " + $(if ($statusAfter.Count -eq 0) { '<clean>' } else { "$($statusAfter.Count) 条" }))
        foreach ($l in $statusAfter) { & $writeEvidence "=== STATUS after: $l" }
        if ($headBefore -ne $headAfter) {
            & $writeEvidence "=== WARN: 跑期间 HEAD 变了（$headBefore → $headAfter），本次结果归属需重新判定"
        }
        if ($statusChanged) {
            # 2026-11-12 监察实证：`0cf4eabfb` 那次 prod 跑期间有人改 TimetableWeekPage.kt，
            # 守卫读到被临时改掉的那一行而红——**一次本可避免的假红被当成真红分析了一整轮**。
            # 所以工作区变了与 HEAD 变了同级：都要告警，并且**不输出 RESULT 数字**（结果归属存疑）。
            & $writeEvidence "=== WARN: 跑期间工作区被改，本次结果归属存疑（STATUS before/after 集合不同）"
        }
    }

    # ③ 用例数：**只有本次测试任务真的执行过**才允许打 RESULT。
    # 2026-11-12 监察实证：编译失败那轮（`> Task :app:compileDevDebugKotlin FAILED`）也打印了
    # 「5 tests, 1 failures」，而且聚合 sha 与上一轮真红完全相同——它把旧 XML 又读了一遍。
    # 后果是「编译失败」伪装成「测试失败」：判据让看 RESULT 与失败用例名，而编译失败恰好没有
    # 用例名，很容易被当成"红在别处"。所以这里先判状态，再决定是否计数。
    $logTextForState = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
    $compileFailed = $logTextForState -match '> Task :app:compile[A-Za-z0-9_]* FAILED'
    $testState = ''
    if ($testTaskArg) {
        $tm = [regex]::Match($logTextForState, '> Task ' + [regex]::Escape($testTaskArg) + '(?<state>[^\r\n]*)')
        if ($tm.Success) { $testState = $tm.Groups['state'].Value.Trim() }
    }
    $testRan = ($testState -eq '')

    $emittedResult = $false
    # 标记语义（2026-11-12 定死，别混）：
    # · `NO-TEST-TASK` —— 本次请求本来就不含测试任务（如 `:app:help`、`:app:compile*`）⇒ **正常**；
    # · `TESTS-NOT-RUN` —— 该跑却没跑（编译失败 / UP-TO-DATE / SKIPPED / 产物缺失）⇒ **异常**。
    # 一个标记承载两种语义时，机械扫描只能二选一地误判（监察实测把两份 help 日志标成异常）。
    if ($compileFailed) {
        & $writeEvidence "=== TESTS-NOT-RUN (compile failed)"
    } elseif (-not $testTaskArg) {
        & $writeEvidence "=== NO-TEST-TASK（本次请求不含测试任务；正常，不是异常）"
    } elseif (-not $testRan) {
        & $writeEvidence "=== TESTS-NOT-RUN (test task 未执行：$($testState.Trim()))"
    } elseif (-not $resultsDirPath -or -not (Test-Path -LiteralPath $resultsDirPath)) {
        # #2 兜底：任务说跑了，但结果目录没有产物（被清空后没重建）⇒ 同样不许报数。
        & $writeEvidence "=== TESTS-NOT-RUN (test task 执行但结果目录无产物：$resultsDirName)"
    } elseif ($statusChanged) {
        # 跑期间工作区被改：测试确实跑了，但**数字归属存疑**，所以不输出用例数（不是"没跑"）。
        & $writeEvidence "=== RESULT-WITHHELD（跑期间工作区被改，用例数不输出；见上方 WARN）"
    } else {
        foreach ($dir in @(Get-ChildItem $resultsRoot -Directory | Where-Object { $_.Name -eq $resultsDirName })) {
            $xmlFiles = @(Get-ChildItem $dir.FullName -Filter "*.xml" -File)
            if ($xmlFiles.Count -eq 0) { continue }
            $tests = 0; $failures = 0; $errors = 0; $skipped = 0
            $failureLines = @()
            foreach ($f in $xmlFiles) {
                try {
                    [xml]$doc = Get-Content $f.FullName -Raw
                    $tests += [int]$doc.testsuite.tests
                    $failures += [int]$doc.testsuite.failures
                    $errors += [int]$doc.testsuite.errors
                    $skipped += [int]$doc.testsuite.skipped
                    # 失败列表：摘要必须能回答「红在哪」，否则复核还得重跑（2026-11-12 监察）。
                    foreach ($tc in @($doc.testsuite.testcase)) {
                        foreach ($bad in @(@($tc.failure) + @($tc.error))) {
                            if ($null -eq $bad) { continue }
                            # 断言消息优先取 message 属性（首行通常就是断言原文），没有再退回正文。
                            $msgRaw = [string]$bad.GetAttribute('message')
                            if ([string]::IsNullOrWhiteSpace($msgRaw)) { $msgRaw = [string]$bad.InnerText }
                            $msg = ($msgRaw -split "`n")[0].Trim()
                            $failureLines += ("FAILURE {0}.{1} :: {2}" -f $tc.classname, $tc.name, $msg)
                        }
                    }
                } catch { }
            }
            & $writeEvidence "=== RESULT[$($dir.Name)]: $tests tests, $failures failures, $errors errors, $skipped skipped (XML 文件 $($xmlFiles.Count))"
            & $writeEvidence "=== RESULT-DIR: $($dir.FullName)"
            $emittedResult = $true

            # 归档摘要（2026-11-12 监察要求）：过滤跑会覆盖同变体的 XML 目录，
            # 上一次全量的磁盘物证会就此消失（实测：`--tests` 跑完后只剩 1 份 XML / 3 tests）。
            # 所以每次跑完把「本次是谁、多少用例、每份 XML 的 sha256 + 汇总 sha」写进
            # `.agents/diag/<runId>/summary.txt`，不复制 XML 本体（省盘），但足以事后核对
            # 「某次声称的 N 用例」是不是这一批文件算出来的。
            $shaShortAgg = if ($headBefore) { $headBefore.Substring(0, [Math]::Min(9, $headBefore.Length)) } else { "nogit" }
            $sumDir = Join-Path $repoRoot (".agents/diag/{0}-{1}-{2}" -f $runStamp, $shaShortAgg, $dir.Name)
            New-Item -ItemType Directory -Path $sumDir -Force | Out-Null
            $sumLines = @(
                "=== REQUEST: $($effective -join ' ')",
                "=== FILTERED: $(if (($effective -join ' ') -match '--tests') { 'yes（--tests 生效，非全量）' } else { 'no（全量）' })",
                "=== HEAD before: $headBefore",
                "=== HEAD after: $(if ($gitExe) { $headAfter } else { '<n/a>' })",
                "=== RESULT[$($dir.Name)]: $tests tests, $failures failures, $errors errors, $skipped skipped",
                "=== XML-DIR: $($dir.FullName)",
                "=== XML-COUNT: $($xmlFiles.Count)",
                "=== FAILURE-COUNT: $($failureLines.Count)",
                ""
            )
            $sumLines += $failureLines
            if ($failureLines.Count -gt 0) { $sumLines += "" }
            $hashPairs = @()
            foreach ($f in $xmlFiles) {
                $fh = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
                $relName = $f.Name
                $hashPairs += "$relName $fh"
                $sumLines += "XML-SHA256 $relName $fh"
            }
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $aggBytes = [System.Text.Encoding]::UTF8.GetBytes(($hashPairs -join "`n"))
            $aggHash = (([System.BitConverter]::ToString($sha256.ComputeHash($aggBytes)) -replace '-', '')).ToLower()
            $sha256.Dispose()
            $sumLines += ""
            $sumLines += "=== AGGREGATE-SHA256: $aggHash"
            Set-Content -LiteralPath (Join-Path $sumDir "summary.txt") -Value $sumLines -Encoding utf8NoBOM
            if (-not (Test-Path -LiteralPath (Join-Path $sumDir "summary.txt"))) {
                throw "归档摘要写入失败：$sumDir\summary.txt"
            }
            & $writeEvidence "=== SUMMARY-DIR: $sumDir"
        }
    }

    # ④ 落盘自检（2026-11-12）：证据机制自己必须被证明。日志里缺 `=== REQUEST/HEAD before/after`
    #    （以及跑过测试时的 `=== RESULT`）⇒ 说明落盘路径其实失效了，此时**不许**报成功。
    if (-not (Test-Path -LiteralPath $logPath)) {
        throw "日志不存在：$logPath——不把无日志当成功"
    }
    $logText = Get-Content -LiteralPath $logPath -Raw
    $requiredMarkers = @('=== REQUEST:', '=== HEAD before:', '=== HEAD after:')
    if ($emittedResult) { $requiredMarkers += '=== RESULT[' }
    $missing = @($requiredMarkers | Where-Object { -not $logText.Contains($_) })
    if ($missing.Count -gt 0) {
        throw ("日志缺证据行 [{0}]：{1}——落盘路径可能失效，不把这次跑当成有证据" -f ($missing -join ', '), $logPath)
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
