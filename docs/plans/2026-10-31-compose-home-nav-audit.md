# Compose 首页与导航 · 重构质量审核（2026-10-31）

> 触发：用户「首页与导航页面审核一下重构质量，功能有没有复刻完，页面有没有一模一样做过来，把他完善好」。
> 审核对象：**壳级首页**（`PagesShellActivity` + `TimetableWeekPage` 顶栏/背景）+ **底部导航（玻璃坞）** + 顶栏「更多」菜单。
> 对照物：Flutter 正式版 Dart 源码（`lib/`）。唯一判据是 Dart 源码与 ARB；本仓旧文档只作线索。
> 周视图**页面本体**已在 `docs/plans/2026-10-29-compose-week-view-audit.md` 审过，本文不重复，只接它 §六 列在「本页之外」的那几项。

---

## 零、结论（先看这段）

**判定：这一轮把「首页与导航」从「看着像」推到了「设置改了就真的变」，但还不是一模一样。**

修之前有三处**功能失效**（用户改设置完全没反应，或点了看错内容），这一轮已修：

| # | 症状（修之前） | 根因 | 现状 |
|---|---|---|---|
| 1 | 设置里自定义底栏按钮，底栏**一点变化没有** | 底栏写死「课表 / 日程 / 任务 / 设置」四项，`glassDockActions` 谁都不读 | 读用户存档；最多 5 个；空表回退 Dart 默认「日课表 / 周课表 / 任务」 |
| 2 | 设置里自定义八宫格按钮，右上「更多」菜单**一点变化没有** | 菜单写死 8 个默认项（`TimetableMenuDefaults.entries()`） | 读 `homeGridMenuActions`；空表/只剩钉住项回退默认 8 项 |
| 3 | 点星期栏「周五」进日视图，看到的**永远是今天**；日程条目一条不出现、日期标题是自造中文串 | `c3.day` 分支写死 `LocalDate.now()`，意图字段 `pendingDayViewDayOfWeek` 写了没人读；壳里手拼 `DayViewPageData` | 意图经一次性 `consumeDayViewDayOfWeek()` 进入；数据装配改走模型层唯一实现 `DayViewDataAssembler` + `dayViewPageDataOf`；周数/可见星期也下传 |

顺带修掉的：首页壁纸整层（选了壁纸首页一片纯色）、底栏圆钮加课、`classic` 无坞形态、冷启动恢复上次停留的视图、底栏「无选中」态、环状导航（A→B→A 点了没反应）、槽宽不随槽数更新、宽屏药丸不居中。

**还差三层（按影响）**，都不是小修，已单列在 §四：

1. **下拉快捷导入**（Dart 首页的主要导入入口，Compose 里完全不存在）；
2. **情侣爱心按钮 + 覆盖层**（绑了情侣的用户看不到）；
3. **顶栏两颗常驻玻璃球 + 列表档菜单的形变/图标/二级「添加三选」/更新角标**。

**真机一条都没验**（agent 只能声明编译与 JVM 单测），见 §六。

---

## 一、审核方法

1. 独立审计员（只读）逐行读 Compose 壳与 Dart 首页/导航源码，产出 `.agents/compose-phase3/claims/_AUDIT-home-nav.md`（338 行，10 个维度、17 项死控件、P0/P1/P2 分级）；
2. Lead 复核：把「是缺口」和「已在途接上」分开，凡本轮已修的**重新用源码核一遍**，不采信审计员一行结论；
3. 修完按仓库门槛收口：L0 模块单测 → L1 编译闸门 → 样式守卫 → 咬合探针（改坏 → 红 → 还原 → 绿）。

---

## 二、这次改了什么（逐项，带文件）

### A. 底栏导航（玻璃坞）

