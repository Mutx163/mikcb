#Requires -Version 7
<#
.SYNOPSIS
    把「该用独显」的程序批量写进 Windows 显卡首选项（HKCU\Software\Microsoft\DirectX\UserGpuPreferences），
    顺手清掉指向已删除文件的失效条目，并可选注册计划任务长期自动跑。

.DESCRIPTION
    为什么需要它：无 MUX（不支持独显直连）的机器上，Windows「设置 → 系统 → 屏幕 → 显示卡」里
    每个程序一条 GpuPreference。手工加有四个问题：
      1. 装一个加一个，永远漏；
      2. 版本化目录（Edge / WebView2 / Gemini 的 app-1.2.3）升级后旧路径失效，等于白设；
      3. 卸载应用留下死条目，看不出来；
      4. 没有任何地方汇总「现在到底哪些在独显」。

    本脚本用规则识别「有图形负载」的程序（Electron/Chromium 界面、游戏、3D/视频工具），
    按需写入 GpuPreference=2（高性能），并清理失效条目。每次改动前存一份完整备份，可一键还原。

    GpuPreference 取值：0=让 Windows 决定，1=省电（核显），2=高性能（独显）。
    本脚本只写 2，绝不把我们自己新增的条目写成 1；已有条目是 1 的视为用户有意为之，只报告不改。

.PARAMETER Mode
    audit    只读体检：列出已设/失效/疑似漏掉的程序（默认）
    discover 只读排查：列出扫到的全部候选程序及判定结果（查「为什么没识别到」用）
    list     只列当前注册表里的所有条目
    apply    清理失效 + 补齐漏掉的（会先备份）
    install  注册计划任务（登录时 + 每 4 小时自动 apply，无窗口）
    uninstall 删除计划任务
    status   查看计划任务与条目统计
    restore  用最近一次备份整体还原

.PARAMETER DryRun
    只打印将要做的事，不写注册表。与 apply/restore 搭配。

.PARAMETER ExtraExe
    额外强制加入的 exe 路径（支持通配）。也可以写进 .agents/gpu-preference/extra.txt。

.PARAMETER DenyExe
    额外排除的正则。也可以写进 .agents/gpu-preference/deny.txt。

.EXAMPLE
    pwsh -NoProfile -File scripts/gpu-preference.ps1 -Mode audit

.EXAMPLE
    pwsh -NoProfile -File scripts/gpu-preference.ps1 -Mode apply -DryRun

.EXAMPLE
    pwsh -NoProfile -File scripts/gpu-preference.ps1 -Mode apply

.EXAMPLE
    pwsh -NoProfile -File scripts/gpu-preference.ps1 -Mode install
#>
[CmdletBinding()]
param(
    [ValidateSet('audit', 'discover', 'list', 'apply', 'install', 'uninstall', 'status', 'restore')]
    [string]$Mode = 'audit',

    [switch]$DryRun,
    [switch]$Quiet,

    [string[]]$ExtraExe = @(),
    [string[]]$DenyExe = @(),

    [int]$MaxEntries = 250,
    [string]$LogFile
)

$ErrorActionPreference = 'Stop'

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$DataDir = Join-Path $RepoRoot '.agents\gpu-preference'
$BackupDir = Join-Path $DataDir 'backups'
$LogPath = if ($LogFile) { $LogFile } else { Join-Path $DataDir 'gpu-preference.log' }
$ExtraFile = Join-Path $DataDir 'extra.txt'
$DenyFile = Join-Path $DataDir 'deny.txt'
$CacheFile = Join-Path $DataDir 'cache.json'
$TaskName = 'Mikcb-GpuPreference'
$RegKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$script:Changed = 0

# ---------------------------------------------------------------- 基础设施

