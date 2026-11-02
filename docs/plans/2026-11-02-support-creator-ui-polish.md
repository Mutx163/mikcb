# 支持作者页 UI 质量重构（2026-11-02）

> **范围**：只改「支持作者」页的视觉与版式。
> 渲染层：`android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt`
> 文案常量：`android/app/src/main/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorModel.kt`
> 文案对拍：`android/app/src/test/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorModelTest.kt`
> **不改**数据拉取（`SupportCreatorHost.kt` / `DonorsFeed.kt`）、路由、ARB 正文。

## 一、用户反馈

用户原话：「重构捐助支持页面 ui 样式质量，现在看起来整体很丑很奇怪」。
这是**观感问题**，不是功能缺失。数据、二维码、保存、鸣谢都已在（F09 已接真数据）。

## 二、现状硬伤（逐条有代码证据）

| # | 症状 | 证据 | 后果 |
|---|---|---|---|
| 1 | 顶栏标题与头卡标题一字不差 | `SupportCreatorPage.kt:108` 用 `heroTitle` 做页面标题；`:376` 头卡又写 `heroTitle` | 进页先看到两遍「支持轻屿课表继续更新」，像模板没填完 |
| 2 | 收款方式选择是「卡片里再放两张卡」 | `:140-151` 两个 `MethodTab`，而 `MethodTab`（`:428`）内部又是 `QingyuCard` | 卡片套卡片，双层圆角/阴影，选中态只换文字颜色，不像分段控件 |
| 3 | 二维码被强制 1:1 | `:170-177` `.aspectRatio(1f)` + `ContentScale.Fit`；真实素材 `assets/donate/wechatpay.png` 是 **1325×1806**、`alipay.png` 是 **1182×1772** | 竖版支付海报被缩进正方形，左右两条空带、二维码本身只有指甲盖大——这是「奇怪」的最大来源 |
| 4 | 二维码没有白色底 | 海报自带的白色卡在缩放后仍可辨，但外层井用 `surfaceContainer` 且没有白垫 | 深色模式/半透明底上对比不稳 |
| 5 | 「点击放大扫码」被放到两栏下方通栏 | `:218-230` 在 QR + 按钮的 `Row` 之外 | 它只解释二维码，却横跨整张卡，和按钮列无关 |
| 6 | 二维码区是「左图右按钮」两栏 | `:157-217` 两个 `weight(1f)` | 400dp 屏上每栏约 166dp，二维码小、按钮窄，重心偏左 |
| 7 | 鸣谢名单一行一张卡 | `:296-298` 每个 donor 一个 `QingyuRow`（内部 `QingyuCard`） | 三五个捐赠人就出现三五张独立卡片，像列表碎了 |
| 8 | 更新时间单独飘在卡片外 | `:286-295` `Text(updatedAtLabel)` 作为独立 item | 与「鸣谢名单」这个分组标题脱节，且右对齐缺失 |
| 9 | 鸣谢卡没有刷新入口 | 只有加载失败时 `QingyuRow(onClick=onReload)` | 名单加载成功后无法手动刷新 |
| 10 | 卡片的 `title` / `subtitle` / `subtitleNote` 三个字段没渲染 | `SupportDonorData` 有，`:285-299` 只用了 `updatedAt` 和 `donors` | 数据源提供的说明和备注被吞掉 |
| 11 | 「已支持」和「保存」都是灰底按钮，无主次 | `:184-210` `buttonColors()` + `textButtonColors()` | 主操作不突出 |

## 三、目标版式（从上到下）

页面骨架保持：`QingyuPageScaffold(title = SupportCreatorStrings.pageTitle, onBack)` +
`QingyuPageList(innerPadding = innerPadding, horizontalPadding = QingyuPageCardMargin, verticalArrangement = spacedBy(12.dp), contentPadding = PaddingValues(bottom = 24.dp))`。

### 3.1 顶栏标题

