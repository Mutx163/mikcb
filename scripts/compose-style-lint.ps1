<#
.SYNOPSIS
    Compose 页面样式检查（对齐官方 miuix demo）。规则定义见
    docs/reference/compose-page-style-rules.md，权威闸门是 JUnit 的
    ComposePageStyleGuardTest.kt，本脚本是同一套判据的**只读自查**工具。

.DESCRIPTION
    扫描 android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/<域>/*.kt，
    用 4 个扫描器判 R1..R7：
      · 结构（顶栏 / 滚动）      → R1 / R2
      · 内容块（卡片 / 分组标题） → R3 / R6
      · 字体（字号 / 字重）      → R4 / R7
      · 颜色                     → R5

    规则：**待修违规必须为 0**。真正需要保留的写法登记在
    tool/compose_style_exceptions/<域>.txt，一行 `<相对路径>|<规则>|<原因>`；
    每条例外都必须命中一处真实违规（过期即红）。

    -Write 只做一件事：删掉**已经修好、不再命中**的过期例外行。
    它**绝不新增**，所以不存在「把新违规洗进基线」的后门。
    新增例外只能人工编辑文件并写明原因。

.EXAMPLE
    pwsh -File scripts/compose-style-lint.ps1 -Domain statistics
    pwsh -File scripts/compose-style-lint.ps1 -Domain statistics -Write
    pwsh -File scripts/compose-style-lint.ps1 -Domain all
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Domain,

    # 只删过期例外；不会新增任何行（没有旧行可加）。
    [switch]$Write
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pagesRoot = Join-Path $repoRoot "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages"
$exceptionsRoot = Join-Path $repoRoot "tool/compose_style_exceptions"

if (-not (Test-Path $pagesRoot)) {
    Write-Error "找不到页面源码目录：$pagesRoot"
    exit 2
}

if ($Domain -eq "all") {
    $domains = @(Get-ChildItem -Path $pagesRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
} else {
    $one = Join-Path $pagesRoot $Domain
    if (-not (Test-Path $one)) {
        $avail = (Get-ChildItem -Path $pagesRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object) -join ', '
        Write-Error "没有这个域：$Domain（可选：$avail）"
        exit 2
    }
    $domains = @($Domain)
}

# ── 判据常量 ────────────────────────────────────────────────────────────
# 与 ComposePageStyleGuardTest.kt 的四个 Scanner 一一对应：
# regex 与组合条件必须逐字保持一致，改一边就同步改另一边。
#
# 注意：Kotlin 的尾随 lambda 可以写成 `Card {` 而**没有括号**，所以判据一律用
# `\s*[({]` 同时接受两种写法。只写 `\(` 会留下一条绕过通道
# （2026-10-28 咬合探针实测：`Card {` / `LazyColumn {` 写法当时被判据完全漏掉）。
$reHasTopBar = [regex]'(?:Small)?TopAppBar\s*[({]|QingyuPageScaffold\s*[({]'
$reBackButton = [regex]'IconButton\s*\(\s*onClick\s*=\s*onBack'
$reLazyColumn = [regex]'(?<![A-Za-z])LazyColumn\s*[({]'
$rePageList = [regex]'QingyuPageList\s*[({]'
$reHaptic = [regex]'scrollEndHaptic'
$reVerticalScroll = [regex]'verticalScroll\(rememberScrollState\(\)\)'
$reRawCard = [regex]'(?<![A-Za-z])Card\s*[({]'
$reFontSize = [regex]'fontSize\s*=\s*[0-9]+(\.[0-9]+)?\.sp'
$reHardColor = [regex]'Color\(0x'
# R6：只判「未限定的调用/定义」，不认主题槽的成员访问——
# `Color(QingyuTheme.sectionLabel(dark))` 是语义取色（与 actionIcon 同值），不是自拼标题。
# 负向后顾排除标识符与 `.`，于是 `sectionLabel("分组")`、`private fun sectionLabel(` 仍命中，
# `QingyuTheme.sectionLabel(` / `obj.sectionLabel(` 不再命中。
$reSectionLabel = [regex]'(?<![A-Za-z0-9_$.])sectionLabel\s*\('
$reSectionTitle = [regex]'QingyuSectionTitle\s*[({]'
# R7：只匹配 `fontWeight = FontWeight.X` 字面量；`fontWeight = weight` 是用户自己的功能设置，不算。
$reFontWeight = [regex]'fontWeight\s*=\s*FontWeight\.'

# 域级豁免：这些目录本来就该用裸组件（见规则文档 §五）
$exempt = @{
    "shell"    = @("R1")               # 壳自带导航栏，不是子页
    "showcase" = @("R1", "R3", "R7")   # 展厅故意逐个展示官方裸组件与字重
}

# 4 个扫描器。每个函数返回 `Rel / Rule / Detail` 对象列表。
$scanners = @(
    "Get-SkeletonViolations",
    "Get-ContentBlockViolations",
    "Get-TypographyViolations",
    "Get-ColorViolations"
)

# ── 只看代码：剥注释与字符串内容 ────────────────────────────────────────
# 与守卫的 stripCommentsAndStrings 同一套状态机（行注释 / 可嵌套块注释 /
# 字符串 / 字符 / 原始字符串）。注释里讲的旧写法、字符串里的示例代码都不参与判定；
# 换行一律保留，报出来的行号才准。
function Remove-KotlinCommentsAndStrings {
    param([string]$Source)

    $out = [System.Text.StringBuilder]::new($Source.Length)
    $i = 0
    $n = $Source.Length
    $lineComment = $false
    $blockDepth = 0
    $quote = [char]0
    $raw = $false

    while ($i -lt $n) {
        $ch = $Source[$i]
        $next = if ($i + 1 -lt $n) { $Source[$i + 1] } else { [char]0 }
        $third = if ($i + 2 -lt $n) { $Source[$i + 2] } else { [char]0 }

        if ($lineComment) {
            if ($ch -eq "`n") { $lineComment = $false; [void]$out.Append($ch) }
            $i++
            continue
        }
        if ($blockDepth -gt 0) {
            if ($ch -eq '/' -and $next -eq '*') {
                $blockDepth++; [void]$out.Append('  '); $i += 2
            } elseif ($ch -eq '*' -and $next -eq '/') {
                $blockDepth--; [void]$out.Append('  '); $i += 2
            } else {
                if ($ch -eq "`n") { [void]$out.Append($ch) }
                $i++
            }
            continue
        }
        if ($raw) {
            if ($ch -eq '"' -and $next -eq '"' -and $third -eq '"') {
                $raw = $false; [void]$out.Append('"""'); $i += 3
            } else {
                if ($ch -eq "`n") { [void]$out.Append($ch) }
                $i++
            }
            continue
        }
        if ($quote -ne [char]0) {
            if ($ch -eq '\') {
                [void]$out.Append('  '); $i += 2
            } elseif ($ch -eq $quote) {
                [void]$out.Append($ch); $quote = [char]0; $i++
            } else {
                if ($ch -eq "`n") { [void]$out.Append($ch) }
                $i++
            }
            continue
        }
        if ($ch -eq '/' -and $next -eq '/') {
            $lineComment = $true; [void]$out.Append(' '); $i += 2; continue
        }
        if ($ch -eq '/' -and $next -eq '*') {
            $blockDepth = 1; [void]$out.Append(' '); $i += 2; continue
        }
        if ($ch -eq '"' -and $next -eq '"' -and $third -eq '"') {
            $raw = $true; [void]$out.Append('"""'); $i += 3; continue
        }
        if ($ch -eq '"' -or $ch -eq "'") {
            $quote = $ch; [void]$out.Append($ch); $i++; continue
        }
        [void]$out.Append($ch)
        $i++
    }
    return $out.ToString()
}

function Get-CodeLines {
    param([string]$Path)
    $code = Remove-KotlinCommentsAndStrings -Source ([System.IO.File]::ReadAllText($Path))
    $n = 0
    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($code -split "`n")) {
        $n++
        if ($line.TrimStart().StartsWith("import ")) { continue }
        $result.Add([pscustomobject]@{ Line = $n; Code = $line.TrimEnd("`r") })
    }
    return $result
}

function Get-FirstLine {
    param($Lines, [regex]$Re)
    $hit = $Lines | Where-Object { $Re.IsMatch($_.Code) } | Select-Object -First 1
    if ($hit) { $hit.Line } else { 0 }
}

function Get-HitCount {
    param($Lines, [regex]$Re)
    @($Lines | Where-Object { $Re.IsMatch($_.Code) }).Count
}

# ── 扫描器 1：结构（顶栏 / 滚动）→ R1 / R2 ─────────────────────────────
function Get-SkeletonViolations {
    param($Rel, $Lines, $Exempt)
    $out = [System.Collections.Generic.List[object]]::new()
    $code = ($Lines | ForEach-Object { $_.Code }) -join "`n"

    # R1 页面骨架与顶栏 → 不许手搓顶栏行（官方 TopAppBar / QingyuPageScaffold 都行）
    if ($Exempt -notcontains "R1" -and $reBackButton.IsMatch($code) -and -not $reHasTopBar.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R1"
            Detail = "手搓顶栏行（返回键），未走官方 TopAppBar / QingyuPageScaffold（第 $(Get-FirstLine $Lines $reBackButton) 行）"
        })
    }

    # R2 滚动容器 → QingyuPageList
    if ($reLazyColumn.IsMatch($code) -and -not $rePageList.IsMatch($code) -and -not $reHaptic.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R2"
            Detail = "裸 LazyColumn，缺滚动三件套与滚动条（第 $(Get-FirstLine $Lines $reLazyColumn) 行）"
        })
    }
    if ($reVerticalScroll.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R2"
            Detail = "用 Column+verticalScroll 当主滚动（非惰性，第 $(Get-FirstLine $Lines $reVerticalScroll) 行）"
        })
    }
    return @($out)
}

# ── 扫描器 2：内容块（卡片 / 分组标题）→ R3 / R6 ────────────────────────
function Get-ContentBlockViolations {
    param($Rel, $Lines, $Exempt)
    $out = [System.Collections.Generic.List[object]]::new()
    $code = ($Lines | ForEach-Object { $_.Code }) -join "`n"

    # R3 卡片 → QingyuCard
    if ($Exempt -notcontains "R3" -and $reRawCard.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R3"
            Detail = "裸 Card，缺按压反馈与语义圆角（第 $(Get-FirstLine $Lines $reRawCard) 行）"
        })
    }

    # R6 分组标题 → QingyuSectionTitle
    if ($reSectionLabel.IsMatch($code) -and -not $reSectionTitle.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R6"
            Detail = "自己拼分组标题，未走 QingyuSectionTitle（第 $(Get-FirstLine $Lines $reSectionLabel) 行）"
        })
    }
    return @($out)
}

# ── 扫描器 3：字体（字号 / 字重）→ R4 / R7 ──────────────────────────────
function Get-TypographyViolations {
    param($Rel, $Lines, $Exempt)
    $out = [System.Collections.Generic.List[object]]::new()
    $code = ($Lines | ForEach-Object { $_.Code }) -join "`n"

    # R4 字号 → MiuixTheme.textStyles
    if ($reFontSize.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R4"
            Detail = "写死字号 $(Get-HitCount $Lines $reFontSize) 处，首处第 $(Get-FirstLine $Lines $reFontSize) 行（应用 MiuixTheme.textStyles）"
        })
    }

    # R7 字重 → 主题字阶上的 shiftWeight
    if ($Exempt -notcontains "R7" -and $reFontWeight.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R7"
            Detail = "写死字重 $(Get-HitCount $Lines $reFontWeight) 处，首处第 $(Get-FirstLine $Lines $reFontWeight) 行（应用 MiuixTheme.textStyles.*.shiftWeight）"
        })
    }
    return @($out)
}

# ── 扫描器 4：颜色 → R5 ─────────────────────────────────────────────────
function Get-ColorViolations {
    param($Rel, $Lines, $Exempt)
    $out = [System.Collections.Generic.List[object]]::new()
    $code = ($Lines | ForEach-Object { $_.Code }) -join "`n"

    # R5 颜色 → 主题取色
    if ($reHardColor.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel    = $Rel
            Rule   = "R5"
            Detail = "写死颜色 $(Get-HitCount $Lines $reHardColor) 处，首处第 $(Get-FirstLine $Lines $reHardColor) 行（应用主题语义槽）"
        })
    }
    return @($out)
}

function Get-Violations {
    param([string]$DomainName)

    $dir = Join-Path $pagesRoot $DomainName
    $files = @(Get-ChildItem -Path $dir -Recurse -File -Filter *.kt | Sort-Object FullName)
    $ex = $exempt[$DomainName]
    if ($null -eq $ex) { $ex = @() }
    $out = [System.Collections.Generic.List[object]]::new()

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($pagesRoot.Length + 1).Replace('\', '/')
        $lines = @(Get-CodeLines -Path $f.FullName)
        foreach ($scanner in $scanners) {
            $hits = @(& $scanner -Rel $rel -Lines $lines -Exempt $ex)
            foreach ($hit in $hits) { $out.Add($hit) }
        }
    }
    return @($out | Sort-Object Rel, Rule)
}

# ── 例外清单 ────────────────────────────────────────────────────────────
function Read-ExceptionEntries {
    $map = @{}
    if (-not (Test-Path $exceptionsRoot)) { return $map }
    foreach ($f in @(Get-ChildItem -Path $exceptionsRoot -File -Filter *.txt | Sort-Object Name)) {
        $n = 0
        foreach ($raw in [System.IO.File]::ReadAllLines($f.FullName)) {
            $n++
            $line = $raw.Trim()
            if ($line -eq "" -or $line.StartsWith("#")) { continue }
            $parts = $line -split '\|'
            if ($parts.Count -lt 3) {
                Write-Error "例外行格式不对（应为 <相对路径>|<规则>|<原因>）：$($f.Name):$n → $line"
                exit 2
            }
            $rel = $parts[0].Trim()
            $rule = $parts[1].Trim()
            $reason = (($parts[2..($parts.Count - 1)]) -join "|").Trim()
            if ($rel -eq "" -or $rule -eq "" -or $reason -eq "") {
                Write-Error "例外行的路径/规则/原因都不能为空：$($f.Name):$n → $line"
                exit 2
            }
            $key = "$rel|$rule"
            if ($map.ContainsKey($key)) {
                Write-Error "例外键重复：$key（$($f.Name):$n）——同一处只登记一次"
                exit 2
            }
            $map[$key] = [pscustomobject]@{
                Key    = $key
                Reason = $reason
                Source = "$($f.Name):$n"
            }
        }
    }
    return $map
}

# -Write 只删过期行；看见当前仍命中的例外就原样保留。
# 绝不把「新违规」写成例外——那正是旧版 -Write 的后门。
function Remove-StaleExceptions {
    param([string]$DomainName, [object[]]$Violations)

    $file = Join-Path $exceptionsRoot "$DomainName.txt"
    if (-not (Test-Path $file)) { return }

    $keys = @($Violations | ForEach-Object { "$($_.Rel)|$($_.Rule)" } | Sort-Object -Unique)
    $kept = New-Object System.Collections.Generic.List[string]
    $removed = 0
    $n = 0

    foreach ($raw in [System.IO.File]::ReadAllLines($file)) {
        $n++
        $line = $raw.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { $kept.Add($raw); continue }
        $parts = $line -split '\|'
        if ($parts.Count -lt 3) {
            Write-Error "例外行格式不对（应为 <相对路径>|<规则>|<原因>）：$($DomainName).txt:$n → $line"
            exit 2
        }
        $key = "$($parts[0].Trim())|$($parts[1].Trim())"
        if ($keys -contains $key) { $kept.Add($raw) } else { $removed++ }
    }

    $hasData = @($kept | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") }).Count -gt 0
    if ($hasData) {
        Set-Content -Path $file -Value $kept -Encoding UTF8
    } else {
        # 空清单不留在仓库里（旧版 21 份基线里 19 份就是这种空壳）。
        Remove-Item -Path $file -Force
    }

    if ($removed -gt 0) {
        Write-Host "  已删除过期例外 $removed 行：$file" -ForegroundColor Yellow
    }
}

# ── 主流程 ──────────────────────────────────────────────────────────────

$violationsByDomain = @{}
foreach ($d in $domains) {
    $violationsByDomain[$d] = @(Get-Violations -DomainName $d)
    if ($Write) {
        Remove-StaleExceptions -DomainName $d -Violations $violationsByDomain[$d]
    }
}

$exceptions = Read-ExceptionEntries
$pendingTotal = 0
$usedTotal = 0
$staleTotal = 0

foreach ($d in $domains) {
    $v = $violationsByDomain[$d]
    $currentKeys = @($v | ForEach-Object { "$($_.Rel)|$($_.Rule)" } | Sort-Object -Unique)
    $pendingKeys = @($currentKeys | Where-Object { -not $exceptions.ContainsKey($_) })
    $usedKeys = @($currentKeys | Where-Object { $exceptions.ContainsKey($_) })
    $stale = @($exceptions.Values |
            Where-Object { $_.Source.StartsWith("$($d).txt:") -and ($currentKeys -notcontains $_.Key) } |
            Sort-Object Key)

    $pendingTotal += $pendingKeys.Count
    $usedTotal += $usedKeys.Count
    $staleTotal += $stale.Count

    Write-Host ""
    Write-Host "=== $d ：$($currentKeys.Count) 处命中 / $($pendingKeys.Count) 待修 / $($usedKeys.Count) 例外 / $($stale.Count) 过期 ===" -ForegroundColor Cyan

    if ($v.Count -eq 0) {
        Write-Host "  干净" -ForegroundColor Green
    } else {
        $v | ForEach-Object {
            $key = "$($_.Rel)|$($_.Rule)"
            if ($exceptions.ContainsKey($key)) {
                Write-Host ("  [例外] {0,-4} {1}  {2}" -f $_.Rule, $_.Rel, $exceptions[$key].Reason) -ForegroundColor DarkGray
            } else {
                Write-Host ("  [待修] {0,-4} {1}  {2}" -f $_.Rule, $_.Rel, $_.Detail) -ForegroundColor Yellow
            }
        }
    }
    $stale | ForEach-Object {
        Write-Host ("  [过期] {0}  ({1})" -f $_.Key, $_.Source) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "合计：待修 $pendingTotal 处，例外 $usedTotal 条，过期 $staleTotal 条" -ForegroundColor Cyan

if ($pendingTotal -gt 0) {
    Write-Host "待修违规必须为 0。改代码走共享套件；确有正当理由要保留的，人工编辑 tool/compose_style_exceptions/<域>.txt 并写明原因（-Write 不会帮你加）。" -ForegroundColor Red
}
if ($staleTotal -gt 0) {
    Write-Host "过期例外必须删掉：加 -Write 只删过期行，不会新增。" -ForegroundColor Red
}
if (-not $Write) {
    Write-Host "（只读模式；加 -Write 只会删除过期例外，不会新增任何行）" -ForegroundColor DarkGray
}

if ($pendingTotal -gt 0 -or $staleTotal -gt 0) { exit 1 }
exit 0