function Initialize-DataDir {
    foreach ($d in @($DataDir, $BackupDir)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    if (Test-Path -LiteralPath $LogPath) {
        $len = (Get-Item -LiteralPath $LogPath).Length
        if ($len -gt 1MB) { Move-Item -LiteralPath $LogPath -Destination "$LogPath.1" -Force }
    }
}

function Say([string]$msg, [string]$color = 'Gray') {
    if (-not $Quiet) { Write-Host $msg -ForegroundColor $color }
    try {
        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Add-Content -LiteralPath $LogPath -Value "[$stamp] $msg" -Encoding utf8
    }
    catch { }
}

# ---------------------------------------------------------------- 注册表读写

function Get-GpuPrefs {
    $table = @{}
    if (-not (Test-Path -LiteralPath $RegKey)) { return $table }
    $key = Get-Item -LiteralPath $RegKey
    foreach ($name in $key.GetValueNames()) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $raw = [string]$key.GetValue($name)
        $num = 2
        if ($raw -match 'GpuPreference\s*=\s*(-?\d+)') { $num = [int]$matches[1] }
        $table[$name.ToLowerInvariant()] = [pscustomobject]@{
            Path   = $name
            Value  = $raw
            Num    = $num
            Exists = (Test-Path -LiteralPath $name)
        }
    }
    return $table
}

function Save-Backup($prefs) {
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $file = Join-Path $BackupDir "backup-$stamp.json"
    $entries = [ordered]@{}
    foreach ($k in ($prefs.Keys | Sort-Object)) { $entries[$prefs[$k].Path] = $prefs[$k].Value }
    [pscustomobject]@{ timestamp = (Get-Date).ToString('o'); machine = $env:COMPUTERNAME; entries = $entries } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file -Encoding utf8
    # 只留最近 20 份
    Get-ChildItem -LiteralPath $BackupDir -Filter 'backup-*.json' | Sort-Object Name -Descending |
        Select-Object -Skip 20 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Say "[gpu] 已备份当前 $($entries.Count) 条到 $file" 'DarkGray'
    return $file
}

function Set-HighPerformance([string]$exePath) {
    if (-not (Test-Path -LiteralPath $RegKey)) {
        New-Item -Path $RegKey -Force | Out-Null
    }
    if ($DryRun) {
        Say "  [dry-run] 将写入  $exePath" 'Yellow'
        return
    }
    New-ItemProperty -LiteralPath $RegKey -Name $exePath -Value 'GpuPreference=2;' -PropertyType String -Force | Out-Null
    $script:Changed++
}

function Remove-Pref([string]$regName) {
    if ($DryRun) { Say "  [dry-run] 将删除  $regName" 'Yellow'; return }
    Remove-ItemProperty -LiteralPath $RegKey -Name $regName -Force
    $script:Changed++
}

# ---------------------------------------------------------------- 候选发现

function Test-ElectronApp([string]$exe) {
    $dir = [System.IO.Path]::GetDirectoryName($exe)
    if (Test-Path -LiteralPath (Join-Path $dir 'resources\app.asar')) { return $true }
    if ((Test-Path -LiteralPath (Join-Path $dir 'icudtl.dat')) -and
        (Get-ChildItem -LiteralPath $dir -Filter '*.pak' -ErrorAction SilentlyContinue | Select-Object -First 1)) { return $true }
    # 有的 Electron 应用把 resources 放在上一级（版本化 shell）
    $up = [System.IO.Path]::GetDirectoryName($dir)
    if ($up -and (Test-Path -LiteralPath (Join-Path $up 'resources\app.asar'))) { return $true }
    return $false
}

function Test-GameLike([string]$exe) {
    if ($exe -match '(?i)\\steamapps\\common\\|\\Epic Games\\|\\WeGameApps\\|\\GOG Games\\|\\SteamLibrary\\') { return $true }
    if ($exe -match '(?i)-Win64-Shipping\.exe$') { return $true }
    $dir = [System.IO.Path]::GetDirectoryName($exe)
    if (Test-Path -LiteralPath (Join-Path $dir 'UnityPlayer.dll')) { return $true }
    if (Test-Path -LiteralPath (Join-Path $dir 'Engine\Binaries\Win64')) { return $true }
    return $false
}

