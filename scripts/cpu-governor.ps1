<#
.SYNOPSIS
    给 AI Agent / 构建进程做「CPU 核心分配」的限速闸门。

.DESCRIPTION
    把指定的进程（默认：Java/Gradle/Kotlin/Dart/node/DSH 这类 AI 与构建侧进程）
    钉到一部分物理核上，并降低其调度优先级，从而保证留给用户的那几个核随时有空。

    只改两件事：进程的 CPU 亲和性（affinity）与调度优先级（priority class）。
    两件都只作用于「同名进程」，不碰系统设置，随时可 -Mode restore 还原。

    子进程会继承父进程的亲和性，所以 launch / watch 两种模式能覆盖整棵进程树
    （gradle 客户端 → daemon → kotlinc 都在限速范围内）。

.PARAMETER Mode
    status  只读：打印 CPU 拓扑、当前热点进程、哪些已被限速。
    apply   立刻对当前已存在的匹配进程生效。
    watch   常驻，按固定间隔持续对新出现的匹配进程生效（推荐配合构建/Agent 使用）。
    launch  用限速环境启动一条命令，命令及其所有子进程自动受限（最稳的方式）。
    restore 把本工具改过的进程还原成原来的亲和性与优先级。

.PARAMETER Preset
    build  = 构建链（java / gradle / kotlin / dart / flutter_tester / 本机构建外的编译器）
    agents = AI 侧（node / DSH / claude / codex / cursor-agent）
    all    = 两者（默认）

.PARAMETER ReserveCores
    留给用户/系统的物理核数量（默认 2）。不是线程数——脚本会自动把该物理核的
    两个超线程一起留出来，避免「用户核」和「AI 核」共用同一个物理核的执行单元。

.PARAMETER Priority
    给受限进程设定的调度优先级，默认 BelowNormal（低于正常）。
    桌面任何普通优先级线程一有活就能抢到 CPU；机器空闲时 AI 仍可吃满自己那几个核。
    想更激进可以用 Idle（只在完全没人用 CPU 时才跑）。

.EXAMPLE
    # 先看现状（什么都不改）
    pwsh -File scripts/cpu-governor.ps1 -Mode status

.EXAMPLE
    # 常驻看门狗：AI/构建进程只能上 4 个物理核，留 2 个核给桌面
    pwsh -File scripts/cpu-governor.ps1 -Mode watch -Preset all -ReserveCores 2

.EXAMPLE
    # 直接在限速环境里跑一次编译（子进程全部继承）
    pwsh -File scripts/cpu-governor.ps1 -Mode launch -Command "pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin"

.EXAMPLE
    # 还原
    pwsh -File scripts/cpu-governor.ps1 -Mode restore
#>
[CmdletBinding()]
param(
    [ValidateSet('status', 'apply', 'watch', 'launch', 'restore')]
    [string]$Mode = 'status',

    [ValidateSet('all', 'build', 'agents')]
    [string]$Preset = 'all',

    [string[]]$Names,

    [int[]]$Pids,

    [ValidateRange(1, 15)]
    [int]$ReserveCores = 2,

    [ValidateSet('BelowNormal', 'Idle', 'Normal')]
    [string]$Priority = 'BelowNormal',

    [ValidateRange(1, 120)]
    [int]$IntervalSeconds = 5,

    [string]$Command,

    [switch]$CapJvmCpu,

    [switch]$NoAffinity,

    [switch]$DryRun,

    [string]$StateFile
)

$ErrorActionPreference = 'Stop'

if (-not $StateFile) {
    $StateFile = Join-Path (Join-Path $PSScriptRoot '..\.agents\cpu-governor') 'state.json'
}

