# Compose 页面样式规则（对齐官方 miuix demo）

> **一句话**：`composeP1` 下的每个页面都必须用**共享页面套件**搭，不许直接调 miuix 裸组件。
> 判定由 `android/app/src/test/kotlin/com/mutx163/qingyu/pages/ComposePageStyleGuardTest.kt` 机械执行，
> 每个域一份棘轮基线 `tool/compose_style_baseline/<域>.txt`。
>
> 建立日期：2026-10-28。起因：用户实测「好多页面各不一样」「对比 demo 一堆毛病」，
> 根因是共享封装早就写好了，但页面还在直接调裸组件，于是手感/滚动/圆角/轴线各写各的。

---

## 一、为什么是「规则 + 棘轮」，不是「写进文档请大家自觉」

2026-10-28 实测（`pages/` 下 60 个带返回键的页面）：

| 症状 | 实测 | 后果 |
|---|---|---|
| 裸 `LazyColumn`，不走 `QingyuPageList` | 42 页 | 没有末端轻震、没有过度滚动回弹、没有右侧滚动条 |
| `Column + verticalScroll` 当主滚动 | 8 页 | 非惰性列表，长列表逐项组合，卡 |
| 裸 `Card(`，绕过 `QingyuCard` | 27 页 | 可点卡片按下去**零反馈**；圆角被默认压成 16（设置组应 24） |
| 写死 `fontSize =` | 34 页 | 用户字重 / 系统粗体 / 字阶全失效 |
| 写死 `Color(0x…)` | 23 页 | 深色模式与主题色失效 |
| 自己拼分组标题 | 47 页 | 文字左缘对不齐官方那条 28dp 轴线 |

这些**都不是编译错误**，测试全绿、真机才看得出来 ⇒ 靠人记着写必然漏。
所以：**把正确行为设成默认值**（共享组件），**再用测试钉住不许绕开**。

---

## 二、七条规则

> 每条给：**必须怎么干** / **判定** / **为什么**。
> 规则编号 `R1…R7` 就是基线文件里那一列，报错时对号入座。

### R1 · 不许手搓顶栏行 → 官方 `TopAppBar` / `QingyuPageScaffold`

```kotlin
QingyuPageScaffold(title, onBack, smallTopBar = ...) { ... }   // 首选
// 或直接用官方 Scaffold + TopAppBar（大标题+scrollBehavior+接线三件齐，见 PageScaffoldGuardTest）
```

- **判定**：文件里有 `IconButton(onClick = onBack)`（手搓返回键）却**没有**任何官方 `TopAppBar` /
  `SmallTopAppBar` / `QingyuPageScaffold` → 违规。
- **为什么**：历史上返回键被手写进 `Row`/`Column`，于是图标、底色、位置各写各的（右箭头转 180°、
  透明底、20sp 手写标题三种）。官方 `TopAppBar` 与 `QingyuPageScaffold` 都是可接受的正解；
  真伪分歧只在「有没有官方顶栏」。
- **注意**：本规则曾是 `Small?TopAppBar`（正则写错，等于只匹配 `SmallTopAppBar`），2026-10-28 自查
  修正为现在这条——它不再因为一个页面直接用了官方 `TopAppBar` 而误报。

### R2 · 滚动容器 → `QingyuPageList`

```kotlin
QingyuPageList(
    innerPadding = innerPadding,
    scrollBehavior = scrollBehavior,   // 从骨架拿，接上顶栏折叠
) {
    item(key = "group") { /* 一组 = 一个 item */ }
}
```

- **判定**：
  - 出现 `LazyColumn(` 但**既没有** `QingyuPageList(` **也没有** `scrollEndHaptic` → 违规（裸 LazyColumn）；
  - 出现 `verticalScroll(rememberScrollState())` → 违规（非惰性列表）。
- **为什么**：官方配方是三件套 `scrollEndHaptic()` + `overScrollVertical()` + `nestedScroll(behavior.nestedScrollConnection)`，
  再配一条 `VerticalScrollBar`。少任何一件，手感与观感都与 demo 不同；
  `Column + verticalScroll` 还会把长列表的惰性组合丢掉。
- **豁免**：弹层/抽屉内部的短列表（不承载页面级滚动）、`QingyuPageList.kt` 自身。

### R3 · 卡片 → `QingyuCard`

```kotlin
QingyuCard(onClick = { … }) { /* 内容 */ }              // 普通卡片，圆角 16
QingyuCard(cornerRadius = QingyuCardDefaults.SettingsGroupCorner, onClick = …) { }
```

- **判定**：出现 `Card(`（前面不是 `Qingyu`）→ 违规。
- **为什么**：官方 `Card` 的 `pressFeedbackType` 默认 `None`、`showIndication` 默认 `false`
  ⇒ 能点的卡片按下去**什么都不发生**；圆角默认 16，而设置组在 Dart 侧是 24。
  `QingyuCard` 把「可点就自动 `Sink` 反馈 + 开指示」设成默认。
- **内边距**：包 `*Preference` 行时**不要**传 `insideMargin`（Preference 自带 16）；
  包普通内容时传 `QingyuCardDefaults.ContentInsideMargin`（否则贴边）。
