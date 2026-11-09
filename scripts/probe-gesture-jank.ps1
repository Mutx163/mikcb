<#
.SYNOPSIS
    只读抓取「滑动卡住」现场：帧台账 + 系统 jank 统计 + 相关 logcat。

.DESCRIPTION
    只调用这些 adb 子命令（全部只读，不注入触摸、不改设置、不装不卸）：
      adb devices / adb shell dumpsys gfxinfo <包> [framestats] /
      adb shell dumpsys display / adb shell dumpsys window / adb logcat -d

    用法（手机连上、停在日视图、把「滑不动」复现出来之后）：
      pwsh -File scripts/probe-gesture-jank.ps1
      pwsh -File scripts/probe-gesture-jank.ps1 -Package com.mutx163.qingyu.debug
      pwsh -File scripts/probe-gesture-jank.ps1 -Watch 20     # 边滑边抓 20 秒

    输出落在 `.agents/diagnostics/gesture-<时间戳>/`（`.agents/` 已在 .gitignore 里）。

.PARAMETER SelfTest
    不碰手机，用内置样本验证帧数据解析，防止抓回来一堆数字算错。

.NOTES
    帧数据缓冲只保留最近约 120 帧（60Hz 下约 2 秒）——复现完要尽快抓；
    抓不到就用 -Watch 让它一边轮询一边等你滑。
#>
[CmdletBinding()]
param(
    [string]$Package = '',
    [string]$Serial = '',
    [int]$Watch = 0,
    [int]$Interval = 2,
    [int]$LogLines = 800,
    [string]$OutDir = '',
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$script:Failures = 0

# ── 帧数据解析（纯函数，SelfTest 直接跑它）──────────────────────────────

function ConvertFrom-FrameStats {
    <#
        返回每个帧的毫秒数（FrameCompleted − IntendedVsync）。
        framestats 的行首比表头多一列（窗口下标），按实际列数自动判偏移。
    #>
    param([string[]]$Lines)

    $headerIndex = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^Flags,.*IntendedVsync.*FrameCompleted') { $headerIndex = $i; break }
    }
    if ($headerIndex -lt 0) { return @() }

    $header = $Lines[$headerIndex].Split(',')
    $startIdx = [Array]::IndexOf($header, 'IntendedVsync')
    $endIdx = [Array]::IndexOf($header, 'FrameCompleted')
    if ($startIdx -lt 0 -or $endIdx -lt 0) { return @() }

    $frames = [System.Collections.Generic.List[double]]::new()
    for ($i = $headerIndex + 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i].Trim()
        if ($line -eq '' -or $line -match '^-+PROFILEDATA-+$' -or $line -match '^---') { continue }
        $cells = $line.Split(',')
        # 行首多一列（窗口下标）；表头列数 = 行首之后的列数。
        $offset = if ($cells.Count -eq $header.Count + 1) { 1 } else { 0 }
        $si = $startIdx + $offset
        $ei = $endIdx + $offset
        if ($cells.Count -le [Math]::Max($si, $ei)) { continue }
        $start = 0L; $end = 0L
        if (-not [long]::TryParse($cells[$si], [ref]$start)) { continue }
        if (-not [long]::TryParse($cells[$ei], [ref]$end)) { continue }
        if ($start -le 0 -or $end -le 0 -or $end -lt $start) { continue }
        $frames.Add(($end - $start) / 1e6)
    }
    return $frames
}

function Get-Percentile {
    param([double[]]$Values, [double]$P)
    if ($Values.Count -eq 0) { return 0 }
    $sorted = $Values | Sort-Object
    $idx = [Math]::Min($sorted.Count - 1, [Math]::Ceiling($P / 100.0 * $sorted.Count) - 1)
    return [double]$sorted[[Math]::Max(0, $idx)]
}