# ---------------------------------------------------------------- CPU 拓扑
function Get-CpuTopology {
    if (-not ('CpuTopo' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class CpuTopo
{
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetLogicalProcessorInformationEx(int relationshipType, IntPtr buffer, ref int returnedLength);

    // PROCESSOR_RELATIONSHIP 布局：
    //   BYTE Flags; BYTE EfficiencyClass; BYTE Reserved[20]; WORD GroupCount; GROUP_AFFINITY GroupMask[];
    // 条目头是 {int Relationship; int Size;} ⇒ 尾巴从 offset+8 开始，
    // 所以 GroupCount 在 +30、GroupMask 从 +32 开始，每个 GROUP_AFFINITY 16 字节。
    // 返回 "mask|smt|eff" 字符串，由 PowerShell 侧解析，省得写一堆结构体。
    public static List<string> GetCores()
    {
        var result = new List<string>();
        int len = 0;
        GetLogicalProcessorInformationEx(0, IntPtr.Zero, ref len); // RelationProcessorCore = 0
        if (len == 0) return result;
        IntPtr buf = Marshal.AllocHGlobal(len);
        try
        {
            if (!GetLogicalProcessorInformationEx(0, buf, ref len)) return result;
            int offset = 0;
            while (offset < len - 8)
            {
                int size = Marshal.ReadInt32(buf, offset + 4);
                if (size <= 0) break;
                byte flags = Marshal.ReadByte(buf, offset + 8);
                byte eff   = Marshal.ReadByte(buf, offset + 9);
                int groupCount = Marshal.ReadInt16(buf, offset + 30);
                var masks = new List<string>();
                for (int g = 0; g < groupCount; g++)
                {
                    int moff = offset + 32 + g * 16;
                    if (moff + 8 > offset + size) break;
                    ulong m = (ulong)Marshal.ReadInt64(buf, moff);
                    masks.Add(m.ToString("X"));
                }
                result.Add(string.Join(",", masks) + "|" + ((flags & 1) != 0 ? "smt" : "nosmt") + "|" + eff);
                offset += size;
            }
        }
        finally { Marshal.FreeHGlobal(buf); }
        return result;
    }
}
'@
    }

    $cores = @()
    $i = 0
    foreach ($line in [CpuTopo]::GetCores()) {
        $parts = $line -split '\|'
        $maskList = $parts[0] -split ','
        $mask = [uint64]0
        foreach ($m in $maskList) { $mask = $mask -bor [uint64]::Parse($m, 'HexNumber') }
        $cores += [pscustomobject]@{
            Index    = $i
            Mask     = $mask
            Smt      = ($parts[1] -eq 'smt')
            EffClass = [int]$parts[2]
            Lps      = $maskList.Count
        }
        $i++
    }

    $all = [uint64]0
    foreach ($c in $cores) { $all = $all -bor $c.Mask }
    return [pscustomobject]@{ Cores = $cores; AllMask = $all }
}

function Get-PopCount([uint64]$v) {
    $n = 0
    while ($v -ne 0) { if ($v -band 1) { $n++ }; $v = $v -shr 1 }
    return $n
}

# ---------------------------------------------------------------- 目标名单
$PresetMap = @{
    build  = @(
        'java', 'javaw', 'kotlinc', 'gradle', 'gradlew',
        'dart', 'dartvm', 'dartaotruntime', 'flutter', 'flutter_tester', 'dcm',
        'cmake', 'ninja', 'clang', 'clang++', 'lld', 'ld'
    )
    agents = @(
        'node', 'DSH', 'dsh',
        'claude', 'claude-code', 'codex', 'cursor-agent', 'aider', 'gemini', 'qwen'
    )
}

function Resolve-TargetNames {
    if ($Names -and $Names.Count -gt 0) { return @($Names) }
    switch ($Preset) {
        'build'  { return $PresetMap.build }
        'agents' { return $PresetMap.agents }
        default  { return @($PresetMap.build + $PresetMap.agents | Select-Object -Unique) }
    }
}

# ---------------------------------------------------------------- 状态存取
function Read-State {
    if (Test-Path $StateFile) {
        try { return @(Get-Content $StateFile -Raw | ConvertFrom-Json) } catch { return @() }
    }
    return @()
}

function Write-State($entries) {
    $dir = Split-Path $StateFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # 只留还活着的进程，避免文件无限膨胀
    $live = @()
    foreach ($e in $entries) {
        $p = Get-Process -Id $e.Pid -ErrorAction SilentlyContinue
        if ($p -and $p.StartTime.Ticks -eq $e.StartTicks) { $live += $e }
    }
    if ($live.Count -eq 0) {
        Remove-Item $StateFile -ErrorAction SilentlyContinue
        return
    }
    $live | ConvertTo-Json -Depth 4 | Set-Content -Path $StateFile -Encoding utf8
}

# 全局待写状态（内存里累积，结束时一次性落盘）
$script:State = $null

function Initialize-State {
    if ($null -eq $script:State) {
        $script:State = [System.Collections.Generic.List[object]]::new()
        foreach ($e in @(Read-State)) { $script:State.Add($e) }
    }
}

function Save-Original($proc) {
    Initialize-State
    $ticks = $proc.StartTime.Ticks
    foreach ($e in $script:State) { if ($e.Pid -eq $proc.Id -and $e.StartTicks -eq $ticks) { return } }
    $script:State.Add([pscustomobject]@{
            Pid        = $proc.Id
            Name       = $proc.Name
            StartTicks = $ticks
            Affinity   = [int64]$proc.ProcessorAffinity
            Priority   = [string]$proc.PriorityClass
            AppliedAt  = (Get-Date).ToString('o')
        })
}

# ---------------------------------------------------------------- 施加/还原
function Set-Governed($proc, [uint64]$mask, [string]$prio) {
    $changed = @()
    if ($proc.HasExited) { return $changed }

    if (-not $NoAffinity.IsPresent) {
        $cur = [uint64][int64]$proc.ProcessorAffinity
        if ($cur -ne $mask) {
            if (-not $DryRun) {
                Save-Original $proc
                try { $proc.ProcessorAffinity = [IntPtr]([int64]$mask); $changed += 'affinity' }
                catch { if (-not $proc.HasExited) { Write-Warning ("亲和性设置失败 {0}({1}): {2}" -f $proc.Name, $proc.Id, $_.Exception.Message) } }
            }
            else { $changed += 'affinity(dry)' }
        }
    }

    if ($prio -ne 'Normal') {
        $want = [System.Diagnostics.ProcessPriorityClass]::$prio
        if (-not $proc.HasExited -and $proc.PriorityClass -ne $want) {
            if (-not $DryRun) {
                Save-Original $proc
                try { $proc.PriorityClass = $want; $changed += 'priority' }
                catch { if (-not $proc.HasExited) { Write-Warning ("优先级设置失败 {0}({1}): {2}" -f $proc.Name, $proc.Id, $_.Exception.Message) } }
            }
            else { $changed += 'priority(dry)' }
        }
    }

    return $changed
}

function Invoke-Govern([uint64]$mask, [string]$prio) {
    $targets = @(Resolve-TargetNames)
    Initialize-State
    $touched = 0
    $total = 0

    if (-not $script:HeaderShown) {
        Write-Host ("[governor] 允许的核 mask = 0x{0:X}（{1} 线程），优先级 = {2}" -f $mask, (Get-PopCount $mask), $prio) -ForegroundColor Cyan
        $script:HeaderShown = $true
    }

    $procs = @()
    if ($Pids -and $Pids.Count -gt 0) {
        foreach ($id in $Pids) {
            $p = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($p) { $procs += $p } else { Write-Warning "进程 $id 不存在" }
        }
    }
    else {
        foreach ($t in $targets) {
            $procs += @(Get-Process -Name $t -ErrorAction SilentlyContinue)
        }
    }

    foreach ($p in $procs) {
        $total++
        $ch = @(Set-Governed $p $mask $prio)
        if ($ch.Count -gt 0) {
            $touched++
            Write-Host ("  已限速 {0}({1})  ->  {2}" -f $p.Name, $p.Id, ($ch -join '+')) -ForegroundColor Yellow
        }
    }

    if (-not $DryRun) { Write-State $script:State }

    # 看门狗模式下「这一轮什么都没改」是常态，别每 5 秒刷一行
    if ($Mode -ne 'watch' -or $touched -gt 0) {
        Write-Host ("[governor] 扫描 {0} 个匹配进程，本次改动 {1} 个。" -f $total, $touched) -ForegroundColor Cyan
    }
    return $touched
}

# ---------------------------------------------------------------- 主流程
$topo = Get-CpuTopology
$coreCount = $topo.Cores.Count

if ($ReserveCores -ge $coreCount) {
    throw "ReserveCores=$ReserveCores 会把全部 $coreCount 个物理核都留出来，AI 就没核可用了。"
}

# 前面 ReserveCores 个物理核留给用户/系统（Windows 的定时器与调度工作偏向低编号核），
# AI 用剩下的高编号物理核。按物理核整块切，绝不与用户共用同一个核的两条超线程。
$userMask = [uint64]0
$aiMask   = [uint64]0
for ($i = 0; $i -lt $coreCount; $i++) {
    if ($i -lt $ReserveCores) { $userMask = $userMask -bor $topo.Cores[$i].Mask }
    else { $aiMask = $aiMask -bor $topo.Cores[$i].Mask }
}

switch ($Mode) {

    'status' {
        Write-Host '=== CPU 拓扑 ===' -ForegroundColor Cyan
        Write-Host ("物理核 {0} 个，逻辑线程 {1} 条" -f $coreCount, (Get-PopCount $topo.AllMask))
        foreach ($c in $topo.Cores) {
            Write-Host ("  core#{0}  逻辑线程 mask=0x{1:X}  SMT={2}" -f $c.Index, $c.Mask, $c.Smt)
        }
        Write-Host ''
        Write-Host '=== 当前分配方案（按现在的参数）===' -ForegroundColor Cyan
        Write-Host ("  用户/系统  {0} 个物理核  mask=0x{1:X} ({2} 线程)" -f $ReserveCores, $userMask, (Get-PopCount $userMask))
        Write-Host ("  AI/构建    {0} 个物理核  mask=0x{1:X} ({2} 线程)" -f ($coreCount - $ReserveCores), $aiMask, (Get-PopCount $aiMask))
        Write-Host ''
        Write-Host '=== 当前 CPU 占用最高的进程 ===' -ForegroundColor Cyan
        try {
            $s = (Get-Counter '\Process(*)\% Processor Time' -ErrorAction Stop).CounterSamples |
                Where-Object { $_.InstanceName -notin @('_total', 'idle') -and $_.CookedValue -gt 1 } |
                Sort-Object CookedValue -Descending | Select-Object -First 10
            $s | ForEach-Object {
                Write-Host ("  {0,-32} {1,6:N1} %" -f $_.InstanceName, ($_.CookedValue / [Environment]::ProcessorCount))
            }
        }
        catch { Write-Warning "取不到实时 CPU 计数器：$($_.Exception.Message)" }
        Write-Host ''
        Write-Host '=== 已被本工具限速的进程 ===' -ForegroundColor Cyan
        $state = @(Read-State)
        if ($state.Count -eq 0) { Write-Host '  （无）' }
        else {
            foreach ($e in $state) {
                $p = Get-Process -Id $e.Pid -ErrorAction SilentlyContinue
                if (-not $p) { continue }
                Write-Host ("  {0}({1})  原 affinity=0x{2:X} 原优先级={3} 现 affinity=0x{4:X}" -f `
                        $e.Name, $e.Pid, $e.Affinity, $e.Priority, [int64]$p.ProcessorAffinity)
            }
        }
    }

    'apply' {
        $null = Invoke-Govern -mask $aiMask -prio $Priority
    }

    'watch' {
        Write-Host ("[governor] 看门狗启动：每 {0} 秒扫一次；Ctrl+C 停止。" -f $IntervalSeconds) -ForegroundColor Green
        Write-Host ("[governor] 目标预设 = {0}；用户保留 {1} 个物理核 (mask=0x{2:X})。" -f $Preset, $ReserveCores, $userMask) -ForegroundColor Green
        while ($true) {
            $null = Invoke-Govern -mask $aiMask -prio $Priority
            Start-Sleep -Seconds $IntervalSeconds
        }
    }

    'launch' {
        if (-not $Command) { throw 'launch 模式需要 -Command "要跑的命令"' }

        # 先给自己设限：Windows 的子进程会继承父进程的亲和性，
        # 所以从这里派生的整棵进程树（gradle → daemon → kotlinc）自动落进限速区。
        $self = Get-Process -Id $PID
        if (-not $DryRun) {
            try { $self.ProcessorAffinity = [IntPtr]([int64]$aiMask) } catch { Write-Warning "给自身设亲和性失败：$($_.Exception.Message)" }
            if ($Priority -ne 'Normal') {
                try { $self.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::$Priority } catch { }
            }
        }
        Write-Host ("[governor] 受限启动：mask=0x{0:X} ({1} 线程)，优先级 {2}" -f $aiMask, (Get-PopCount $aiMask), $Priority) -ForegroundColor Green
        Write-Host ("[governor] 命令：{0}" -f $Command) -ForegroundColor Green

        if ($CapJvmCpu) {
            # 让 JVM 也相信自己只有这么多线程，否则 Gradle 会按 12 核开 12 个 worker 挤在 8 条线程上
            $n = Get-PopCount $aiMask
            $env:JAVA_TOOL_OPTIONS = "-XX:ActiveProcessorCount=$n"
            Write-Host ("[governor] JAVA_TOOL_OPTIONS={0}" -f $env:JAVA_TOOL_OPTIONS) -ForegroundColor Green
        }

        & pwsh -NoProfile -Command $Command
        exit $LASTEXITCODE
    }

    'restore' {
        $state = @(Read-State)
        if ($state.Count -eq 0) { Write-Host '[governor] 没有需要还原的记录。'; break }
        $done = 0
        foreach ($e in $state) {
            $p = Get-Process -Id $e.Pid -ErrorAction SilentlyContinue
            if (-not $p) { continue }
            if ($p.StartTime.Ticks -ne $e.StartTicks) { continue }   # PID 被复用了，别动
            try {
                $p.ProcessorAffinity = [IntPtr]([int64]$e.Affinity)
                $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::$($e.Priority)
                $done++
                Write-Host ("  已还原 {0}({1}) -> affinity=0x{2:X} 优先级={3}" -f $e.Name, $e.Pid, $e.Affinity, $e.Priority) -ForegroundColor Yellow
            }
            catch { Write-Warning ("还原失败 {0}({1}): {2}" -f $e.Name, $e.Pid, $_.Exception.Message) }
        }
        Remove-Item $StateFile -ErrorAction SilentlyContinue
        Write-Host ("[governor] 还原 {0} 个进程。" -f $done) -ForegroundColor Cyan
    }
}