| 项 | 改法 | 文件 |
|---|---|---|
| A1 槽位来源 | 新增纯模型 `HomeDockNavModel.resolveIds(raw, isNavigable)`：去重保序 → 丢掉没有去处的 id → 截断 5 → 空表回退 `['day','week','tasks']`（Dart `resolveGlassDockActionIds` 同口径） | `main: pages/shell/HomeDockNavModel.kt`（新） |
| A2 条目长相 | `HomeNavIcons.dockItem/menuItem`：id → 文案（`SettingsGlassDockEditorPage.labelOf`，ARB 逐字）+ 图标（官方 miuix 图标，找不到给 `More`，不给错暗示） | `composeP1: pages/shell/HomeNavIcons.kt`（新） |
| A3 点条目去哪 | 底栏条目 → 壳页面 id：`week`/`day` 是视图动作，其余转交 `shellTimetableMenuPageId` 那张唯一映射表；**底栏保留**（与 Dart 内嵌页同构），不是推一层 | `main: pages/PagesShellActivity.kt` |
| A4 圆钮加课 | `glassDockShowAddButton` / `glassDockButtonEntryId` 接上；圆钮用官方 `FloatingActionButton`（不自绘），绑定别的入口时按目录打开，残留 id 回退加课（Dart `handleRoundButtonTap` 同口径） | 同上 + `pages/shell/GlassDockNavigationBar.kt`（新增 `trailingContent` 槽） |
| A5 经典形态 | `homeNavigationForm == classic` ⇒ 不画底栏（Dart `home_chrome_spec.dart:78-80`） | `PagesShellActivity.kt` |
| A6 冷启动视图 | `timetableHomeViewMode` 恢复上次周/日/月；切视图写回存档 | 同上 |
| A7 无选中态 | `selectedIndex == -1` 时整栏不亮、不画指示器（Dart `soft_glass_tab_bar.dart:225,343`） | `GlassDockNavigationBar.kt` |
| A8 槽宽 | `tabWidthPx` 由「栏宽 + 槽数」派生（`derivedStateOf`），修掉 2026-10-28 审计 E6：槽数变了槽宽不更新 | 同上 |
| A9 宽屏居中 | 外层 Column 横向居中对齐，修掉旧审计 E5（480dp 屏右侧空 76dp） | 同上 |

> 开发壳的「页面索引」条目（`index`）只在**用户没自定义过底栏**时追加到末尾，一旦动过底栏就完全按存档来；拆壳（R2）时随 `PagesShellActivity` 一起删。

### B. 顶栏「更多」菜单

| 项 | 改法 | 文件 |
|---|---|---|
| B1 条目排列 | 新增纯模型 `HomeMenuNavModel.resolveIds`：去重保序、丢掉本仓没有去处的 id、空表**或只剩钉住项**回退默认 8 项（Dart `resolveHomeGridMenuEntries` 自愈口径） | `main: pages/shell/HomeMenuNavModel.kt`（新） |
| B2 三个视图统一 | `homeTopMenuItems(settings)` 成为唯一入口：周视图（`ShellWiring`）、月视图、日视图全部改读它 | `main: pages/ShellWiring.kt`、`main: pages/ShellPageIndex.kt` |
| B3 缺的映射 | 补齐 `addExam` / `addTask` / `addScheduleItem` / `more` / `quickSwitchTimetable` 五条目录 → 页面映射（此前在编辑器里能选，选了点了没反应） | `ShellWiring.kt` |

### C. 日视图入口（导航参数透传）

`c3.day` 分支重写：`initialDayOfWeek` 读点击意图、`visibleDays` 读「隐藏周末」、`totalWeeks` 读学期周数、数据装配交模型层、日程/考试/待办三类卡片接上目标页。意图用 `consumeDayViewDayOfWeek()` 一次性消费，避免下次从底栏进日视图时沿用上次点的那天。

### D. 首页壁纸 + 壁纸上的墨色

| 项 | 改法 | 文件 |
|---|---|---|
| D1 壁纸层 | 周视图新增最底层 `backdrop` 槽；有壁纸时页面底色改透明（Dart `scaffoldBackgroundColor = transparent` 同口径） | `pages/timetable/TimetableWeekPage.kt` |
| D2 快照 | 宿主从用户存档建不可变快照（取景倍数/对齐/模糊/解码宽已在模型层收口） | `app/TimetableHost.kt` |
| D3 墨色翻面 | 壁纸「顶部那条带」平均亮度 → 主题深/浅两套文字色（Dart 判据阈值 0.45）；亮度未知先按主题 | `TimetableHost.kt`、`TimetableTopBar.kt` |
| D4 渲染实现 | 解码/缓存/取景/模糊/亮度采样 | `pages/shell/HomeBackgroundModel.kt`、`HomeWallpaperBackdrop.kt`（新，home-bg 泳道） |

### E. 顺带修的两个存量缺陷

- `pushPage` 环状导航：A→B→A 以前静默无反应，现在弹回那一层。
- `TaskWiringGuardTest` 重写：底栏不再自带槽位渲染，「两个渲染点」这个前提被结构消灭，守卫改钉「主屏只能走 `ShellPageContent` + `rootPageIdFor`，不许直接构造页面宿主」。

---

## 三、逐项对照（Dart 行为 → 现状 → 判定）

完整 10 维对照见 `.agents/compose-phase3/claims/_AUDIT-home-nav.md` §一，这里只留结论行：

