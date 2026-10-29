<#
.SYNOPSIS
    跨 Agent 安全 Gradle 构建包装脚本（带全局排队互斥锁）。

.DESCRIPTION
    当多个 Agent 并发工作时，并发执行 Gradle 会瞬间拉起多个 JVM（每个 2~4GB），
    造成系统内存枯竭、CPU 剧烈抖动与缓存文件锁冲突。
    本脚本利用 Windows 内核级命名互斥锁（Mutex），确保本机同一时刻最多只有 1 个
    Gradle 构建在运行，其余 Agent 自动排队，杜绝内存雪崩。

    本脚本还**只在本地**覆盖一处「为省 CI 而伤本地」的配置。CI / CNB 直接调 gradlew，
    不经过本脚本，因此完全不受影响；`android/gradle.properties` 里的 `org.gradle.daemon=false`
    保留不动。
    （2026-10-27 实测：`org.gradle.daemon=false` 时每次调用固定开销 ~27s，
     当天本机累计启动一次性 JVM ≥577 个、构建耗时 8.2 小时。）
      --daemon      覆盖 org.gradle.daemon=false
                    （实测 `:app:help`：28s → 7s（daemon 热）→ 收敛后 3s）

    daemon 的**空闲退出时间不在这里传**，而是写在 `android/gradle.properties` 的
    `org.gradle.daemon.idletimeout=600000`。别改成命令行 `-D`：daemon 的复用判据包含
    `idleTimeout`，多一个 `-D` 就会造出「只有走本闸门的客户端才认」的第二个 daemon，
    与 Android Studio / 裸 gradlew 各占一份内存（2026-10-27 实测同机因此并存 2 个 daemon、
    4 个 JVM 合计 6803 MB，可用内存从 9.39 GB 掉到 4.02 GB）。

    刻意**不**打开 kotlin 增量编译（尽管 gradle.properties 里写着 false）：
    2026-10-27 实测加 `-Pkotlin.incremental=true` 后，4 个 Flutter 插件模块
    （dynamic_color / device_info_plus / image_picker_android / file_picker，源码位于
    PUB_CACHE 的 D:\Cache\Pub\hosted\pub.dev\...）**必然编译失败**：
      Could not close incremental caches in ...\build\kotlin\compileDebugKotlin\cacheable\caches-jvm\jvm\kotlin
    同一命令改回 `-Pkotlin.incremental=false` 立即 BUILD SUCCESSFUL（对照实验原始输出见
    `.agents/diag/perf-2026-10-27/opt/verify.md`）。要再试增量，必须先解决这个插件缓存报错。

    另外：当请求的任务**全部**是 `:app:compile*Kotlin` 这种「只编 Kotlin」的编译任务时，
    按**变体名**推导并追加 `-x :app:compileFlutterBuild<变体>`（例如
    `:app:compileDevDebugKotlin` → `-x :app:compileFlutterBuildDevDebug`），省掉
    flutter.bat → dart → dartvm → dartaotruntime 那条链（实测 3 个 Dart 进程、约 700MB）。
    L2 测试任务（`:app:test*`）**不会**被自动排除——单测需要 Flutter 资源。
    要强制走完整链时加 -WithFlutterAssets。

    （2026-10-29 改：原来写死 `compileFlutterBuildComposeUiDebug`。composeUi flavor 删除后
     那个任务已不存在，写死会让 `-x` 指向不存在的任务而直接构建失败，故改为按变体推导。）

.EXAMPLE
    pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin
    pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest
    pwsh -File scripts/safe-gradle.ps1 -WithFlutterAssets :app:compileDevDebugKotlin
#>

[CmdletBinding()]
param(
    # 关掉「只编 Kotlin 时自动跳过 Flutter 资源链」的默认行为。
    [switch]$WithFlutterAssets,

    # 重新看到 Gradle 弃用警告（默认压制：AGP 9 下每个 Flutter 插件模块各打一条
    # 「Deprecated 'org.jetbrains.kotlin.android' plugin usage」，~19 条纯噪音；
    # 走 Gradle 警告通道，--warning-mode none 能压掉；AGP 自己的 7 条 WARNING 走
    # android.sync.suppressAgpWarnings（gradle.properties），与此开关无关。
    # CI / AS / 裸 gradlew 不经过本闸门，不受影响。）
    [switch]$ShowDeprecations,

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

    Push-Location $androidDir
    try {
        # 本地专用覆盖（见 .DESCRIPTION）：命令行参数优先级高于 android/gradle.properties，
        # 所以这里能覆盖 daemon=false，而 CI 不受影响。
        # 注意：**不要**在这里加 -D 之类的 JVM/上下文参数。daemon 的复用判据包含
        # DefaultDaemonContext（javaHome + daemonOpts + idleTimeout …），多一个 -D 就会
        # 造出一个「只有走本闸门的客户端才认」的独立 daemon，与 Android Studio / 裸 gradlew
        # 各占一份内存（2026-10-27 实测：同机因此并存 2 个 daemon、4 个 JVM 合计 6.8 GB）。
        # idle 超时统一写在 android/gradle.properties 里，让所有客户端收敛到同一个 daemon。
        $effective = @('--daemon') + @($GradleArgs)

        # 默认压掉 Gradle 通道的弃用警告（见 $ShowDeprecations 注释）。
        # 加在 $effective 上、在 onlyKotlin 判定之后都不影响：判定读的是 $GradleArgs（纯任务名）。
        if (-not $ShowDeprecations) {
            $effective += @('--warning-mode', 'none')
        }

        # 「只编 Kotlin」时自动跳过 Flutter/Dart 那条链；L2 测试任务不匹配，不会被跳过。
        #
        # 跳过的任务名**按变体推导**，不写死（2026-10-29）：composeUi flavor 删除后
        # `compileFlutterBuildComposeUiDebug` 已不存在，写死会让 -x 指向不存在的任务。
        if (-not $WithFlutterAssets -and @($GradleArgs).Count -gt 0) {
            $onlyKotlinCompile = $true
            $flutterAssetTasks = @()
            foreach ($a in $GradleArgs) {
                if ($a -notmatch '^:app:compile([A-Za-z0-9]+)Kotlin$') {
                    $onlyKotlinCompile = $false
                    continue
                }
                $variant = $Matches[1]
                # 只有「flavor+构建类型」这种真变体才有 compileFlutterBuild* 任务；
                # ProdDebugUnitTest 这类测试编译任务不加（加了同样指向不存在的任务）。
                if ($variant -match '^(Dev|Perf|Prod|Itest)(Debug|Profile|Release)$') {
                    $flutterAssetTasks += ":app:compileFlutterBuild$variant"
                }
            }
            if ($onlyKotlinCompile -and $flutterAssetTasks.Count -gt 0 -and ($GradleArgs -notcontains '-x')) {
                foreach ($t in $flutterAssetTasks) {
                    if ($GradleArgs -notcontains $t) {
                        $effective += @('-x', $t)
                        Write-Host ">>> [safe-gradle] 只编 Kotlin：自动追加 -x $t（要完整链加 -WithFlutterAssets）" -ForegroundColor DarkCyan
                    }
                }
            }
        }

        Write-Host ">>> [safe-gradle] 实际参数: $($effective -join ' ')" -ForegroundColor DarkGray
        & $gradlew @effective
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
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
