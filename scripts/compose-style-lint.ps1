<#
.SYNOPSIS
    Compose 页面样式规则检查（对齐官方 miuix demo）。规则定义见
    docs/reference/compose-page-style-rules.md，权威闸门是 JUnit 的
    ComposePageStyleGuardTest.kt，本脚本是同一套判据的**自查/生成基线**工具。

.DESCRIPTION
    扫描 android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/<域>/*.kt，
    按 R1..R6 六条规则列违规；-Write 时把自己域的基线文件重写为当前违规集
    （已修好的行会自动消失，这就是「棘轮只进不出」的落地点）。

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
$baselineRoot = Join-Path $repoRoot "tool/compose_style_baseline"

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
# 全部按「代码行」判：行首 // 或 * 的注释行、import 行都不参与，
# 避免文档注释里摆着的示例代码造出假红（PageScaffoldGuardTest 踩过这个坑）。

# 注意：Kotlin 的尾随 lambda 可以写成 `Card {` 而**没有括号**，所以判据一律用
# `\s*[({]` 同时接受两种写法。只写 `\(` 会留下一条绕过通道
# （2026-10-28 咬合探针实测：`Card {` / `LazyColumn {` 写法当时被判据完全漏掉）。
$reTopAppBar = [regex]'(?<![A-Za-z])Small?TopAppBar\s*[({]'
$reSkeleton = [regex]'QingyuPageScaffold\s*[({]'
$reLazyColumn = [regex]'(?<![A-Za-z])LazyColumn\s*[({]'
$rePageList = [regex]'QingyuPageList\s*[({]'
$reHaptic = [regex]'scrollEndHaptic'
$reVerticalScroll = [regex]'verticalScroll\(rememberScrollState\(\)\)'
$reRawCard = [regex]'(?<![A-Za-z])Card\s*[({]'
$reFontSize = [regex]'fontSize\s*=\s*[0-9]+(\.[0-9]+)?\.sp'
$reHardColor = [regex]'Color\(0x'
$reSectionLabel = [regex]'sectionLabel\('
$reSectionTitle = [regex]'QingyuSectionTitle\s*[({]'

# 域级豁免：这些目录本来就该用裸组件（见规则文档 §五）
$exempt = @{
    "shell"    = @("R1")          # 壳自带导航栏，不是子页
    "showcase" = @("R1", "R3")    # 展厅故意逐个展示官方裸组件
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

    $dir = Join-Path $pagesRoot $DomainName
    $files = @(Get-ChildItem -Path $dir -Recurse -File -Filter *.kt | Sort-Object FullName)
    $ex = $exempt[$DomainName]
    $out = New-Object System.Collections.Generic.List[object]

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($pagesRoot.Length + 1).Replace('\', '/')
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

        # R1 页面骨架与顶栏 → QingyuPageScaffold
        if ($ex -notcontains "R1" -and $reTopAppBar.IsMatch($all) -and -not $reSkeleton.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R1"; Detail = "自己组合顶栏，未走 QingyuPageScaffold（第 $(& $firstLine $reTopAppBar) 行）" })
        }

        # R2 滚动容器 → QingyuPageList
        if ($reLazyColumn.IsMatch($all) -and -not $rePageList.IsMatch($all) -and -not $reHaptic.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R2"; Detail = "裸 LazyColumn，缺滚动三件套与滚动条（第 $(& $firstLine $reLazyColumn) 行）" })
        }
        if ($reVerticalScroll.IsMatch($all)) {
            $out.Add([pscustomobject]@{ Rel = $rel; Rule = "R2"; Detail = "用 Column+verticalScroll 当主滚动（非惰性，第 $(& $firstLine $reVerticalScroll) 行）" })
        }

        # R3 卡片 → QingyuCard
        if ($ex -notcontains "R3" -and $reRawCard.IsMatch($all)) {
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