# 3D / 视频 / 模拟器 / 放大之类的「重图形但不像游戏」的程序（按文件名）
$script:HeavyNameRx = '(?i)^(acad|acadlt|acadfic|3dsmax|blender|obs64|obs32|davinci|resolve|premiere|afterfx|photoshop|illustrator|hd-player|bluestacks|qemu-system-.+|magpie.*|mpc-hc.*|mpc-be.*|potplayermini64|potplayer64|vlc|mstsc|vmware|virtualbox|clouddesktop-qml|remoteapp|sunloginclient|todesk|gameviewer|steamwebhelper)\.exe$'

function Test-HeavyByName([string]$exe) {
    return ([System.IO.Path]::GetFileName($exe) -match $script:HeavyNameRx)
}

# --- Tauri / WebView2 类界面：没法靠目录结构判断，只能看二进制里的框架标记。
# 这些程序和 Electron 一样，界面是浏览器内核画的，走核显会明显更卡。
# 全量读 100 多个 exe 太贵，所以按「路径 + 大小 + 修改时间」缓存结论，只在新装/升级后重扫一次。
function Read-MarkerCache {
    if ($null -ne $script:MarkerCache) { return }
    $script:MarkerCache = @{}
    if (-not (Test-Path -LiteralPath $CacheFile)) { return }
    try {
        $raw = Get-Content -LiteralPath $CacheFile -Raw -Encoding utf8 | ConvertFrom-Json
        foreach ($p in $raw.PSObject.Properties) { $script:MarkerCache[$p.Name] = $p.Value }
    }
    catch { $script:MarkerCache = @{} }
}

function Save-MarkerCache {
    if ($null -eq $script:MarkerCache -or $DryRun) { return }
    # 顺手丢掉已卸载程序的缓存，避免文件无限增长
    foreach ($k in @($script:MarkerCache.Keys)) {
        if (-not (Test-Path -LiteralPath $k)) { $script:MarkerCache.Remove($k) }
    }
    try { $script:MarkerCache | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $CacheFile -Encoding utf8 }
    catch { }
}

function Test-WebViewUiApp([string]$exe) {
    $fi = Get-Item -LiteralPath $exe -ErrorAction SilentlyContinue
    if (-not $fi) { return $false }
    if ($fi.Length -gt 150MB) { return $false }          # 这么大的基本是游戏/大型程序，不靠这个判据
    if ($fi.Length -lt 4MB) { return $false }            # 太小的多半是启动器存根
    $key = $exe.ToLowerInvariant()
    $sig = '{0}:{1}' -f $fi.Length, $fi.LastWriteTimeUtc.Ticks
    Read-MarkerCache
    if ($script:MarkerCache.ContainsKey($key) -and [string]$script:MarkerCache[$key].sig -eq $sig) {
        return [bool]$script:MarkerCache[$key].webui
    }
    $hit = $false
    $bytes = $null
    try {
        $bytes = [System.IO.File]::ReadAllBytes($exe)
        $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
        $hit = $ascii.Contains('WebView2') -and ($ascii.Contains('tauri') -or $ascii.Contains('TAURI'))
    }
    catch { $hit = $false }
    finally { $bytes = $null }
    $script:MarkerCache[$key] = [pscustomobject]@{ sig = $sig; webui = $hit }
    return $hit
}

function Test-Denied([string]$exe, [string[]]$denyRx) {
    foreach ($rx in $denyRx) {
        if ([string]::IsNullOrWhiteSpace($rx)) { continue }
        if ($rx.StartsWith('#')) { continue }
        if ($exe -match $rx) { return $true }
    }
    return $false
}