新增 `SupportCreatorStrings.pageTitle = "请作者喝杯咖啡"`（ARB `supportCreatorTitle`，六份 ARB 已有）。
头卡标题继续用 `heroTitle`。两者不再重复。

### 3.2 头卡（第 1 张卡）

```
QingyuCard(insideMargin = ContentInsideMargin)
  Row(spacedBy(12.dp), Alignment.Top) {
    Box(size 54.dp) {
      Box(size 50.dp, clip 14.dp, background surfaceContainer, border 1dp outline/alpha)
        QingyuAssetImage(launcher_icon, fillMaxSize)
      Box(align BottomEnd, offset(2,2), size 18.dp, clip 6.dp, background primary)
        Icon(Favorites, 10.dp, tint onPrimary)
    }
    Column(weight 1f, spacedBy(6.dp)) {
      Row(Alignment.CenterVertically) {
        Text(heroTitle, body1 + SEMIBOLD, primaryText, weight 1f, maxLines 2)
        RunningBadge()
      }
      Text(heroSubtitle, footnote1, secondaryText, lineHeight 19.sp)
      Row(spacedBy(6.dp)) { FeatureChip x3 }
    }
  }
```

- `RunningBadge`：`footnote2 + SEMIBOLD`，`success` 色，底 `success.copy(alpha = 0.14f)`，圆角 6，padding 6×2。
- `FeatureChip`：`footnote2 + SEMIBOLD`，圆角 6，padding 8×3；三色分别取
  `MiuixTheme.colorScheme.primary`（教务适配）、`QingyuIconColors.ORANGE`（修复问题）、
  `QingyuTheme.success(dark)`（体验优化）；底色一律 `accent.copy(alpha = 0.13f)`。
  **不要写 `Color(0x…)`**；颜色来源限主题槽或 `QingyuIconColors`。

### 3.3 收款卡（第 2 张卡，纵向单列）

```
QingyuCard(insideMargin = ContentInsideMargin)
  Column(spacedBy(12.dp)) {
    Text(methodTitle, body2 + SEMIBOLD, primaryText)
    TabRowWithContour(
      tabs = [wechatLabel, alipayLabel],
      selectedTabIndex = method.ordinal,
      onTabSelected = { method = ... },
      minWidth = 0.dp, maxWidth = Dp.Infinity,
      colors = TabRowDefaults.tabRowColors(
        backgroundColor = MiuixTheme.colorScheme.secondaryVariant,
        contentColor = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        selectedBackgroundColor = MiuixTheme.colorScheme.surfaceContainerHighest,
        selectedContentColor = MiuixTheme.colorScheme.onBackground,
      ),
    )
    Box(fillMaxWidth, Center) {
      QingyuCard(
        modifier = fillMaxWidth(0.72f),
        insideMargin = PaddingValues(0.dp),
        cornerRadius = 16.dp,
        onClick = { previewOpen = true },
      ) {
        QingyuAssetImage(
          assetPath = assetPath,
          modifier = fillMaxWidth().clip(RoundedCornerShape(16.dp)),
          contentDescription = scanTitleFor(method),
          useNaturalAspectRatio = true,
        )
      }
    }
    Row(center, spacedBy(4.dp)) {
      Icon(Show, 14.dp, secondaryText)
      Text(tapQrHint, footnote2, secondaryText)
    }
    Row(spacedBy(10.dp)) {
      Button(saveShort, weight 1f, colors = buttonColorsPrimary())
      Button(confirmedShort, weight 1f, colors = buttonColors())
    }
    Text(hintFor(method), footnote1, secondaryText, textAlign Center, fillMaxWidth)
  }
```

**关键点**

1. **二维码必须按素材原始宽高比显示**。给 `QingyuAssetImage` 增加
   `useNaturalAspectRatio: Boolean = false`：加载到 bitmap 后按
   `image.width / image.height` 调 `Modifier.aspectRatio(...)`。头卡图标走 `size(50.dp)`，不传此参数。
   不要再用 `aspectRatio(1f)` 套海报。
