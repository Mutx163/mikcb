# Compose 弹窗 / 对话框 · 全参数审核（2026-11-02）

> 触发：用户「审核一次软件里面所有的弹窗，写的对不对，边距，字体颜色等等全部参数，全部审核」。
> 范围：`android/app/src/composeP1/kotlin` 下全部弹层/对话框（初版按三种官方入口扫到 40 个文件、77 处调用；查漏又补了 11 个自建/内联弹窗，见 §一之二）。
> 判据：官方 miuix 0.9.4 源码（`OverlayDialog.kt` / `DialogContentLayout.kt` / `OverlayBottomSheet.kt` / `BottomSheetContentLayout.kt` / `Button.kt`）、官方 demo（`docs/reference/miuix-demo/`）、Dart 原版（`lib/ui/hyperos/hyperos_dialog.dart` / `hyperos_sheet.dart` / `hyperos_miuix_spec.dart`）、上一轮弹层审核（`docs/plans/2026-10-30-compose-popup-audit.md`）、miuix 优先标准与例外登记、文案规则。
> 方法：6 组并行逐调用点读完整 composable → 每组一条独立复核（允许反驳）→ 一次查漏。**只读审核，未改任何文件；未跑 L1/L2，未上真机。**

---

## 复核结论（2026-11-02 晚回填；2026-11-03 二次下探，先读这段再看正文）

> 本节与两表新增的「回填 11-02」列，是 2026-11-02 晚的二次复核结果：5 组并行逐条重读**当前工作区代码**（含未提交改动）后回填。原条目一字未删，正文保留当时行号与口径备查；**行号已整体漂移，一律以回填列的当前行号为准**。**2026-11-03 起以本节计数为准**：晚间回填后又落地一批修复（`bcbc8ab6` 成就弹层等），逐条状态以两表回填列 + 11-03 追记为准。

### 总数

| 口径 | 条数 |
|---|---:|
| 表行总数（附表 120 + 查漏 18；一行含多个位置的按一行计） | **138** |
| 已不成立（代码已修，回填列写明现状与对应修复） | **126** |
| 仍成立（回填列已更新为当前行号；含登记过的已知债） | **11** |
| 部分成立（主问题已修、残留半条，回填列说明剩余） | **1** |

> 早间汇总曾按「65 仍成立 / 76 已不成立」通报；2026-11-02 晚间逐条回填的实测为 104 / 29 / 5。**2026-11-03 二次下探**：成就详情弹层 3 条（附表 110-112）由 `bcbc8ab6` 修掉（常驻组合退场 + per-id 语义色），计数更新为 107 / 26 / 5。**2026-11-03 第二批（app / components / timetable / sync 四域）**：又清 13 行（云备份详情组 ×4、解绑确认、WebDAV 连接弹层 ×2、同步冲突三键框、主题动作表、说明框、课表周页死 import），计数更新为 120 / 17 / 1。**2026-11-03 第三批（timetable 文案）**：`7aba9894` 清掉 `TimetableProfilesStrings` 中文常量对象（查漏 199），计数更新为 121 / 16 / 1。**2026-11-03 第四批（收尾）**：course 域 4 条经核实已由并行泳道修掉（`a150be39` 调课限高、`b5647157` 备注顶部、`2ce5679e` 周格白字、`4325e210` 周加减读屏——本批逐条对当前代码核实后回填），裸 `Popup` 由收尾批迁官方 `OverlayListPopup`（守卫 `CourseOverviewSortPopupGuardTest` + 咬合探针），计数更新为上表 **126 / 11 / 1**。**以本节 + 两表回填列的逐条状态为准。**

### 行号漂移规律

- **修过的文件漂移大**：`SettingsHost.kt` 自绘 `SettingsDialogFrame` 整段删除、拆成多个独立 `OverlayDialog` 函数（主题弹层区 +10~+30）；`TimetableProfilesPage.kt` 整页弹窗重构（中后段 +100~+150）；`AddCoursePage.kt` 周选择区（+100~+150）；`ExamPickerSheets.kt` 补徽章/日期行/取消按钮后普遍后移几十行；`CloudSyncPage.kt` 的 `SyncConflictDialog` 整体迁到 `CloudSyncControllerPage.kt`。
- **没动过的文件零漂移**：`CloudBackupDetailSheet.kt`（±0）、`CoupleTimetableSettingsPage.kt`（−1~−5）、`CoupleWebdavConnectSheet.kt`（0~−7）、`AchievementDetailSheet.kt`、`WeekSelectorSheet.kt`、`CourseOverviewPage.kt`、`TimetableWeekPage.kt`——仍成立条目恰好集中在这些文件。

### 已被哪几批修掉（简短对照）

| 域 | 主力修复 |
|---|---|
| settings | `9e001202` 六处弹层常驻；`d7463b14`+`af7c6711` 滑杆弹窗；`01b577fe` 确认删除标题；`3d1151ce`/`f5eafbb0` 末尾空白；`23d78f15` 滚轮 SEMIBOLD |
| 外观/主题桥 | `40c25bc9` 页面层不再重置主题档位；`QingyuPageTheme` 默认参数改继承 + `onSurface`/`onSurfaceSecondary` 桥接 |
| time_scheme | `79f5cedf`（弹层债 #1-#4）+ `1185e014`（#5-#11：内边距/动作排布/分享正文/chip/字阶） |
| exam | `d2637b73` `a8fb43e7` `fd1d07e5` `b05552bd` `f98e377e` `f5826ace` `38c7de30` `2618d5af`（星期按钮/徽章/限高/置灰/字号/分割线整批） |
| task | `f273129f` 常驻组合 + `ff28674c` 正文居中 + `ca8d802c` 间距 12dp |
| schedule（查漏裸卡 ×4） | 全部改官方 `OverlayDialog`；三份白字 `MiuixActionButton` 合并为 `ScheduleActionButton`；日期时间改滚轮（`8c51f888`） |
| import | `98b8477e` 配色组改底部弹层 + `400e34b3` 自定义调试删除确认横排 |
| transfer/export/about/showcase/diagnostics | `abdb222e` ICS 正文居中；`625302a3` 镜像弹窗取消键；`a7701c17` showcase；`ea21e4ed`+`32d7679c` 支持作者；`baeb8624` 关于弹层常驻；`661f5441` 内存统计常驻快照+日志框边距 |
| 课表管理 | 整页弹窗重构：原生 `Dialog` 清零，4 弹窗走 `OverlayDialog`、更多操作走 `QingyuSheet` |
| 云同步 | WebDAV 连接重写为 `QingyuSheet`；`SyncConflictDialog` 接上真实调用并改官方 `OverlayDialog` |
| statistics（11-03） | `bcbc8ab6` 成就详情弹层常驻组合退场 + 徽章按成就 id 取语义色（附表 110-112 三条清掉） |
| shell（WebDAV 接线） | `7f085ef3` 连接/测试挪 IO 线程 + 真状态接线 |
| 第二批（11-03）：sync | `f4f7a199` 云备份详情宿主常驻组合（附表 330-333 + 281）、解绑确认常驻 + 12dp（334/335）、WebDAV 连接弹层常驻 + 动作固定底部（336/337）、同步冲突三键框竖排（查漏 198） |
| 第二批（11-03）：app | `5d0ed9e5` 主题动作表改 ChoiceTile 行形态（附表 256）、说明框等宽 12dp（257） |
| 第二批（11-03）：timetable | `5f0a4e7e` 顺带清掉课表周页死 import（查漏 205）；守卫假红盲区由 `2d645db5` 修掉（S1D/S3/S4 判据整体先剥注释） |
| 第三批（11-03）：timetable 文案 | `7aba9894` `TimetableProfilesStrings` 对象清零（查漏 199）——22 条在用文案迁 `TimetableStrings`（12 复用 + 10 补录 ARB 既有键，零新增），10 条死成员删除，parity 对拍 + CJK 基线 36→4 |
| 第四批（11-03）：收尾 | course 域 4 条为并行泳道已修、本批逐条核实回填（`a150be39` 调课限高、`b5647157` 备注顶部、`2ce5679e` 周格白字、`4325e210` 周加减读屏）；裸 `Popup`（附表 273）迁官方 `OverlayListPopup`，守卫 `CourseOverviewSortPopupGuardTest` + 咬合探针 |

### 仍成立的 11 条速览（2026-11-03 第四批收尾后）

42dp 无标题空档 ×4（`CourseActionSheet` / `CourseNoteSheet` / `WeekSelectorSheet` / `AppearanceEditorHost`，等上游悬浮把手，拍板 #7）、学期滚轮抢手势（需真机）、选周结构分歧（按拍板 #5 保留）、输入自动聚焦 4 处未加（按拍板 #1 默认不加；课表管理一处已加待拍板）、`QingyuSheet` 标题动作贴边（潜在）/ IME 叠加（需真机+套件层，共享套件只记录不扩散）/ 官方字阶（按拍板 #2 接受）、ICS 菜单形态（按拍板 #8 保留结构，即「部分成立」那条）。~~裸 `Popup`（`CourseOverviewPage`）~~ → 已由收尾批迁官方 `OverlayListPopup`；~~调课列表 480dp / 备注顶部 16dp / 周格白字 / 周加/减无障碍~~ → 已由并行泳道修掉（`a150be39` / `b5647157` / `2ce5679e` / `4325e210`），收尾批逐条核实回填。明细见两表回填列。

### 材质对照（2026-11-03 弹窗材质批，对齐 NexioSchedule）

用户反馈「弹窗材质/圆角简陋」。取 `HaoZai000/NexioSchedule`（其 `miuix/` 目录是 miuix 的 fork，弹窗配方在我们同一个文件 `DialogContentLayout.kt` 里改）逐项对照：

| 项 | 我们（miuix-ui 0.9.4 上游 + 本仓桥） | NexioSchedule（fork） | 差异判定 |
|---|---|---|---|
| 布局骨架 | 手机贴底（BottomCenter）/ 宽屏居中，MaxWidth 420dp，outsideMargin 12dp，屏角圆角 coerceIn(32,48) | 完全一致（同一上游） | 无差异 |
| 圆角 | 屏角 −12dp，夹 32..48dp（贴底）；居中 32dp；官方 `cornerRadius` 参数可覆写 | 屏角 −12dp，下限 32dp（无上夹） | **实质一致**，不简陋 |
| 内边距 | 本仓口径显式 16dp（S1D 守卫） | 默认 24dp | 本仓更紧，是既定口径不是债 |
| 标题/正文字阶 | title4 Medium 居中 / body1 居中（官方） | 同（另换 MotionAwareText） | 实质一致 |
| 进出场 | 手机上滑入 / 260ms Decelerate 出；遮罩 300/250ms | 同 + 预测返回跟手 | 实质一致 |
| **表面材质** | `squircleSurface` **实心板**，底色 = `colorScheme.background`（亮 #F2F2F2 / 暗 #242424，与页面同色） | `drawBackdrop(vibrancy + blur + lens)` + 半透明压色（亮 0.78 / 暗 0.87）+ `edgeLight` 边缘高光 | **核心差异：玻璃分层 vs 实心平板** |
| 遮罩强度 | 官方默认亮 30% / 暗 60% 黑，全量绘制 | 同底 ×0.6 → 等效 **18% / 36%** | 我们重 ~1.7×，**本批已改**（见下） |

**「简陋在哪」一句话**：骨架（圆角/边距/字阶/动画）与对方同源无差距，差在**表面材质**——对方是「实时模糊玻璃 + 半透明压色 + 边缘高光」的分层表面，我们是与页面同色的实心平板，叠上偏重的遮罩，观感就「死板、简陋」。

**本批落地（一次生效，零性能代价）**：主题桥（`QingyuPageTheme` 亮/暗色板）显式映射 `windowDimming = Black.copy(alpha=0.18/0.36)`——对齐 Nexio ×0.6 软化档，全部弹层（Dialog/BottomSheet/Popup 共用此槽）遮罩同步变柔。守卫 `QingyuDialogMaterialGuardTest`（判据先剥注释）钉住两行，咬合探针（删行→红→还原→绿）过。

**玻璃分层方案（未落地，待拍板/待真机）**：弹窗表面玻璃有两条路——①像 Nexio 一样 fork `miuix-ui` 在 `DialogContentLayout`/`BottomSheetContentLayout` 内部接 `miuix-blur`（干净、跟手动画天然对齐，但改库=依赖升级/例外审批，Lead 专属）；②不 fork，用官方公开参数从外部拼（`OverlayDialog(cornerRadius=X, backgroundColor=半透明)` + `modifier` 里挂 miuix-blur 的 `drawBackdrop`）——可行但有两条代价：47 处 `OverlayDialog` 调用点要迁统一封装；`OverlayBottomSheet` 拖动位移经 graphicsLayer 施加、外部采样层拿不到内部偏移，**拖动时模糊区可能错位，必须真机验证**。仓内已有玻璃基建可复用（`QingyuPageScaffold.rememberQingyuBlurBackdrop` 页面级 backdrop、`components/liquid/` 折射）。在真机验证 + 审批前不动默认观感（「不要为了像而硬塞模糊」）。

**2026-11-03 追记：玻璃已选定方案并落地试点**（用户拍板「改库……先改一个看看效果」）。物理 fork 两条路（includeBuild / project 替换）都要求本地模块提供 miuix-ui 全部 API = 整库 vendor，违背「diff = 单文件级别、不整库搬」红线，故走「官方公开参数 + miuix-blur 官方模块」：`components/glass/GlassOverlayDialog.kt`（官方容器 + `cornerRadius=32dp` 与玻璃面同值锁定 + 半透明压色 亮0.78/暗0.87 + `drawBackdrop(colorControls 饱和度1.5 + blur 24dp, highlight=GlassStrokeMiddle*)`；无录像带/不支持 RuntimeShader/开关关 → 自动回落官方实心）+ `QingyuDialogGlass.enabled` 一键回退 + `QingyuPageScaffold` 以 `LocalQingyuPageBackdrop` 复用顶栏既有录像带（不新增图层录制）。**试点唯一调用点：加课页「删除课程确认」**；其余 46 处弹窗与全部底部弹层保持现状，守卫 `QingyuGlassDialogGuardTest` 钉调用点数=1 与开关默认；例外登记见 `miuix-component-first-standard.md` 第 5 条。遗留：进场动画期采样跟手、底部弹层拖动（暂不接玻璃）、低端机帧率——只能真机验证。