function Get-CandidateExes {
    $set = @{}

    function Add-Cand([string]$p) {
        if ([string]::IsNullOrWhiteSpace($p)) { return }
        $p = $p.Trim().Trim('"')
        if (-not $p.ToLowerInvariant().EndsWith('.exe')) { return }
        if (-not (Test-Path -LiteralPath $p)) { return }
        $lower = $p.ToLowerInvariant()
        if (-not $set.ContainsKey($lower)) { $set[$lower] = $p }
    }

    # 1) 开始菜单快捷方式：用户真正会点的东西
    $wsh = $null
    try { $wsh = New-Object -ComObject WScript.Shell } catch { }
    if ($wsh) {
        foreach ($root in @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
                "$env:AppData\Microsoft\Windows\Start Menu\Programs")) {
            Get-ChildItem -LiteralPath $root -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
                $t = $null
                try { $t = $wsh.CreateShortcut($_.FullName).TargetPath } catch { }
                Add-Cand $t
            }
        }
    }

    # 2) 卸载项里的主程序图标
    foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        Get-ItemProperty $root -ErrorAction SilentlyContinue | Where-Object { $_.DisplayIcon } | ForEach-Object {
            Add-Cand (($_.DisplayIcon -split ',')[0])
        }
    }

    # 3) 用户级安装目录（Cursor / DSH / TRAE 这类都在这里）
    $programsDir = Join-Path $env:LOCALAPPDATA 'Programs'
    if (Test-Path -LiteralPath $programsDir) {
        Get-ChildItem -LiteralPath $programsDir -Recurse -Depth 2 -Filter *.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 15MB } | ForEach-Object { Add-Cand $_.FullName }
    }

    # 4) 当前有窗口的进程（绕过快捷方式，抓到真实 exe）
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | ForEach-Object {
        try { Add-Cand $_.Path } catch { }
    }

    # 5) 卸载项里的安装目录（CFD/CAD、绿色版游戏这类没有快捷方式又不进 Programs 的）
    $roots2 = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
    foreach ($root in $roots2) {
        Get-ItemProperty $root -ErrorAction SilentlyContinue | Where-Object { $_.InstallLocation } | ForEach-Object {
            $loc = ([string]$_.InstallLocation).Trim().Trim('"')
            if ($loc -and (Test-Path -LiteralPath $loc)) {
                Get-ChildItem -LiteralPath $loc -Recurse -Depth 2 -Filter *.exe -ErrorAction SilentlyContinue |
                    Where-Object { $_.Length -gt 4MB } | ForEach-Object { Add-Cand $_.FullName }
            }
        }
    }

    # 6) 游戏库：Steam 位置从注册表取（装在 E:\Program Files (x86)\Steam 这种非默认路径也能找到）
    $steamLibraries = @()
    $steamRoots = @()
    foreach ($regPath in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $sp = (Get-ItemProperty -LiteralPath $regPath -ErrorAction SilentlyContinue).SteamPath
        if ($sp) { $steamRoots += ($sp -replace '/', '\') }
    }
    $steamRoots += @('C:\Program Files (x86)\Steam', 'D:\Steam', 'E:\Steam', 'F:\Steam')
    foreach ($candidate in ($steamRoots | Sort-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        $steamLibraries += $candidate
        $vdf = Join-Path $candidate 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            Get-Content -LiteralPath $vdf | ForEach-Object {
                if ($_ -match '"path"\s+"(.+?)"') { $steamLibraries += ($matches[1] -replace '\\\\', '\') }
            }
        }
    }
    foreach ($lib in ($steamLibraries | Sort-Object -Unique)) {
        $common = Join-Path $lib 'steamapps\common'
        if (-not (Test-Path -LiteralPath $common)) { continue }
        Get-ChildItem -LiteralPath $common -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -Depth 3 -Filter *.exe -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 20MB -and $_.FullName -notmatch '(?i)\\Redistributables\\|\\redist\\|\\Support\\|\\EasyAntiCheat\\|\\BattlEye\\' } |
                Sort-Object Length -Descending | Select-Object -First 2 | ForEach-Object { Add-Cand $_.FullName }
        }
    }

    # 7) Epic：位置从启动器自己的清单取，取不到再退回常见目录
    $epicRoots = @()
    $epicDat = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
    if (Test-Path -LiteralPath $epicDat) {
        try {
            $json = Get-Content -LiteralPath $epicDat -Raw -Encoding utf8 | ConvertFrom-Json
            foreach ($inst in $json.InstallationList) {
                if ($inst.InstallLocation) { $epicRoots += $inst.InstallLocation }
            }
        }
        catch { }
    }
    $epicRoots += @('C:\Program Files\Epic Games', 'D:\Epic Games', 'E:\Epic Games', 'F:\Epic Games')
    foreach ($epic in ($epicRoots | Sort-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $epic)) { continue }
        Get-ChildItem -LiteralPath $epic -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -Depth 4 -Filter *.exe -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 20MB -and $_.FullName -notmatch '(?i)\\Redistributables\\|\\redist\\|\\Support\\|\\EasyAntiCheat\\|\\BattlEye\\' } |
                Sort-Object Length -Descending | Select-Object -First 2 | ForEach-Object { Add-Cand $_.FullName }
        }
    }

    # 8) 用户手写的 extra.txt / -ExtraExe
    $extraPats = @($ExtraExe)
    if (Test-Path -LiteralPath $ExtraFile) {
        $extraPats += (Get-Content -LiteralPath $ExtraFile -Encoding utf8 | Where-Object { $_ -and -not $_.StartsWith('#') })
    }
    foreach ($pat in $extraPats) {
        if ([string]::IsNullOrWhiteSpace($pat)) { continue }
        if ($pat -match '[*?]') {
            Get-ChildItem -Path $pat -ErrorAction SilentlyContinue | ForEach-Object { Add-Cand $_.FullName }
        }
        else { Add-Cand $pat }
    }

    return $set
}

