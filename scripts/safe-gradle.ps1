<#
.SYNOPSIS
    跨 Agent 安全 Gradle 构建包装脚本（带全局排队互斥锁）。

.DESCRIPTION
    当多个 Agent 并发工作时，并发执行 Gradle 会瞬间拉起多个 JVM（每个 2~4GB），
    造成系统内存枯竭、CPU 剧烈抖动与缓存文件锁冲突。
    本脚本利用 Windows 内核级命名互斥锁（Mutex），确保本机同一时刻最多只有 1 个
    Gradle 构建在运行，其余 Agent 自动排队，杜绝内存雪崩。

.EXAMPLE
    pwsh -File scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin
#>

[CmdletBinding()]
param(
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
        if ($GradleArgs.Count -eq 0) {
            & $gradlew
        } else {
            & $gradlew @GradleArgs
        }
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