- **豁免**：`components/QingyuCard.kt` 自身。

### R4 · 字号 → `MiuixTheme.textStyles.*`

```kotlin
Text(text = "标题", style = MiuixTheme.textStyles.body1, color = …)   // ✅
Text(text = "标题", fontSize = 15.sp, color = …)                     // ❌
```

- **判定**：页面文件里出现 `fontSize = <数字>.sp` → 违规。
- **为什么**：`fontSize` 绕过了 `MiuixTheme` 注入的字阶，**用户自定义字重、系统粗体、字阶调整全部失效**
  （`QingyuPageTheme` 已经把字阶注入进去了）。字阶取值见 `theme/QingyuTypography.kt`：
  main/paragraph/button 17 · body1 16 · body2/subtitle 14 · footnote1 13 · footnote2 11 ·
  title1 32 · title2 24 · title3 20 · title4 18。

### R5 · 颜色 → `MiuixTheme.colorScheme.*` 或 `Color(QingyuTheme.*)`

```kotlin
color = MiuixTheme.colorScheme.onBackground          // ✅ 主题感知
color = Color(QingyuTheme.secondaryText(dark))       // ✅ 自家色板
color = Color(0xFF999999)                            // ❌ 深色模式下必然错
```

- **判定**：页面文件里出现 `Color(0x` → 违规。
- **为什么**：写死色值在深色模式/换主题色后必然与周围不一致；`QingyuPageTheme` 已把自家色板桥进
  `MiuixTheme.colorScheme`，语义槽取色即可。语义槽对照表见 `docs/reference/miuix-api-mapping.md` §1。
- **豁免**：确实与主题无关的固定语义色（如危险色 `QingyuFixedTokens.DESTRUCTIVE`、图标彩豆），
  但**应当**改走 token 而不是字面量；要留在基线里必须在该行写明原因。

### R6 · 分组标题 → `QingyuSectionTitle`

```kotlin
QingyuSectionTitle("分组名")     // ✅ 官方 SmallTitle，自带 28dp 左缘
```

- **判定**：页面文件里出现**未限定的** `sectionLabel(`（调用或定义，即前面不是标识符或 `.`）
  却**没有** `QingyuSectionTitle(` → 违规。判据正则 `(?<![A-Za-z0-9_$.])sectionLabel\s*\(`，
  与 `ComposePageStyleGuardTest` / `compose-style-lint.ps1` 同一套（2026-11-02 收窄，
  见提交 `b15aad25`）。两个方向：
  - **会命中**：`private fun sectionLabel(text: String) { Text(...) }`——自拼 13sp + padding
    的分组标题，缺 `QingyuSectionTitle` 就红（咬合探针实测）；
  - **不命中**：`Color(QingyuTheme.sectionLabel(dark))`——这是主题语义取色
    （`sectionLabel` 槽是 `actionIcon` 的别名），不是自拼标题；带 `.` 前缀的成员访问一律不算。
- **为什么**：官方骨架的横向刻度是「页面 0 → Card 外边距 12 → Preference 自带 16 = 文字左缘 **28**」，
  而 `SmallTitle` 自带 28 正好对齐。自己写 `Text(13.sp) + padding(start = 4.dp)` 就对不齐这条轴线，
  整页看起来「行不齐」。

### R7 · 字重 → `MiuixTheme.textStyles.*.shiftWeight()`

```kotlin
// ✅ 在主题字阶上按设计增量加重
style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD)
// ❌ 绝对字重，会把主题的平移结果整个盖掉
style = MiuixTheme.textStyles.body1, fontWeight = FontWeight.SemiBold
```

- **判定**：页面文件里出现 `fontWeight = FontWeight.<字面量>` → 违规。
- **为什么**：`MiuixTheme.textStyles.*` 的每个槽位已经被 `buildQingyuTextStyles` 平移过
  （设计字重 + 用户字重 − 400 − 系统粗体增量）。页面再写绝对字重是**覆盖**，
  用户在设置里调「应用字重」时，这些文字不跟着变。
  2026-11-01 清理前页面层有 **311 处**这种写法。
- **写法**：增量取 `QingyuWeightDelta` 的具名常量：
  `LIGHT(-100)` / `MEDIUM(+100)` / `SEMIBOLD(+200)` / `BOLD(+300)` / `EXTRABOLD(+400)`；
  条件式写成 `shiftWeight(if (选中) QingyuWeightDelta.SEMIBOLD else 0)`。
  `SpanStyle` 用同名的 `shiftWeight` 扩展。
- **等价性**：默认设置（用户 400、系统未开粗体）下与旧写法的绝对值完全一致，
  由 `QingyuTextStylesTest` 的 7 条契约测试钉住。
- **豁免**：`pages/showcase/`（展厅故意展示绝对字重）；
  用户可配置的功能字重（如实时活动自己的字重选项，写法是 `fontWeight = weight` 而不是字面量，
  判据本来就不会命中）。

---

## 三、页面的标准配方（照抄）