### 需拍板的 8 个决策点（2026-11-02 暂按「能不折腾就不折腾」定默认）

| # | 决策 | 两个选项的差异 | 当前默认 |
|---|---|---|---|
| 1 | 输入类弹窗自动聚焦 | 加=对齐 Dart `autofocus:true`，点开即弹键盘；不加=避免自动弹键盘干扰返回手势。现状分裂：课表管理新建/重命名已加 `FocusRequester`，主题命名/作息新建重命名/滑杆/镜像地址 4 处未加 | 不加；课表管理已加的一处是否回退待拍板 |
| 2 | 弹层标题/正文字阶 | 接受官方 `title4` 18sp Medium / `body1` 16sp（Medium 绕过用户字重平移）vs 套件自绘标题/正文对齐 Dart 17sp w400 / 14sp w400 | 接受官方，登记为已接受组件缺口 |
| 3 | 动作按钮间距 | 12dp（本仓 Dialog 口径，已大范围落地）vs 20dp（官方 demo） | 12dp |
| 4 | 危险操作配色 | 红底+`onError` 实心 vs 中性底红字（二选一全仓统一） | 红底 `onError`，已实质统一（恢复默认/删主题/课表管理清空删除/云备份删除均此式） |
| 5 | 加课选周结构 | 改回 Dart 全屏子页 vs 保留小对话框（正文已可滚、限高 0.72 屏） | 不动结构，保留对话框 |
| 6 | 解绑确认按钮颜色 | 按 Dart 改 primary 主色 vs 保留实心红（语义强化） | 保留红；10dp 间距待收 12dp（对齐类小修） |
| 7 | 无标题底栏 42dp 空档 | 等 miuix 提供悬浮把手参数 vs 改传 title 用官方 18sp 居中标题（偏离 Dart 左对齐 17sp） | 保留空档等上游 |
| 8 | ICS 导出动作菜单形态 | 改按钮锚点菜单/`QingyuSheet`（去标题去箭头，Dart 形态）vs 保留模态 `OverlayDialog`+`ArrowPreference`（箭头有「进入下一级」歧义） | 不动结构；边距/分割线已修 |

### 文档间矛盾（列出待确认，未擅自统一）

1. 台账 §9.8⑤「截至 HEAD 页面顶栏/弹层未接」与派工表 §五②「页面顶栏已接（`08246e26`）、弹层未逐项核」矛盾——按提交证据顶栏已接；本次只把台账该半句改对（弹层半句两处口径一致：均未逐项核）。
2. 台账 P3-E 批次行与 §9.3②「成就进场动画与详情弹层未搬」：`AchievementDetailSheet.kt` 现已存在（本报告附表 110-112 审的就是它），「详情弹层未搬」已过时；因属历史批次记录未改写，待确认是否补「已由后续批次搬入」注。
3. 拍板 #1 的「不加自动聚焦」默认与课表管理页已加自动聚焦的现状分裂（同上表 #1）。

---

## 零、结论（先看这段）

**没有发现会崩溃的异常；但找到 1 个会直接挡住功能的 P0（本报告口径：P0 = 功能被挡/数据风险），以及一批用户一眼能看出的 P1/P2。**

| 级别 | 数量（复核后） | 一句话 |
|---|---:|---|
| **P0** | **1** | 加课「自定义周」网格每行只显示第 1 格，后 4 格被压成 0 宽 |
| **P1** | **9** | 页面/弹层两套主题、自绘弹窗返回键关不掉、同色文字看不见、长内容被裁、双倍留白、危险色缺失 |
| **P2** | **55** | 主按钮默认灰、主题色槽没桥接、动作顺序/排布与 Dart 不一致、裸 Popup 等 |
| **P3** | **55** | 间距 8/10/12 不统一、正文左对齐、字重/字号差一档、自动聚焦、无障碍等 |

> 上表是初版三种入口的 120 条复核结果；另有**查漏补的 6 个 P1 / 7 个 P2 / 5 个 P3**（11 个自建/内联弹窗），见 §一之二，未并入上表。

### 最该先修的 9 件

1. **P0 · 加课自定义周网格**：`AddCoursePage.kt:815` 的 `Row` 里 5 个 `AddCourseWeekGridTile` 都没有 `weight`，而 tile 内部是 `Modifier.fillMaxWidth()`（`AddCourseWeekPickerTiles.kt:42-44`）⇒ 第一格吃掉整行，后四格宽度为 0。用户只能选到每行第 1 周。修法：tile 增加 `modifier` 参数，调用处传 `Modifier.weight(1f)`。
2. **P1 · 页面级主题桥把用户设置重置了**：`QingyuPageScaffold.kt:174` 与 15 个页面里的无参 `QingyuPageTheme { ... }` 会用默认 `isDark=跟随系统 / seedColor=null / 用户字重=400 / 字族=null / 字号倍率=1` 重新建一套主题；而壳层 `PagesShellActivity.kt:239` 已经按用户设置建过一套，弹层又默认挂在根 Scaffold 上。结果是**页面正文与弹层各用一套明暗/字体/主题色**：页面里改主题色、字重、字号或手动明暗不生效，弹窗却生效。修法：删掉这些页面级无参包装（壳已统一注入），或让 `QingyuPageTheme` 支持继承当前 `MiuixTheme`。
3. **P1 · 自绘模态框**：`SettingsHost.kt:922` 的 `SettingsDialogFrame` 用 `Box + Color.Black(0.45) + QingyuCard` 手搓「恢复默认 / RGB 取色」两个弹窗；没有 `BackHandler`，弹窗开着按返回键会退出设置页而不是关弹窗；也没有官方 `OverlayDialog` 的遮罩、进出动画、大屏/IME 行为。miuix 优先例外表里没有登记。
4. **P1 · 同色文字看不见**：`CoupleTimetableSettingsPage.kt:341`、`CoupleWebdavConnectSheet.kt:147/197` 用 `primarySurface` 当底、`primary` 当字；无 seed 时两者是同一个颜色，按钮标签完全不可见。
5. **P1 · 长内容不滚动 / 容器选错**：`ImportCommon.kt:499-545`（导入提醒）、`ImportCommon.kt:806-850`（配色组）、`AddCoursePage.kt:749-850`（选周；Dart 原版是全屏子页 + 可滚 ListView，Compose 改成了不可滚的小对话框）、`TimeSchemeManagementDialogs.kt:245-300`（被占用清单）、`DataTransferPage.kt:477-520`（传输预览）在小屏/大字号/内容多时会把标题或底部按钮裁掉。
6. **P1 · 双倍横向留白**：`AdvancedOptionsPage.kt:247`、`SettingsPageRenderers.kt:836`（官方默认 24 + 内容 8 = 32）、`AiImageCourseImportHost.kt:233`（16+16=32）、`IcsExportPage.kt:300`（16+16=32）、`SettingsHolidayHost.kt:527`（16+16=32）。目标是单边 16。
7. **P1 · 危险操作没染红**：`SettingsHost.kt:1631`（主题删除，默认灰实心）、`SettingsHost.kt:991`（恢复默认，灰底红字）、`CloudBackupDetailHost.kt:181`（云备份删除，默认灰）、`CloudBackupDetailSheet.kt:76`（删除，默认文字色）、`IcsExportPage.kt:349`（移除日历，默认灰）。
8. **P1 · 主操作默认灰**：全仓 20+ 处确认/主出口按钮只写了 `Button(...)`，miuix 默认是 `secondaryVariant` 灰底，看起来像禁用。典型：`SettingsHost.kt:862/909/1596/1715`、`AdvancedOptionsPage.kt:286`、`IcsExportPage.kt:378`、`ImportCommon.kt:429`、`TransferButton`（`DataTransferPage.kt:436`）、`CloudBackupDetailHost.kt:129/169`、`CourseFollowupSheets.kt:474/885`、`CourseNoteSheet.kt:265`、`SupportCreatorPage.kt:338`、`AddCoursePage.kt:877`、`LiveKeepAliveSettingsPage.kt:348`、`SettingsPageRenderers.kt:876`。
9. **P1 · 查漏补的 11 个自建/内联弹窗**：日程族 4 处、云同步 WebDAV 连接、课表管理 5 个原生 `Dialog` 现在要么只是页面里的一张 `QingyuCard`、**不是模态框**，要么绕开官方 `OverlayDialog`；`MiuixActionButton` 还是白字落在浅灰底上（`ScheduleListPage.kt:464`、`ScheduleDateRulePage.kt:534`、`AddScheduleItemPage.kt:741`）。详见 §一之二。

### 其余系统性问题

| # | 问题 | 影响面 | 代表位置 |
|---|---|---|---|
| S1 | 主按钮缺 `buttonColorsPrimary()` | 20+ 处 | 见上 |
| S2 | 危险操作缺 `textButtonColors(textColor=error)` 或 `buttonColors(color=error, contentColor=onError)` | 5+ 处 | 主题/云备份/日历/恢复默认 |
| S3 | 动作按钮间距 8 / 10 / 12 / 20 混用 | 全仓 | `TaskListPage.kt:296`（8）、`AddCoursePage.kt:544`（10）、`TimeSchemeManagementDialogs.kt:465`（10）、官方 demo 20 |
| S4 | 动作顺序/排布与 Dart 相反 | 导入预览、容量、作息 | `ImportCommon.kt:672`（覆盖在上、取消在下）、`ImportCommon.kt:785`（两动作竖排） |
| S5 | 主题桥没桥接 `onSurface` / `onSurfaceSecondary` | 所有底部弹层标题、所有 `summary=` 对话框正文 | `QingyuPageTheme.kt:141/154`：sheet 标题 #000（应 #333）、dialog summary #333（应 #999） |
| S6 | 裸 `androidx.compose.ui.window.Popup` 自拼菜单 | 1 处 | `CourseOverviewPage.kt:504`，例外表「待核」第一条 |
| S7 | 写死中文整句 | 2 个导入对话框 | `ImportCommon.kt:554`（en/ja/ko/zh-TW 用户看到中文） |
| S8 | 主题动作表把 ChoiceGroup 行做成 4 颗灰色实心按钮 | 1 处 | `SettingsHost.kt:1674`：Dart 是带图标的列表行，删除项危险色，「应用」不属于这张表 |
| S9 | 输入类弹窗不自动聚焦 | 2 处 | `SettingsHost.kt:1577`、`TimeSchemeManagementDialogs.kt:157`；注意 `SettingsPageRenderers.kt:815` 有「不抢焦点」的产品取舍，需拍板 |
| S10 | 退场动画：卡片/底栏的位移不播 | 多处 | 官方 `OverlayDialog` / `OverlayBottomSheet` 把 `DialogEntry` 的 `enterTransition`/`exitTransition` 显式设为 `None`，真正的内容动画在 `DialogContentLayout` / `BottomSheetContentLayout` 的 `LaunchedEffect(show)` 里；组件被父级 `if`/`when`/`?.let` 整棵移除时，`show` 从未变成 false，卡片/底栏的滑出/缩放不会播（遮罩层可能仍淡出）。另有一类：`show = state != null` + 正文用同一 state 判空，state 变 null 时正文先被清空，退场期间是空板（`TimeSchemeManagementDialogs.kt:149` 这类常驻组合、`LocationTimeMatchHost.kt:214`、`MemoryStatsPage.kt:300`）。 |
| S11 | `QingyuSheet` 底部让位与 `imePadding` 叠加 | 所有带输入框的底栏弹层 | `QingyuSheet.kt:104`：键盘弹出时可能多 24~40dp 空白，需真机 |
| S12 | 死代码 | 1 处 | `ImportCommon.kt:444` `ImportReplaceExistingDialog` 无任何调用点（实际走 `ImportPreviewDialog`），建议删 |
| S13 | 弹层守卫只拦 `OverlayBottomSheet`，不拦 `OverlayDialog` | 4 处对话框漏网 | `ComposeSheetGuardTest.kt:303`；`AdvancedOptionsPage.kt:247`、`SettingsPageRenderers.kt:836`、`DataTransferPage.kt:303/477` 没传 `insideMargin` |
| S14 | 弹层/对话框标题沿用官方 `title4 18sp + Medium`、正文 `body1 16sp`，Dart 是 17sp w400 / 14sp w400 | 全部弹层/对话框 | 官方组件硬编码字重，绕过 `shiftWeight`，用户字重/系统粗体对弹层标题不生效 |

### 做得对的（抽查确认，没有硬凑）

- `QingyuSheet` 套件的 16dp 侧边距、`bottomInset` 落点、`contentScrolls`/`contentPadsHorizontally` 的判据本身是对的；绝大多数调用点也用对了。
- 考试族 5 个选择弹层（`ExamPickerSheets.kt`）、任务课程/日期选择（`TaskPickerSheets.kt`）、作息时间/学期滚轮（`TimeSchemeHost.kt`、`SettingsSemesterHost.kt`）、内存统计（`MemoryStatsPage.kt`）、设置学期/节假日删除、任务/课表顶部菜单：边距、滚动、主按钮、危险色基本干净。
- 4 个课程/考试破坏性确认框（放弃修改、删除课程、删除考试 ×2）用「取消=灰实心、危险=红底 + onError」与 Dart 一致。
- 弹窗文案绝大多数来自 `*Strings` / ARB；除导入那一句外没有写死中文；没有写死 `fontSize` / `fontWeight`（展厅除外）；颜色绝大多数走 `MiuixTheme.colorScheme` / `Color(QingyuTheme.*)`。
- 深色模式取色基本正确；`onSurface`/`onSurfaceSecondary` 两个槽是唯一系统性缺口。

### 需要真机/你配合确认的

源码级审核不能替代真机。以下四类建议在 `dev` 变体上逐条看：

1. **返回键**：打开「恢复默认 / RGB 取色 / 主题命名 / 导入预览」后按系统返回，确认是关弹窗而不是退页面。
2. **矮屏/大字号**：加课选周、导入提醒（多条 warning）、作息使用情况、传输预览，确认底部按钮完整可见。
3. **键盘**：课程备注、WebDAV、主题命名、作息快速生成，确认底部按钮不被键盘顶出、底部不留双倍空白。
4. **换主题色/深色**：情侣课表/WebDAV 的次级按钮、加课周格选中态（白字是否可读）、sheet 标题与 dialog 正文的灰度。


---

## 一、建议修复顺序

### 批次 1 · P0 + P1（先保功能与可读性）

