<#
.SYNOPSIS
    L0 单次运行的「真实耗时 + 峰值内存」采样器（只读观测，不改被测脚本）。

.DESCRIPTION
    `scripts/test-kotlin-module.ps1` 头部注释里的实测数字就是用它采出来的，方法固定下来可复现：
    启动一次被测脚本，每 `-PollMs` 毫秒轮询「本次运行进程树里的 kotlinc JVM」的 WorkingSetSize，
    记录峰值 RSS、kotlinc 存活区间与整次调用墙钟。
    只统计自己派生的进程（按父子关系向下收集），别的 Agent 同时在跑的 kotlinc 不会被算进来。

    为什么需要它：旧版脚本头部写的是「0.1s~0.2s / <150MB」，与实测差了近两个数量级
    （2026-10-28 实测：墙钟 24.3s、kotlinc 峰值 RSS 848MB）。那种数字会让下一个人误以为
    「L0 随便刷也不花钱」，所以实测口径必须能一键复现，而不是靠谁记得。

.EXAMPLE
    pwsh -File scripts/probe-kotlin-module-perf.ps1 -Module "pages/feedback" -Tag feedback
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Module,
    [string]$ScriptPath = (Join-Path $PSScriptRoot "test-kotlin-module.ps1"),
    [int]$PollMs = 100,
    [string]$LogDir = "$env:TEMP\diag\l0",
    [string]$Tag = "run"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$log = Join-Path $LogDir "measure-$Tag.txt"
$outLog = Join-Path $LogDir "measure-$Tag.stdout.txt"
$errLog = Join-Path $LogDir "measure-$Tag.stderr.txt"
$lines = New-Object System.Collections.Generic.List[string]

function Add-Line([string]$s) { $lines.Add($s) | Out-Null; Write-Host $s }

function Get-AllProcs {
    Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CommandLine, WorkingSetSize
}

function Read-LogText([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    try {
        $strict = [System.Text.UTF8Encoding]::new($false, $true)
        return ($strict.GetString($bytes) -split "`r?`n")
    } catch {
        # 子进程 stdout 默认按本机 ANSI 代码页（中文 Windows = 936/GBK）编码
        $ansi = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage)
        return ($ansi.GetString($bytes) -split "`r?`n")
    }
}

Add-Line "=== probe-kotlin-module-perf tag=$Tag module=$Module ==="
Add-Line "script   = $ScriptPath"
Add-Line "started  = $(Get-Date -Format o)"

# 预检：本机是否已有别的 kotlinc 在跑（只记录，不干扰）
$pre = @(Get-AllProcs | Where-Object { $_.Name -eq 'java.exe' -and $_.CommandLine -like '*K2JVMCompiler*' })
Add-Line "precheck: 已存在的（别人的）kotlinc JVM 数 = $($pre.Count)"
foreach ($p in $pre) { Add-Line ("  pre  PID={0} RSS={1}MB" -f $p.ProcessId, [int]($p.WorkingSetSize / 1MB)) }

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process -FilePath "pwsh" -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $ScriptPath, '-Module', $Module) `
    -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru -WindowStyle Hidden

$peakRssMb = 0
$peakPid = 0
$kotlincSeen = @{}
$kotlincFirstSeen = $null
$kotlincLastSeen = $null
$maxCount = 0

while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds $PollMs
    $all = Get-AllProcs
    # 从本次 pwsh 出发，向下收集整棵子进程树
    $desc = New-Object System.Collections.Generic.HashSet[int]
    $frontier = @([int]$proc.Id)
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
    $kots = @($all | Where-Object { $desc.Contains([int]$_.ProcessId) -and $_.CommandLine -like '*K2JVMCompiler*' })
    if ($kots.Count -gt $maxCount) { $maxCount = $kots.Count }
    foreach ($k in $kots) {
        $rss = [int]($k.WorkingSetSize / 1MB)
        $kotlincSeen[[int]$k.ProcessId] = $true
        if ($rss -gt $peakRssMb) { $peakRssMb = $rss; $peakPid = [int]$k.ProcessId }
        if ($null -eq $kotlincFirstSeen) { $kotlincFirstSeen = $sw.ElapsedMilliseconds }
        $kotlincLastSeen = $sw.ElapsedMilliseconds
    }
}

$proc.WaitForExit()
$sw.Stop()

Add-Line "exitcode = $($proc.ExitCode)"
Add-Line "wall_ms  = $($sw.ElapsedMilliseconds)  ($([Math]::Round($sw.Elapsed.TotalSeconds,2)) s)"
Add-Line "kotlinc JVM 峰值 RSS = $peakRssMb MB (PID $peakPid)"
Add-Line "kotlinc JVM 出现过 $($kotlincSeen.Count) 个不同 PID；本次运行内同时存活最大数 = $maxCount"
if ($null -ne $kotlincFirstSeen) {
    Add-Line "kotlinc 首见 $kotlincFirstSeen ms / 末见 $kotlincLastSeen ms ⇒ 编译段约 $([Math]::Round(($kotlincLastSeen - $kotlincFirstSeen) / 1000.0, 2)) s"
}
Add-Line "--- child stdout ($outLog) ---"
foreach ($l in (Read-LogText $outLog)) { Add-Line $l }
Add-Line "--- child stderr（只记首 10 行 / 共 $(@(Read-LogText $errLog).Count) 行）---"
foreach ($l in (@(Read-LogText $errLog) | Select-Object -First 10)) { Add-Line $l }

$lines | Out-File -Encoding utf8 $log
Write-Host "wrote $log"
exit $proc.ExitCode