function Get-DenyList {
    $deny = @(
        '(?i)\\Windows\\',                      # 系统组件（ShellHost / SearchHost 之类）不动
        '(?i)\\WindowsApps\\',                  # 商店应用走系统自己的判定
        '(?i)\\Package Cache\\',
        '(?i)\\Temp\\',
        # Edge / Chrome 的版本号目录每次升级都换名，写进去下次就失效。
        # 这两家都已有稳定的 Application\<exe> 通用路径条目，该条目会跟着版本走。
        '(?i)\\Microsoft\\Edge\\Application\\\d+\.',
        '(?i)\\Google\\Chrome\\Application\\\d+\.',
        # WebView2 同理，且实测跟随父应用的设置走，不需要单独设
        '(?i)msedgewebview2\.exe$',
        # 应用内部的 CLI / 分享目标等辅助进程，不是界面本体
        '(?i)\\resources\\[^\\]*\.exe$',
        '(?i)\\share-target\\',
        '(?i)\\(xllite|ThunderRepair|ThunderUninstall|XLLiveUD)\.exe$',   # 迅雷的辅助进程，主程序 Thunder.exe 已单独覆盖
        '(?i)\\tray\\',                                          # 托盘小工具（如抖音的 douyin_tray），不是界面本体
        '(?i)(elevation_service|elevated_tracing_service)\.exe$', # Chromium 系的特权辅助服务，不渲染画面
        '(?i)^.*\\wallpaper(32|64)\.exe$',      # Wallpaper Engine 留核显才省电
        '(?i)(unins|uninstall|卸载|setup|installer|update|updater|crashpad|crashreport|vc_redist|\.tmp)'
    )
    if (Test-Path -LiteralPath $DenyFile) {
        $deny += (Get-Content -LiteralPath $DenyFile -Encoding utf8 | Where-Object { $_ -and -not $_.StartsWith('#') })
    }
    $deny += $DenyExe
    return $deny
}

function Get-WantedApp {
    param($Candidates, [string[]]$DenyRx, $Prefs)
    $out = @()
    foreach ($key in ($Candidates.Keys | Sort-Object)) {
        $exe = $Candidates[$key]
        if (Test-Denied $exe $DenyRx) { continue }
        $isWanted = $false
        $why = ''
        if (Test-ElectronApp $exe) { $isWanted = $true; $why = 'Electron/Chromium 界面' }
        elseif (Test-GameLike $exe) { $isWanted = $true; $why = '游戏' }
        elseif (Test-HeavyByName $exe) { $isWanted = $true; $why = '3D/视频/模拟器' }
        elseif (Test-WebViewUiApp $exe) { $isWanted = $true; $why = 'WebView2/Tauri 界面' }
        if (-not $isWanted) { continue }
        $out += [pscustomobject]@{
            Path      = $exe
            Reason    = $why
            HasPref   = $Prefs.ContainsKey($key)
            PrefNum   = if ($Prefs.ContainsKey($key)) { $Prefs[$key].Num } else { $null }
        }
    }
    return $out
}

