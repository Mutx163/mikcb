<#
.SYNOPSIS
    L0 模块锁咬合探针：证明「同一模块并发调用会被串行化、且不互相删输出」。

.DESCRIPTION
    并行起 N 个 `scripts/test-kotlin-module.ps1 -Module <同一个模块>`，全程轮询
    「本次探针派生的进程树里的 kotlinc JVM」，据此判定锁是否真的生效。
    只统计自己启动的进程树（按父子关系向下收集），不会把别的 Agent 的 kotlinc 算进来。

    默认（locked）模式的断言：
      A1 每个并发调用的退出码都是 0
      A2 任一采样时刻，同时存活的 kotlinc JVM 数 <= 1        ← 锁的咬合点
      A3 两次调用用的 kotlinc @argfile 路径互不相同          ← 共享路径已消除
      A4 结束后：%TEMP% 下没有本次运行新留下的 mikcb-l0-* 目录；
         build/tmp/kotlinc_<slug>.args 未被改写、build/tmp/test_classes_<slug> 不存在
                                                              ← 旧共享路径彻底不再使用
    反向验证（必须做）：把被测脚本里的锁临时去掉，A2 必须变红（探针 exit 1）；
    还原后必须重新变绿。没有反向验证，这个探针可能只是「永远绿的摆设」。

    跨模块模式（`-SecondModule pages/xxx -ExpectMaxConcurrent 2`）用来证明锁**不是全局锁**：
    两个不同模块必须能真正并行（峰值 kotlinc JVM 数 >= 2）；做成全局锁会把多 Agent 拖成串行。

    baseline 模式（`-ExpectMaxConcurrent 2 -ExpectSharedArgFile`）用来复现**旧版**脚本的 bug：
    旧版 args 文件/输出目录按模块名固定，后启动的进程一进来就
    `Remove-Item -Recurse -Force $outDir` 删掉先启动进程的输出目录、并覆盖同一份 args 文件。
    为了稳定抓到这一刀，baseline 模式配合 `-StaggerMs`（先起 run1，等它的 kotlinc 已经在编了，
    再起 run2），此时：
      A2b 峰值 kotlinc JVM 数必须 >= 2（证明真并发了）
      A4b 必须抓到「输出目录在还有 kotlinc 活着时被删掉/重建」与「argfile 在 kotlinc 活着时被改写」

.EXAMPLE
    # 正常（锁在位）——应绿
    pwsh -File scripts/probe-kotlin-module-lock.ps1 -Module pages/feedback

    # 复现旧版 bug（旧版脚本：git show HEAD:scripts/test-kotlin-module.ps1 > scripts/probe-kotlin-module-baseline.ps1）
    pwsh -File scripts/probe-kotlin-module-lock.ps1 -Module pages/feedback `
        -ScriptPath scripts/probe-kotlin-module-baseline.ps1 `
        -ExpectMaxConcurrent 2 -ExpectSharedArgFile -StaggerMs 5000
#>