1. `AddCourseWeekPickerTiles.kt` 的 tile 增加 `modifier` 参数，`AddCoursePage.kt:815` 的 `Row` 里逐格传 `Modifier.weight(1f)`；补一条布局探针（截图或 Compose 单测断言每行 5 个子项宽度 > 0）。
2. `SettingsHost.kt:922` 的 `SettingsDialogFrame` 整体换成官方 `OverlayDialog`；`SettingsConfirmResetDialog` / `SettingsColorPickerDialog` 一起迁。换完确认返回键、遮罩、进出动画、大屏行为都回来了。
3. 情侣课表 / WebDAV 的 `primarySurface` 底 + `primary` 字改为「主操作 `buttonColorsPrimary()`、次操作 `buttonColors()`」；`SlotButton` 选中态用 primary、未选中用 secondary。
4. 给「导入提醒 / 配色组 / 加课选周 / 作息使用情况 / 传输预览」的正文加可滚动容器与限高，标题和动作按钮留在滚动区外。
5. 把 `AdvancedOptionsPage`、`SettingsPageRenderers`、`AiImageCourseImportHost`、`IcsExportPage`、`SettingsHolidayHost` 五处横向内缩收到单边 16。
6. 给主题删除、云备份删除、移除日历、恢复默认四处补危险色（实心红底 + `onError` 字，或中性底 + 红字，二选一但全仓统一）。
7. 把 `ScheduleListPage` / `ScheduleDateRulePage` 的三张内联卡改成 `OverlayDialog`；`MiuixActionButton` 的 `onPrimary` 白字配默认灰底改成 `buttonColorsPrimary()`（删除类用 `error + onError`）。

### 批次 2 · P2（一致性）

- 全仓扫一遍 `Button(` 确认/主出口：需要主操作的补 `buttonColorsPrimary()`；取消改 `TextButton`。
- `QingyuPageTheme.kt` 补齐 `onSurface` / `onSurfaceSecondary` 两个槽。
- 导入预览改为「取消 → 更新（推荐） → 覆盖（主）」；两动作横排，三动作竖排，间距 12dp。
- 主题动作表改回带图标的 Choice 行（或至少区分删除色），与 Dart 的动作集合对齐。
- `CourseOverviewPage.kt:504` 裸 `Popup` 换 `OverlayListPopup` / `OverlayDropdownMenu`，并从例外表「待核」移除。
- `TimetableProfilesPage.kt` 的 5 个原生 `Dialog` 迁到 `OverlayDialog`；`CloudSyncPage.kt:675` 的死代码 `SyncConflictDialog` 接上或删掉。
- `ImportCommon.kt:554` 的硬编码中文进 ARB 六语；顺手删死代码 `ImportReplaceExistingDialog`。
- 作息时间滚轮 180→220、补 `SEMIBOLD`；按钮文案「保存」→「确定」。
- `QingyuSheet.kt:104` 让底部让位感知 IME；真机确认键盘场景不再多一截空白。

### 批次 3 · P3（细节）

- 动作间距统一 12dp（或按官方 demo 20dp），不要再出现 8/10/12 三种。
- 对话框正文与 Dart 一样居中（短确认句）；长说明/清单保持左对齐。
- 输入类弹窗自动聚焦：先拍板 `SettingsPageRenderers.kt:815` 那条「不抢焦点」取舍，再统一。
- 无障碍：周次加减、清除等图标补 `contentDescription`。
- 主题命名/作息命名弹层加 `FocusRequester`；列表分割线去掉最后一条；选中态白字改 `onPrimary`。

---

## 二、方法与限制

- 本轮是**源码级**审核：逐调用点读完整 composable，对照官方 0.9.4 源码、官方 demo、Dart 原版和上一轮弹层报告；没有运行 L1/L2，也没有上真机。
- 上一轮报告（2026-10-30）已经修掉的 S1/S2/S3/S4 没有重复报；本轮报的是它没覆盖的「字体/颜色/对齐/动作排布/主题桥/滚动/状态」。
- 标记 `[已知债]` 的条目是上一轮已登记、本轮未修的：42dp 顶部空档、考试选周弹层矮屏裁切、滚轮与外层滚动抢手势、展厅豁免。它们仍应留在待办里，但不是本轮新发现。
- 「退场动画」这一条经过源码复核：`OverlayDialog` / `OverlayBottomSheet` 把 `DialogEntry` 的 enter/exit 设为 `None`，真正的卡片/底栏位移在 `DialogContentLayout` / `BottomSheetContentLayout` 里；父级整棵移除时 `show` 不会变 false，所以卡片/底栏的滑出/缩放不播（遮罩可能仍淡出）。不要把它简化成「完全没有动画」，也不要把常驻 `show = state != null` 的「空板退场」混为一谈。
- **Flutter 正式包**（`lib/` 下那套 HyperosDialog/HyperosSheet）不在本轮范围；`dev` 变体现在走的是 Compose，本轮按 Compose 审。需要的话可以再跑一轮 Flutter 侧。

---

---

## 一之二、查漏：初版清单之外的 11 个自建/内联弹窗

初版清单按 `OverlayDialog` / `QingyuSheet` / `Popup` 三种入口扫描，漏了两类：**自己写 `androidx.compose.ui.window.Dialog`**，以及**把确认卡直接当兄弟节点发出来、根本没包成弹窗**。最后一遍查漏代理把 `composeP1` 的 199 个 `.kt` 全量重扫，确认共漏 **11 个真实弹窗**（日程族 4、云同步 2、课表管理 5），全部绕开官方 miuix 弹层，弹层守卫也拦不到。下面这 18 条单独计，不并入上面的 120 条表。

| 位置 | 形态 | 问题 | 级别 | 回填 11-02 |
|---|---|---|---|---|
| `ScheduleListPage.kt:373` | 裸 `QingyuCard`，在页面 `Scaffold` 之后直接发出 | **不是模态框**：没有 `Dialog`/`Overlay` 容器、没有遮罩、返回键退的是整页；作为兄弟节点会叠在页面左上或落到页面下方。删除确认应改 `OverlayDialog`。 | **P1** | 已不成立：删除确认已改官方 `OverlayDialog`（现 `ScheduleListPage.kt:211`，遮罩+点外部/返回键关闭）。 |
| `AddScheduleItemPage.kt:645` | 裸 `QingyuCard`，重复日程范围确认 | 同上，不是模态；只有「本次 / 全部」两个动作，**没有取消**，用户改主意只能按返回，而返回会退掉编辑页并丢未保存内容。 | **P1** | 已不成立：改 `OverlayDialog`（现 `AddScheduleItemPage.kt:659-663`），返回/点外部只关弹窗不退页、草稿不再丢；「本次/全部」双出口无取消是注释写明的有意取舍。 |
| `ScheduleDateRulePage.kt:347` / `:486` | 裸 `QingyuCard`，规则新增/编辑 + 删除确认 | 同上，不是模态；编辑框有名称、两个日期、方案、开关等 6 组以上字段，却不限高、不可滚、不避键盘。 | **P1** | 已不成立：新增/编辑与删除确认均为 `OverlayDialog` 常驻、`show` 驱动（现 `ScheduleDateRulePage.kt:365` / `:523`）。 |
| `CloudSyncPage.kt:597` | 裸 `QingyuCard`，WebDAV 连接 | 同上，不是模态；Dart 是底部弹层（`showHyperosSheet` + `PickerSheetScaffold`），Compose 没有遮罩、点外部/返回不关、不避键盘。 | **P1** | 已不成立：重写为 `WebdavConnectSheet` → `QingyuSheet`（现 `CloudSyncPage.kt:621`），有遮罩、点空白/返回关闭。 |
| `TimetableProfilesPage.kt:577`（另 641/703/762/827） | 原生 `Dialog` + `QingyuCard`，外层 24dp + `insideMargin 20dp` | 单边内容缩进 **44dp**，是仓库对话框目标 16dp 的近三倍；还叠加平台 `Dialog` 自身内缩。 | **P1** | 已不成立：改官方 `OverlayDialog` + `insideMargin DpSize(16,16)`（现 `TimetableProfilesPage.kt:581-585`），44dp 缩进已消。 |
| `ScheduleListPage.kt:464` / `ScheduleDateRulePage.kt:534` / `AddScheduleItemPage.kt:741` | `MiuixActionButton` | `Button` 默认 `secondaryVariant` 浅灰底，文字却写死 `color = onPrimary`（白）⇒ **白字落在浅灰底上，几乎看不见**；删除按钮也不是红色。三份副本同一写法。 | **P1** | 已不成立：三份副本合并为共享 `ScheduleActionButton`，`primary` 分支用 `buttonColorsPrimary()`（现 `ScheduleActionButton.kt:48`），KDoc 记录了旧病。 |
| `TimetableProfilesPage.kt:573/637/699/758/823` | 5 个原生 `androidx.compose.ui.window.Dialog` + `QingyuCard` | 绕开官方 `OverlayDialog`：没有 miuix 遮罩、进出动画、大屏/IME 行为；平台 `Dialog` 默认宽度也比官方 420dp 窄；例外表无登记。更多操作菜单（Dart 是 `HyperosSheet` 底部弹层）也被做成居中 `Dialog`。 | P2 | 已不成立：原生 `Dialog` 清零；4 个输入/确认弹窗走 `OverlayDialog`、更多操作菜单改 `QingyuSheet` 底部弹层（现 `TimetableProfilesPage.kt:581/645/701/742/791`）。 |
| `TimetableProfilesPage.kt:602` | 新建/重命名/清空/删除动作 | 全部默认灰底：主操作没有 `buttonColorsPrimary()`；清空/删除是灰底红字，而 Dart `destructive` 是红底 + `onError`。 | P2 | 已不成立：主操作 `buttonColorsPrimary()`、清空/删除红底 + `onError`（现 `TimetableProfilesPage.kt:619/683/722-725/763-766`）。 |
| `TimetableProfilesPage.kt:76` | `object TimetableProfilesStrings` 本地中文常量 | 课表管理页（含 5 个弹窗）的标题/正文/按钮/无障碍文案全在这个对象里，不是 `ArbText`/ARB；en/ja/ko/zh-TW 用户会看到中文。 | P2 | 已不成立（2026-11-03 第三批）：`7aba9894` 对象清零——22 条在用文案迁入 main 侧 `TimetableStrings`（12 条复用既有 ArbText、10 条补录 ARB 既有键，零新增键、六语 ARB 未动），10 条零引用死成员删除；页面 31 处调用点改走 `TimetableStrings`，随 `TimetableStringsParityTest` 机械对拍；CJK 基线对应行 36→4（余 3 条开发预览示例数据 + 1 条「已激活」读屏键待后续入 ARB）。 |
| `CloudSyncPage.kt:637` | WebDAV 两个动作 | 「测试连接 / 连接并拉取」都是默认灰底，主操作没有强调色；下面还多一整行「取消」`TextButton`，Dart 只有底部两枚等宽实心按钮、靠下滑/返回关闭。 | P2 | 已不成立：测试连接=`buttonColors()` 次级、连接并拉取=`buttonColorsPrimary()` 主色，取消行已去掉（现 `CloudSyncPage.kt:659`/`:672`，`:599-602` 注释明确只有两枚等宽按钮）。 |
| `CloudSyncPage.kt:682` | `SyncConflictDialog` 裸卡片 | 三个动作塞进同一行（Dart 对 3 个动作是竖排）；**全仓没有调用点**，同步冲突实际由模型层自动裁决，用户永远看不到这个选择框。 | P2 | 已不成立（2026-11-03 第二批）：`f4f7a199` 三动作竖排整宽（取消→保留本机→使用云端）、正文居中，弹层常驻组合（现 `CloudSyncControllerPage.kt:229-280`，调用点 `:158-176`）。 |
| `ShellPageIndex.kt:1748` | WebDAV 宿主接线 | `testing = false, connecting = false` 写死，进度圈与按钮禁用永远不生效；`onTestConnection` / `onConfirm` 在主线程直接调同步网络方法，可能卡住界面。 | P2 | 已不成立：已接真状态 `sheetTesting`/`sheetConnecting`（现 `ShellPageIndex.kt:1752-1753`），连接/测试均走 `Dispatchers.IO`（`:1779`/`:1795`，`7f085ef3`）。 |
| `AddScheduleItemPage.kt:400` | 日期/时间字段 | 开始/结束日期、起止时间都是自由文本 `TextField`，没有 Dart 的 `HyperosPickerField` + 日期/时间滚轮弹层；用户得手输 `2026-10-01` 这类格式。 | P2 | 已不成立：日期/时间改滚轮选值行（`HyperosPickerField` 等价物，现 `AddScheduleItemPage.kt:795` 起，滚轮弹层 `:843`/`:940`；`8c51f888`）。 |
| `TimetableProfilesPage.kt:590` | 新建/重命名输入框 | 没有自动聚焦，Dart 明确 `autofocus: true`。 | P3 | 已不成立：新建/重命名已加 `FocusRequester` 自动聚焦（现 `TimetableProfilesPage.kt:575-579`/`:639-643`）。⚠ 与拍板 #1「默认不加自动聚焦」相左，是否回退待拍板。 |
| `AddScheduleItemPage.kt:654` | 手工弹窗标题 | 统一 `title4 + shiftWeight(BOLD)` 且左对齐；官方 `OverlayDialog` 是 `title4 Medium` 居中，Dart `sheetTitle` 约 17sp w600。 | P3 | 已不成立：改走官方 `OverlayDialog` 的 `title` 槽（居中 Medium，现 `AddScheduleItemPage.kt:659-661`）。 |
| `ShellPageIndex.kt:1752` | WebDAV 测试失败提示 | 写死中文 `"连接测试失败"`，没走 ARB；该行已在 CJK 基线冻结。 | P3 | 已不成立：改 `SyncStrings.localizeSyncError(...)` 本地化（现 `ShellPageIndex.kt:1786`，连接失败同款 `:1803`）；「连接测试失败」全仓 0 命中。 |
| `CloudSyncPage.kt:675` | `SyncConflictDialog` | 死代码（模型层 `SyncConflictDialogView` 仍存在）。 | P3 | 已不成立：渲染层死代码已删；模型层 `SyncConflictDialogView` 经 `conflictDialog()` 被 `CloudSyncControllerPage.kt:232` 真实调用（另有单测），不再是死代码。 |
| `TimetableWeekPage.kt:66` | `import androidx.compose.ui.window.Dialog` | 未使用的 import。 | P3 | 已不成立（2026-11-03 第二批）：死 import 已删并随 `5f0a4e7e` 落库（本会话先在工作区删除，并行泳道「分享按钮接导出链路」整文件提交时顺带带入；HEAD 无 `window.Dialog` import）。 |