function Format-FrameSummary {
    param([double[]]$Frames, [double]$BudgetMs)

    if ($Frames.Count -eq 0) { return @('（没有解析到帧数据）') }

    $over1 = @($Frames | Where-Object { $_ -gt $BudgetMs }).Count
    $over2 = @($Frames | Where-Object { $_ -gt $BudgetMs * 2 }).Count
    $worst = $Frames | Sort-Object -Descending | Select-Object -First 5
    $lines = @(
        ('帧数: {0}' -f $Frames.Count),
        ('单帧预算: {0:N2} ms' -f $BudgetMs),
        ('超 1 倍预算: {0} 帧 ({1:N1}%)' -f $over1, (100.0 * $over1 / $Frames.Count)),
        ('超 2 倍预算: {0} 帧 ({1:N1}%)' -f $over2, (100.0 * $over2 / $Frames.Count)),
        ('P50 / P90 / P99: {0:N1} / {1:N1} / {2:N1} ms' -f `
                (Get-Percentile $Frames 50), (Get-Percentile $Frames 90), (Get-Percentile $Frames 99)),
        ('最慢 5 帧: ' + (($worst | ForEach-Object { '{0:N1}' -f $_ }) -join ' / ') + ' ms')
    )
    return $lines
}

function Get-GfxInfoHighlights {
    <# 从 `dumpsys gfxinfo` 正文里抠出系统自己的 jank 口径。 #>
    param([string[]]$Lines)
    $patterns = 'Total frames rendered', 'Janky frames', '50th percentile', '90th percentile',
    '95th percentile', '99th percentile', 'Number Missed Vsync', 'Number Slow UI thread',
    'Number Slow issue draw commands', 'Number Slow bitmap uploads', 'Number Slow issue'
    $out = foreach ($line in $Lines) {
        $t = $line.Trim()
        foreach ($p in $patterns) { if ($t.StartsWith($p)) { $t; break } }
    }
    return @($out)
}

# ── 自检：不碰手机，验证解析与统计 ──────────────────────────────────────

if ($SelfTest) {
    $sample = @(
        'Flags,FrameTimelineVsyncId,IntendedVsync,Vsync,InputEventId,HandleInputStart,AnimationStart,PerformTraversalsStart,DrawStart,SyncStart,IssueDrawCommandsStart,SwapBuffers,FrameCompleted',
        '0,0,1000000000,1000000000,0,0,0,0,0,0,0,1010000000,1016600000',
        '0,0,2000000000,2000000000,0,0,0,0,0,0,0,2010000000,2016600000',
        '0,0,3000000000,3000000000,0,0,0,0,0,0,0,3030000000,3035000000',
        '0,0,4000000000,4000000000,0,0,0,0,0,0,0,4005000000,4010000000',
        '---PROFILEDATA---'
    )
    $frames = @(ConvertFrom-FrameStats -Lines $sample)
    $budget = 16.6667
    $expected = @(16.6, 16.6, 35.0, 10.0)
    $ok = $frames.Count -eq $expected.Count
    for ($i = 0; $ok -and $i -lt $expected.Count; $i++) {
        if ([Math]::Abs($frames[$i] - $expected[$i]) -gt 0.05) { $ok = $false }
    }
    $summary = Format-FrameSummary -Frames $frames -BudgetMs $budget
    $over = @($frames | Where-Object { $_ -gt $budget }).Count
    Write-Host '── 自检 ──'
    $summary | ForEach-Object { Write-Host "  $_" }
    Write-Host ("  期望帧数 {0}，实得 {1}；超预算 {2} 帧（期望 1）" -f $expected.Count, $frames.Count, $over)
    if ($ok -and $over -eq 1) {
        Write-Host '  结果：通过' -ForegroundColor Green
        exit 0
    }
    Write-Host '  结果：失败' -ForegroundColor Red
    exit 1
}

# ── 设备与包 ────────────────────────────────────────────────────────────

function Invoke-Adb {
    param([string[]]$AdbArgs)
    $prefix = @()
    if ($Serial) { $prefix = @('-s', $Serial) }
    return & adb @prefix @AdbArgs 2>&1
}

$devices = @(& adb devices 2>&1 | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' })
if ($devices.Count -eq 0) {
    Write-Host '没有检测到设备。' -ForegroundColor Yellow
    Write-Host '请：USB 连手机 → 开发者选项开「USB 调试」→ 手机上点「允许」→ 回来重跑。'
    exit 2
}
if (-not $Serial -and $devices.Count -gt 1) {
    Write-Host '检测到多台设备，请用 -Serial 指定：' -ForegroundColor Yellow
    $devices | ForEach-Object { Write-Host "  $($_.Split()[0])" }
    exit 2
}
if (-not $Serial) { $Serial = $devices[0].Split()[0] }

if (-not $Package) {
    $installed = @(Invoke-Adb @('shell', 'pm', 'list', 'packages'))
    $candidates = @('com.mutx163.qingyu.debug', 'com.mutx163.qingyu.profile', 'com.mutx163.qingyu', 'com.mutx163.qingyu.itest')
    $Package = $candidates | Where-Object { $installed -match "package:$([regex]::Escape($_))$" } | Select-Object -First 1
    if (-not $Package) {
        Write-Host '设备上没找到轻屿课表的四个包名，请用 -Package 指定。' -ForegroundColor Yellow
        exit 3
    }
}

if (-not $OutDir) {
    $OutDir = Join-Path (Join-Path (Get-Location) '.agents/diagnostics') ('gesture-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 刷新率（只读）：拿不到就按 60Hz
$budgetMs = 16.6667
$display = @(Invoke-Adb @('shell', 'dumpsys', 'display'))
$rateLine = $display | Select-String -Pattern 'mRefreshRate=|renderFrameRate=' | Select-Object -First 1
if ($rateLine -and $rateLine.Line -match '([0-9]+\.?[0-9]*)\s*$') {
    $hz = [double]$Matches[1]
    if ($hz -ge 30 -and $hz -le 165) { $budgetMs = 1000.0 / $hz }
}
$focus = (Invoke-Adb @('shell', 'dumpsys', 'window')) | Select-String -Pattern 'mCurrentFocus' | Select-Object -First 1

$meta = @(
    "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "设备: $Serial",
    "包名: $Package",
    "单帧预算: $([Math]::Round($budgetMs, 3)) ms",
    "前台: $($focus -replace '\s+', ' ')",
    '只读采集：未注入触摸、未改设置、未装卸载。'
)
$meta | Set-Content -Path (Join-Path $OutDir 'meta.txt') -Encoding utf8

# ── 采集 ────────────────────────────────────────────────────────────────

function Save-GfxInfo {
    param([string]$Stamp)
    $plain = @(Invoke-Adb @('shell', 'dumpsys', 'gfxinfo', $Package))
    $plain | Set-Content -Path (Join-Path $OutDir "gfxinfo-$Stamp.txt") -Encoding utf8
    $stats = Get-GfxInfoHighlights -Lines $plain

    $framesRaw = @(Invoke-Adb @('shell', 'dumpsys', 'gfxinfo', $Package, 'framestats'))
    $framesRaw | Set-Content -Path (Join-Path $OutDir "framestats-$Stamp.txt") -Encoding utf8
    $frames = @(ConvertFrom-FrameStats -Lines $framesRaw)

    return [pscustomobject]@{
        Stamp    = $Stamp
        Stats    = $stats
        Frames   = $frames
        Summary  = @(Format-FrameSummary -Frames $frames -BudgetMs $budgetMs)
        Worst    = if ($frames.Count) { ($frames | Measure-Object -Maximum).Maximum } else { 0 }
    }
}

$results = @()
if ($Watch -gt 0) {
    Write-Host "轮询 $Watch 秒（每 $Interval 秒一次）。现在开始滑，把「滑不动」复现出来…" -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds($Watch)
    $i = 0
    while ((Get-Date) -lt $deadline) {
        $i++
        $r = Save-GfxInfo -Stamp ('w{0:d2}' -f $i)
        $results += $r
        Write-Host ("  [{0:d2}] 帧 {1}，最慢 {2:N1} ms" -f $i, $r.Frames.Count, $r.Worst)
        Start-Sleep -Seconds $Interval
    }
} else {
    $results += Save-GfxInfo -Stamp 'snapshot'
}

# logcat：整段留档 + 只挑卡顿相关的
$log = @(Invoke-Adb @('logcat', '-d', '-t', "$LogLines"))
$log | Set-Content -Path (Join-Path $OutDir 'logcat.txt') -Encoding utf8
$logJank = @($log | Select-String -Pattern 'Choreographer|Skipped \d+ frames|ANR |am_anr|Input dispatching timed out|OpenGLRenderer' |
        ForEach-Object { $_.Line })
$logJank | Set-Content -Path (Join-Path $OutDir 'logcat-jank.txt') -Encoding utf8

# ── 汇总 ────────────────────────────────────────────────────────────────

$report = [System.Collections.Generic.List[string]]::new()
$report.Add('==== 采集结果 ====')
$meta | ForEach-Object { $report.Add($_) }
$report.Add('')
$report.Add('系统口径（dumpsys gfxinfo）：')
if ($results[-1].Stats.Count) { $results[-1].Stats | ForEach-Object { $report.Add("  $_") } } else { $report.Add('  （无）') }
$report.Add('')
foreach ($r in $results) {
    $report.Add("帧数据 [$($r.Stamp)]：")
    $r.Summary | ForEach-Object { $report.Add("  $_") }
    $report.Add('')
}
$report.Add("logcat 卡顿相关行: $($logJank.Count) 条（见 logcat-jank.txt）")
$report.Add("输出目录: $OutDir")

$report | Set-Content -Path (Join-Path $OutDir 'summary.txt') -Encoding utf8
$report | ForEach-Object { Write-Host $_ }

$worstOverall = if ($results.Count) { ($results | Measure-Object -Property Worst -Maximum).Maximum } else { 0 }
if ($worstOverall -gt $budgetMs * 3) {
    Write-Host ("`n结论倾向：抓到明显掉帧（最慢 {0:N1} ms ≈ {1:N1} 帧预算）。" -f $worstOverall, ($worstOverall / $budgetMs)) -ForegroundColor Yellow
} else {
    Write-Host ("`n结论倾向：本次窗口没有抓到长帧（最慢 {0:N1} ms）。若手感仍然卡，下一步要查手势消费方。" -f $worstOverall) -ForegroundColor Yellow
}
Write-Host "把 summary.txt 的内容发我即可（原始文件都在 $OutDir）。"