[CmdletBinding()]
param(
    [string]$Module = "pages/feedback",
    [string]$SecondModule = "",
    [string]$ScriptPath = (Join-Path $PSScriptRoot "test-kotlin-module.ps1"),
    [int]$Runs = 2,
    [int]$ExpectMaxConcurrent = 1,
    [switch]$ExpectSharedArgFile,
    [int]$StaggerMs = 0,
    [int]$TimeoutSec = 600,
    [int]$PollMs = 120,
    [string]$LogDir = "$env:TEMP\diag\l0",
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (-not $Tag) { $Tag = "probe-" + (Get-Date -Format "yyyyMMdd-HHmmss") }
$reportPath = Join-Path $LogDir "$Tag.report.txt"
$lines = New-Object System.Collections.Generic.List[string]
$failures = New-Object System.Collections.Generic.List[string]

function Add-Line([string]$s) { $lines.Add($s) | Out-Null; Write-Host $s }
function Add-Fail([string]$s) { $failures.Add($s) | Out-Null; Add-Line "  [FAIL] $s" }
function Add-Note([string]$s) { Add-Line "  [note] $s" }

$cleanModule = $Module -replace "^android/app/src/(main|test)/kotlin/com/mutx163/qingyu/pages/", "" `
                       -replace "^pages/", "" -replace "[\\/]+$", ""
$slug = $cleanModule -replace "[^A-Za-z0-9_.\-]", "_"
$repoRoot = Split-Path -Parent $PSScriptRoot
$legacyArgFile = Join-Path $repoRoot "build/tmp/kotlinc_$slug.args"
$legacyOutDir = Join-Path $repoRoot "build/tmp/test_classes_$slug"

function Get-AllProcs {
    Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CommandLine, WorkingSetSize
}

function Get-Descendants([int[]]$roots, $all) {
    $desc = New-Object System.Collections.Generic.HashSet[int]
    $frontier = @($roots)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($pid0 in $frontier) {
            foreach ($p in $all) {
                if ([int]$p.ParentProcessId -eq $pid0 -and -not $desc.Contains([int]$p.ProcessId)) {
                    $desc.Add([int]$p.ProcessId) | Out-Null
                    $next += [int]$p.ProcessId
                }
            }
        }
        $frontier = $next
    }
    # 逗号包一层：PowerShell 会把函数返回值里的集合自动展开（空集合直接变 $null），
    # 展开后拿到的是 int[] 而不是 HashSet，后续 .Contains() 就会炸。
    return , $desc
}

# 子进程 stdout 是本机 ANSI 代码页（中文 Windows = 936/GBK）编码的，直接 Get-Content
# 按 UTF-8 读会变成乱码；先按 UTF-8 严格解码，失败退回 ANSI 代码页。
function Read-LogText([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    try {
        $strict = [System.Text.UTF8Encoding]::new($false, $true)
        return ($strict.GetString($bytes) -split "`r?`n")
    } catch {
        $ansi = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage)
        return ($ansi.GetString($bytes) -split "`r?`n")
    }
}

function Get-ArgFilesFromCmd([string]$cmd) {
    $found = @()
    if (-not $cmd) { return $found }
    foreach ($m in [regex]::Matches($cmd, '@([^"\s]+\.args)')) { $found += $m.Groups[1].Value }
    return $found
}

function Get-Stamp([string]$path) {
    $i = Get-Item $path -ErrorAction SilentlyContinue
    if ($i) { return $i.LastWriteTime.ToString("o") } else { return "<不存在>" }
}

Add-Line "=== probe-kotlin-module-lock  tag=$Tag ==="
Add-Line "module        = $cleanModule (slug=$slug)" + $(if ($SecondModule) { "   secondModule=$SecondModule（跨模块模式：期望两个模块并行，不被全局锁串起来）" } else { "" })
Add-Line "script        = $ScriptPath"
Add-Line "runs          = $Runs   expectMaxConcurrent=$ExpectMaxConcurrent  expectSharedArgFile=$($ExpectSharedArgFile.IsPresent)  staggerMs=$StaggerMs"
Add-Line "started       = $(Get-Date -Format o)"
Add-Line ""

# ---- 前置快照 ----
$preTempDirs = @(Get-ChildItem $env:TEMP -Directory -Filter "mikcb-l0-*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$preLegacyArgStamp = Get-Stamp $legacyArgFile
Add-Line "前置状态："
Add-Line "  %TEMP% 下已存在的 mikcb-l0-* 目录数 = $($preTempDirs.Count)"
Add-Line "  build/tmp/kotlinc_$slug.args LastWriteTime = $preLegacyArgStamp"
Add-Line "  build/tmp/test_classes_$slug 存在 = $(Test-Path $legacyOutDir)"
$preKots = @(Get-AllProcs | Where-Object { $_.Name -eq 'java.exe' -and $_.CommandLine -like '*K2JVMCompiler*' })
Add-Line "  本机已有的（别人的）kotlinc JVM 数 = $($preKots.Count)"
Add-Line ""

# ---- 并发启动（可错峰）----
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$procs = @()
for ($i = 1; $i -le $Runs; $i++) {
    if ($i -gt 1 -and $StaggerMs -gt 0) {
        Add-Line "错峰等待 ${StaggerMs}ms 后再启动 run$i ..."
        Start-Sleep -Milliseconds $StaggerMs
    }
    $o = Join-Path $LogDir "$Tag.run$i.stdout.txt"
    $e = Join-Path $LogDir "$Tag.run$i.stderr.txt"
    $mod = if ($i -ge 2 -and $SecondModule) { $SecondModule } else { $Module }
    $p = Start-Process -FilePath "pwsh" `
        -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $ScriptPath, '-Module', $mod) `
        -RedirectStandardOutput $o -RedirectStandardError $e -PassThru -WindowStyle Hidden
    $procs += [pscustomobject]@{ Index = $i; Proc = $p; Out = $o; Err = $e; Module = $mod; StartedMs = $sw.ElapsedMilliseconds }
    Add-Line "run$i 启动 pid=$($p.Id) t=$($sw.ElapsedMilliseconds)ms module=$mod  stdout=$o"
}
$rootIds = @($procs | ForEach-Object { [int]$_.Proc.Id })
Add-Line ""

# ---- 轮询 ----
$maxConcurrent = 0
$peakRss = 0
$argFilesSeen = New-Object System.Collections.Generic.HashSet[string]
$kotlincPids = @{}
$timeline = New-Object System.Collections.Generic.List[string]
$lastState = ""
$outMissingWhileAlive = $false
$outRecreatedWhileAlive = $false
$argRewrittenWhileAlive = $false
$prevOutCreation = "<无>"
$prevArgStamp = $preLegacyArgStamp
$pollCount = 0

while (@($procs | Where-Object { -not $_.Proc.HasExited }).Count -gt 0) {
    Start-Sleep -Milliseconds $PollMs
    $pollCount++
    $all = Get-AllProcs
    $desc = Get-Descendants $rootIds $all
    $kots = @($all | Where-Object { $desc.Contains([int]$_.ProcessId) -and $_.CommandLine -like '*K2JVMCompiler*' })
    if ($kots.Count -gt $maxConcurrent) { $maxConcurrent = $kots.Count }
    foreach ($k in $kots) {
        $kotlincPids[[int]$k.ProcessId] = $true
        $rss = [int]($k.WorkingSetSize / 1MB)
        if ($rss -gt $peakRss) { $peakRss = $rss }
        foreach ($af in (Get-ArgFilesFromCmd $k.CommandLine)) { $argFilesSeen.Add($af) | Out-Null }
    }

    # 旧共享路径的现场取证（只有 baseline 模式关心，locked 模式下这些状态根本不该变）
    $legacyOutExists = Test-Path $legacyOutDir
    $outCreation = "<无>"
    if ($legacyOutExists) {
        $di = Get-Item $legacyOutDir -ErrorAction SilentlyContinue
        if ($di) { $outCreation = $di.CreationTime.ToString("o") }
    }
    $argStampNow = Get-Stamp $legacyArgFile
    # 这三个「旧共享路径被踩」的取证只在 baseline 模式算：locked 模式下旧目录本来就该一直不存在，
    # 不加这个门会把「目录不存在」误记成「被删过」，报告就成了误导。
    if ($ExpectSharedArgFile -and $kots.Count -gt 0) {
        if (-not $legacyOutExists) { $outMissingWhileAlive = $true }
        if ($prevOutCreation -ne "<无>" -and $outCreation -ne "<无>" -and $outCreation -ne $prevOutCreation) { $outRecreatedWhileAlive = $true }
        if ($argStampNow -ne $prevArgStamp) { $argRewrittenWhileAlive = $true }
    }
    if ($outCreation -ne "<无>") { $prevOutCreation = $outCreation }
    $prevArgStamp = $argStampNow

    $state = "kotlinc=$($kots.Count) legacyOut=$legacyOutExists outCreation=$outCreation legacyArgWrite=$argStampNow"
    if ($state -ne $lastState) {
        $lastState = $state
        $timeline.Add(("t={0,6}ms  {1}" -f $sw.ElapsedMilliseconds, $state)) | Out-Null
    }
}

# ---- 收尾 ----
$allExited = $true
foreach ($p in $procs) {
    if (-not $p.Proc.WaitForExit($TimeoutSec * 1000)) {
        $allExited = $false
        Add-Line "run$($p.Index) 超时未退出，强杀进程树 pid=$($p.Proc.Id)"
        & taskkill /T /F /PID $p.Proc.Id 2>&1 | Out-Null
    }
}
$sw.Stop()

Add-Line "--- 采样时间线（状态变化时才记录，共 $pollCount 次采样）---"
foreach ($t in $timeline) { Add-Line "  $t" }
Add-Line ""

Add-Line "--- 结果 ---"
Add-Line "并发调用峰值 kotlinc JVM 数 = $maxConcurrent （期望 <= $ExpectMaxConcurrent）"
Add-Line "kotlinc JVM 峰值 RSS = $peakRss MB；出现过的 kotlinc PID 数 = $($kotlincPids.Count)"
Add-Line "旧共享输出目录在 kotlinc 活着时消失过 = $outMissingWhileAlive；被重建过 = $outRecreatedWhileAlive （仅 baseline 模式有意义）"
Add-Line "旧共享 argfile 在 kotlinc 活着时被改写 = $argRewrittenWhileAlive （仅 baseline 模式有意义）"
Add-Line "观察到的 @argfile 路径（$($argFilesSeen.Count) 个）："
foreach ($a in $argFilesSeen) { Add-Line "  $a" }
Add-Line ""
foreach ($p in $procs) {
    Add-Line "run$($p.Index) exitcode = $($p.Proc.ExitCode)  module=$($p.Module)   （总墙钟 $([Math]::Round(($sw.ElapsedMilliseconds)/1000.0,1))s）"
}
Add-Line ""

Add-Line "--- 各次调用的原始输出 ---"
foreach ($p in $procs) {
    Add-Line "### run$($p.Index) module=$($p.Module) stdout ($($p.Out))"
    foreach ($l in (Read-LogText $p.Out)) { Add-Line "  $l" }
    $errLines = @(Read-LogText $p.Err)
    Add-Line "### run$($p.Index) stderr（只记首 5 行 / 共 $($errLines.Count) 行）"
    foreach ($l in ($errLines | Select-Object -First 5)) { Add-Line "  $l" }
    Add-Line ""
}

# ---- 断言 ----
Add-Line "--- 断言 ---"
if (-not $allExited) { Add-Fail "A0 有并发调用未在 $TimeoutSec s 内退出" }
foreach ($p in $procs) {
    if ($p.Proc.ExitCode -ne 0) {
        if ($ExpectSharedArgFile) {
            Add-Note "baseline 模式：run$($p.Index) 退出码 $($p.Proc.ExitCode) != 0（可能就是互删造成的失败，正是要复现的现象）"
        } else {
            Add-Fail "A1 run$($p.Index) 退出码 $($p.Proc.ExitCode) != 0"
        }
    }
}
if ($maxConcurrent -gt $ExpectMaxConcurrent) {
    Add-Fail "A2 峰值 kotlinc JVM 数 $maxConcurrent > 期望 $ExpectMaxConcurrent（锁没兜住）"
}
if ($ExpectSharedArgFile -and $maxConcurrent -lt 2) {
    Add-Fail "A2b(baseline) 峰值 kotlinc JVM 数 $maxConcurrent < 2，没复现出同模块并发"
}
if ($SecondModule -and -not $ExpectSharedArgFile -and $maxConcurrent -lt 2) {
    Add-Fail "A2c(跨模块) 峰值 kotlinc JVM 数 $maxConcurrent < 2：两个不同模块被串行化了，说明锁做成了全局锁（应当只按模块互斥）"
}
if (-not $ExpectSharedArgFile -and $argFilesSeen.Count -lt $Runs) {
    Add-Fail "A3 只观察到 $($argFilesSeen.Count) 个不同的 @argfile 路径（<$Runs 次调用），共享路径可能还在"
}
if ($ExpectSharedArgFile -and $argFilesSeen.Count -ne 1) {
    Add-Fail "A3(baseline) 期望所有进程共用同一个 @argfile，实际 $($argFilesSeen.Count) 个"
}

$postTempDirs = @(Get-ChildItem $env:TEMP -Directory -Filter "mikcb-l0-*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$newTempDirs = @($postTempDirs | Where-Object { $preTempDirs -notcontains $_ })
if ($newTempDirs.Count -gt 0) { Add-Fail "A4 本次运行在 %TEMP% 留下了 $($newTempDirs.Count) 个 mikcb-l0-* 目录：$($newTempDirs -join '; ')" }

$postLegacyArgStamp = Get-Stamp $legacyArgFile
$legacyOutExistsAfter = Test-Path $legacyOutDir

if (-not $ExpectSharedArgFile) {
    if ($postLegacyArgStamp -ne $preLegacyArgStamp) {
        Add-Fail "A4 build/tmp/kotlinc_$slug.args 被改写了（$preLegacyArgStamp -> $postLegacyArgStamp），旧共享路径没消除"
    }
    if ($legacyOutExistsAfter) {
        Add-Fail "A4 build/tmp/test_classes_$slug 仍然存在，旧共享输出目录没消除"
    }
} else {
    if (-not ($outMissingWhileAlive -or $outRecreatedWhileAlive)) {
        Add-Fail "A4(baseline) 没抓到「旧共享输出目录在 kotlinc 还活着时被删掉/重建」"
    }
    if (-not $argRewrittenWhileAlive) {
        Add-Fail "A4(baseline) 没抓到「旧共享 argfile 在 kotlinc 还活着时被改写」"
    }
}

Add-Line ""
Add-Line "结束状态："
Add-Line "  build/tmp/kotlinc_$slug.args LastWriteTime = $postLegacyArgStamp"
Add-Line "  build/tmp/test_classes_$slug 存在 = $legacyOutExistsAfter"
Add-Line "  %TEMP% 新增残留目录数 = $($newTempDirs.Count)"
Add-Line ""
if ($failures.Count -eq 0) {
    Add-Line "PROBE RESULT = PASS"
} else {
    Add-Line "PROBE RESULT = FAIL（$($failures.Count) 条失败）"
    foreach ($f in $failures) { Add-Line "  - $f" }
}

$lines | Out-File -Encoding utf8 $reportPath
Write-Host "wrote $reportPath"
if ($failures.Count -eq 0) { exit 0 } else { exit 1 }