# ---------------------------------------------------------------- 各模式

function Invoke-Discover {
    Initialize-DataDir
    $prefs = Get-GpuPrefs
    $deny = Get-DenyList
    $cands = Get-CandidateExes
    Say ''
    Say ("== 候选排查：共扫到 {0} 个 exe ==" -f $cands.Count) 'Cyan'
    foreach ($key in ($cands.Keys | Sort-Object)) {
        $exe = $cands[$key]
        $verdict = '跳过（没识别出图形负载）'
        $color = 'DarkGray'
        if (Test-Denied $exe $deny) { $verdict = '跳过（命中排除规则）'; $color = 'DarkGray' }
        elseif (Test-ElectronApp $exe) { $verdict = '要（Electron 界面）'; $color = 'White' }
        elseif (Test-GameLike $exe) { $verdict = '要（游戏）'; $color = 'White' }
        elseif (Test-HeavyByName $exe) { $verdict = '要（3D/视频/模拟器）'; $color = 'White' }
        elseif (Test-WebViewUiApp $exe) { $verdict = '要（WebView2/Tauri 界面）'; $color = 'White' }
        $has = if ($prefs.ContainsKey($key)) { '已设' } else { '未设' }
        Say ("  [{0,-3}] [{1}] {2}" -f $has, $verdict, $exe) $color
    }
    Save-MarkerCache
    Say ''
}

function Invoke-Audit([bool]$showAll) {
    Initialize-DataDir
    $prefs = Get-GpuPrefs
    $deny = Get-DenyList
    $cands = Get-CandidateExes
    $wanted = Get-WantedApp $cands $deny $prefs

    $alive = @($prefs.Values | Where-Object { $_.Exists })
    $stale = @($prefs.Values | Where-Object { -not $_.Exists })
    $lowPref = @($alive | Where-Object { $_.Num -eq 1 })
    $missing = @($wanted | Where-Object { -not $_.HasPref })

    Say ''
    Say "== 显卡首选项体检 ==" 'Cyan'
    Say ("注册表条目 {0} 条：有效 {1}，失效 {2}" -f $prefs.Count, $alive.Count, $stale.Count)

    if ($stale.Count) {
        Say "`n失效条目（文件已不存在，等于白设）：" 'Yellow'
        foreach ($s in ($stale | Sort-Object Path)) { Say ("  - {0}" -f $s.Path) 'DarkYellow' }
    }
    if ($lowPref.Count) {
        Say "`n被你设成「省电/核显」的（脚本不会改）：" 'Cyan'
        foreach ($l in $lowPref) { Say ("  - {0}" -f $l.Path) 'Gray' }
    }
    Say ("`n识别到有图形负载的程序 {0} 个，其中还没设的 {1} 个：" -f $wanted.Count, $missing.Count) 'Cyan'
    foreach ($m in ($missing | Sort-Object Reason, Path)) {
        Say ("  [{0,-16}] {1}" -f $m.Reason, $m.Path) 'White'
    }
    if ($showAll) {
        Say "`n已设且有效的：" 'Cyan'
        foreach ($a in ($alive | Sort-Object Path)) { Say ("  - {0}" -f $a.Path) 'Gray' }
    }
    Say ''
    Save-MarkerCache
    $script:AuditResult = [pscustomobject]@{
        Prefs = $prefs; Stale = $stale; Missing = $missing; Wanted = $wanted; Low = $lowPref
    }
    return $script:AuditResult
}