2. 二维码卡**不要再叠白色垫板**：素材本身就是带白底二维码的支付海报；再套白框只会多一圈。
3. 点击放大由 `QingyuCard(onClick=…)` 提供官方按压反馈，**不要**给图片挂裸 `Modifier.clickable`。
4. 选中「微信/支付宝」用官方 `TabRowWithContour`，**不要**再自拼两张 `QingyuCard`。
5. 保存按钮用 `ButtonDefaults.buttonColorsPrimary()`，已支持按钮用 `ButtonDefaults.buttonColors()`；
   两者同高、同 `weight(1f)`。

### 3.4 预览弹层

`QingyuSheet(show = previewOpen, title = scanTitleFor(method), onDismissRequest = …)`：

```
Column(centered, spacedBy(12.dp)) {
  Box(fillMaxWidth, Center) {
    QingyuCard(fillMaxWidth(0.9f), insideMargin = 0, cornerRadius = 20.dp) {
      QingyuAssetImage(poster, fillMaxWidth, clip 20.dp, useNaturalAspectRatio = true)
    }
  }
  Text(scanQrSubtitle, footnote1, secondaryText, textAlign Center)
  Button(saveToGallery, fillMaxWidth, colors = buttonColorsPrimary())
}
```

弹层不新增「关闭」文案（ARB 没有该键）；下滑/点空白/返回键关闭是官方行为。

### 3.5 鸣谢区（第 3 张卡）

**分组标题**：`QingyuSectionTitle(donorData?.title?.takeIf { it.isNotEmpty() } ?: donorListTitle)`。
卡片内部**不再重复写标题**。

```
QingyuCard(insideMargin = PaddingValues(0.dp)) {
  when {
    isLoading && donorData == null -> 居中 CircularProgressIndicator（上下 28dp）
    loadError != null && donorData == null -> 错误卡
    else -> 名单卡
  }
}
```

**名单卡**：

```
Column {
  Column(padding 16.dp) {
    Row(verticalAlignment = CenterVertically) {
      Column(weight 1f) {
        subtitle?.let { Text(footnote1, secondaryText, lineHeight 19.sp) }
        updatedAt?.let { Text(updatedAtLabel(it), footnote2, secondaryText, padding top 4) }
      }
      if (isLoading) CircularProgressIndicator(size = 20.dp) else IconButton(onReload) { Icon(Refresh, 20.dp, actionIcon) }
    }
    subtitleNote?.let {
      Row(spaceBy 8, padding top 10, background surfaceContainerHighest, clip 10, border 1dp outline alpha 0.5, padding 12×10) {
        Icon(Edit, 16.dp, primary)
        Text(it, footnote2, primaryText, lineHeight 19.sp)
      }
    }
    // 若 loadError != null 且已有旧数据：在这里显示错误行 + 重试，不隐藏旧名单
  }
  if (donors.isEmpty()) {
    Text(donorListEmpty, footnote1, secondaryText, padding(16.dp))
  } else {
    donors.forEachIndexed { index, donor ->
      if (index > 0) HorizontalDivider(Modifier.padding(start = 56.dp))
      DonorRow(donor)
    }
  }
}
```

`DonorRow`：

```
Row(fillMaxWidth, padding(horizontal 16.dp, vertical 12.dp), spacedBy(12.dp), CenterVertically) {
  Box(size 28.dp, clip CircleShape, background YELLOW.copy(alpha 0.14f), center) {
    Icon(Favorites, 14.dp, tint YELLOW)
  }
  Column(weight 1f) {
    Text(name, body1 + MEDIUM, primaryText)
    meta?.let { Text(it, footnote1, secondaryText, maxLines 2, overflow Ellipsis, padding top 2) }
  }
}
```

**错误卡**（无旧数据时）：`Column(padding 16.dp, spacedBy 10.dp)`：
`Text(donorListLoadFailed, body2, primaryText)` +
`Text(loadError, footnote2, error)` +
`Button(reloadAction, fillMaxWidth, buttonColors())`。