```kotlin
@Composable
fun XxxPage(viewState: XxxViewState, onBack: () -> Unit) {
    QingyuPageScaffold(title = viewState.title, onBack = onBack) {
        // innerPadding / scrollBehavior 来自骨架
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
        ) {
            item(key = "group1") {
                QingyuSectionTitle("分组一")
                QingyuCard(
                    modifier = Modifier
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(bottom = QingyuSectionGap),
                    // 里面是 Preference → 不传 insideMargin
                ) {
                    SwitchPreference(title = "开关", checked = …, onCheckedChange = …)
                    ArrowPreference(title = "跳转", onClick = …)
                }
            }
            item(key = "group2") {
                QingyuSectionTitle("分组二")
                QingyuCard(
                    modifier = Modifier
                        .padding(horizontal = QingyuPageCardMargin)
                        .padding(bottom = QingyuSectionGap),
                    insideMargin = QingyuCardDefaults.ContentInsideMargin,  // 普通内容必须给
                ) {
                    Text(text = "任意内容", style = MiuixTheme.textStyles.body2)
                }
            }
        }
    }
}
```

要点：
1. **不要**自己 `Scaffold` + `TopAppBar`（R1）；
2. **不要**自己 `LazyColumn`（R2）；
3. **不要**自己 `Card`（R3）；
4. 字号/颜色一律走主题（R4/R5）；
5. 分组 = 一个 `item(key = "…")`，里面 `QingyuSectionTitle → QingyuCard → 多行`（R6）；
6. 页面横向留白由每个块自己带 12dp，**不要在 `contentPadding` 里加左右 16dp**
   （否则滚动条贴不到屏幕边缘、与 `SmallTitle` 的 28 轴线错开）。

---

## 四、棘轮基线怎么用（改页面的人看这一节）

### 4.1 基线在哪、谁拥有

```
tool/compose_style_baseline/
    about.txt      ← 拥有 about/ 这个域的人维护
    course.txt
    ...
```

一行 = 一处待还的债，格式 `<相对路径>|<规则>|<说明>`。**一个域一个文件**，
这样多个 Agent 并行时各改各的、不会撞车（共用一个文件必然冲突）。

### 4.2 三条纪律

1. **守卫只拦新增**：基线里已冻结的违规不会让测试变红；**新写的**违规会。
   ⇒ 新页面天然无法退回旧写法。
2. **修好一条就删一行**：基线里那行还留着、但代码已经不违规了，测试会报「**过期**」并变红。
   ⇒ 逼着人还债，不许只进不出。
3. **不许为了让提交变绿往基线里加行**（除非写清原因，例如「本页确实需要固定语义色」）。
   那是把守卫变成摆设，比没有守卫更糟。

### 4.3 怎么跑

```powershell
# 看自己域还欠哪些（不写文件）
pwsh -File scripts/compose-style-lint.ps1 -Domain statistics

# 修完之后重新生成自己域的基线（会自动删掉已修好的行）
pwsh -File scripts/compose-style-lint.ps1 -Domain statistics -Write

# 权威闸门（JUnit，CI 与 L2 都跑这个）
pwsh -File scripts/safe-gradle.ps1 :app:testComposeUiDebugUnitTest
```

> 只跑自己域：**不要**在别人的域还没修完时跑全量 `-Domain all -Write`，那会把别人的债
> 记到你头上、也让他们的过期判定失效。

---

## 五、边界与例外

| 情况 | 处理 |
|---|---|
| `components/` 下的共享套件自身 | 天然豁免（它就是被用来绕开裸组件的） |
| `pages/shell/`（壳、导航栏、玻璃坞） | 豁免 R1；它自带导航栏，不是子页 |
| `pages/showcase/`（组件展厅） | 豁免 R1/R3/R7——**它故意逐个展示官方裸组件与字重**，这正是它的用途 |
| 弹层/抽屉内部的短列表 | 豁免 R2（不承载页面级滚动） |
| 确实需要的固定语义色 | 允许，但要在基线行里写原因 |
| 与 Dart 原版行为冲突 | **Dart 是行为真相、demo 是样式真相**；冲突时行为从 Dart、样式从 demo，并在 KDoc 写明 |

---

## 六、相关文件

- 套件：`components/QingyuPageScaffold.kt`（骨架/返回键）· `QingyuPageList.kt`（滚动三件套+滚动条）·
  `QingyuCard.kt`（按压反馈+圆角）· `QingyuPageTheme.kt`（主题桥）·
  `QingyuTextStyles.kt`（字阶注入 + `shiftWeight` 强调）
- 守卫：`android/app/src/test/kotlin/com/mutx163/qingyu/pages/ComposePageStyleGuardTest.kt`
- 上游基准：`docs/reference/miuix-demo/CHEATSHEET-Demo范例.md` §3（页面骨架配方）、§3.4（分组节奏表）、
  §3.7（六个坑）；`docs/reference/miuix-demo/CHEATSHEET-玻璃与手感.md` §2（按压反馈）
- 既有同类守卫（写法参考）：`PageScaffoldGuardTest.kt`、`SettingsRowComponentGuardTest.kt`
- 色板对照：`docs/reference/miuix-api-mapping.md`