| 维度 | 判定 |
|---|---|
| 页面骨架与背景层 | **部分**：结构位次对，壁纸/状态栏遮罩/连续玻璃带本轮补了壁纸与墨色，玻璃带还没做 |
| 顶栏标题与切课表 | **部分**：文案/样式对；点标题仍是推整页管理页，不是原地快切弹层 |
| 右上「更多」菜单 | **部分**：形态分流（list/grid）与条目排列已对；列表档缺图标/形变/二级「添加三选」/更新角标 |
| 爱心（情侣）按钮 | **未做** |
| 壁纸与玻璃墨色 | **部分**：壁纸 + 顶栏墨色已通；星期栏/时间列墨色、区域背景、玻璃带未接 |
| 底栏导航 | **部分**：条目来源/圆钮/形态/无选中态已对；材质只有一档（Dart 有液态/磨砂/实体三档），圆钮不是玻璃 |
| 下拉快捷导入 | **未做** |
| 周↔日↔月动效 | **未做**（Dart `flight_*` 是独立动效子系统） |
| 返回栈与转场 | **已复刻**（官方 `NavTransitions.MiuixDefault`，不自研） |
| 无障碍与字号 | **部分**：底栏读屏已不重复念；应用字号/字重两个设置全 App 不生效（属主题层，不在本批） |

---

## 四、仍未做 / 已知差异（诚实清单）

| 级别 | 项 | 现状 | 为什么没在这次做 |
|---|---|---|---|
| P0 | **下拉快捷导入** | 无手势、无指示器；模型层会话状态机已在，生产 0 消费者 | 要接手势 + 指示器 + 导入会话，跨 `pages/timetable` 滚动容器与导入域，属单独一批 |
| P0 | **情侣爱心按钮 / 覆盖层** | 无按钮、无绑定态来源、无覆盖层 | 需要情侣域数据进首页 + 覆盖层渲染，跨域 |
| P1 | 顶栏两颗**常驻玻璃球** | 是行内 40dp 圆按钮，不是浮在内容上的玻璃球 | 玻璃球要跨采样层绘制（和坞同一套 backdrop 管线），与「玻璃带」一起做才不半成品 |
| P1 | 列表档「更多」菜单 | miuix 文本列表；缺行带图标、形变弹层、二级「添加三选」、更新角标 | 形变弹层属官方 `OverlayListPopup` 能力边界；图标/角标可后续单独补 |
| P1 | 底栏材质只有一档 | 有采样源就走液态，否则实体 | Dart 的「磨砂」档依赖全局模糊开关（`frostedAppearance` 未迁移），实体档也依赖它 |
| P1 | 圆钮不是玻璃 | 官方 FAB（实色主色） | 自绘玻璃圆钮属「自研形状」，需先按 `docs/reference/miuix-component-first-standard.md` 登记例外 |
| P1 | 点标题无快切弹层 | 推课表管理页 | 快切弹层（锚定列表 + 管理入口）是独立组件 |
| P1 | 玻璃带 / 状态栏遮罩 / 区域背景 | 未接 | `homePageHeaderBlurEnabled` 等键连模型都没有；属外观管线 |
| P1 | 应用字号 / 字重 | `appTextScale` / `appFontWeight` 全 App 0 消费者 | 属主题层（`QingyuPageTheme` + 密度覆盖），牵一发动全身 |
| P2 | 底栏遮挡滚动内容 | 页面滚动内容没有为坞留 bottom inset（Dart `glassDockContentScrollInset`） | 要页面级滚动内边距参数，跨全部页面 |
| P2 | 底栏尺寸口径 | 药丸上限 380 vs Dart 272；底部留白口径不同；圆钮 54 vs 56 | 需用户拍板（改尺寸会动已验收的观感） |
| P2 | 根层返回语义 | 非周视图按返回 = 回周视图；Dart 内嵌页按返回 = 退出 App | 需产品定夺（现在的行为更安全） |
| P2 | `GlassDockGeometry` 旧口径死代码 | 仍在（旧审计 E1），无生产调用 | 挪文件 + `@Deprecated` 是一次纯机械改动，留给下一批 |
| P2 | 八宫格瓷贴细节 | 8dp vs Dart 10dp、无更新角标、无等高空标题区 | 未逐像素核对 |
| P2 | 日视图待办勾选 | `onToggleTask` 未传（页面因此不画勾选框） | 需要仓储的写入口，本批不动仓储接口 |
| P2 | 日/月视图壁纸 | 只有周视图接了壁纸 | 日/月页数据结构不同，按页接 |

---

## 五、证据

> agent 只能声明「编译通过 / JVM 单测通过」；真机一律见 §六。

### 5.1 L0 模块单测（`pages/shell`，纯 JVM）

```
pwsh -NoProfile -File scripts/test-kotlin-module.ps1 -Module "pages/shell"
...
OK (115 tests)
```

含本轮新增：`HomeNavModelTest`（18 例）、`HomeBackgroundModelTest`（35 例，壁纸几何/解码/模糊换算/墨色阈值，期望值手推自 Dart）；
以及被重写的 `TaskWiringGuardTest`（5 例）、被本轮修复而转绿的 `DayViewWiringGuardTest`（5 例）。