**已有旧数据但刷新失败**：在名单卡头部下方加：
`Text(donorListLoadFailed, footnote2, error)` + `TextButton(reloadAction, onClick=onReload)`，
旧名单照常显示。不要因为一次刷新失败把整份名单换掉。

## 四、约束

- 样式守卫 R1–R7 全部适用；目前 `tool/compose_style_baseline/about.txt` 为空，**不得新增任何基线行**。
  只允许 `MiuixTheme.textStyles.*` / `MiuixTheme.colorScheme.*` / `Color(QingyuTheme.*)` /
  `QingyuIconColors.*`；禁止 `Color(0x…)`、`fontSize = n.sp`、`fontWeight = FontWeight.X`。
- 渲染层禁止中文字面量；所有文案走 `SupportCreatorStrings`。
- 使用 `SupportCreatorStrings.pageTitle` 后，`tool/copy_style_dead_keys_baseline.txt` 里的
  `supportCreatorTitle` 已经变成活键，**必须删掉那一行**，否则文案守卫会报「过期项」。
- 不改 ARB 六份文件、不改 `SupportCreatorHost.kt`。
- 现有 `Toast` 提示保留（不在本任务范围）。

## 五、验收

```bash
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain about
pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/about"
pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin
dart run tool/copy_style_lint.dart
```

期望：样式守卫 0 违规；L0 全绿（含新增的 `supportCreatorTitle` 对拍）；L1 编译通过；文案 lint 无新增死键/过期项。
真机观感仍需用户用 `dev` 变体逐页对照（本任务只声明编译与 JVM 单测）。

## Task 1: 重排支持作者页并修正二维码比例

**目标**：按 §三 的目标版式重写 `SupportCreatorPage.kt`，并完成 §四 的文案/基线配套。

**写作用域**

- `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt`
- `android/app/src/main/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorModel.kt`
- `android/app/src/test/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorModelTest.kt`
- `tool/copy_style_dead_keys_baseline.txt`（只删 `supportCreatorTitle` 一行）

**必须做到**

1. 顶栏标题改用 `SupportCreatorStrings.pageTitle`（新增常量，值逐字等于 ARB `supportCreatorTitle`）。
2. `SupportCreatorModelTest.arbStringsMatchModel` 增加 `"supportCreatorTitle" to SupportCreatorStrings.pageTitle`。
3. 头卡按 §3.2 重做：应用图标 + 心形角标、标题 + 运行中徽标、副标题、三枚带底色胶囊。
4. 收款卡按 §3.3 重做：官方 `TabRowWithContour`、二维码按原始宽高比、单列纵向、主次按钮。
5. 预览弹层按 §3.4 重做。
6. 鸣谢区按 §3.5 合并为一张卡：分组标题 + 头部（副标题/更新时间/刷新）+ 备注条 + 分隔线行；
   加载、失败、空态、有旧数据但刷新失败四种状态都要覆盖。
7. `QingyuAssetImage` 增加 `useNaturalAspectRatio`，二维码/海报传 `true`，图标不传。
8. 删除不再使用的 import；不要留下未使用的 `MethodTab`、`QingyuRow` 调用。
9. 跑 §五 的四条命令；把实际输出写进报告。若 L1/L2 因别的泳道在途而红，说明红在哪、与本次改动是否相关。

**不要做**

- 不改数据拉取、路由、ARB 六份文件、`SupportCreatorHost.kt`。
- 不新增任何样式基线行；不为了让测试变绿而改守卫。
- 不新增中文文案（除 `pageTitle` 这个 ARB 已有键）。

**报告**

写到 `.superpowers/sdd/2026-11-02-support-creator-ui-polish/task-1-report.md`：
改了什么、每处对应哪个症状、四条命令的实际结果、仍未验证的事项（真机观感）。
返回只给状态、提交哈希、测试一行摘要、遗留顾虑。