function Invoke-Apply {
    Initialize-DataDir
    $prefs = Get-GpuPrefs
    if ($prefs.Count -gt 0 -and -not $DryRun) { $null = Save-Backup $prefs }

    $deny = Get-DenyList
    $cands = Get-CandidateExes
    $wanted = Get-WantedApp $cands $deny $prefs

    $removed = 0
    $added = 0

    # 1) 清掉失效条目（只清「盘还在、文件没了」的，避免把移动盘上的条目误删）
    Say "`n-- 清理失效条目 --" 'Cyan'
    foreach ($s in ($prefs.Values | Where-Object { -not $_.Exists })) {
        $drive = [System.IO.Path]::GetPathRoot($s.Path)
        if ($drive -and -not (Test-Path -LiteralPath $drive)) {
            Say ("  跳过（盘不在线）{0}" -f $s.Path) 'DarkGray'; continue
        }
        Remove-Pref $s.Path
        $removed++
        if (-not $DryRun) { Say ("  删除  {0}" -f $s.Path) 'Yellow' }
    }
    if ($removed -eq 0) { Say '  没有失效条目。' 'DarkGray' }

    # 2) 补齐漏掉的
    Say "`n-- 补写独显条目 --" 'Cyan'
    $total = $prefs.Count
    foreach ($w in ($wanted | Where-Object { -not $_.HasPref } | Sort-Object Path)) {
        if ($total + $added -ge $MaxEntries) { Say ("  已达上限 {0} 条，停止追加。" -f $MaxEntries) 'Yellow'; break }
        Set-HighPerformance $w.Path
        $added++
        if (-not $DryRun) { Say ("  写入  [{0}] {1}" -f $w.Reason, $w.Path) 'Green' }
    }
    if ($added -eq 0) { Say '  没有需要新增的。' 'DarkGray' }
    elseif ($DryRun) { Say ("  将新增 {0} 条。" -f $added) 'Yellow' }

    Say ("`n== 完成：清理 {0} 条，写入 {1} 条{2} ==" -f $removed, $added, $(if ($DryRun) { '（dry-run，未落盘）' } else { '' })) 'Cyan'
    Save-MarkerCache

    if (-not $DryRun) {
        # 让系统重新读取：Explorer 不需要重启，新启动的进程按新设置走
        Say '新设置对之后启动的进程生效；已经在跑的程序要重开一次。' 'DarkGray'
    }
}

function Invoke-Restore {
    Initialize-DataDir
    $latest = Get-ChildItem -LiteralPath $BackupDir -Filter 'backup-*.json' | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) { Say '没有备份可还原。' 'Red'; return }
    $data = Get-Content -LiteralPath $latest.FullName -Raw -Encoding utf8 | ConvertFrom-Json
    Say ("用 {0} 还原（{1} 条）" -f $latest.Name, $data.entries.PSObject.Properties.Count) 'Cyan'
    $prefs = Get-GpuPrefs
    foreach ($k in $prefs.Keys) {
        if (-not ($data.entries.PSObject.Properties.Name | Where-Object { $_.ToLowerInvariant() -eq $k })) {
            Remove-Pref $prefs[$k].Path
        }
    }
    foreach ($prop in $data.entries.PSObject.Properties) {
        $name = $prop.Name
        if ($DryRun) { Say "  [dry-run] 恢复 $name = $($prop.Value)" 'Yellow'; continue }
        if (-not (Test-Path -LiteralPath $RegKey)) { New-Item -Path $RegKey -Force | Out-Null }
        New-ItemProperty -LiteralPath $RegKey -Name $name -Value $prop.Value -PropertyType String -Force | Out-Null
    }
    Say ("还原完成，改动 {0} 处{1}" -f $script:Changed, $(if ($DryRun) { '（dry-run）' } else { '' })) 'Cyan'
}

function Show-List {
    $prefs = Get-GpuPrefs
    Say ("当前共 {0} 条：" -f $prefs.Count) 'Cyan'
    foreach ($p in ($prefs.Values | Sort-Object Path)) {
        $flag = if (-not $p.Exists) { '失效' } elseif ($p.Num -eq 2) { '独显' } elseif ($p.Num -eq 1) { '核显' } else { '自动' }
        Say ("  [{0}] {1}" -f $flag, $p.Path) 'White'
    }
}