> 中途一次红是别的泳道正在写 `ShellPageIndex.kt` / `TimetableHost.kt` 造成的瞬时状态；他们落定后一次全绿（同一命令、同一天）。

### 5.2 L1 编译闸门

```
pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin
BUILD SUCCESSFUL in 3m 7s
```

（本轮第一次 L1 是红的：`onOpenSchedule` 参数个数、`DayViewDataAssembler` 里一处未限定调用；修完复跑才绿，两次都在本条留痕。）

### 5.3 样式守卫（棘轮）

```
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain shell      → 合计 0 处
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain timetable  → 合计 9 处（与基线完全一致，未新增）
```

### 5.4 咬合探针（改坏 → 红 → 还原 → 绿）

| 改坏什么 | 期望 | 实际 |
|---|---|---|
| `HomeDockNavModel.MAX_SLOTS` 5 → 6 | 「超过五个槽位截断」红 | 红（`expected:<5> but was:<6>`），还原后绿 |
| 主屏分支里临时加一行 `TaskListHost(` | 「主屏不许自己构造页面宿主」红 | 红，还原后绿 |
| 主屏 `pageId = rootPageIdFor(...)` 改成写死 `"d2.taskList"` | 「必须把条目 id 交给映射表」红 | 红，还原后绿 |
| 壁纸模型 `CARD_GLASS_INK_FLIP_LUMINANCE` 0.2 → 0.5 | 卡片玻璃墨色那条红 | 红（`expected:<Dark> but was:<Light>`），还原后绿 |
| 壁纸 `drawRect` 改成「基础溢出 × 倍数」错误公式 | 几何两条红 | 红（`expected:<-750.0> but was:<-500.0>`），还原后绿 |

### 5.5 没做的验证（诚实清单）

- **L2（`:app:testDevDebugUnitTest`）本轮没跑完**：跑到一半撞上另一条泳道正在改 `DayViewPage.kt`（`QingyuCard` 未导入）而中断；architecture 守卫里与本次相关的两条
  （`ComposePageStyleGuardTest` 的 shell 域、`TaskWiringGuardTest`）已分别用样式 lint 与模块 L0 覆盖。
- 真机一条没验（§六）。

---

## 六、真机待验（必须由用户做，agent 不能声明）

装 `dev` 包后在首页逐条看：

1. **底栏条目**：设置 → 首页与导航 → 自定义底栏按钮，删掉一项 / 加一项 / 拖顺序，返回首页底栏应立刻跟着变；删到只剩 1 个、加到 5 个都试。
2. **圆钮**：打开「显示加课圆钮」，底栏右侧出现圆形按钮，点它进加课页；把圆钮绑定成别的入口，点它应打开那一页。
3. **经典形态**：把首页形态切「经典」，底栏应消失；再经右上「更多 → 设置」切回玻璃坞应恢复。
4. **更多菜单**：自定义八宫格（换个顺序、加「全部功能」），三个视图（周/日/月）的菜单内容应一致。
5. **日视图**：点星期栏「周五」，进去应是**周五**；当天有考试/日程时应出现对应卡片，点卡片进对应页。
6. **壁纸**：设置壁纸（浅色一张、深色一张），首页应立即出现壁纸；深色壁纸下顶栏标题应自动变白、浅色壁纸下应变深；调模糊/放大/对齐应跟着变。
7. **无选中态**：把「日课表」从底栏删掉，切到日视图，底栏应**整栏不亮**（而不是亮第一格）。
8. **环状导航**：A 页 → B 页 → 再从菜单点 A，应回到 A 页，不是没反应。

---

## 七、给下一个人的提醒

- **底栏条目现在是用户数据**：不要在任何地方再写死「四个槽位」。加一条新入口 = 在 `SettingsGlassDockEditorPage.catalog` 加条目 + 在 `shellTimetableMenuPageId` 加一行映射，两处缺一处就会被解析层当成「没有去处」丢掉。
- **菜单同理**：`homeTopMenuItems(settings)` 是唯一入口，三个视图都调它。
- **改 `GlassDockNavigationBar` 前先读它类注释的四层结构**，别加裁切、别把 `tabWidthPx` 改回 `onSizeChanged` 里算。
- **壁纸的墨色判据只有一个**：`HomeBackgroundModel.chromeInkPolarity`（阈值 0.45）。别在渲染层另写一套 0.5。
- **日视图数据只走 `DayViewDataAssembler`**：在壳里手拼 `DayViewPageData` 会重演「日程不出现、日期标题自造、周数越界」三件事，`DayViewWiringGuardTest` 会红。