**为什么这条重要**：用户问的是「软件里面所有弹窗」。这 11 处在真机上大概率表现为「点删除后页面左上角冒出一张卡」「按返回直接退页、草稿丢了」「按钮白字看不见」，和「弹窗」的预期差得很远；它们不在上一轮 70 处普查里，也不在本次初版正则里，属于**清单口径本身漏掉的面**。

**修法**：日程族 4 处、云同步 WebDAV 连接、课表管理 5 个原生 `Dialog` 全部改成 `OverlayDialog`（更多操作菜单改 `QingyuSheet`）；`MiuixActionButton` 统一改 `buttonColorsPrimary()`（删除/清空用 `error + onError`）；`TimetableProfilesStrings` 迁 ARB 六语；`ShellPageIndex` 的 WebDAV 接线补 `testing/connecting` 状态并挪到 `Dispatchers.IO`。

## 附：逐条发现清单

> `复核` 列：CONFIRMED=独立复核确认；PARTIAL=部分成立/已知债；EXTRA=复核时补的；UNVERIFIED=该组复核尚未返回（以审核员结论为准）。
> `回填 11-02` 列：2026-11-02 晚二次复核的逐条现状（成立/已不成立/部分成立 + 当前行号 + 现状与修复提交）；口径见顶部「复核结论」。

