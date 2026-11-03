<#
.SYNOPSIS
    Compose 页面样式规则检查（对齐官方 miuix demo）。规则定义见
    docs/reference/compose-page-style-rules.md，权威闸门是 JUnit 的
    ComposePageStyleGuardTest.kt，本脚本是同一套判据的**自查/生成基线**工具。

.DESCRIPTION
    扫描 android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/<域>/*.kt，
    以及共享套件层 .../qingyu/components/*.kt（`-Domain components`，2026-11-04 补域；
    基线键前缀 `components/`），按 R1..R7 七条规则列违规；-Write 时把自己域的基线文件
    重写为当前违规集（已修好的行会自动消失，这就是「棘轮只进不出」的落地点）。

    一个域一个基线文件 tool/compose_style_baseline/<域>.txt，
    这样多 Agent 并行时各改各的，不会撞同一个文件。

.EXAMPLE
    pwsh -File scripts/compose-style-lint.ps1 -Domain statistics
    pwsh -File scripts/compose-style-lint.ps1 -Domain statistics -Write
    pwsh -File scripts/compose-style-lint.ps1 -Domain all
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Domain,

    # 把当前违规集写成该域的基线（修完一条就少一行）
    [switch]$Write
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pagesRoot = Join-Path $repoRoot "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages"
$componentsRoot = Join-Path $repoRoot "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components"
$baselineRoot = Join-Path $repoRoot "tool/compose_style_baseline"

if (-not (Test-Path $pagesRoot)) {
    Write-Error "找不到页面源码目录：$pagesRoot"
    exit 2
}

# 域 → 源码根。pages 下按目录分域；components 是共享套件层（2026-11-04 补域），
# 它不是 pages/<域>，但同样要过 R1..R7，且基线键前缀固定为 `components/`。
$domainRoots = @{}
foreach ($d in @(Get-ChildItem -Path $pagesRoot -Directory | Select-Object -ExpandProperty Name)) {
    $domainRoots[$d] = Join-Path $pagesRoot $d
}
if (Test-Path $componentsRoot) { $domainRoots["components"] = $componentsRoot }

if ($Domain -eq "all") {
    $domains = @($domainRoots.Keys | Sort-Object)
} else {
    if (-not $domainRoots.ContainsKey($Domain)) {
        $avail = ($domainRoots.Keys | Sort-Object) -join ', '
        Write-Error "没有这个域：$Domain（可选：$avail）"
        exit 2
    }
    $domains = @($Domain)
}

# ── 判据常量 ────────────────────────────────────────────────────────────
# 全部按「代码行」判：行首 // 或 * 的注释行、import 行都不参与，
# 避免文档注释里摆着的示例代码造出假红（PageScaffoldGuardTest 踩过这个坑）。

# 注意：Kotlin 的尾随 lambda 可以写成 `Card {` 而**没有括号**，所以判据一律用
# `\s*[({]` 同时接受两种写法。只写 `\(` 会留下一条绕过通道
# （2026-10-28 咬合探针实测：`Card {` / `LazyColumn {` 写法当时被判据完全漏掉）。
#
# R1 判据曾写成 `Small?TopAppBar`（= "Smal" + 可选 l），只匹配到 SmallTopAppBar，
# 漏掉了最常见的裸 TopAppBar —— 2026-10-28 自查抓到。现改为判「手搓顶栏行」：
# 文件里有 `IconButton(onClick = onBack)` 却没有官方 TopAppBar / QingyuPageScaffold。
# 裸 TopAppBar 与 SmallTopAppBar 都是官方组件、输出正确，不再视为违规。
$reHasTopBar = [regex]'(?:Small)?TopAppBar\s*[({]|QingyuPageScaffold\s*[({]'
$reBackButton = [regex]'IconButton\s*\(\s*onClick\s*=\s*onBack'
$reLazyColumn = [regex]'(?<![A-Za-z])LazyColumn\s*[({]'
$rePageList = [regex]'QingyuPageList\s*[({]'
$reHaptic = [regex]'scrollEndHaptic'
$reVerticalScroll = [regex]'verticalScroll\(rememberScrollState\(\)\)'
$reRawCard = [regex]'(?<![A-Za-z])Card\s*[({]'
$reFontSize = [regex]'fontSize\s*=\s*[0-9]+(\.[0-9]+)?\.sp'
$reHardColor = [regex]'Color\(0x'
# R6：自己拼分组标题。判据认「未限定的调用/定义」，不认主题槽的成员访问——
# `Color(QingyuTheme.sectionLabel(dark))` 是语义取色（与 actionIcon 同值），不是自拼标题。
# 2026-11-02 实测：裸子串 `sectionLabel(` 把这种正当取色判成了 R6 假红。
# 负向后顾排除标识符与 `.`，于是 `sectionLabel("分组")`、`private fun sectionLabel(` 仍命中，
# `QingyuTheme.sectionLabel(` / `obj.sectionLabel(` 不再命中。
$reSectionLabel = [regex]'(?<![A-Za-z0-9_$.])sectionLabel\s*\('
$reSectionTitle = [regex]'QingyuSectionTitle\s*[({]'

# R7：写死绝对字重。只匹配 `fontWeight = FontWeight.X` 字面量；
# `fontWeight = weight`（实时活动自己的功能设置）不算——那是用户选的绝对值，不是设计强调。
$reFontWeight = [regex]'fontWeight\s*=\s*FontWeight\.'

# 域级豁免：这些目录本来就该用裸组件（见规则文档 §五）
$exempt = @{
    "shell"    = @("R1")               # 壳自带导航栏，不是子页
    "showcase" = @("R1", "R3", "R7")   # 展厅故意逐个展示官方裸组件与字重
}

# 文件级豁免：套件本体就是「被用来绕开裸组件」的那一层，规则文档 §二 R3 明文豁免
# `components/QingyuCard.kt` 自身（其它组件文件不豁免，仍按 R1..R7 逐条查）。
$fileExempt = @{
    "components/QingyuCard.kt" = @("R3")
}

function Get-CodeLines {
    param([string]$Path)
    $n = 0
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $n++
        $t = $line.TrimStart()
        if ($t.StartsWith("//") -or $t.StartsWith("*") -or $t.StartsWith("/*")) { continue }
        if ($t.StartsWith("import ")) { continue }
        $result.Add([pscustomobject]@{ Line = $n; Code = ($line -replace "//.*$", "") })
    }
    return $result
}

function Get-Violations {
    param([string]$DomainName)

    $dir = $domainRoots[$DomainName]
    $files = @(Get-ChildItem -Path $dir -Recurse -File -Filter *.kt | Sort-Object FullName)
    $ex = $exempt[$DomainName]
    $out = New-Object System.Collections.Generic.List[object]

    foreach ($f in $files) {
        $relBody = $f.FullName.Substring($dir.Length + 1).Replace('\', '/')
        # 页面域沿用 `pages/<域>/文件` 的相对路径；components 域补上 `components/` 前缀，
        # 保证基线键与守卫（File 相对 pagesRoot）的读取口径一致。
        $rel = if ($DomainName -eq "components") { "components/$relBody" } else { $relBody }
        $fx = $fileExempt[$rel]
        $lines = @(Get-CodeLines -Path $f.FullName)
        $all = ($lines | ForEach-Object { $_.Code }) -join "`n"

        # 首个命中的行号（找不到就回 0）
        $firstLine = {
            param([regex]$re)
            $hit = $lines | Where-Object { $re.IsMatch($_.Code) } | Select-Object -First 1
            if ($hit) { $hit.Line } else { 0 }
        }
        $hitCount = {
            param([regex]$re)
            @($lines | Where-Object { $re.IsMatch($_.Code) }).Count
        }

        # R1 页面骨架与顶栏 → 不许手搓顶栏行（用官方 TopAppBar 或 QingyuPageScaffold）
        if ($ex -notcontains "R1" -and $reBackButton.IsMatch($all) -and -not $reHasTopBar.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R1"; Detail = "手搓顶栏行（返回键），未走官方 TopAppBar / QingyuPageScaffold（第 $(& $firstLine $reBackButton) 行）" })
        }

        # R2 滚动容器 → QingyuPageList
        if ($reLazyColumn.IsMatch($all) -and -not $rePageList.IsMatch($all) -and -not $reHaptic.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R2"; Detail = "裸 LazyColumn，缺滚动三件套与滚动条（第 $(& $firstLine $reLazyColumn) 行）" })
        }
        if ($reVerticalScroll.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R2"; Detail = "用 Column+verticalScroll 当主滚动（非惰性，第 $(& $firstLine $reVerticalScroll) 行）" })
        }

        # R3 卡片 → QingyuCard（QingyuCard.kt 本体按规则文档明文豁免）
        if ($ex -notcontains "R3" -and $fx -notcontains "R3" -and $reRawCard.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R3"; Detail = "裸 Card，缺按压反馈与语义圆角（第 $(& $firstLine $reRawCard) 行）" })
        }

        # R4 字号 → MiuixTheme.textStyles
        if ($reFontSize.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R4"; Detail = "写死字号 $(& $hitCount $reFontSize) 处，首处第 $(& $firstLine $reFontSize) 行（应用 MiuixTheme.textStyles）" })
        }

        # R5 颜色 → 主题取色
        if ($reHardColor.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R5"; Detail = "写死颜色 $(& $hitCount $reHardColor) 处，首处第 $(& $firstLine $reHardColor) 行（应用主题语义槽）" })
        }

        # R6 分组标题 → QingyuSectionTitle
        if ($reSectionLabel.IsMatch($all) -and -not $reSectionTitle.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R6"; Detail = "自己拼分组标题，未走 QingyuSectionTitle（第 $(& $firstLine $reSectionLabel) 行）" })
        }

        # R7 字重 → 主题字阶上的 shiftWeight
        if ($ex -notcontains "R7" -and $reFontWeight.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R7"; Detail = "写死字重 $(& $hitCount $reFontWeight) 处，首处第 $(& $firstLine $reFontWeight) 行（应用 MiuixTheme.textStyles.*.shiftWeight）" })
        }
    }

    return @($out | Sort-Object Rel, Rule)
}

# ── 主流程 ──────────────────────────────────────────────────────────────

$total = 0
foreach ($d in $domains) {
    $v = @(Get-Violations -DomainName $d)
    $total += $v.Count
    Write-Host ""
    Write-Host "=== $d ：$($v.Count) 处 ===" -ForegroundColor Cyan
    if ($v.Count -eq 0) {
        Write-Host "  干净" -ForegroundColor Green
    } else {
        $v | ForEach-Object { Write-Host ("  {0,-4} {1}  {2}" -f $_.Rule, $_.Rel, $_.Detail) }
    }

    if ($Write) {
        if (-not (Test-Path $baselineRoot)) { New-Item -ItemType Directory -Path $baselineRoot -Force | Out-Null }
        $file = Join-Path $baselineRoot "$d.txt"
        $header = @(
            "# $d 域的 Compose 页面样式基线（棘轮）。规则见 docs/reference/compose-page-style-rules.md",
            "# 一行一处待还的债：<相对路径>|<规则>|<说明>",
            "# 修好一处就删一行；留着已修好的行会被守卫判「过期」而变红。",
            "# 由 scripts/compose-style-lint.ps1 -Domain $d -Write 重新生成。"
        )
        $body = if ($v.Count -eq 0) { @() } else { @($v | ForEach-Object { "$($_.Rel)|$($_.Rule)|$($_.Detail)" }) }
        Set-Content -Path $file -Value ($header + $body) -Encoding UTF8
        Write-Host "  已写入基线：$file" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "合计：$total 处" -ForegroundColor Cyan
if (-not $Write) {
    Write-Host "（只读模式；加 -Write 重新生成该域基线）" -ForegroundColor DarkGray
}
exit 0
