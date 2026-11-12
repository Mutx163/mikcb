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
    以及共享套件层 .../qingyu/components/*.kt（`-Domain components`，2026-11-04 补域；
    基线键前缀 `components/`），同样按 R1..R7 七条规则列违规。

    规则：**待修违规必须为 0**，**过期也必须为 0**。真正需要保留的写法登记在
    tool/compose_style_exceptions/<域>.txt，一行
        <相对路径>|<规则>|<锚列表>|<原因>
    锚列表里的锚**允许重复**：同一个锚写 N 次 = 该文件该规则下「同文本」必须命中 N 处。

    【行级锚 · 2026-11-11】登记单位从「整个文件 + 整条规则」收窄到**行**：
    锚 = 被判定的那行代码（剥注释与字符串内容、trim 之后）的 SHA-256 前 8 位小写十六进制。
    不用行号——行号随无关改动（删一行空行、上方插一段）上下漂移，一漂整片例外就假红。

    【多重集 + 零锚 · 2026-11-12】锚列从**集合**改成**多重集**，并堵掉跨行命中：
      1. 锚按**行**算，允许重复：同一个锚登记 N 次只免检 N 处命中，同文本第 2 处必须各自
         再登记一个同值锚。旧版对锚 distinctBy 去重，同文件再粘一行完全相同的违规能借旧锚
         免检（实测 showcase/ColorBlendToken.kt 82 处命中只有 76 个锚，5 组共锚）。
         **不把行号掺进哈希**：一掺进去「挪一下行号就失去豁免」，人就会去重刷锚，棘轮失效。
      2. **跨行命中一律判待修**：判据在整文件拼接文本上匹配，`\s` 允许跨行，于是
         `IconButton(` 换行后 `onClick = onBack` 能拿到命中，却没有任何单独一行匹配得上，
         行级锚一个都算不出来。这种命中**不可登记**，也**不许**退化成「该文件该规则有例外
         ⇒ 放过」——那等于退回整文件免检，正是 2026-11-11 堵掉的洗白通道。
      3. 过期口径：**任一登记锚失效即过期**（登记次数 > 命中次数就报），不是「全部失效才过期」——
         后者会让陈旧锚无限期留着，「只进不出」的口子重新打开。
      4. 规则名两侧都 ToUpperInvariant 后再拼键；路径保持原样（避免引入新的平台大小写差异）。

    判据（与 ComposePageStyleGuardTest.kt 逐字一致）：
      · 命中次数 > 登记次数 ⇒ [待修]，报「该锚还需再登记 N 次（已登记 X 次 / 命中 Y 处）」；
      · 跨行未计命中 > 0 ⇒ [待修]，点名「零行级锚」，且**不提供**可登记锚；
      · 登记次数 > 命中次数 ⇒ [过期]（改过内容 / 挪到别的文件 / 已修好，都得删）；
      · 同一例外行里重复登记同一个锚 ⇒ **合法**（= 需要 N 处命中），不再判用法错。
    报 [待修] 时脚本直接打印「锚 <hash> 还需再登记 N 次」，人工登记照抄即可。

    -Write 只做两件事：删掉**已经过期**的行与锚（按次数裁：登记 N 次、命中 M 次且 M<N，就裁到
    M 次）。它**绝不新增**，所以不存在「把新违规洗进基线」的后门。新增例外只能人工编辑文件并写明原因。

    【旧格式已作废】三段式 `<路径>|<规则>|<原因>` 等于整文件整规则免检，正是本轮要堵的
    洗白通道（2026-11-11 之前，随便在同文件里再加一处同类违规，那条规则整体不判）。
    现在还写三段会直接判用法错。

.EXAMPLE
    pwsh -File scripts/compose-style-lint.ps1 -Domain statistics
    pwsh -File scripts/compose-style-lint.ps1 -Domain statistics -Write
    pwsh -File scripts/compose-style-lint.ps1 -Domain all
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Domain,

    # 只删过期例外（整行过期就删行、部分锚过期就裁锚）；不会新增任何内容。
    [switch]$Write
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pagesRoot = Join-Path $repoRoot "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages"
$exceptionsRoot = Join-Path $repoRoot "tool/compose_style_exceptions"
$componentsRoot = Join-Path $repoRoot "android/app/src/composeP1/kotlin/com/mutx163/qingyu/components"

# 用法错误一律 exit 2。不用 Write-Error：EAP=Stop 下它会抛出终止错误，拿不到稳定的退出码。
function Write-UsageError {
    param([string]$Message)
    [Console]::Error.WriteLine("[compose-style-lint] $Message")
    exit 2
}

if (-not (Test-Path $pagesRoot)) {
    Write-UsageError "找不到页面源码目录：$pagesRoot"
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
        Write-UsageError "没有这个域：$Domain（可选：$avail）"
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

# 4 个扫描器。每个函数返回 `Rel / Rule / Detail / Anchors` 对象列表。
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

# 文件级豁免：套件本体就是「被用来绕开裸组件」的那一层，规则文档 §二 R3 明文豁免
# `components/QingyuCard.kt` 自身（其它组件文件不豁免，仍按 R1..R7 逐条查）。
$fileExempt = @{
    "components/QingyuCard.kt" = @("R3")
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

# ── 行级锚 ──────────────────────────────────────────────────────────────
# 例外只覆盖「当初登记的那几行」，所以锚必须钉在**被判定的那行代码**上：
# 剥掉注释与字符串内容、trim 之后，取 SHA-256 的前 8 位小写十六进制。
#
# 为什么不用行号：行号会随**无关改动**漂移——上方删一行空行、插一句 import，
# 整片例外就集体假红，人会开始「顺手重跑一遍把锚刷掉」，棘轮就失效了。
# 哈希只跟着这行代码本身走：内容一改就是另一个锚（过期红），挪到别的文件也匹配不上。
#
# 两侧必须算出同一个值：ComposePageStyleGuardTest.kt 的 lineAnchor() 是本函数的
# 逐字对偶（MessageDigest "SHA-256" + trim + UTF-8 + 前 4 字节小写十六进制）。
function Get-LineAnchor {
    param([string]$Code)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Code.Trim())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $digest = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    $hex = ($digest | ForEach-Object { $_.ToString('x2') }) -join ''
    return $hex.Substring(0, 8)
}

# 一行代码可能同时命中同一条规则的多个正则（例如 R2 的 LazyColumn 与 verticalScroll），
# 但锚是**按行**算的，且从 2026-11-12 起**允许重复**：同文本的两行产两个同值锚。
# 旧版在这里按 hash 去重（$seen），于是「同文件再粘一行完全相同的违规」能借旧锚免检——
# 那是 H1 的洞，别加回去。
function Get-AnchorHits {
    param($Lines, [regex]$Re)
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @($Lines | Where-Object { $Re.IsMatch($_.Code) })) {
        $out.Add([pscustomobject]@{ Hash = (Get-LineAnchor $line.Code); Line = $line.Line })
    }
    return @($out)
}

# 跨行未计命中数 = 整文件拼接文本里的匹配数 − Σ(逐行匹配数)。
# 判据在拼接文本上匹配、`\s` 允许跨行，于是 `IconButton(` 换行后 `onClick = onBack` 能在
# 拼接文本里命中，却没有任何单独一行匹配得上 ⇒ 行级锚一个都算不出来。
# 这个数 > 0 就说明有匹配只活在换行处：一律判待修，不可登记。
# 与守卫的 SourceFile.unaccounted(re) 逐字对偶。
function Get-UnaccountedMatches {
    param([string]$Code, $Lines, [regex]$Re)
    $joined = $Re.Matches($Code).Count
    $perLine = 0
    foreach ($line in @($Lines)) { $perLine += $Re.Matches($line.Code).Count }
    return $joined - $perLine
}

# ── 扫描器 1：结构（顶栏 / 滚动）→ R1 / R2 ─────────────────────────────
function Get-SkeletonViolations {
    param($Rel, $Lines, $Exempt)
    $out = [System.Collections.Generic.List[object]]::new()
    $code = ($Lines | ForEach-Object { $_.Code }) -join "`n"

    # R1 页面骨架与顶栏 → 不许手搓顶栏行（官方 TopAppBar / QingyuPageScaffold 都行）
    # 已知残余（2026-11-12 记，不在本轮范围）：reHasTopBar 若只在换行处匹配（`TopAppBar` 单独一行、
    # 括号在下一行），仍会把这处违规**压掉**——那是「跨行命中不该算数」的反方向，属另一类洞。
    if ($Exempt -notcontains "R1" -and $reBackButton.IsMatch($code) -and -not $reHasTopBar.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel       = $Rel
            Rule      = "R1"
            Detail    = "手搓顶栏行（返回键），未走官方 TopAppBar / QingyuPageScaffold（第 $(Get-FirstLine $Lines $reBackButton) 行）"
            Anchors   = @(Get-AnchorHits $Lines $reBackButton)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reBackButton)
        })
    }

    # R2 滚动容器 → QingyuPageList
    if ($reLazyColumn.IsMatch($code) -and -not $rePageList.IsMatch($code) -and -not $reHaptic.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel       = $Rel
            Rule      = "R2"
            Detail    = "裸 LazyColumn，缺滚动三件套与滚动条（第 $(Get-FirstLine $Lines $reLazyColumn) 行）"
            Anchors   = @(Get-AnchorHits $Lines $reLazyColumn)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reLazyColumn)
        })
    }
    if ($reVerticalScroll.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel       = $Rel
            Rule      = "R2"
            Detail    = "用 Column+verticalScroll 当主滚动（非惰性，第 $(Get-FirstLine $Lines $reVerticalScroll) 行）"
            Anchors   = @(Get-AnchorHits $Lines $reVerticalScroll)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reVerticalScroll)
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
            Rel       = $Rel
            Rule      = "R3"
            Detail    = "裸 Card，缺按压反馈与语义圆角（第 $(Get-FirstLine $Lines $reRawCard) 行）"
            Anchors   = @(Get-AnchorHits $Lines $reRawCard)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reRawCard)
        })
    }

    # R6 分组标题 → QingyuSectionTitle
    if ($reSectionLabel.IsMatch($code) -and -not $reSectionTitle.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel       = $Rel
            Rule      = "R6"
            Detail    = "自己拼分组标题，未走 QingyuSectionTitle（第 $(Get-FirstLine $Lines $reSectionLabel) 行）"
            Anchors   = @(Get-AnchorHits $Lines $reSectionLabel)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reSectionLabel)
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
            Rel       = $Rel
            Rule      = "R4"
            Detail    = "写死字号 $(Get-HitCount $Lines $reFontSize) 处，首处第 $(Get-FirstLine $Lines $reFontSize) 行（应用 MiuixTheme.textStyles）"
            Anchors   = @(Get-AnchorHits $Lines $reFontSize)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reFontSize)
        })
    }

    # R7 字重 → 主题字阶上的 shiftWeight
    if ($Exempt -notcontains "R7" -and $reFontWeight.IsMatch($code)) {
        $out.Add([pscustomobject]@{
            Rel       = $Rel
            Rule      = "R7"
            Detail    = "写死字重 $(Get-HitCount $Lines $reFontWeight) 处，首处第 $(Get-FirstLine $Lines $reFontWeight) 行（应用 MiuixTheme.textStyles.*.shiftWeight）"
            Anchors   = @(Get-AnchorHits $Lines $reFontWeight)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reFontWeight)
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
            Rel       = $Rel
            Rule      = "R5"
            Detail    = "写死颜色 $(Get-HitCount $Lines $reHardColor) 处，首处第 $(Get-FirstLine $Lines $reHardColor) 行（应用主题语义槽）"
            Anchors   = @(Get-AnchorHits $Lines $reHardColor)
            CrossLine = (Get-UnaccountedMatches -Code $code -Lines $Lines -Re $reHardColor)
        })
    }
    return @($out)
}

function Get-Violations {
    param([string]$DomainName)

    $dir = $domainRoots[$DomainName]
    $files = @(Get-ChildItem -Path $dir -Recurse -File -Filter *.kt | Sort-Object FullName)
    $ex = $exempt[$DomainName]
    if ($null -eq $ex) { $ex = @() }
    $out = [System.Collections.Generic.List[object]]::new()

    foreach ($f in $files) {
        $relBody = $f.FullName.Substring($dir.Length + 1).Replace('\', '/')
        # 页面域沿用 `pages/<域>/文件` 的相对路径；components 域补上 `components/` 前缀，
        # 保证基线键与守卫（File 相对 pagesRoot）的读取口径一致。
        $rel = if ($DomainName -eq "components") { "components/$relBody" } else { "$DomainName/$relBody" }
        $fx = $fileExempt[$rel]
        $lines = @(Get-CodeLines -Path $f.FullName)
        # 文件级豁免（如 components/QingyuCard.kt 的 R3）并进域级豁免一起下发给扫描器。
        $effectiveExempt = @($ex)
        if ($fx) { $effectiveExempt += $fx }
        foreach ($scanner in $scanners) {
            $hits = @(& $scanner -Rel $rel -Lines $lines -Exempt $effectiveExempt)
            foreach ($hit in $hits) { $out.Add($hit) }
        }
    }
    return @($out | Sort-Object Rel, Rule)
}

# 按 `文件|规则` 聚合：一个例外键对应一处命中集合；R2 的两种形态（LazyColumn /
# verticalScroll）是**同一个键**，锚与跨行命中都合并到一组里（M1 合并语义）。
function Group-ViolationsByKey {
    param([object[]]$Violations)
    $map = [ordered]@{}
    foreach ($hit in $Violations) {
        $key = "$($hit.Rel)|$($hit.Rule)"
        if (-not $map.Contains($key)) {
            $map[$key] = [pscustomobject]@{
                Key        = $key
                Rel        = $hit.Rel
                Rule       = $hit.Rule
                Details    = [System.Collections.Generic.List[string]]::new()
                Violations = [System.Collections.Generic.List[object]]::new()
            }
        }
        $g = $map[$key]
        if (-not $g.Details.Contains($hit.Detail)) { $g.Details.Add($hit.Detail) }
        $g.Violations.Add($hit)
    }
    return $map
}

# 锚的**多重集**：同一个锚出现几次就是几处命中（2026-11-12 消耗式语义）。
# 只收哈希字符串（命中侧先投影 .Hash，登记侧本来就是字符串），避免「对象/字符串」两种入参
# 混用造成 null 键。[ordered] 只为输出顺序稳定，计数才是判据。
function Get-HashCounts {
    param([string[]]$Hashes)
    $counts = [ordered]@{}
    foreach ($h in @($Hashes)) {
        if (-not $counts.Contains($h)) { $counts[$h] = 0 }
        $counts[$h] = [int]$counts[$h] + 1
    }
    return $counts
}

# ── 例外清单 ────────────────────────────────────────────────────────────
# 一行 = 一处**行级**例外：<相对路径>|<规则>|<锚列表>|<原因>
#   锚 = Get-LineAnchor 的 8 位小写十六进制；
#   锚列表**允许重复**：同一个锚写 N 次 = 该文件该规则下「同文本」必须命中 N 处
#   （2026-11-12 起由集合改多重集，旧文件里每个锚各 1 次仍然完全兼容）；
#   原因里允许再出现 `|`（前两段路径/规则、第三段锚，其余整段算原因）；
#   同一「文件|规则」只允许登记一行，多个锚写在第三段用逗号分隔。
#   规则名统一 ToUpperInvariant 后拼键（与守卫 parseExceptionLine 对偶）；路径保持原样。
# 三段式旧格式（<路径>|<规则>|<原因>）已作废：那等于整文件整规则免检，正是洗白通道。
$reAnchor = [regex]'^[0-9a-f]{8}$'

function ConvertFrom-ExceptionLine {
    param([string]$Line, [string]$Where)

    $parts = $Line -split '\|'
    if ($parts.Count -lt 4) {
        Write-UsageError (
            "例外行格式不对（应为 <相对路径>|<规则>|<锚列表>|<原因>）：$Where → $Line`n" +
            "三段式旧格式已作废——它等于整文件整规则免检。请按行级锚重新登记" +
            "（跑一次本脚本，[待修] 行下面会直接打印「锚 <hash> 还需再登记 N 次」）。")
    }
    $rel = $parts[0].Trim()
    $ruleRaw = $parts[1].Trim()
    $rule = $ruleRaw.ToUpperInvariant()
    $anchors = @($parts[2].Split(',') | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' })
    $reason = (($parts[3..($parts.Count - 1)]) -join "|").Trim()

    if ($rel -eq "" -or $rule -eq "" -or $reason -eq "") {
        Write-UsageError "例外行的路径/规则/原因都不能为空：$Where → $Line"
    }
    if ($anchors.Count -eq 0) {
        Write-UsageError "例外行没有登记任何锚（第三段为空）：$Where → $Line"
    }
    # 同一个锚重复出现是**合法**的（= 要求该文件该规则下同文本命中 N 处），不再判用法错。
    # 2026-11-11 那版把它当错误，会把新语义直接挡死。
    foreach ($a in $anchors) {
        if (-not $reAnchor.IsMatch($a)) {
            Write-UsageError "锚不是 8 位小写十六进制：'$a'（$Where）→ $Line"
        }
    }
    return [pscustomobject]@{
        Key     = "$rel|$rule"
        Rel     = $rel
        Rule    = $rule
        RuleRaw = $ruleRaw
        Anchors = $anchors
        Reason  = $reason
    }
}

function Read-ExceptionEntries {
    $map = [ordered]@{}
    if (-not (Test-Path $exceptionsRoot)) { return $map }
    foreach ($f in @(Get-ChildItem -Path $exceptionsRoot -File -Filter *.txt | Sort-Object Name)) {
        $n = 0
        foreach ($raw in [System.IO.File]::ReadAllLines($f.FullName)) {
            $n++
            $line = $raw.Trim()
            if ($line -eq "" -or $line.StartsWith("#")) { continue }
            $entry = ConvertFrom-ExceptionLine -Line $line -Where "$($f.Name):$n"
            if ($map.Contains($entry.Key)) {
                Write-UsageError "例外键重复：$($entry.Key)（$($f.Name):$n）——同一处只登记一次，多个锚合并进同一行"
            }
            $entry | Add-Member -NotePropertyName SourceFile -NotePropertyValue $f.Name
            $entry | Add-Member -NotePropertyName Source -NotePropertyValue "$($f.Name):$n"
            $map[$entry.Key] = $entry
        }
    }
    return $map
}

# 每个「文件|规则」组判一次：当前命中（多重集）vs 登记（多重集）。
#   Pending = 命中次数 > 登记次数的盈余 → 新增违规（必须改代码）
#   Missing = 登记次数 > 命中次数的盈余 → 过期（改过内容 / 挪位置 / 已修好）
#   跨行命中（CrossLine > 0）算待修，但**没有**可登记的锚。
function Get-GroupAnalysis {
    param([object[]]$Violations, $Exceptions)

    $groups = Group-ViolationsByKey -Violations $Violations
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($key in @($groups.Keys | Sort-Object)) {
        $g = $groups[$key]

        $hitAnchors = [System.Collections.Generic.List[object]]::new()
        $crossLine = 0
        foreach ($v in $g.Violations) {
            $crossLine += [int]$v.CrossLine
            foreach ($a in @($v.Anchors)) { $hitAnchors.Add($a) }
        }
        $hitCounts = Get-HashCounts -Hashes @($hitAnchors | ForEach-Object { $_.Hash })

        $entry = $Exceptions[$key]
        $regCounts = if ($null -eq $entry) { [ordered]@{} } else { Get-HashCounts -Hashes @($entry.Anchors) }

        # 待修：每个锚「命中次数 − 登记次数」的盈余，逐处点名到行号。
        $pending = [System.Collections.Generic.List[object]]::new()
        $pendingTotal = 0
        foreach ($h in @($hitCounts.Keys)) {
            $reg = if ($regCounts.Contains($h)) { [int]$regCounts[$h] } else { 0 }
            $hit = [int]$hitCounts[$h]
            if ($hit -le $reg) { continue }
            $lines = @($hitAnchors | Where-Object { $_.Hash -eq $h } | ForEach-Object { $_.Line })
            $pending.Add([pscustomobject]@{
                Hash         = $h
                Registered   = $reg
                Hit          = $hit
                Need         = $hit - $reg
                SurplusLines = @($lines | Select-Object -Skip $reg)
            })
            $pendingTotal += $hit - $reg
        }
        $pendingTotal += $crossLine

        # 过期：任一登记锚失效即过期（登记次数 − 命中次数 > 0 就报）。
        $missing = [System.Collections.Generic.List[object]]::new()
        $staleTotal = 0
        foreach ($h in @($regCounts.Keys)) {
            $reg = [int]$regCounts[$h]
            $hit = if ($hitCounts.Contains($h)) { [int]$hitCounts[$h] } else { 0 }
            if ($reg -le $hit) { continue }
            $missing.Add([pscustomobject]@{ Hash = $h; Registered = $reg; Hit = $hit })
            $staleTotal += $reg - $hit
        }

        $hitTotal = 0
        foreach ($h in @($hitCounts.Keys)) { $hitTotal += [int]$hitCounts[$h] }

        $items.Add([pscustomobject]@{
            Key          = $key
            Rel          = $g.Rel
            Rule         = $g.Rule
            Details      = @($g.Details)
            Anchors      = @($hitAnchors)
            Entry        = $entry
            Pending      = @($pending)
            Missing      = @($missing)
            CrossLine    = $crossLine
            HitCount     = $hitTotal + $crossLine
            PendingCount = $pendingTotal
            StaleCount   = $staleTotal
        })
    }
    return $items
}

# -Write 只删过期货：
#   · 某行的锚**全都**不再命中 ⇒ 整行删掉；
#   · 还有效的锚 ⇒ 只重写锚那一列：按次数保留 min(命中次数, 登记次数) 个，
#     顺序不变（重复锚也是按顺序裁尾）。
# 绝不新增锚或行，所以「跑一下命令把新违规洗绿」这条后门仍然关着。
function Remove-StaleExceptions {
    param([string]$DomainName, [object[]]$Items)

    $file = Join-Path $exceptionsRoot "$DomainName.txt"
    if (-not (Test-Path $file)) { return }

    $live = @{}
    foreach ($item in $Items) { $live[$item.Key] = (Get-HashCounts -Hashes @($item.Anchors | ForEach-Object { $_.Hash })) }

    $raw = [System.IO.File]::ReadAllText($file)
    $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $kept = New-Object System.Collections.Generic.List[string]
    $removedLines = 0
    $trimmedLines = 0
    $n = 0

    foreach ($line in @($raw -split "`r?`n")) {
        $n++
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { $kept.Add($line); continue }
        $entry = ConvertFrom-ExceptionLine -Line $t -Where "$($DomainName).txt:$n"
        $hitCounts = if ($live.ContainsKey($entry.Key)) { $live[$entry.Key] } else { [ordered]@{} }

        # 按次数消费：同一个锚登记 3 次、命中 1 处 ⇒ 留前 1 个，其余 2 个算过期。
        $anchorsKept = [System.Collections.Generic.List[string]]::new()
        $consumed = @{}
        foreach ($a in @($entry.Anchors)) {
            $avail = if ($hitCounts.Contains($a)) { [int]$hitCounts[$a] } else { 0 }
            $used = if ($consumed.ContainsKey($a)) { [int]$consumed[$a] } else { 0 }
            if ($used -lt $avail) {
                $anchorsKept.Add($a)
                $consumed[$a] = $used + 1
            }
        }
        if ($anchorsKept.Count -eq 0) {
            $removedLines++
            continue
        }
        if ($anchorsKept.Count -lt @($entry.Anchors).Count) {
            $trimmedLines++
            # 规则列保留**原样大小写**：-Write 只删过期，不顺手改格式。
            $kept.Add(("{0}|{1}|{2}|{3}" -f $entry.Rel, $entry.RuleRaw, ($anchorsKept -join ','), $entry.Reason))
        } else {
            $kept.Add($line)
        }
    }

    if ($removedLines -eq 0 -and $trimmedLines -eq 0) { return }

    $hasData = @($kept | Where-Object {
            $x = $_.Trim()
            $x -ne "" -and -not $x.StartsWith("#")
        }).Count -gt 0
    if ($hasData) {
        [System.IO.File]::WriteAllText(
            $file,
            (($kept -join $nl) + $nl),
            [System.Text.UTF8Encoding]::new($false))
    } else {
        # 空清单不留在仓库里（旧版 21 份基线里 19 份就是这种空壳）。
        Remove-Item -Path $file -Force
    }

    Write-Host "  已删过期例外 $removedLines 行、裁掉过期锚 $trimmedLines 行：$($DomainName).txt" `
        -ForegroundColor Yellow
}

# ── 主流程 ──────────────────────────────────────────────────────────────

$violationsByDomain = @{}
foreach ($d in $domains) {
    $violationsByDomain[$d] = @(Get-Violations -DomainName $d)
}

if ($Write) {
    # -Write 先按当前扫描结果裁过期，再重新读清单出报告（否则报出来的还是旧锚）。
    $exceptions = Read-ExceptionEntries
    foreach ($d in $domains) {
        $items = @(Get-GroupAnalysis -Violations $violationsByDomain[$d] -Exceptions $exceptions)
        Remove-StaleExceptions -DomainName $d -Items $items
    }
}

$exceptions = Read-ExceptionEntries
$pendingTotal = 0
$usedTotal = 0
$staleTotal = 0

foreach ($d in $domains) {
    $items = @(Get-GroupAnalysis -Violations $violationsByDomain[$d] -Exceptions $exceptions)
    $currentKeys = @($items | ForEach-Object { $_.Key })
    # 清单里登记了、但该文件该规则已经一条违规都没有的整条例外（按 <域>.txt 归属）。
    $orphans = @($exceptions.Values | Where-Object {
            $_.SourceFile -eq "$($d).txt" -and ($currentKeys -notcontains $_.Key)
        } | Sort-Object Key)

    $hits = 0; $pending = 0; $stale = 0
    foreach ($item in $items) {
        $hits += $item.HitCount
        $pending += $item.PendingCount
        $stale += $item.StaleCount
    }
    foreach ($o in $orphans) { $stale += @($o.Anchors).Count }
    $used = $hits - $pending

    $pendingTotal += $pending
    $usedTotal += $used
    $staleTotal += $stale

    Write-Host ""
    Write-Host "=== $d ：$hits 处命中 / $pending 待修 / $used 例外覆盖 / $stale 过期 ===" -ForegroundColor Cyan

    if ($items.Count -eq 0) {
        Write-Host "  干净" -ForegroundColor Green
    } else {
        foreach ($item in $items) {
            # 同一锚出现多次时折叠成 `hash×3@L118,154,210`：一眼看出「一个锚顶几处命中」。
            $anchorsText = (@($item.Anchors | Group-Object Hash | ForEach-Object {
                        $ls = (@($_.Group | ForEach-Object { $_.Line }) -join ',')
                        if ($_.Count -gt 1) { "$($_.Name)×$($_.Count)@L$ls" } else { "$($_.Name)@L$ls" }
                    }) -join ' ')
            if ($item.PendingCount -eq 0) {
                $reason = if ($null -ne $item.Entry) { $item.Entry.Reason } else { '（无例外登记）' }
                $source = if ($null -ne $item.Entry) { "  $($item.Entry.Source)" } else { '' }
                Write-Host ("  [例外] {0,-4} {1}  {2}" -f $item.Rule, $item.Rel, $reason) -ForegroundColor DarkGray
                Write-Host ("         {0}{1}" -f $anchorsText, $source) -ForegroundColor DarkGray
            } else {
                $detail = ($item.Details -join '；')
                Write-Host ("  [待修] {0,-4} {1}  {2}" -f $item.Rule, $item.Rel, $detail) -ForegroundColor Yellow
                foreach ($p in $item.Pending) {
                    $linesText = if (@($p.SurplusLines).Count -gt 0) { "，未登记的是第 $(@($p.SurplusLines) -join '、') 行" } else { '' }
                    Write-Host ("         锚 {0} 还需再登记 {1} 次（当前已登记 {2} 次 / 当前命中 {3} 处{4}）" -f `
                            $p.Hash, $p.Need, $p.Registered, $p.Hit, $linesText) -ForegroundColor Yellow
                }
                if ($item.CrossLine -gt 0) {
                    Write-Host ("         跨行命中 {0} 处：判据在整文件拼接文本上匹配，`\s` 允许跨行，" -f $item.CrossLine) -ForegroundColor Yellow
                    Write-Host ("         于是没有任何单独一行匹配得上、算不出行级锚。这种命中一律判待修、**不可登记**，" ) -ForegroundColor Yellow
                    Write-Host ("         也不能因为「该文件该规则已有例外」放行（那等于退回整文件免检）；请写回单行或改代码。") -ForegroundColor Yellow
                }
                if ($null -ne $item.Entry) {
                    Write-Host ("         该键已有例外 {0}；同文件同规则的新增命中必须改代码，不许扩例外" -f `
                            $item.Entry.Source) -ForegroundColor Yellow
                }
            }
            foreach ($m in $item.Missing) {
                Write-Host ("  [过期] {0,-4} {1}  锚 {2} 登记 {3} 次、命中 {4} 处：多登 {5} 次（那一行改过内容 / 挪走 / 或已修好）  {6}" -f `
                        $item.Rule, $item.Rel, $m.Hash, $m.Registered, $m.Hit, ($m.Registered - $m.Hit), $item.Entry.Source) -ForegroundColor Red
            }
        }
    }
    foreach ($o in $orphans) {
        Write-Host ("  [过期] {0,-4} {1}  整条例外失效：该文件该规则已无违规（登记 {2} 个锚：{3}）  {4}" -f `
                $o.Rule, $o.Rel, @($o.Anchors).Count, (@($o.Anchors) -join ','), $o.Source) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "合计：待修 $pendingTotal 处，例外覆盖 $usedTotal 处，过期 $staleTotal 处" -ForegroundColor Cyan

if ($pendingTotal -gt 0) {
    Write-Host "待修违规必须为 0。改代码走共享套件；确有正当理由要保留的，人工按「锚 <hash> 还需再登记 N 次」把哈希写进 tool/compose_style_exceptions/<域>.txt 并写明原因（-Write 不会帮你加）。跨行命中的那几条不可登记，只能改代码。" -ForegroundColor Red
}
if ($staleTotal -gt 0) {
    Write-Host "过期例外必须删掉：加 -Write 只裁过期行与过期锚，不会新增。" -ForegroundColor Red
}
if (-not $Write) {
    Write-Host "（只读模式；加 -Write 只会删除过期行与过期锚，不会新增任何内容）" -ForegroundColor DarkGray
}

if ($pendingTotal -gt 0 -or $staleTotal -gt 0) { exit 1 }
exit 0