function Get-TaskInfo {
    return (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
}

function Invoke-Status {
    Initialize-DataDir
    $task = Get-TaskInfo
    $prefs = Get-GpuPrefs
    $alive = @($prefs.Values | Where-Object { $_.Exists }).Count
    Say ''
    Say '== 状态 ==' 'Cyan'
    Say ("计划任务 {0}：{1}" -f $TaskName, $(if ($task) { '已注册（' + $task.State + '）' } else { '未注册' }))
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $TaskName
        Say ("  上次运行 {0}，结果 0x{1:X}" -f $info.LastRunTime, $info.LastTaskResult)
        Say ("  下次运行 {0}" -f $info.NextRunTime)
    }
    Say ("注册表条目 {0} 条（有效 {1}）" -f $prefs.Count, $alive)
    Say ("日志 {0}" -f $LogPath)
    Say ''
}

function Invoke-Install {
    Initialize-DataDir
    $pwsh = (Get-Process -Id $PID).Path
    if (-not $pwsh) { $pwsh = (Get-Command pwsh).Source }
    if (-not $pwsh) { throw '取不到 pwsh 路径，无法注册计划任务' }

    # 用 wscript + VBS 垫片：计划任务直接跑 pwsh 会留一个可见控制台窗口
    $vbsPath = Join-Path $DataDir 'run-hidden.vbs'
    $inner = '"' + $pwsh + '" -NoProfile -NonInteractive -File "' + $PSCommandPath + '" -Mode apply -Quiet -LogFile "' + $LogPath + '"'
    $vbs = 'CreateObject("WScript.Shell").Run "' + $inner.Replace('"', '""') + '", 0, False' + "`r`n"
    Set-Content -LiteralPath $vbsPath -Value $vbs -Encoding ascii -NoNewline

    $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument ('"' + $vbsPath + '"')
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    # 每 4 小时扫一次：新装的程序最多 4 小时内自动纳入。
    # 注意：-RepetitionDuration 不能用 TimeSpan::MaxValue（生成 P99999999DT23H59M59S，任务 XML 判为超范围，
    # Register-ScheduledTask 直接报「格式不正确或超出范围的值」）。用 10 年当「无限」。
    $repeatTrigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(5)) `
        -RepetitionInterval (New-TimeSpan -Hours 4) -RepetitionDuration (New-TimeSpan -Days 3650)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable -MultipleInstances IgnoreNew

    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logonTrigger, $repeatTrigger) `
        -Principal $principal -Settings $settings -Force `
        -Description '自动把有图形负载的程序设为高性能（独显）。由 scripts/gpu-preference.ps1 -Mode install 注册。' | Out-Null

    Say ("[gpu] 已注册计划任务 {0}：登录时 + 每 4 小时自动 apply（无窗口）" -f $TaskName) 'Green'
    Say ("[gpu] 日志 {0}" -f $LogPath) 'Green'
    Say '[gpu] 取消：-Mode uninstall' 'Green'
}

function Invoke-Uninstall {
    $task = Get-TaskInfo
    if (-not $task) { Say '[gpu] 没有注册过计划任务。' 'Cyan'; return }
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Remove-Item -LiteralPath (Join-Path $DataDir 'run-hidden.vbs') -Force -ErrorAction SilentlyContinue
    Say ("[gpu] 已删除计划任务 {0}。注册表里的设置保留，要撤销用 -Mode restore。" -f $TaskName) 'Cyan'
}

# ---------------------------------------------------------------- 入口

switch ($Mode) {
    'audit' { $null = Invoke-Audit $false }
    'discover' { Invoke-Discover }
    'list' { Initialize-DataDir; Show-List }
    'apply' { Invoke-Apply }
    'restore' { Invoke-Restore }
    'install' { Invoke-Install }
    'uninstall' { Invoke-Uninstall }
    'status' { Invoke-Status }
}