| 级别 | 位置 | 类别 | 问题 | 建议 | 复核 | 回填 11-02 |
|---|---|---|---|---|---|---|
| **P0** | `pages/course/AddCoursePage.kt:815` | layout-correctness | 自定义周网格每行 5 个格子都不带 weight，第一个 fillMaxWidth 独占整行，后 4 个被压成 0 宽，只能选到每行第 1 周 | 给每个格子加 weight：`Box(Modifier.weight(1f)) { AddCourseWeekGridTile(...) }`，或给 AddCourseWeekGridTile 增加 modifier 参数并传 `Modifier.weight(1f)`；顺手补一条布局探针（截图或 Compose 单测断言每行子项宽度 > 0）。 | CONFIRMED | 已不成立：每格已传 `Modifier.weight(1f)`、末排补等宽 Spacer（现 `AddCoursePage.kt:831-844`）。 |
| **P1** | `components/QingyuPageTheme.kt:69` | theme-consistency | 页面内层主题桥用默认参数重建，用户设置的主题色 / 应用字重 / 字族在页面正文里失效，而根级弹层仍按设置渲染 | 删掉页面级无参 `QingyuPageTheme {}`（壳已统一注入，见其 KDoc“重复但等价的一层”），或让 QingyuPageTheme 支持“继承当前 MiuixTheme”的默认值（CompositionLocal/sentinel），QingyuPageScaffold 不再二次包裹。改完用非默认主题色 + 非默认字重逐页对照顶栏与正文。 | CONFIRMED | 已不成立：默认参数改继承 `LocalQingyuPageAppearance.current`（现 `QingyuPageTheme.kt:110-114`，`40c25bc9`），页面不再重置主题档位。 |
| **P1** | `pages/export/IcsExportPage.kt:300` | spacing | 对话框 insideMargin 16 又塞进自带 16dp 内边距的 ArrowPreference ⇒ 动作文字单边 32dp（16+16 双倍），而分割线从 16dp 起、比文字短一截 | insideMargin 横向改 0（DpSize(0.dp, 16.dp)），分割线补 Modifier.padding(start = 16.dp)。 | CONFIRMED | 已不成立：`insideMargin` 横向归 0 + 分割线 `start = 16.dp`（现 `IcsExportPage.kt:295-309`）。 |
| **P1** | `pages/import/ImportCommon.kt:520` | layout-scroll | 这三个对话框的正文都直接塞进普通 Column：不限高、不可滚动；提醒条数与配色组行数都没有上界，小屏或大字号下 Title 与上方内容会被挤出屏幕且永远看不到 | 正文换成能滚动的容器（QingyuPageList / verticalScroll）并限高；标题与动作按钮留在滚动之外。 | CONFIRMED | 已不成立：正文 `LazyColumn` + `maxBodyHeight` 限高可滚、动作区在滚动外（现 `ImportCommon.kt:452-518`）。 |
| **P1** | `pages/import/warehouse/AiImageCourseImportHost.kt:233` | spacing | 内容自带 16dp 横向 padding，却仍让 QingyuSheet 再加 16dp ⇒ 单边 32dp 双倍留白，正文比弹层标题向右缩进一整格 | 传 contentPadsHorizontally = true（标题行由套件管，正文由这 16dp 管，单边正好 16）。 | CONFIRMED | 已不成立：已传 `contentPadsHorizontally = true`（现 `AiImageCourseImportHost.kt:232-244`）。 |
| **P1** | `app/SettingsHost.kt:926` | back-handling | 自绘模态框没接系统返回：弹窗开着时按返回键会退出设置页，而不是关掉弹窗 | 改用官方 OverlayDialog 承载；若暂不换，至少在弹窗可见时加 `BackHandler(enabled = true) { onDismiss() }`。 | CONFIRMED | 已不成立：自绘 `SettingsDialogFrame` 已删，恢复默认改官方 `OverlayDialog(show = pendingScope != null)`（现 `SettingsHost.kt:974`），返回/遮罩归官方容器。 |
| **P1** | `pages/course/AddCoursePage.kt:757` | structure-divergence | Dart 原版这个选择器是全屏子页（Dialog.fullscreen + HyperosSubpage + 可滚 ListView），Compose 移植成了小号 OverlayDialog，整页结构、滚动与返回方式都变了 | 按 Dart 改成全屏选择页（复用现有子页壳/返回栈），或至少在 QingyuSheet 内提供可滚正文；不要继续用无滚动的小 OverlayDialog。 | EXTRA(复核补) | 成立：仍是 `OverlayDialog` 小弹窗（现 `AddCoursePage.kt:762-765` 注释自认结构分歧）；滚动已补（见下方同位置 P2 行），按拍板 #5 保留结构。 |
| **P1** | `pages/sync/CoupleTimetableSettingsPage.kt:341` | contrast | 次级动作按钮用 primarySurface 填底、primary 染字，而两者在无 seed 时是同一个颜色，标签完全不可见；主操作又用默认灰，主次颠倒 | PRIMARY 改 ButtonDefaults.buttonColorsPrimary()；SECONDARY 改 ButtonDefaults.buttonColors()（灰底深字，对应 Dart HyperosButtonVariant.secondary）。若确要 tonal，用 primary.copy(alpha=0.12f) 之类真正提亮的底，绝不能用 primarySurface 配 primary 字。 | CONFIRMED | 已不成立：PRIMARY→`buttonColorsPrimary()`、SECONDARY→`buttonColors()`，KDoc 明令禁用 primarySurface+primary 同色组合（现 `CoupleTimetableSettingsPage.kt:340-343`）。 |
| **P1** | `pages/sync/CoupleWebdavConnectSheet.kt:147` | contrast | 「测试连接」的 tonal 配色同样是 primary 字配 primary 底，两项都填好后标签变成同色不可见 | 改为 ButtonDefaults.buttonColors()（次级），主按钮才用 buttonColorsPrimary()。 | CONFIRMED | 已不成立：测试连接已改 `buttonColors()` 次级灰底（现 `CoupleWebdavConnectSheet.kt:144`）。 |
| **P1** | `pages/sync/CoupleWebdavConnectSheet.kt:197` | contrast | 未选中槽位按钮是 primary 字配 primary 底（同色，字看不见）；选中槽位反而用默认灰，强调与 Dart/Kdoc 完全相反 | selected 用 ButtonDefaults.buttonColorsPrimary()，unselected 用 ButtonDefaults.buttonColors()。 | CONFIRMED | 已不成立：选中 `buttonColorsPrimary()`、未选中 `buttonColors()`（现 `CoupleWebdavConnectSheet.kt:193-197`）。 |
| **P2** | `components/QingyuPageTheme.kt:141` | colors | 底部弹层标题取 onSurface，主题桥没有桥接该槽 ⇒ 亮色下是纯黑 #000000，而同族 OverlayDialog 标题和 HyperOS 口径是 #333333 | 在 qingyuLightColors / qingyuDarkColors 各补一行 `onSurface = Color(QingyuTheme.primaryText(dark = false/true))`，同时修好底部弹层标题与 TopAppBar 标题。 | CONFIRMED | 已不成立：两块色板均已加 `onSurface = Color(QingyuTheme.primaryText(...))` 桥接行（现 `QingyuPageTheme.kt:200`/`:229`）。 |
| **P2** | `components/QingyuPageTheme.kt:154` | colors | 对话框正文取 onSurfaceSecondary，主题桥没有桥接该槽 ⇒ 亮色是 80% 黑（≈#333），而 Dart / 本仓次级文字是 #999999 | 在 qingyuLightColors / qingyuDarkColors 补 `onSurfaceSecondary = Color(QingyuTheme.secondaryText(dark = …))`；若不想影响 NumberPicker 的未选中字色，也可在 OverlayDialog 调用点统一传 `summaryColor = Color(QingyuTheme.secondaryText(dark))`。 | CONFIRMED | 已不成立：两块色板均已加 `onSurfaceSecondary = Color(QingyuTheme.secondaryText(...))` 桥接行（现 `QingyuPageTheme.kt:201`/`:230`）。 |
| **P2** | `pages/export/IcsExportPage.kt:293` | form | 分享/保存被做成带标题的模态 OverlayDialog + 两行带右箭头的 ArrowPreference；Dart 原版是按钮锚点菜单（无标题、带图标），右箭头也会被读成“进入下一级”而不是“执行动作” | 改用 QingyuSheet（或官方 OverlayListPopup / OverlayDropdownMenu）承载两个动作，去掉标题与右箭头。 | CONFIRMED | 部分成立：单边 32dp 与分割线已修（现 `IcsExportPage.kt:295-309`）；仍是带标题模态 + `ArrowPreference`，按拍板 #8 保留结构。 |
| **P2** | `pages/export/IcsExportPage.kt:349` | button-variant | 「移除已同步的日程」是破坏性确认（Dart destructive: true），但确认按钮没有任何危险色，用户看不出这一下是删除 | ConfirmRow 增加 destructive 参数，确认按钮传 textButtonColors(textColor = Color(QingyuTheme.error(dark)))。 | CONFIRMED | 已不成立：`ConfirmRow` 已传 `destructive = true` 染红（现 `IcsExportPage.kt:319-369`）。 |
| **P2** | `pages/export/IcsExportPage.kt:378` | button-variant | 确认按钮用默认灰底 Button，没有主操作强调色；取消是 TextButton、确认是默认灰实心 Button，既不是官方“双 TextButton + 主色字”也不是 Dart 的“双实心 + 主色底” | 确认按钮改用 TextButton + textButtonColorsPrimary()（危险场景见下一条），不要在同一个 Row 里混用 TextButton 与默认实心 Button。 | CONFIRMED | 已不成立：双等宽、取消 `TextButton`、确认危险场景染红（现 `IcsExportPage.kt:372-400`）。 |
| **P2** | `pages/import/ImportCommon.kt:429` | button-variant | 「主」按钮没传 buttonColorsPrimary()，渲染成 miuix 默认次级灰底；「次」按钮用 surfaceVariant 作底，深色下与对话框底完全相同（#242424）而“消失”，浅色下白底蓝字反而比灰底主按钮更醒目 | primary 分支传 ButtonDefaults.buttonColorsPrimary()；secondary 分支改用与对话框底有层次的 token 并配 onSecondaryVariant 字色。 | CONFIRMED | 已不成立：primary→`buttonColorsPrimary()`（现 `ImportCommon.kt:447`）；secondary=surfaceVariant 底 + primary 字，注释对齐 Dart `HyperosButtonVariant.secondary`（`:437-440`）。 |
| **P2** | `pages/import/ImportCommon.kt:530` | actions | 提醒对话框只有一个「继续导入」按钮，缺 Dart 原版并列的「取消」动作，用户只有点遮罩/返回键才能退出 | 补一枚「取消」按钮调用 onDismiss，并按两动作横排（见同一文件的排列问题）。 | CONFIRMED | 已不成立：补「取消 + 继续导入」双动作横排 12dp（现 `ImportCommon.kt:500-516`）。 |
| **P2** | `pages/import/ImportCommon.kt:672` | consistency | 预览确认卡把主操作「覆盖导入」放最上、取消放最下，动作顺序与 Dart 完全相反；竖排间距 8dp 也比 Dart 的 12dp 紧 | 顺序改为 取消 → 更新（推荐） → 覆盖导入（主），Spacer 改 12dp。 | CONFIRMED | 已不成立：顺序改「取消 → 更新（推荐） → 覆盖（主）」竖排 12dp（现 `ImportCommon.kt:676-698`）。 |
| **P2** | `pages/import/ImportCommon.kt:785` | actions | 只有两个动作时仍竖排整宽（且主操作在上、取消在下），Dart 与官方 demo 都是两枚等宽按钮横排、主操作在右 | 两动作改成 Row + 各 Modifier.weight(1f) + 12dp 间隔，取消在左、主操作在右。 | CONFIRMED | 已不成立：「本地没课」两动作分支改 `Row` + `spacedBy(12.dp)` 等宽横排、取消在左主在右（现 `ImportCommon.kt:699-721`，`1d7f346f`）。 |
| **P2** | `pages/import/ImportCommon.kt:822` | form | 配色组选择被做成对话框里 7 张可点的嵌套 QingyuCard，且没有 Dart 原版的色块预览；选中标记只是次级灰的「✓」，每行还带一个指向下一级的右箭头 | 改成底部选项列表（QingyuSheet）或至少一张 QingyuCard + RadioButtonPreference；每行补该组色块预览，选中态用主色，去掉右箭头。 | CONFIRMED | 已不成立：改底部弹层 + 逐行色点预览 + 主色勾、清单限高可滚（现 `ImportCommon.kt:815-850`，`98b8477e`）。 |
| **P2** | `pages/import/warehouse/AiImageCourseImportHost.kt:252` | layout-scroll | 内容里有 LazyColumn（QingyuPageList）却未传 contentScrolls = true，套件又在外层套了一层 verticalScroll，内外两层竖向滚动抢手势，底部让位落点也与契约不符 | contentScrolls = true，并在列表之后用 scope 的 bottomInset 补 Spacer。 | PARTIAL | 已不成立：已传 `contentScrolls = true`，列表后 `Spacer(bottomInset)`（现 `AiImageCourseImportHost.kt:245-275`）。 |
| **P2** | `pages/import/warehouse/WarehouseCustomDebugHost.kt:126` | button-variant | 删除确认的两个动作竖排整宽、都用 surfaceVariant 作底；深色下该底与对话框底同为 #242424，按钮边界消失，取消按钮字色还用了 40% 透明的 onSurfaceVariantActions | 改 Row + 各 weight(1f) + 12dp 的两枚 TextButton；删除用 textButtonColors(textColor = error)，取消用默认 textButtonColors()。 | CONFIRMED | 已不成立：`Row` + 等宽 `TextButton`、删除染 error、`shownDelete` 保退场渲染（现 `WarehouseCustomDebugHost.kt:108-178`，`400e34b3`）。 |
| **P2** | `pages/showcase/MiuixShowcaseSubpages.kt:744` | buttons | 确认对话框的「确定」用默认灰 Button，没有主操作强调色；取消用 TextButton，既非官方配方也非 Dart 配方 | 给确认按钮加 `colors = ButtonDefaults.buttonColorsPrimary()`（文件已 import ButtonDefaults），或按官方 demo 改成两个 TextButton、确认键用 textButtonColorsPrimary()。 | CONFIRMED | 已不成立：确定按钮已传 `buttonColorsPrimary()`（现 `MiuixShowcaseSubpages.kt:731-754`，`a7701c17`）。 |
| **P2** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:275` | actions-layout | 两个动作被竖排成两条整宽按钮，Dart 同名弹层是横排等宽两颗、间距 12dp。 | 改为 Row { TextButton(weight(1f)); Spacer(12.dp); TextButton(weight(1f), primary) }，并把 8dp 间距统一到 12dp。 | CONFIRMED | 已不成立：`Row` + `spacedBy(12.dp)` + `weight(1f)` 横排等宽（现 `TimeSchemeManagementDialogs.kt:297-316`，`1185e014`）。 |
| **P2** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:338` | layout-overflow | 使用情况对话框只有清单区限高 380dp，头部与「关闭」按钮固定且整框不可滚，短屏上关闭按钮会被压缩/裁掉。 | 把清单改成 weight(1f) 或屏高比例，或让整个 body 一起滚动并给对话框一个整体最大高度；「关闭」固定在滚动区外。 | CONFIRMED | 已不成立：清单限高改屏高×0.42，「关闭」仍固定滚动区外，矮屏不再顶掉（现 `TimeSchemeUsageSheet`）。 |
| **P2** | `pages/time_scheme/TimeSchemeQuickGenerateSheet.kt:314` | layout-keyboard | 键盘弹起时字段列表会吃掉全部剩余高度，底部「取消/生成」被挤出可视区。 | 给 LazyColumn 加 Modifier.weight(1f, fill = false)（或把字段区整体包进带 weight 的滚动容器），让底部按钮行优先获得固定高度。 | CONFIRMED | 已不成立：字段区 `LazyColumn` `weight(1f, fill = false)`，按钮行始终在屏内（现 `TimeSchemeQuickGenerateSheet.kt:317-322`）。 |
| **P2** | `pages/transfer/DataTransferPage.kt:303` | spacing | [已知债] 两个对话框都没传 insideMargin，沿用 miuix 默认 24dp，与本仓/Dart 的 16dp 口径不一致 | 补 insideMargin = DpSize(16.dp, 16.dp)（两处内容都无自带横向 padding，合计正好 16）。 | PARTIAL | 已不成立：两弹窗均传 `insideMargin = DpSize(16,16)`（现 `DataTransferPage.kt:309`/`:494`）。 |
| **P2** | `pages/transfer/DataTransferPage.kt:436` | button-variant | TransferButton 的 primary 分支没传 buttonColorsPrimary()，主操作渲染成 miuix 默认次级灰底，两个对话框标出的“主操作”没有强调色 | primary 分支传 colors = ButtonDefaults.buttonColorsPrimary()。 | CONFIRMED | 已不成立：primary 分支已传 `buttonColorsPrimary()`（现 `DataTransferPage.kt:421-457`）。 |
| **P2** | `pages/transfer/DataTransferPage.kt:487` | layout-scroll | 导入预览正文可能很长（4 行头信息 + merge/overwrite 两份差异摘要），对话框不限高也不可滚动，小屏/大字号下正文会被裁掉 | 正文套 verticalScroll / LazyColumn 并限高，动作区固定在下。 | CONFIRMED | 已不成立：正文 `LazyColumn` + `heightIn(max = 0.45 屏)` 可滚，动作区固定（现 `DataTransferPage.kt:489-518`）。 |
| **P2** | `android/app/src/test/kotlin/com/mutx163/qingyu/pages/ComposeSheetGuardTest.kt:303` | guard-gap | 弹层守卫只匹配 OverlayBottomSheet，OverlayDialog 的 S1 完全没被守卫覆盖；4 处对话框仍缺 insideMargin，单边 24/32dp | 给守卫加 OverlayDialog 分支（要求显式 insideMargin=16dp，或收一个 QingyuDialog 套件统一给 16dp），并修上述 4 处；AdvancedOptionsPage/SettingsPageRenderers 用 DpSize(8.dp,24.dp)，DataTransferPage 两处用 DpSize(16.dp,16.dp)。 | EXTRA(复核补) | 已不成立：守卫补 `OverlayDialog` 分支（S1D：调用须显式传 `insideMargin`，showcase 豁免，哨兵测试同步加），全仓 47 处仅 `pages/course/ClassAlarmSheet.kt` 1 处存量钉进 `tool/compose_sheet_baseline/course.txt`（course 泳道 `da42188c` 已还）；咬合探针两条都红过（摘 `ImportCommon.kt` 一处 insideMargin → 新增必红；删基线行 → 过期必红），复绿 390 测试全过。2026-11-03 补假绿盲区：判据原为裸 `contains`，实参区**注释**写了 insideMargin 会放行——已改「剥注释（字符串感知）+ 命名参数 `\binsideMargin\s*=` 匹配」，专用钉子测试 + 咬合探针（跳过剥注释 → 钉子测试红）过，409 例绿。 |
| **P2** | `app/SettingsHolidayHost.kt:527` | spacing | 弹层横向内缩叠成 32dp：套件已给 16，分区标题/删除按钮/按钮行/滚轮行又各自加 16 | 保留套件的 16、删掉这些行内额外的 horizontal=16；或改成根 Column 统一 16 + contentPadsHorizontally=true 并删掉行内 16。 | PARTIAL | 已不成立：改 `contentPadsHorizontally = false`，不再另补横向内缩（现 `SettingsHolidayHost.kt:374`）。 |
| **P2** | `app/SettingsHost.kt:815` | exit-animation | 六处弹层把 show 写死为 true、靠在父级条件里移除组件来关闭，关闭时退场动画全部不播 | 弹层常驻组合，用状态驱动 show（如 remember 一个可空状态并传 `show = state != null`）；onDismiss 只改状态，必要时在 onDismissFinished 里做清理。 | CONFIRMED | 已不成立：六处弹层常驻、`show` 状态驱动（现 `SettingsHost.kt:629/652/975/1043/1607/1656` 等，全文件无 `show = true`；`9e001202`）。 |
| **P2** | `app/SettingsHost.kt:862` | button-variant | 确认按钮用默认灰色 Button（secondary），与 Dart/同族时间弹层的 primary 不一致，读起来像禁用 | 加 `colors = ButtonDefaults.buttonColorsPrimary()`。 | CONFIRMED | 已不成立：已传 `buttonColorsPrimary()`（现 `SettingsHost.kt:885`）。 |
| **P2** | `app/SettingsHost.kt:909` | button-variant | 唯一动作是右对齐的默认灰色小按钮；对话框主操作应为强调色 | 至少加 `colors = ButtonDefaults.buttonColorsPrimary()`；更贴官方可改成主操作 TextButton + textButtonColorsPrimary()。 | CONFIRMED | 已不成立：唯一动作已补 `buttonColorsPrimary()`（仍右对齐，现 `SettingsHost.kt:933`）。 |
| **P2** | `app/SettingsHost.kt:922` | miuix-first | 恢复默认/选色弹窗是自绘遮罩 + QingyuCard 手搓对话框，绕开官方 OverlayDialog，且未登记 miuix-first 例外 | 换成 `OverlayDialog(insideMargin = DpSize(16.dp, 16.dp))`；若确实必须自绘，补进 docs/reference/miuix-component-first-standard.md 的例外登记。 | CONFIRMED | 已不成立：恢复默认（现 `SettingsHost.kt:974`）与 RGB 选色（`:1042`）均改官方 `OverlayDialog` + 16dp（`:1022` 注释记 2026-11-02 迁移）。 |
| **P2** | `app/SettingsHost.kt:991` | danger-color | 恢复默认（危险操作）的确认按钮是灰底 + 红字，不是 Dart 的红底 + onError，也不是“只染字”的文字按钮 | 改成 `ButtonDefaults.buttonColors(color = Color(QingyuTheme.error(dark)), contentColor = Color(QingyuTheme.onError(dark)))`，或按 S3 用文字按钮只染字。 | CONFIRMED | 已不成立：红底 + `onError` 字，注释明写「不再用灰底+红字」（现 `SettingsHost.kt:1003`）。 |
| **P2** | `app/SettingsHost.kt:1596` | button-variant | 主题命名确认按钮是默认灰色 Button，Dart 确认按钮是 primary | 加 `colors = ButtonDefaults.buttonColorsPrimary()`。 | CONFIRMED | 已不成立：已传 `buttonColorsPrimary()`（现 `SettingsHost.kt:1638`，空名禁用逻辑保留）。 |
| **P2** | `app/SettingsHost.kt:1631` | danger-color | 删除按钮是默认灰色实心，完全没染危险色；Dart destructive 变体是红底 + onError 字 | `ButtonDefaults.buttonColors(color = Color(QingyuTheme.error(dark)), contentColor = Color(QingyuTheme.onError(dark)))`（需 isSystemInDarkTheme）。 | CONFIRMED | 已不成立：`buttonColors(color = error, contentColor = onError)`（现 `SettingsHost.kt:1676`）。 |
| **P2** | `app/SettingsHost.kt:1674` | consistency | 动作表把四项都画成整宽灰色实心按钮；Dart 是 ChoiceGroup 列表行，删除项带危险色图标，且“应用”属于另一个预览弹层 | 改用官方 preference/choice 行（或至少用 TextButton/危险色区分删除），并与 Dart 的动作集合对齐。 | CONFIRMED | 已不成立（2026-11-03 第二批）：`5d0ed9e5` 改「图标 + 文案」ChoiceTile 行（Ok/Edit/Copy/Delete，删除行危险色，现 `SettingsHost.kt:1712-1723`）；与 Dart 的刻意分歧（「应用」留表，Dart 的应用入口在预览弹层而 Compose 无预览弹层）已注释写明。 |
| **P2** | `app/SettingsHost.kt:1715` | button-variant | 说明框的确认按钮是默认灰色，撤销/确定又挤在行尾 8dp；主操作应为强调色，官方动作区是等宽按钮 + 20dp | 确认按钮加 primary 配色；按官方配方改成等宽 TextButton + 20dp 间距。 | CONFIRMED | 已不成立（2026-11-03 第二批）：`5d0ed9e5` 有撤销时改「撤销 TextButton + 确认主色实心」等宽 12dp（本仓 Dialog 口径，现 `SettingsHost.kt:1799-1821`）；无撤销保持单颗主色右对齐（`:1822-1835`，本文件 :933 先例口径）。 |
| **P2** | `app/TimeSchemeHost.kt:473` | exit-animation | 两个 picker 调用点都写 show = true 且由 `when (pickPhase)` 条件组合，确认/取消时弹层瞬间消失，没有退场动画 | picker 常驻组合，用 `show = pickPhase != SectionPickPhase.None` 驱动；状态只切内容不摘组件。 | CONFIRMED | 已不成立：`show = startPick/endPick != null` + `rememberLastNonNull` 钉退场内容（现 `TimeSchemeHost.kt:491-504`，`79f5cedf`）。 |
| **P2** | `pages/about/AdvancedOptionsPage.kt:253` | spacing | 对话框没把 insideMargin 收到 16：官方默认 24 + 内容自己 8 = 单边 32dp | 传 `insideMargin = DpSize(8.dp, 16.dp)`，或去掉内容 8dp 并传 16dp。 | CONFIRMED | 已不成立：`insideMargin = DpSize(8,16)`，注释写明单边合计 16（现 `AdvancedOptionsPage.kt:249-300`）。 |
| **P2** | `pages/about/AdvancedOptionsPage.kt:286` | button-variant | 取消和确认都是默认灰色实心按钮，确认缺少 primary | 确认加 `colors = ButtonDefaults.buttonColorsPrimary()`；取消改用 TextButton。 | CONFIRMED | 已不成立：取消 `TextButton` + 确认主色实心（现 `AdvancedOptionsPage.kt:282-299`，`625302a3`）。 |
| **P2** | `pages/course/AddCoursePage.kt:757` | layout-scroll | 周选择对话框正文不可滚动；miuix 小屏对话框不设高度上限且底部对齐，内容超高时从顶部裁掉标题/模式组 | 给正文 Column 套 `verticalScroll(rememberScrollState())` 并对周网格限高（如 `heightIn(max = 屏高 * 0.5f)`），或把该弹层迁到 QingyuSheet。 | PARTIAL | 已不成立：正文 `LazyColumn` + `heightIn(max = 屏高×0.72)` + 触感/过滚（现 `AddCoursePage.kt:764-777`）。 |
| **P2** | `pages/course/AddCoursePage.kt:877` | button-variant | 周选择的「确认」是主操作却用默认灰色 Button，未给 buttonColorsPrimary() | 加 `colors = ButtonDefaults.buttonColorsPrimary()`。 | CONFIRMED | 已不成立：确认按钮已传 `buttonColorsPrimary()`（现 `AddCoursePage.kt:902`）。 |
| **P2** | `pages/course/CourseActionSheet.kt:140` | spacing-known-debt | [已知债] 所有 title=null 的底栏弹层顶部都有固定 42dp 空档（24dp 把手 + 18dp 空标题行） | 等 miuix 提供把手悬浮开关；短期统一约定「title=null 时内容顶部 padding 必须为 0」，并可在套件里对 title=null 注入等价顶部间距以便将来一处修改。 | PARTIAL | 成立（已知债）：仍 `title = null`，42dp 空档在（现 `CourseActionSheet.kt:140-157`；`QingyuSheet.kt:51-54` KDoc 自认组件能力缺口），见拍板 #7。 |
| **P2** | `pages/course/CourseFollowupSheets.kt:474` | button-variant | 地点弹层的「确认」用默认灰色 Button，主操作没有强调色 | 加 `colors = ButtonDefaults.buttonColorsPrimary()`。 | CONFIRMED | 已不成立：已传 `buttonColorsPrimary()`（现 `CourseFollowupSheets.kt:477`）。 |
| **P2** | `pages/course/CourseFollowupSheets.kt:713` | layout-clipping | 调课弹层把列表写死 480dp，底部按钮固定在列表外；可用高度不足时按钮会被压掉 | 把 480dp 换成屏高比例（如 `(LocalConfiguration.current.screenHeightDp * 0.5f).dp`），或用 `BoxWithConstraints` + `weight(1f)` 让列表占据剩余空间、按钮固定保留。 | PARTIAL | 已不成立（2026-11-03 收尾核实）：限高改屏高比例 `RESCHEDULE_LIST_HEIGHT_FRACTION`（现 `CourseFollowupSheets.kt:704`，`a150be39`），矮屏底部按钮不再被压；「固定件在列表外 + `contentScrolls=true`」结构保持。 |
| **P2** | `pages/course/CourseFollowupSheets.kt:885` | button-variant | 调课的「确认调课」用默认灰色 Button，未给强调色 | 加 `colors = ButtonDefaults.buttonColorsPrimary()`。 | CONFIRMED | 已不成立：已传 `buttonColorsPrimary()` 且 `enabled` 随可确认态置灰（现 `CourseFollowupSheets.kt:890`）。 |
| **P2** | `pages/course/CourseNoteSheet.kt:158` | spacing-double | 备注弹层内容顶部又加 16dp，叠在套件固定 42dp 空档上，顶部留白变成 58dp | 去掉 `top = 16.dp`（改为 0）；若确实需要更多留白，应在套件层统一，而不是由单个调用点补。 | CONFIRMED | 已不成立（2026-11-03 收尾核实）：顶部不再另加 16dp，注释写明与 42dp 空档的叠加关系（现 `CourseNoteSheet.kt:143-161`，`b5647157`）；42dp 空档本身仍按拍板 #7 在册（见 CourseActionSheet 行）。 |
| **P2** | `pages/course/CourseNoteSheet.kt:265` | button-variant | 备注弹层的「保存」是主操作，却用默认灰色 Button，未给强调色 | 加 `colors = ButtonDefaults.buttonColorsPrimary()`（需 import ButtonDefaults）。 | CONFIRMED | 已不成立：保存已传 `buttonColorsPrimary()`（现 `CourseNoteSheet.kt:268`）。 |
| **P2** | `pages/course/CourseOverviewPage.kt:504` | miuix-first | [已知债] 排序菜单仍是裸 androidx.compose.ui.window.Popup + QingyuCard 自拼三行，未换官方列表弹层 | 换成 `OverlayListPopup` / `ListPopup`，锚点仍用现有 anchorBounds；替换后从待核清单登记移除。 | PARTIAL | 已不成立（2026-11-03 收尾）：迁官方 `OverlayListPopup` + `ListPopupColumn` + `DropdownImpl`，常驻组合、`show` 状态驱动，遮罩/进出场/返回键与点空白关闭归官方；定位经官方 `PopupPositionProvider` 扩展点右对齐到排序图标实测矩形、贴其下方 4dp（现 `CourseOverviewPage.kt:239` 调用 / `:484` 本体）。守卫 `CourseOverviewSortPopupGuardTest` 钉「官方组件在场 + 原生 Popup 不回流 + 常驻组合」（判据先剥注释），咬合探针两条各红后还原复绿，course 域 L0 224 例绿。例外表「待核」首条可移除。 |
| **P2** | `pages/diagnostics/MemoryStatsPage.kt:300` | state-lifecycle | 关闭时 sheet 立即变 null，title 和正文同时被置空，退场动画期间弹层会先「塌成空板」再滑走 | 用一个 `val lastSheet = remember { mutableStateOf(...) }` 在关闭时保留最后一份 sheet，供退场期间渲染；或把 title/正文改为非空快照。 | CONFIRMED | 已不成立：常驻 `show = sheet != null` + `currentSheet` 最后非空快照（现 `MemoryStatsPage.kt:297-318`，`661f5441`）。 |
| **P2** | `pages/exam/ExamPickerSheets.kt:118` | layout-clipping | [已知债] 日期周次弹层 contentScrolls=true 且固定件四段在列表之后，矮屏/大字号会把底部按钮行挤出面板 | 把列表上限从 0.64 降到 ~0.55（或改成「屏高 − 固定件实测高度」）；或让取消/确认行跟随列表一起滚动。需真机在矮屏上验证按钮完整可见。 | PARTIAL | 已不成立（静态缓解）：限高 0.64→屏高×0.55，注释写明给固定件留高度（现 `ExamPickerSheets.kt:156`，`f98e377e`）；矮屏表现仍待真机复核。 |
| **P2** | `pages/exam/ExamPickerSheets.kt:196` | spacing-button | 7 个星期按钮用默认 TextButton，每颗左右各 16dp 内边距；400dp 屏每颗仅约 44dp 宽，留给文字只剩约 12dp | 给 TextButton 传 `insideMargin = PaddingValues(horizontal = 4.dp, vertical = 8.dp)`，或改用与 Dart 同款的轻量 chip 容器。 | CONFIRMED | 已不成立：`insideMargin = PaddingValues(horizontal = 4.dp, vertical = 8.dp)`（现 `ExamPickerSheets.kt:241`，`d2637b73`）。 |
| **P2** | `pages/exam/ExamPickerSheets.kt:196` | missing-content | 星期按钮丢了 Dart 每格下方的具体日期（日名 11sp + 日期 10sp 两行），Compose 只剩一个 17sp 的星期字 | 把按钮内容改成两行：日名用 11sp（footnote2 一档）、日期用 10sp，对齐 Dart 的 Column 配方；同时配 finding 11 的 insideMargin 收窄。 | EXTRA(复核补) | 已不成立：星期按钮改「日名 + 月-日」两行（现 `ExamPickerSheets.kt:243-252`，`a8fb43e7`）。 |
| **P2** | `pages/exam/ExamPickerSheets.kt:231` | dead-action | 没选星期时「确认」按钮仍可点，但 onClick 里判空后什么都不做，用户以为卡死 | `enabled = dayOfWeek != null`（禁用态配色随之生效），或者在未选时默认取当前/第 1 天并允许确认。 | CONFIRMED | 已不成立：`enabled = dayOfWeek != null` 置灰（现 `ExamPickerSheets.kt:272`，`f5826ace`）。 |
| **P2** | `pages/exam/ExamPickerSheets.kt:489` | missing-content | 关联课程行缺少 Dart 的 36dp 课程颜色徽章，弹层底部也没有 Dart 的全宽「取消」按钮 | 给 `ExamCourseOption` 补 color 字段并由 `coursePickerOptions` 带上；行内按 Dart 画 36dp 前缀徽章，底部补全宽 secondary 取消按钮。 | EXTRA(复核补) | 已不成立：行内补 36dp 圆角课程色徽章、底部补全宽「取消」`TextButton`（现 `ExamPickerSheets.kt:547-557`/`:596-602`，`b05552bd`）。 |
| **P2** | `pages/settings/SettingsPageRenderers.kt:837` | exit-animation | show=true 且由 `if (editing && helper != null)` 条件组合，关闭时对话框直接消失，没有退场动画 | 让 SliderValueDialog 常驻组合、把可见性改成状态（show 参数化），关闭时先置 show=false。 | CONFIRMED | 已不成立：常驻 `show = editing`（现 `SettingsPageRenderers.kt:812-813` 调用、`:868-869` 定义，`d7463b14`）。 |
| **P2** | `pages/settings/SettingsPageRenderers.kt:842` | spacing | 对话框没把 insideMargin 收到 16：官方默认 24 + 内容自己 8 = 单边 32dp | 传 `insideMargin = DpSize(8.dp, 16.dp)`（或去掉内容 8dp 后传 16dp）。 | CONFIRMED | 已不成立：`insideMargin = DpSize(8,16)`，注释写明「框架侧也 8 ⇒ 单边 16」（现 `SettingsPageRenderers.kt:873`）。 |
| **P2** | `pages/settings/SettingsPageRenderers.kt:876` | button-variant | 取消和确定都是默认灰色实心按钮，确定缺少 primary，看起来像两个次要操作 | 确定加 `colors = ButtonDefaults.buttonColorsPrimary()`；取消改用 TextButton（官方配方）。 | CONFIRMED | 已不成立：取消 `TextButton` + 确定 `buttonColorsPrimary()`（现 `SettingsPageRenderers.kt:906`/`:924`，`af7c6711`）。 |
| **P2** | `pages/sync/CloudBackupDetailHost.kt:135` | button-variant | 「恢复」是主操作却用默认灰 buttonColors()，没有任何强调色 | colors = ButtonDefaults.buttonColorsPrimary()。 | CONFIRMED | 已不成立：恢复已传 `buttonColorsPrimary()`（现 `CloudBackupDetailHost.kt:135`）。 |
| **P2** | `pages/sync/CloudBackupDetailHost.kt:181` | button-variant | 「删除」是不可撤销的破坏性操作，却和「取消」一样是灰底灰字，既无危险色也无主次区分 | colors = ButtonDefaults.buttonColors(color = Color(QingyuTheme.error(dark)), contentColor = Color(QingyuTheme.onError(dark)))（实心危险按钮必须同时给 contentColor，S4）。 | CONFIRMED | 已不成立：删除改 `buttonColors(error, onError)` 红底（现 `CloudBackupDetailHost.kt:182-185`）。 |
| **P2** | `pages/sync/CloudBackupDetailSheet.kt:68` | layout | 动作区做成半宽并排 Row，主次配色也错：恢复是灰底、删除是灰字 TextButton；Dart 是整宽竖排 + primary 恢复 + destructive 删除 | 改成 Column + 两颗 fillMaxWidth 按钮；恢复用 buttonColorsPrimary()，删除用 error/onError。若要保留并排，至少纠正配色并说明为何偏离 Dart。 | CONFIRMED | 已不成立（2026-11-03 第二批）：`f4f7a199` 动作区改整宽竖排、恢复在前删除在后；删除同步改红底 onError（Dart destructive 口径），现 `CloudBackupDetailSheet.kt:73-102`。 |
| **P2** | `pages/sync/CoupleWebdavConnectSheet.kt:159` | button-variant | 「连接并拉取」是主操作，但 Button 不传 colors，实际渲染成 secondaryVariant 灰底，与上方蓝色块并列时反而像次要按钮 | 补 colors = ButtonDefaults.buttonColorsPrimary()。 | CONFIRMED | 已不成立：已传 `buttonColorsPrimary()`（现 `CoupleWebdavConnectSheet.kt:157`）。 |
| **P3** | `app/TimeSchemeHost.kt:226` | lifecycle-exit | 所有时间模板弹层都按 `when (dialog)` 分支按需挂载，关闭时整棵 OverlayDialog/QingyuSheet 立即离开组合，退场动画完全不播。 | 把弹层提升为宿主顶层常驻组合，宿主维护「当前 payload + visible」两态；关闭时只置 visible=false，等 onDismissFinished 再清 payload（与 AddTaskPage 应做的修法相同）。 | EXTRA(复核补) | 已不成立：五个弹层全部常驻组合、组件内自驱 `show = state != null`（现 `TimeSchemeHost.kt:227-230` 注释「弹层债 #1」，`79f5cedf`）。 |
| **P3** | `components/QingyuSheet.kt:96` | typography | 弹层/对话框标题沿用官方硬编码 title4 18sp + FontWeight.Medium，正文用 body1 16sp；Dart 是 17sp w400 / 14sp w400，且 Medium 绕过用户字重/系统粗体平移 | 要么在套件/对话框里不用官方 title/summary 参数，改用 Text(MiuixTheme.textStyles.title4.shiftWeight(...)) 与 body2 自绘标题/正文；要么把“官方组件 18/500/16 与 Dart 17/400/14 的差异”登记为已接受的组件缺口，并在真机逐弹窗确认。 | EXTRA(复核补) | 成立：仍把 `title` 原样透传官方 `OverlayBottomSheet`（现 `QingyuSheet.kt:96`），官方 18sp Medium 照旧；按拍板 #2 接受官方字阶。 |
| **P3** | `components/QingyuSheet.kt:100` | layout | contentPadsHorizontally=true 会把标题行的左右内边距一起归零，startAction/endAction 会贴到面板边缘（潜在问题，当前无人使用标题动作） | 把标题动作的横向留白与内容内边距解耦（例如对 title 动作单独包一层 16dp Box，或保留标题行 padding），至少在 KDoc 里写明 contentPadsHorizontally=true 时不要同时使用 startAction/endAction。 | CONFIRMED | 成立（潜在）：`contentPadsHorizontally=true` 仍整框横向归零（现 `QingyuSheet.kt:100`），标题动作无单独内边距；KDoc 已补阈值警告（`:61-66`）但未解耦。 |
| **P3** | `components/QingyuSheet.kt:104` | spacing-keyboard | 键盘弹出时底部让位仍加 navigationBars + 16dp，与组件自带的 imePadding 叠加 ⇒ 键盘上方多出约 24~40dp 空白 | 让 bottomInset 感知 IME：先取 `WindowInsets.ime.getBottom(density)`，IME 可见时只加 ContentBottomGap，不可见时加 navigationBars + ContentBottomGap（或对 navigationBars 做 exclude(ime) 后再相加）。需真机键盘场景复核。 | PARTIAL | 成立：底部让位仍固定 `WindowInsets.navigationBars + 16dp`（现 `QingyuSheet.kt:104-106`），全文件无 IME 感知；需真机键盘场景复核。 |
| **P3** | `pages/export/IcsExportPage.kt:319` | alignment | 两个确认框的正文都是左对齐，Dart 确认框的 message 是居中 | 正文补 Modifier.fillMaxWidth() + textAlign = TextAlign.Center。 | CONFIRMED | 已不成立：正文 `fillMaxWidth()` + `TextAlign.Center`（现 `IcsExportPage.kt:319-369`，`abdb222e`）。 |
| **P3** | `pages/import/ImportCommon.kt:554` | localization | 「日常更新建议优先选择更新课表，保留本地独有课程并合并新课程」是写死在渲染层的整句中文，不在任何 ARB/资源里，en/ja/ko/zh-TW 用户会看到中文 | 六份 ARB 增键并 gen-l10n，渲染层改取 *Strings（或复用已有 guidance 键）。 | PARTIAL | 已不成立：进六份 ARB，渲染层改 `ImportStrings.importReplaceExistingGuidance`（`ImportArbText`，现 `ImportStrings.kt:105`、用于 `ImportCommon.kt:665`，`965db6df`）。 |
| **P3** | `pages/import/ImportCommon.kt:597` | lifecycle | 三处在 show=false 时直接 return，把 OverlayDialog 整个移出组合，官方 260ms 的退场动画（下移/缩放 + 遮罩淡出）一次都不会播 | 去掉提前 return，改为 OverlayDialog(show = show, ...)；需要重置内部状态时用 remember(show) 或 LaunchedEffect(show)。 | CONFIRMED | 已不成立：`LaunchedEffect(show)` 打开时重置状态、不再提前 return（现 `ImportCommon.kt:580-599`）。 |
| **P3** | `pages/import/warehouse/WarehouseCustomDebugHost.kt:119` | lifecycle | 点「删除」时先把 pendingDelete 置空，对话框在 260ms 退场动画里正文变成空串（只剩「删除「」？」） | 用 remember 保留最后一次非空记录，动画期间继续渲染它。 | CONFIRMED | 已不成立：`shownDelete` 保留最后一份非空记录供退场渲染（现 `WarehouseCustomDebugHost.kt:108-119`）。 |
| **P3** | `pages/showcase/MiuixShowcaseSubpages.kt:799` | spacing | [已知债] 展厅底部弹层只有内容 16dp 底距，没有系统手势区让位，按钮落在导航条/手势区里 | 改用 QingyuSheet（套件已带 navigationBars + 16dp）；或内容末尾补 `Spacer(WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + 16.dp)`。 | PARTIAL | 已不成立：改 `QingyuSheet`，手势区让位与 16dp 由套件统一管（现 `MiuixShowcaseSubpages.kt:802-820`，`a7701c17`）。 |
| **P3** | `pages/showcase/MiuixShowcaseSubpages.kt:807` | spacing | [已知债] 展厅底部弹层未传 insideMargin，官方默认 24 再叠内容 16 ⇒ 单边 40dp | 演示本仓口径时改用 QingyuSheet；若坚持展示官方裸组件，传 `insideMargin = DpSize(0.dp, 0.dp)` 让内容 16dp 成为唯一边距（或去掉内容 padding、保留官方 24dp）。 | PARTIAL | 已不成立：同上，`QingyuSheet` 16dp 口径、`contentPadsHorizontally` 归零防叠加（现 `:802-820`）。 |
| **P3** | `pages/task/AddTaskPage.kt:387` | lifecycle-exit | 删除确认框用条件组合 + show=true 挂载，关闭时组件直接从组合里移除，退场动画不会播；TaskListPage.kt:281 的 pendingDelete?.let 同病。 | 把 OverlayDialog 移出 if/let 常驻组合，show 用布尔状态；内容用 `if (visible)` 守，并在关闭时保留最后一条数据供退场渲染。 | CONFIRMED | 已不成立：两处均改 `OverlayDialog` 常驻、`show` 由 `showDeleteConfirm && onDelete != null` / `pendingDelete != null` 驱动并保留最后数据（现 `AddTaskPage.kt:387-426`、`TaskListPage.kt:280-321`，`f273129f`）。 |
| **P3** | `pages/task/AddTaskPage.kt:397` | text-alignment | 删除确认正文默认左对齐，Dart 与官方对话框的正文都是居中；TaskListPage.kt:290 同。 | 补 `textAlign = TextAlign.Center` 与 `modifier = Modifier.fillMaxWidth()`。 | CONFIRMED | 已不成立：正文改官方 `summary` 槽，官方容器自带居中（`ff28674c`）。 |
| **P3** | `pages/task/AddTaskPage.kt:402` | action-spacing | 任务族删除确认按钮间距 8dp（TaskListPage.kt:296 同），低于 Dart 的 12dp 与官方 demo 的 20dp，也小于本仓其他确认框。 | 统一成 12dp（本仓 Dialog 口径）或 20dp（官方配方）。 | CONFIRMED | 已不成立：`spacedBy(12.dp)` + 两颗 `weight(1f)` 等宽（`ca8d802c`）。 |
| **P3** | `pages/time_scheme/LocationTimeMatchHost.kt:214` | lifecycle-exit | 删除地点组对话框同样在 deleting 变 null 时同时清空 title/summary/content，退场动画期间只剩空面板。 | 保留最后一次 deleting 的副本用于渲染，show 单独由 deleting != null 决定。 | CONFIRMED | 已不成立：`shownDelete` 保留最后一次 deleting 副本、`show = pendingDelete != null`（现 `LocationTimeMatchHost.kt:218-221`，`79f5cedf` 批次）。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:101` | title-padding | 菜单弹层为给内容 16dp 把 contentPadsHorizontally 设为 true，套件横向内边距归零时标题行也跟着归零；模板名较长会贴到面板边。 | 套件在 contentPadsHorizontally=true 时给 TitleAndActionsRow 单独补 16dp；或该弹层改由内容自绘标题（会多一条 18dp 空标题行，需权衡）。 | CONFIRMED | 已不成立：改 `contentPadsHorizontally = false`（现 `TimeSchemeManagementDialogs.kt:114`），标题行不再贴边。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:157` | keyboard-focus | 新建/重命名输入框没有自动聚焦，Dart 原版是 autofocus: true。 | 加 `val focusRequester = remember { FocusRequester() }` + `LaunchedEffect(current) { focusRequester.requestFocus() }`，并把 Modifier.focusRequester 传给 TextField。 | CONFIRMED | 成立：输入框仍无自动聚焦（现 `:157` 附近，全文件无 `FocusRequester`）；按拍板 #1 默认不加。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:264` | layout-overflow | 占用清单直接铺在不可滚动的 Column 里，占用方多/名字长时会把两个动作按钮挤出屏幕。 | 把 intro + 清单放进有上界的 verticalScroll/LazyColumn（weight 或 heightIn），动作行留在滚动区外。 | CONFIRMED | 已不成立：占用清单 `LazyColumn` + `heightIn(max)` 可滚，两动作固定列表外（现 `TimeSchemeDeleteBlockedSheet`）。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:414` | content-missing | 分享弹层只显示标题和三个动作，缺了 Dart 原版居中的模板名正文；模型已经提供 schemeName。 | 在动作区上方加 `if (current.schemeName.isNotBlank()) Text(current.schemeName, style = body2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp))`，并删掉文件头那条过期差异说明。 | PARTIAL | 已不成立：动作区上方补了居中 `schemeName` 正文，注释明记「弹层债 #7」（现 `TimeSchemeShareSheetDialog`，`1185e014`）。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:463` | actions-layout | onSecondary 非空时三个按钮挤在一行，Dart 对超过两个动作是竖排；「查看使用情况」会被压窄/换行。 | onSecondary != null 时改用 Column(spacedBy(12.dp))，每颗 fillMaxWidth。 | PARTIAL | 已不成立：`onSecondary != null` 改 `Column` + `spacedBy(12.dp)` 整宽竖排（`1185e014`）。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:465` | action-spacing | DialogActionRow 两个/三个按钮的间距是 10dp，Dart 是 12dp、官方 demo 20dp；LocationTimeMatchHost.kt:227 也是 10dp。 | 统一为 12dp。 | CONFIRMED | 已不成立：`DialogActionRow` 与分享弹层按钮间距统一 12dp（`1185e014`）。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:520` | typography-chip | 三个统计 chip 的字号、颜色、内边距、圆角都与 Dart HyperosTag 不一致，且 maxLines=1 在外语/长标签下会截断。 | chip 改为 12sp 主文本色、内边距 8×2、圆角 6dp，并去掉 maxLines=1（或改成 maxLines=2 + 省略策略需与 Dart 对齐后再定）。 | EXTRA(复核补) | 已不成立：chip 改 6dp 圆角 / 8×2 内边距 / `footnote1.shiftWeight(MEDIUM)` / 次级文本色、去 maxLines（现 `UsageChip`，`1185e014`）。 |
| **P3** | `pages/time_scheme/TimeSchemeManagementDialogs.kt:556` | typography | 使用情况弹层的标题/正文整体比 Dart 小一档：分区标题 body1(16) vs listTitle(17)，副标题与引用行 footnote1(13) vs listDetail(14)，说明句也 13 vs 14。 | 分区标题/引用主行改 `MiuixTheme.textStyles.main`，副标题/引用副行/说明句改 `body2`。 | CONFIRMED | 已不成立：分区标题改 `textStyles.main`、副标题/说明句改 `body2`（现 `UsageSection`，`1185e014`）。 |
| **P3** | `pages/timetable/WeekSelectorSheet.kt:84` | known-debt | [已知债] QingyuSheet 未传 title，套件仍画 24dp 把手 + 18dp 空标题行，自绘标题前多出约 42dp 空白（上轮报告 §五.2 的组件能力缺口）。 | 等上游提供 dragHandleOverlaysContent / 无标题时不占行；短期只能在「42dp 空档」与「改用框架 18sp 居中标题（偏离 Dart 17sp 左对齐）」之间取舍。 | PARTIAL | 成立（已知债）：仍 `title = null` + 正文自绘标题，42dp 空档在（现 `WeekSelectorSheet.kt:84`），见拍板 #7。 |
| **P3** | `pages/transfer/DataTransferPage.kt:479` | lifecycle | 预览弹窗在退场动画期间标题切到兜底文案、正文清空，面板会先“变空”再消失 | remember 最后一次非空 content，动画期间继续渲染它。 | CONFIRMED | 已不成立：`shown` 保留最后一份非空 content（现 `DataTransferPage.kt:483-488`）。 |
| **P3** | `app/AppearanceEditorHost.kt:737` | known-debt | [已知债] 无标题弹层顶部恒有约 42dp 空档（把手条 24 + 空标题行 18） | 暂时保留并记录；不要为了压顶部而给内容加负间距（会破坏模糊带/滚动起点），等 miuix 提供悬浮把手参数再收。 | PARTIAL | 成立（已知债）：材质/壁纸面板仍不传 `title`（现 `AppearanceEditorHost.kt:737`/`:770`），42dp 空档见 `QingyuSheet.kt:51-54` KDoc，见拍板 #7。 |
| **P3** | `app/SettingsHost.kt:839` | typography | 时间滚轮用 title3 但没加 SEMIBOLD，Dart 是 title3 + w600 | 改成 `MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD)`。 | CONFIRMED | 已不成立：`title3.shiftWeight(QingyuWeightDelta.SEMIBOLD)`（现 `SettingsHost.kt:859`/`:868`，`23d78f15`）。 |
| **P3** | `app/SettingsHost.kt:869` | spacing | 底部多叠一层 16dp：内容末尾 Spacer(16) 加上套件自己的 bottomInset（手势区 + 16） | 删掉内容末尾这颗 Spacer(16)。 | CONFIRMED | 已不成立：末尾 `Spacer(16)` 已删，注释写明套件 `contentScrolls=false` 时自动补手势区+16dp（现 `SettingsHost.kt:890`，`f5eafbb0`）。 |
| **P3** | `app/SettingsHost.kt:1058` | button-variant | 选色弹窗的确认按钮（“完成”）用默认灰色 Button，主操作没有强调色 | 确认按钮加 `colors = ButtonDefaults.buttonColorsPrimary()`；若按 finding 1 整框换成 OverlayDialog，也要保留这条。 | EXTRA(复核补) | 已不成立：完成按钮已传 `buttonColorsPrimary()`（现 `SettingsHost.kt:1089`）。 |
| **P3** | `app/SettingsHost.kt:1577` | input-focus | 主题命名输入框没有自动聚焦，Dart 对话框显式 autofocus: true | 加 `val focusRequester = remember { FocusRequester() }` + `LaunchedEffect(Unit) { focusRequester.requestFocus() }`，TextField 传 `Modifier.focusRequester(...)`。 | PARTIAL | 成立：主题命名输入框仍无自动聚焦（现 `SettingsHost.kt:1615-1624`，全文件无 `FocusRequester`）；按拍板 #1 默认不加，且 `SettingsPageRenderers` 有「不抢焦点」既有取舍。 |
| **P3** | `app/SettingsHost.kt:1618` | copy | 删除确认的标题用了 themeDelete（“删除”，与确认按钮同字），Dart 用的是 confirmDeleteTitle（“确认删除”） | 把 confirmDeleteTitle 加进对应的 Kotlin 字符串表并用于 title。 | CONFIRMED | 已不成立：改 `SettingsStrings.confirmDeleteTitle`（现 `SettingsHost.kt:1659`，`01b577fe`）。 |
| **P3** | `app/SettingsHost.kt:1666` | spacing | 动作表底部多出约 16dp：Column 的 vertical=8 + 末尾 Spacer(8) 叠加在套件的 bottomInset 之上 | 删掉末尾 Spacer(8)，或去掉 Column 的 vertical 底部 8（两者至少留一个即可）。 | CONFIRMED | 已不成立：末尾 `Spacer(8)` 已删，注释写明套件已补让位（现 `SettingsHost.kt:1712`，`3d1151ce`）。 |
| **P3** | `app/SettingsSemesterHost.kt:240` | known-debt | [已知债] 固定高 NumberPicker 被套进套件的外层 verticalScroll，滚轮手势会不会被外层抢走只有真机能验 | 真机验证；若出现抢手势，把这些弹层改 contentScrolls=true 并在内容末尾自补 `Spacer(bottomInset)`。 | PARTIAL | 成立（已知债）：两个滚轮弹层仍未传 `contentScrolls`（套件默认自套 `verticalScroll`，见 `QingyuSheet.kt:113-116`），内层仍固定高 `NumberPicker`（现 `SettingsSemesterHost.kt:240`/`:325`）；需真机验证。 |
| **P3** | `app/TimeSchemeHost.kt:547` | typography | 时间滚轮高 180dp、title3 无 SEMIBOLD；Dart 同弹层是 220dp + title3 w600 | 高度改 220dp，textStyle 改 `title3.shiftWeight(QingyuWeightDelta.SEMIBOLD)`。 | CONFIRMED | 已不成立：`.height(220.dp)` + `title3.shiftWeight(SEMIBOLD)`（现 `TimeSchemeHost.kt:562`/`:575`/`:584`，`79f5cedf`）。 |
| **P3** | `app/TimeSchemeHost.kt:591` | copy | 确认按钮文案用 saveAction（“保存”），Dart 同一个时间弹层用 confirmAction（“确定”） | 改用 confirmAction。 | CONFIRMED | 已不成立：改 `TimeSchemeManagementStrings.confirmAction`（现 `TimeSchemeHost.kt:610`，`:608-609` 注释对齐 Dart）。 |
| **P3** | `pages/about/AboutStaticPage.kt:148` | animation | 两个 About 弹层都是「条件成立才组合 + show = true」，点空白/返回关闭时无下滑退场，直接消失 | 把弹层提升为常驻组合，`show = infoSheetEntry != null` / `show = repositorySheetOpen`，内容用非空快照。 | CONFIRMED | 已不成立：常驻组合 + `show = infoSheetEntry != null` / `show = repositorySheetOpen` + `lastInfoEntry` 退场快照（现 `AboutStaticPage.kt:99-104`/`:152-162`，`baeb8624`）。 |
| **P3** | `pages/about/AdvancedOptionsPage.kt:256` | input-focus | 镜像地址输入框不自动聚焦，Dart 同弹窗是 autofocus: true | 加 FocusRequester + `LaunchedEffect(Unit) { requestFocus() }`。落地前先确认与 SettingsPageRenderers.kt:815-816 已记录的「不主动抢焦点」口径是否冲突。 | EXTRA(复核补) | 成立：镜像地址输入框仍无自动聚焦（现 `AdvancedOptionsPage.kt:249-300` 无 `FocusRequester`）；按拍板 #1 默认不加，与「不抢焦点」口径一致。 |
| **P3** | `pages/about/SupportCreatorPage.kt:306` | animation | 静态 show = true，previewOpen 置 false 时直接移出组合，关闭没有退场动画 | 弹层常驻，show = previewOpen；内容用非空快照避免退场时被清空。 | EXTRA(复核补) | 已不成立：弹层常驻、只翻 `show`（现 `SupportCreatorPage.kt:182` 注释，`32d7679c`）。 |
| **P3** | `pages/about/SupportCreatorPage.kt:338` | button-variant | Dart 的二维码弹框有「保存到相册」+「关闭」两个动作（关闭还是主色），Compose 只剩保存一颗按钮 | 补一颗次要/主色「关闭」按钮，或确认「靠手势关闭」是有意精简并写进文件注释。 | CONFIRMED | 已不成立：补「保存 + 关闭」两动作、关闭为 primary（现 `SupportCreatorPage.kt:487-497`，`:487` 注释对齐 Dart，`ea21e4ed`）。 |
| **P3** | `pages/course/AddCourseWeekPickerTiles.kt:61` | color-hardcoded | 周格与选择胶囊的选中态写死 Color.White，换浅色主题种子后白字落在浅色 primary 上会看不清 | 两处都改成 `MiuixTheme.colorScheme.onPrimary`（或 `Color(QingyuTheme.onAccent(dark))`）。 | PARTIAL | 已不成立（2026-11-03 收尾核实）：选中态改 `Color(QingyuTheme.onAccent(dark))`（现 `AddCourseWeekPickerTiles.kt:62`/`:163`，`2ce5679e`）。 |
| **P3** | `pages/course/CourseFollowupSheets.kt:307` | accessibility | 周次加/减是 IconButton，但图标 contentDescription = null，读屏无法知道这颗按钮是加还是减 | 给 FollowupStepButton 增加 contentDescription 参数，调用处传「上一周/下一周」等 ARB 文案（不要硬编码中文）。 | CONFIRMED | 已不成立（2026-11-03 收尾核实）：`FollowupStepButton` 增加 `contentDescription` 参数并落进 Icon，周 ± 两处传 ARB `reschedulePreviousWeekAction` / `rescheduleNextWeekAction`（现 `CourseFollowupSheets.kt:765`/`:778`，`4325e210`，六份 ARB 同步由该泳道完成）。 |
| **P3** | `pages/diagnostics/LiveDiagnosticsLogPage.kt:307` | margin | [已知债] 对话框纵向 insideMargin 仍是 24dp，本仓对话框纵向口径是 16dp | insideMargin = DpSize(8.dp, 16.dp)（内容 Row 只需横向 8）。 | PARTIAL | 已不成立：`insideMargin = DpSize(8,16)`，注释写明避免与内容 8dp 叠成 32（现 `LiveDiagnosticsLogPage.kt:307`，`661f5441`）。 |
| **P3** | `pages/exam/ExamPickerSheets.kt:149` | missing-content | 周次行缺少 Dart 的 36dp 周数字徽章（选中=主色实心、本周=次色、其余=浅底） | 按 Dart 在行首加 36dp 圆角色块 + 周数字，三种状态分别用 primary / secondary / surfaceContainerHighest。 | EXTRA(复核补) | 已不成立：补 `WeekBadge` 36dp 三态徽章（现 `ExamPickerSheets.kt:172-177`/`:713-739`，`fd1d07e5`）。 |
| **P3** | `pages/exam/ExamPickerSheets.kt:161` | typography | 考试选择器选项行用 body1(16sp)/footnote1(13sp)，Dart 对应 listTitle(17sp)=main、listDetail(14sp)=body2 | 标题改 `MiuixTheme.textStyles.main`，副题改 `MiuixTheme.textStyles.body2`（两处列表都改）。 | CONFIRMED | 已不成立：主行 `textStyles.main`、副行 `body2`，两处列表同口径（现 `ExamPickerSheets.kt:184`/`:190`/`:563`/`:571`，`38c7de30`）。 |
| **P3** | `pages/exam/ExamPickerSheets.kt:181` | divider | 列表最后一项之后仍画分割线，底部多出一条悬空线 | 改用 `itemsIndexed`，`if (index < weeks.lastIndex)`（课程弹层同理）再画分割线。 | CONFIRMED | 已不成立：末项后不再画分割线（现 `ExamPickerSheets.kt:205`/`:588`，`2618d5af`）。 |
| **P3** | `pages/statistics/AchievementDetailSheet.kt:55` | animation | achievement 变成 null 时整个 composable 提前 return，弹层被移出组合，关闭时没有退场动画 | 外部一直保留调用，`show = achievement != null`，内部用 remember 保存最后一份非空 achievement 供退场渲染。 | CONFIRMED | 已不成立（2026-11-03 复核）：常驻组合、`show = achievement != null` + `lastAchievement` 最后非空快照退场渲染（现 `AchievementDetailSheet.kt:61-66`/`:94`，`bcbc8ab6`）。 |
| **P3** | `pages/statistics/AchievementDetailSheet.kt:59` | color | 已解锁徽章也用主题 primary 而非该成就的 per-id 语义色；CourseStatisticsPage 的徽章格子同样如此，与 Dart 的每个成就颜色身份不一致 | 把 accent 放进 AchievementView 或按 rawAchievement.id 复用 AchievementModel.accentOf，已解锁/未解锁两态都从该 accent 派生。 | EXTRA(复核补) | 已不成立（2026-11-03 复核）：accent 按成就 id 取 `achievementAccentColor(AchievementModel.accentOf(id))`，与 Dart `_achievementAccent` 及主页徽章格子同源（现 `AchievementDetailSheet.kt:69-74`，`bcbc8ab6`）。 |
| **P3** | `pages/statistics/AchievementDetailSheet.kt:88` | color | 未解锁徽章用中性 surfaceContainerHighest 填底，Dart 用该成就自身强调色的 14%（暗色 26%）淡染，徽章失去了每个成就的颜色身份 | 按 achievement.id 取同一套 accent（Dart `_achievementAccent`），用它做 14%/26% 的淡染与描边；或把 accent 放进 AchievementView 模型。 | CONFIRMED | 已不成立（2026-11-03 复核）：未解锁改同一 accent 的淡染底 + 描边 + 图标淡染（14%/26% 底、28%/44% 边，现 `AchievementDetailSheet.kt:75-91`，`bcbc8ab6`）。 |
| **P3** | `pages/sync/CloudBackupDetailHost.kt:102` | animation | 两个 OverlayDialog 都写成「if (state) { show = true }」，状态一变整棵对话框就被移出组合，官方 260ms 退场动画永远不会播 | 把 OverlayDialog 提到条件外，`show = confirmRestore` / `show = confirmDelete`；CloudBackupDetailSheet 的显隐也由 entryId 驱动而不是靠 if 包住。 | CONFIRMED | 已不成立（2026-11-03 第二批）：`f4f7a199` 宿主弃提前 return、两个确认框常驻组合 `show` 驱动（现 `CloudBackupDetailHost.kt:152-159`/`:215-224`），退场动画能播完。 |
| **P3** | `pages/sync/CloudBackupDetailHost.kt:110` | typography | 确认框正文左对齐，Dart 的对话框 message 是居中 | 给 Text 补 textAlign = TextAlign.Center（或改用 summary 槽并统一 14sp 样式）。 | CONFIRMED | 已不成立（2026-11-03 第二批）：`f4f7a199` 两个确认框正文 `fillMaxWidth() + TextAlign.Center`（现 `CloudBackupDetailHost.kt:164-170`/`:217-223`）；差异概要清单保持左对齐。 |
| **P3** | `pages/sync/CloudBackupDetailSheet.kt:55` | animation | 静态 show = true，宿主 entryId 置空时整棵弹层先被移出组合，关闭没有退场动画 | 把弹层提升为常驻组合，show = entryId != null，并用最后一份非空 view 渲染退场内容。 | EXTRA(复核补) | 已不成立（2026-11-03 第二批）：`f4f7a199` sheet 加 `show` 参数、宿主弃提前 return 且 `rememberLastNonNull` 保留最后一份非空 view 渲染退场（现 `CloudBackupDetailSheet.kt:45-67`、宿主 `CloudBackupDetailHost.kt:87-102`）。 |
| **P3** | `pages/sync/CloudBackupDetailSheet.kt:76` | layout | Compose 把删除放在左、恢复放在右；Dart 是恢复在前、删除在后，动作顺序与主次关系相反 | 改成 Column 时按 Dart 顺序先恢复后删除。 | EXTRA(复核补) | 已不成立（2026-11-03 第二批）：`f4f7a199` 动作区改整宽竖排「恢复在前（primary）、删除在后（红底 onError）」12dp（现 `CloudBackupDetailSheet.kt:73-102`），对齐 Dart `cloud_backup_ui_helpers.dart:76-94`。 |
| **P3** | `pages/sync/CoupleTimetableSettingsPage.kt:266` | animation | 静态 show = true，showUnlinkConfirm 置 false 时直接移出组合，OverlayDialog 无退场动画 | 把 OverlayDialog 提到条件外，show = showUnlinkConfirm。 | EXTRA(复核补) | 已不成立（2026-11-03 第二批）：`f4f7a199` 弃条件挂载改常驻 `show = showUnlinkConfirm`（现 `CoupleTimetableSettingsPage.kt:264-297`）。 |
| **P3** | `pages/sync/CoupleTimetableSettingsPage.kt:287` | button-variant | 解绑确认按钮做成实心红，Dart 是 primary 主色按钮；按钮间距也用了 10dp（其余同族均为 12dp） | 若按 Dart 对齐，改成 buttonColorsPrimary()、间距 12dp；若确定要保留危险红，需在文件里写明这是有意的语义强化（当前没有任何说明）。 | CONFIRMED | 已不成立（2026-11-03 第二批）：`f4f7a199` 间距 10→12dp；实心红按拍板 #6 保留并在代码注释写明语义强化（现 `CoupleTimetableSettingsPage.kt:273-292`）。 |
| **P3** | `pages/sync/CoupleWebdavConnectSheet.kt:74` | animation | 静态 show = true，宿主 showConnectSheet 置 false 时直接移出组合，关闭没有退场动画 | 让组件常驻组合，show = showConnectSheet，标题/正文在退场期间用最后一份快照。 | EXTRA(复核补) | 已不成立（2026-11-03 第二批）：`f4f7a199` sheet 加 `show` 参数、宿主弃 `if` 条件挂载改常驻组合（现 `CoupleWebdavConnectSheet.kt:76-88`、宿主 `CoupleTimetableSettingsHost.kt:228-269`）。 |
| **P3** | `pages/sync/CoupleWebdavConnectSheet.kt:143` | layout | 动作按钮放在弹层滚动内容里，Dart 的 PickerSheetScaffold 把动作固定在弹层底部；键盘弹出或小屏时主按钮可能被推到可视区外 | 把动作行移出滚动内容、固定在弹层底部（套件需要增加固定 footer 槽，或调用方自行分段）。 | EXTRA(复核补) | 已不成立（2026-11-03 第二批）：`f4f7a199` 动作行固定弹层底部（Dart `PickerSheetScaffold` actions 槽同位）、字段区 `LazyColumn` 内滚 + `weight(1f, fill=false)`（现 `CoupleWebdavConnectSheet.kt:88-197`）。 |

合计 120 条（已剔除复核明确驳回的条目）。**2026-11-02 回填**：另有查漏 18 条，两表合计 138 行。**2026-11-03 二次下探**：成就详情弹层 3 条（附表 110-112）由 `bcbc8ab6` 修掉——两表合计 **已不成立 107 / 仍成立 26 / 部分成立 5**。**2026-11-03 第二批（app / components / timetable / sync 四域）**：`f4f7a199` + `5d0ed9e5` + `5f0a4e7e` 又清 13 行。**2026-11-03 第三批（timetable 文案）**：`7aba9894` 清掉 `TimetableProfilesStrings` 对象（查漏 199）——两表合计 **已不成立 121 / 仍成立 16 / 部分成立 1**。**2026-11-03 第四批（收尾）**：course 域 4 条为并行泳道已修（`a150be39`/`b5647157`/`2ce5679e`/`4325e210`）逐条核实回填，裸 `Popup` 迁官方 `OverlayListPopup`——两表合计 **已不成立 126 / 仍成立 11 / 部分成立 1**；逐条现状见「回填 11-02」列（含 11-03 追记），汇总见顶部「复核结论」。
