# 外观编辑页（外观编辑 · 材质弹层 · 壁纸弹层）Compose 迁移审核

> **审核人**：appearance-verify（独立审核，不采信实现者自述）
> **任务**：task-5（A 段现状审核 / B 段对抗验证）
> **审核快照**：`git rev-parse --short HEAD` = **3f3b7354**（分支 `compose-migration`），
> 取数时间 **2026-10-29 20:54 +08:00**。工作区有未提交改动（本轮 T1–T4 四条泳道正在写）。
> **被审文件的 mtime**（= 我读到的那一版）：`SettingsAppearanceEditorPage.kt` 12:41 /
> `SettingsMaterialModel.kt` 12:40 / `SettingsMaterialPanels.kt` 14:01 /
> `SettingsBackdropFlowPage.kt` 12:46 / `SettingsRecentWallpaperPage.kt` 12:43 /
> `SettingsBingWallpaperGalleryPage.kt` 12:46 / `AppearanceEditorState.kt` 20:38 /
> `MaterialSheetBody.kt` 20:43 / `WallpaperSheetBody.kt` 20:43 /
> `SettingsPageRenderers.kt` 20:40 / `ShellPageIndex.kt` 20:54。
> **判定基准**：只认本仓 Dart 原件 `lib/...`（行号如下）。本文不引用任何外部软件作为参照。
> **状态词**：`已复刻` / `形态不对` / `缺数据源` / `缺交互` / `完全没做` / `未验·真机`。
> **证据分级**：`编译`（读源码）/ `单测`（JVM 单测可断言）/ `未验·真机`（只能在设备上看）。

---

## 0. 结论（先说最重的）

**这一页现在还不是「迁移完成」，是「模型层骨架 + 不可达的面板模型」。用户从设置里点进「外观编辑」，看到的是一张空卡 + 两行箭头，两颗按钮点了没反应。**

最严重的 5 个缺口（按用户可感知程度排序）：

1. **整页形态完全不是那一页。** Dart 是沉浸式整页（无顶栏、无列表、暗底 + 居中等比缩尺的真课表卡 + 顶部一行三件套 + 底部两颗圆钮，`:44-76`、`:1581-1758`）；Kotlin 走的是设置族通用列表骨架，顶栏写着「外观编辑」、下面一张空预览卡 + 两条 `ARROW` 行（`ShellPageIndex.kt:344` → `SettingsPageRenderers.kt:142-171`）。**形态不对，不是细节差异，是页型不同。**
2. **底部两颗入口点了没反应。** 两行的 `actionTarget` 是 `appearanceEditor.wallpaper` / `appearanceEditor.material`（`SettingsAppearanceEditorPage.kt:88/95`），而壳只把 `target` 当道由串翻译成壳页面 id（`ShellPageIndex.kt:1379` → `ShellWiring.kt:687-731`），这两个串在表里**没有**，`shellPageIdForRoute` 返回 `null` ⇒ 点按彻底 no-op。
3. **材质面板 / 壁纸面板的节点模型写好了，但一个都打不开。** `ShellPageIndex.kt:345-347` 有 `b.materialGeneral` / `b.backdropFlow` 等路由，但全仓 grep 除这三行外**零引用**（说明它们既不在任何入口、也不在 `shellPageIdForRoute` 里），并且都喂**空构造 state**。`MaterialSheetBody.kt` / `WallpaperSheetBody.kt`（20:43 新建）也还没有任何宿主调用它们（`grep AppearanceEditorHost|AppearanceEditorScreen` 为空）。
4. **所有材质/壁纸设置键都不在设置模型里，写了也落不了盘。** `TimetableSettingsModel` 的字段清单里没有 `frostedBlurEnabled` / `liquidGlassTuning` / `homeBandGlassMaterial` / `homePageWallpaperPath` / `wallpaperHistory` / `homePageBackdropFollowsWeekPager` 中的任何一个（`TimetableSettingsModel.kt:53-200` 逐字段读完）；`SettingsActionDispatcher` 的 rowId 常量表里**没有任何 `material.*` / `backdrop.*` 分支**（`SettingsActionDispatcher.kt:115-240`），未知 rowId 一律 `Ignored`（`:952` + `writeSetting` 的 `else ->` 分支，理由串：「未识别的 rowId」）。`AppearanceEditorState.kt:111-123` 自己写明了这件事：**「在那之前，材质面板的每一行都还在显示出厂值 —— 这是「点了写不进去」的根因，不许当成已完成。」**
5. **Dart 的整套「编辑语义」一条都没落**：即时落盘 + 250ms debounce + 串行保存队列 + 落盘失败回滚 + dispose 前 flush 未到期草稿（`:596-665`、`:587-592`）、取消 = 回滚到进页快照（`:735-740`）、完成 = 保留并发布退场图（`:672-675`、`:751-762`）、加载罩（`:1849-1871`、`:2515-2650`）。Kotlin 侧对应的只有常量：`CANCEL_TARGET` / `DONE_TARGET` / `LOADING_LABEL`（`SettingsAppearanceEditorPage.kt:48-54`），没有一处行为。

**清单规模**：功能点 **78 条**（A7 / B9 / C5 / D3 / E19 / F13 / G11 / H1 / I3 / J7）；当前判定
`已复刻` **21** 条 / `形态不对` **9** 条 / `缺数据源` **8** 条 / `缺交互` **7** 条 /
`完全没做` **31** 条 / `未验·真机` **2** 条。已被单测钉住的断言**只覆盖模型结构**，
没有任何一条断言「值来自真设置」或「动作真的落地」——见 §4.1。

**文案侧目前是干净的**：`dart run tool/copy_style_lint.dart` → 行内超宽新增 0、死键新增 0、复述新增 0（详见 §4.3）。

---

## 1. 逐条清单（可直接当验收表）

> 「怎么证」列：`L0` = `pwsh -NoProfile -File scripts/test-kotlin-module.ps1 -Module "pages/settings"`
> （真 JVM，600–800MB，别反复跑）；`编译` = L1 `:app:compileDevDebugKotlin`；
> `真机` = 只能 `PagesShellActivity` dev 变体上逐页对照，需用户配合。

### A. 整页形态与转场（Dart `:44-76`、`:1581-1758`）

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| A1 | 沉浸式整页：不透明深底 `_scrimColor`，无顶栏、无列表滚动（`:100`、`:1581-1616`） | **完全没做** | `ShellPageIndex.kt:344` 走 `SettingsScreen` → `SettingsPageRenderers.kt:142-171`（`QingyuPageScaffold` + 标题 + 返回键 + 滚动列表） | 真机 |
| A2 | 缩放转场分层出场：暗底 `growT`、chrome `chromeT`（`:259-269`、`:2456-2511`） | **完全没做** | 全仓无 `growT` / `chromeT` 对应物（`grep` 0 命中） | 真机 |
| A3 | 卡片落点上报 `hyperosZoomLanding`（`:1656-1673`） | **完全没做** | 同上 | 真机 |
| A4 | 系统返回 = 取消（`PopScope`，`:1590-1597`） | **缺交互** | 壳的返回只调 `onBack`（`ShellPageIndex.kt:344` 传 `onBack`），与「回滚草稿」无关 | L0（可断言「取消目标存在」）+ 真机（断言行为做不到） |
| A5 | 状态栏图标走浅色 `AnnotatedRegion`（`:1598-1600`） | **完全没做** | 无一处置 `SystemUiOverlayStyle` | 真机 |
| A6 | `FrostedAppearanceScope(appearance: _draft.frostedAppearance)` —— 预览读**草稿**外观（`:1601-1604`） | **完全没做** | 无对应注入点 | 真机 |
| A7 | 页面级玻璃采样宿主 `_pageGlass`（`:175-176`、`:1608`） | **完全没做** | 无 `HyperosGlassBackdropHost` 等价物 | 真机 |

### B. 预览卡（真首页缩尺卡 / 烤图）

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| B1 | 真首页整屏 1:1 渲染源 + `PreviewBakeBoundary` 烤图、`pixelRatio = dpr`（`:1684-1704`、`:1769-1783`） | **完全没做** | `SettingsAppearanceEditorPage.kt:72-77` 只给了一个 `InlineKind.PREVIEW_CARD` 占位节点，`note` 里自述「由宿主注入预览槽位」——宿主不存在 | 真机 |
| B2 | 卡片画烤出来的位图 `RawImage(fit: contain)`（`:1817`） | **完全没做** | `SettingsPageRenderers.kt:795-833` 的 `PreviewCard` 渲染器画的是「卡片标题 + 两个色块 tile」，且本页的 preview 节点 **没给 label/texts**，所以是**一张全空卡** | 真机（或截图） |
| B3 | 卡片几何：可用宽 `0.86×屏宽`、`topReserve = topInset+16+40+18`、`bottomReserve = bottomInset+24+56+8+18`、等比 `scale`、圆角 = 屏幕圆角×scale、几何居中（`:114`、`:1624-1650`） | **完全没做** | 无对应计算；`previewFlex=4/contentFlex=6`（`SettingsAppearanceEditorPage.kt:108-109`）是列表权重，不是几何 | L0 可断言常量若将来抽出来；现在无对象可断 |
| B4 | 卡片浮影 `Color(0x66000000)` blur 32 spread 2，透明度跟 `growT` 淡入（`:107`、`:1829-1842`） | **完全没做** | 无 `BoxShadow` 定义 | 真机 |
| B5 | 日/周只切**预览**、不动真实浏览状态（`TimetableHomePreviewScope`，`:1770-1782`）；初始值跟首页持久化视图（`:203-204`、`:376-380`） | **缺数据源** | `dayWeekOptions()` 只返回两项常量（`SettingsAppearanceEditorPage.kt:142-155`）；`AppearanceEditorBridge.toState` 里 `previewDayView` 读的是 `model.timetableHomeViewMode`（`AppearanceEditorState.kt:133`）—— 键存在、但没有宿主消费它 | L0（model→state 可断言），真机（交互） |
| B6 | 预览起始滚动位置取「进页那一刻」（`:218-227`、`:1775`） | **完全没做** | 无对应快照 | 真机 |
| B7 | 渲染源吞掉所有点按 `IgnorePointer`（`:1776`） | **完全没做** | 无渲染源 | — |
| B8 | 卡片在转场落点前不画（`Opacity` 阶跃，`:1724-1742`） | **完全没做** | — | 真机 |
| B9 | 预览烤图的 5 路脏信号（草稿版本号 / 日周 / 哪一天 / 落盘变化 / 预糊位图）（`:303-337`） | **完全没做** | 无重烤机制 | 真机 |

### C. 顶部 chrome（一行三件套）

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| C1 | 一行：`取消 ｜ 日·周分段 ｜ 完成`，`Padding fromLTRB(20, topInset+12, 20, 0)`（`:1892-1918`） | **形态不对** | `chromeRows()` 产出的两条是 `MiuixRowComponent.ARROW`（`SettingsAppearanceEditorPage.kt:119-134`），明确「是浮层、不进 spec 节点树」——于是**任何渲染器都不画它们**；只有单测在读它 | L0（结构）+ 真机（位置/尺寸） |
| C2 | 取消/完成胶囊 `84×40`、白 14% 底 + 18% 描边、字 15、完成 w600 取消 w400（`:1931-1953`） | **形态不对** | 同上（无胶囊渲染物） | 真机 |
| C3 | 日/周分段：999 圆角胶囊（白 12% + 14% 描边、padding 3），选中段白 92% + `0xFF1A1A1A` 字、字 14（`:1958-2008`） | **形态不对** | `dayWeekOptions()` 只是数据（`:142-145`），无渲染物 | 真机 |
| C4 | chrome 在**缩放转场结束后**才出场（`:1885-1918`、`:2491-2511`） | **完全没做** | 无 `chromeT` | 真机 |
| C5 | 弹层打开期间 chrome **位置与可见性不变**（`:780-782`） | **未验·真机** | 弹层都打不开，无从验 | 真机 |

### D. 底部 chrome（两颗圆钮）

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| D1 | 两颗 `56×56` 圆钮（白 14% 底 + 16% 描边、图标 26）+ 名字 12（白 86%）+ **圆钮与名字同属一个点击区** + 间距 40（`:2012-2090`） | **形态不对** | `SettingsAppearanceEditorPage.kt:80-98` 是 `SettingsGroup` 里的两条 `ARROW` 行（列表行，不是圆钮） | 真机 |
| D2 | 底部留白 = `bottomInset + 16`（`:2027`） | **完全没做** | — | 真机 |
| D3 | 两颗分别打开壁纸弹层 / 材质弹层（`:2034`、`:2042`） | **缺交互** | `actionTarget = appearanceEditor.wallpaper/.material`，`ShellPageIndex.kt:1379` 只做 `shellPageIdForRoute(target)`，该函数 `else -> null`（`ShellWiring.kt:730`）⇒ no-op | L0（可断言「目标串必须有接收方」——目前必然红，见 §5.3） |

### E. 材质弹层（两页签）

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| E1 | 弹层承载：**最多半屏** `_materialSheetMaxHeightFactor = 0.5`（`:120`、`:162-166`、`:839-841`）；把手悬浮、顶部渐变模糊带（`:2296-2311`）；内容自己带底部留白（`:890-894`） | **完全没做** | `MaterialSheetBody.kt:46-76` 只有 `Column + TabRow + HorizontalPager`，没有 `maxHeight`、没有模糊带、没有宿主（无 `ModalBottomSheet` 调用点） | 真机 |
| E2 | 两页签「通用 / 课程卡片」+ 内联横向翻页，点选与滑动互相跟随（`:2331-2351`） | **已复刻** | `MaterialSheetBody.kt:53-75`（`rememberPagerState` + `HorizontalPager` + `TabRow.onTabSelected`） | L0（`MaterialSheetPages` 常量 + 页序）+ 真机 |
| E3 | 通用页顺序 = 总闸 → 顶栏玻璃 → 高级材质 → 只读地图（`:921-924`） | **已复刻** | `SettingsMaterialPanels.kt:53-119` | L0 |
| E4 | 默认材质两档（实体 / 液态玻璃）+ 实体档说明（`:974-993`） | **已复刻** | `SettingsMaterialPanels.kt:59-79`（RADIO + 条件 `SettingsDescription`） | L0 |
| E5 | 首页顶栏玻璃三档（跟随默认 / 实体 / 液态）（`:1007-1017`） | **已复刻** | `SettingsMaterialPanels.kt:88-100`、`:254-259` | L0 |
| E6 | 档位滑杆：`min 1 / max 10 / divisions 9`、**10 格全画节点**、读数只给数字（`:1410-1449`） | **形态不对** | `SettingsMaterialPanels.kt:143-163` 是 `MiuixRowComponent.SLIDER` + `SettingsSliderSpec`，量程/分格对，但 `keyPoints`（轨道节点）在 Kotlin 行模型里没有表达位（`SettingsSliderSpec` 只有 min/max/divisions/defaultValue）⇒ 「带节点」这一视觉特征丢失 | L0（量程可断）+ 真机（节点看不看得到） |
| E7 | 八根旋钮（折射量 0–20/40 格、带 1–24/46 格、陡缓 1–6/20 格、色散 20 格、边缘强度 20 格、边缘宽度 0–3/30 格、模糊 0–40 每格 1、染色 20 格；读数格式 1 位 / 2 位 / 百分比 / 整数）（`:1471-1577`） | **已复刻** | `SettingsMaterialPanels.kt:271-359` 逐根对齐（含 `format(…,1)` / `percent` / `blurSigmaMax.roundToInt()`） | L0（`SettingsMaterialModelTest` + 本页测试已钉） |
| E8 | 「恢复默认」按钮（只恢复液态调参）+ 一句范围说明（`:1053-1085`） | **形态不对** | `SettingsMaterialPanels.kt:178-195`：按钮降级成 `ARROW` 行 + `RESET_SCOPE` target `liquidGlass`；且该 action 在壳里也无落点（本面板无宿主） | L0（target 常量）+ 真机 |
| E9 | 深色更暗开关（`:1095-1104`） | **已复刻** | `SettingsMaterialPanels.kt:202-209` | L0 |
| E10 | 独立设置深色档开关（**取反**语义）（`:1105-1123`） | **已复刻** | `SettingsMaterialPanels.kt:210-218`（`switchValue = !linkLiquidGlassTuning`） | L0 |
| E11 | 深色档八根旋钮（独立时显示，回落链 深色??浅色??默认）（`:1130-1139`、`:1373-1386`） | **已复刻** | `SettingsMaterialPanels.kt:223-233` | L0 |
| E12 | 玻璃坞作用范围开关（`:1148-1157`） | **已复刻** | `SettingsMaterialPanels.kt:236-249` | L0 |
| E13 | 各表面当前材质三行只读（顶栏带 / 玻璃坞 / 课程卡片），推导与渲染门控同口径（`:1168-1191`、`:33-41`、`surface_material.dart`） | **已复刻** | `SettingsMaterialPanels.kt:386-413` + `SettingsMaterialModel.kt:296-346` | L0（推导可逐条断言） |
| E14 | 课程卡片页：卡片外观三档 chips（`:1244-1253`） | **已复刻** | `SettingsMaterialPanels.kt:481-493`（RADIO，三档 = `CourseCardSurfaceStyle` 三个值） | L0 |
| E15 | 「总闸会盖过本页」提示只在确实被压住时出现（`:1223-1225`、`:1254-1262`） | **已复刻** | `SettingsMaterialPanels.kt:495-501` + `SettingsMaterialModel.kt:355-357` | L0 |
| E16 | 课程卡片档位滑杆（与通用页同一枚举、同一分格）（`:1274-1290`） | **形态不对** | 同 E6（`SettingsMaterialPanels.kt:512-536`） | 真机 |
| E17 | 卡片八根旋钮，模糊上限 `kPreblurMaxSigma = 24`（`:1294-1312`） | **已复刻** | `SettingsMaterialPanels.kt:537-547` + `SettingsMaterialModel.kt:71` | L0 |
| E18 | 面板里**不开二级弹层**（滑杆关掉点标题弹数字框、选项用内联胶囊）（`:1432-1433`、`:2361-2372`、`:2400`） | **未验·真机** | Kotlin 用 `RADIO` / `SLIDER` 行；`MiuixRowComponent.RADIO` 点开后是不是二级弹层，取决于渲染层实现，未在设备上确认 | 真机 |
| E19 | 弹层里改一下、面板自己立刻重画（`_draftRevision` 订阅，`:187-193`、`:2293-2295`） | **完全没做** | 无草稿版本号 / 无订阅机制 | 真机 |

### F. 壁纸弹层（两页签）

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| F1 | 两页签「壁纸 / 设置」+ 内联翻页（`:2167-2205`） | **已复刻** | `WallpaperSheetBody.kt:40-71` | L0 + 真机 |
| F2 | 第一页顺序：选图块 → 最近使用 → 每日壁纸（`:440-476`、`:480-481`） | **已复刻** | `SettingsBackdropFlowPage.kt:83-179` | L0 |
| F3 | 选图块：标题 + 文件名（跨平台分隔符切）/「未选择」（`:857-895`） | **已复刻** | `SettingsBackdropFlowPage.kt:194-204` + `fileNameOf`（`:314-317`） | L0 |
| F4 | 文件已丢失的警示条（可点回选图、警示底色）（`:873-895`、`:946-989`） | **缺交互** | 行有了（`SettingsBackdropFlowPage.kt:206-216`），但 `target = backdrop.image.missing` 无接收方 | L0（可断言 target 有落点）+ 真机 |
| F5 | 「选择图片」独占一行（主操作）+ 已有壁纸时「调整位置 / 清除图片」第二行平分（`:896-936`；三颗挤一行会掉字，`:900-902`） | **形态不对** | `SettingsBackdropFlowPage.kt:217-238` 是**三条 `ARROW` 行**，不是「一主两副按钮」；且 pick / adjust 的 target 无接收方（`backdrop.image.pick` / `.adjust` 均 `null`） | 真机 |
| F6 | 「最近使用」缩略图条：高 116、卡宽 78、选中环、角标×、**长按**、确认条画在条外、删除 + 撤销 toast、正在用的那张不可移除（`:800-835`、`:816-818`、`settings_recent_wallpaper.dart:16/22/53-205`） | **形态不对** | `SettingsBackdropFlowPage.kt:98-116` 把整段压成一个 `SettingsInline(kind = CONTROL_CARD)`；`SettingsPageRenderers.kt:956-1020` 的 `ControlCard` 只会画「标题 + 副标题 + 一排按钮」，**没有横滑缩略图**；那颗按钮的 key 是 `homePageWallpaperRecentImageLabel`，`controlCardWiring`（`:1020-1037`）对它返回 `null` ⇒ **一颗点了没反应的死按钮** | 真机 |
| F7 | 每日壁纸入口按钮（整宽）→ 推图库页（`:482-499`、`:659-674`） | **缺交互** | 降级成 `ARROW` 行且 `target = bingWallpaperGallery` 无接收方（`SettingsBackdropFlowPage.kt:155-161`） | L0 + 真机 |
| F8 | 自动换开关：读图库台账、**打开即换一次**、四种结局各给一句 toast（`:515-555`、`:572-642`） | **缺数据源** | `BackdropFlowState.bingAutoApplyEnabled` 恒 `false`（`SettingsBackdropFlowPage.kt:351-352`），无常量桥到 `BingWallpaperStore`；`AUTO_APPLY_GOES_THROUGH_DRAFT = false`（`:57`）只是把「不写草稿」记成常量 | L0（只能断常量）+ 真机 |
| F9 | 第二页：背景随周次滑动开关（`:762-791`） | **已复刻** | `SettingsBackdropFlowPage.kt:258-265` | L0 |
| F10 | 第二页：壁纸模糊滑杆，**0 档显示「关闭」**、量程 0–24 每格 1、越界钳制（`:742-753`、`widgets/wallpaper_blur_tile.dart:56-84`） | **已复刻** | `SettingsBackdropFlowPage.kt:278-303` | L0 |
| F11 | 壁纸历史台账：全局 10 条、当前这张补最前、切回**连取景（alignX/Y/scale）一起**还原、淘汰时删文件且白名单三路并集、删除可撤销（`:281-437`、`:795-835`、`wallpaper_history.dart:20-56`） | **缺数据源** | `WallpaperPanelState.history` 默认空、`AppearanceEditorBridge.toState` 也没填（`AppearanceEditorState.kt:132`）；无台账、无白名单、无文件删除逻辑 | L0（`recentEntries` / `isRemovable` 可断，已有测试）+ 其余未验 |
| F12 | 壁纸位置编辑页（拖动取景、完成落盘、退出即删未采用的文件、压在弹层收起之后推）（`:676-720`、`:115-149`） | **完全没做** | 全仓无该页 | 真机 |
| F13 | 每日壁纸图库页（网格 + 缓存态 + 失败重试 + 选图后在它之上叠位置页）（`:644-674`、`lib/screens/settings/bing_wallpaper_gallery_page.dart`） | **缺数据源 / 缺交互** | `SettingsBingWallpaperGalleryPage.kt:63-` 有节点模型，但 `ShellPageIndex.kt:349` 喂 `BingGalleryState()`（空），且该路由无任何入口引用 | L0 + 真机 |

### G. 编辑语义（即时落盘 / 取消回滚 / 完成）

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| G1 | 即时落盘：改一下草稿就写盘（`:596-631`、`:75-76` 类注释） | **完全没做** | `CANCEL_TARGET` / `DONE_TARGET` 只是字符串常量（`SettingsAppearanceEditorPage.kt:50-54`），无任何宿主实现 | L0（将来可用「改一次 → 模型变」断言） |
| G2 | 滑杆 250ms debounce（`:622-628`） | **完全没做** | 无定时器/防抖 | L0（将来） |
| G3 | 串行保存队列 `_saveQueue`（`:185`、`:633-635`） | **完全没做** | — | L0（将来） |
| G4 | 落盘被拒 / 失败：草稿回滚到 provider 那份 + 提示（`:637-665`） | **完全没做** | — | L0（将来） |
| G5 | 退出前 flush 未到期的 debounce 草稿（`:587-592`） | **完全没做** | — | L0（将来） |
| G6 | 取消 = 用**进页时那份设置**整份回滚，再正常落一次（`:735-740`） | **完全没做** | `_openedWith` 无对应物 | L0（将来，可断言「取消后模型 == 进页快照」） |
| G7 | 完成 = 保留改动 + 发布退场图（`clone()`，`:672-675`、`:751-775`） | **完全没做** | 无退场源概念 | 真机 |
| G8 | 连点退出的守门 `_exiting`（`:132`、`:702-727`） | **完全没做** | — | 真机（连点两次） |
| G9 | 退出时先摘掉仍压栈的弹层路由，否则「完成要点两次」（`:679-727`） | **完全没做** | 无弹层路由 | 真机 |
| G10 | 深链接 `initialMaterialPage`：课程卡片页「卡片外观」直达材质面板第二页（`:78-88`、`:390-410`、`:560`） | **缺交互** | 常量在（`SettingsMaterialSheetPage.COURSE_CARD_PAGE_INDEX = 1`，`SettingsAppearanceEditorPage.kt:178`），但无入口、无宿主消费 | L0（可断「存在直达常量」）+ 真机 |
| G11 | 壁纸流程「先收起弹层再推整页」（否则页面在弹层背后点不到）（`:122-127`、`:656-674`） | **完全没做** | 无该机制 | 真机 |

### H. 加载罩

| # | Dart 功能点（行号） | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| H1 | 三态加载罩（showing/fading/gone）、180ms 淡出、**6s 兜底**、暗底不透明、转圈 + 「加载中」、只在不透明时挡点击（`:1849-1871`、`:277-301`、`:2515-2650`） | **完全没做** | 只有 `LOADING_LABEL` 常量（`SettingsAppearanceEditorPage.kt:47-48`） | 真机 |

### I. 文案

| # | Dart 功能点 | Kotlin 现状 | 证据 | 怎么证 |
|---|---|---|---|---|
| I1 | 全部上屏文案走 ARB（`:1868`、`:2167-2175` 等） | **已复刻** | `SettingsStringsExt1` / `SettingsStrings` 取键，无硬写中文 | L0（`SettingsArbParityTest` 等） |
| I2 | 页签名不复用整页标题、不重名（「壁纸/设置」「通用/课程卡片」）（`:2167-2175`、`:2312-2314`） | **已复刻** | `SettingsAppearanceEditorPage.kt:172-176`、`:193-196` | L0 |
| I3 | 行内文案 ≤11 / 说明 ≤17（AGENTS.md COPY-STYLE） | **已复刻（新增 0）** | `dart run tool/copy_style_lint.dart` 输出见 §4.3 | 命令 |

### J. 数据源 / 接线（系统性问题，见 §4 详述）

| # | 项 | Kotlin 现状 | 证据 |
|---|---|---|---|
| J1 | 路由喂空 state | **缺数据源** | `ShellPageIndex.kt:344`（`spec(SettingsPageState())`）、`:345-347`、`:349` 全是空构造 |
| J2 | 空回调 / target 无落点 | **缺交互** | `ShellPageIndex.kt:1369-1381`（`SettingsScreen`）+ `ShellWiring.kt:687-731` |
| J3 | 材质/壁纸键不在设置模型 | **缺数据源** | `TimetableSettingsModel.kt:53-200`（字段全表）+ `AppearanceEditorState.kt:111-123` |
| J4 | 分派器无 material/backdrop 分支 | **缺数据源** | `SettingsActionDispatcher.kt:115-240`（常量表）、`:952`、`writeSetting` 的 `else ->` |
| J5 | 桥接白名单不含本页 | **缺数据源** | `SettingsPageBridge.kt:51-56`（只有 4 页：general / appearance / theme / courseCard） |
| J6 | 面板页不可达 | **缺交互** | `b.materialGeneral` / `b.materialCourseCard` / `b.backdropFlow` / `b.recentWallpaper` / `b.bingGallery` 除 `ShellPageIndex.kt:345-349` 外**零引用** |
| J7 | 新建的两个面板 Body 无调用方 | **完全没做（接线）** | `grep -rn "MaterialSheetBody\|WallpaperSheetBody" android/app/src` 只命中定义本身（`MaterialSheetBody.kt:46`、`WallpaperSheetBody.kt:40`）与注释 |

---

## 2. 与 Dart 的逐项对照：几何与数值（供 B 段复核）

Lead 给的版式基准我已逐条回 Dart 核对，**基准本身是对的**，出处如下（B 段要拿这一列当尺子）：

| 基准项 | Dart 出处 | 值 |
|---|---|---|
| 可用宽系数 | `:114` | `0.86` |
| 顶部净空 | `:1624` | `topInset + 16 + 40 + 18` |
| 底部净空 | `:1625` | `bottomInset + 24 + 56 + 8 + 18` |
| 等比缩放 | `:1632-1635` | `min(availW/screenW, availH/screenH)` |
| 卡片圆角 | `:1639-1642` | `min(屏幕圆角 × scale, cardH/2)` |
| 卡片居中 | `:1647` | `topReserve + availH/2`，无手工偏移 |
| 浮影 | `:107`、`:1838-1839` | `0x66000000`、blur 32、spread 2 |
| 胶囊按钮 | `:1931-1933` | `84 × 40`，底白 14%、描边白 18%、字 15（完成 w600） |
| 日/周分段 | `:1985-2008` | 容器白 12% + 14% 描边 + padding 3；选中白 92% + `0xFF1A1A1A`，字 14 |
| 顶栏内缩 | `:1892` | `(20, topInset+12, 20, 0)` |
| 圆钮 | `:2064-2086` | `56 × 56`、图标 26、名字 12（白 86%）、两钮间距 40 |
| 底栏留白 | `:2027` | `bottomInset + 16` |
| 弹层高度上限 | `:120`、`:162-166`、`:839-841` | 屏高 × `0.5` |
| 把手悬浮 | `:786-789`、`:2296-2311` | `reserveDragHandleStrip = false`，带高 = 把手 24 + 胶囊 40 |
| 卡片重烤时机 | `:1684-1704` | 路由落定后挂渲染源，`pixelRatio = dpr` |
| 加载罩兜底 | `:301` | 6 s |

---

## 3. 三类系统性问题（单列）

### 3.1 传空 state ⇒ 值恒为出厂、写了不落盘

- 入口 `ShellPageIndex.kt:344`：`SettingsScreen(SettingsAppearanceEditorPage.spec(SettingsPageState()), onBack)`。
  `SettingsPageState()` 是**全默认构造**，页面拿不到用户任何真实设置。
- 五个面板/子页同病：`:345`（`SettingsMaterialGeneralPage.spec(SettingsPageState())`）、
  `:346`（`SettingsMaterialCourseCardPage`）、`:347`（`SettingsBackdropFlowPage.settingsPage(BackdropFlowState())`）、
  `:348`（`RecentWallpaperState()`）、`:349`（`BingGalleryState()`）—— 全是空构造。
- 模型层没有这些键：`TimetableSettingsModel.kt:53-200` 里既无材质那十几个键，也无壁纸那七个键。
  `AppearanceEditorState.kt:111-123` 的自述直接点名了这件事（引文见 §0 第 4 条）。
- 结论：**即使把面板接上屏，每一行显示的都是出厂值，拖滑杆也不会改任何东西**——这是「看起来能点、其实没写」的最坏形态，比「没做」更容易误判为完成。

### 3.2 空回调 ⇒ 点了没反应

- 页面级：`SettingsScreen`（`ShellPageIndex.kt:1369-1381`）的 `onAction` 只做
  `shellPageIdForRoute(target)?.let(openPage)`。于是：
  - `appearanceEditor.wallpaper` / `.material`（SHEET）→ `null` → nothing
  - `appearanceEditor.cancel` / `.done`（NAVIGATE）→ `null` → nothing
  - 面板里 `backdrop.image.pick` / `.adjust` / `.missing` / `bingWallpaperGallery` → `null` → nothing
- 写设置级：`SettingsActionDispatcher` 无 `material.*` / `backdrop.*` / `appearanceEditor.*` 常量，
  `writeSetting` 落到 `else ->` 返回 `Ignored("未识别的 rowId")`（`:952` 附近）。
- 死按钮实例：`backdrop.recent` 的控制卡按钮（`SettingsPageRenderers.kt:1020-1037` 对
  `homePageWallpaperRecentImageLabel` 返回 `null`）—— 按钮画出来了，但连 `onAction` 都不会触发。

### 3.3 文案一致性

- **与 Dart 一致**：页面标题、两枚胶囊、日/周、两颗圆钮、两个面板页签、材质各节标题与旋钮名、
  壁纸各节文案，全部走 `SettingsStrings*`/`SettingsStringsExt*`，与 ARB 同键同值（`L0` 的
  `SettingsArbParityTest` / `SettingsStringsExt*ParityTest` 已覆盖）。
- **复述标题 / 超宽**：`dart run tool/copy_style_lint.dart`（2026-10-29 20:52 跑）：

  ```
  == 行内文案超宽：203 条（存量已冻结 203，新增 0）==
    ✓ 没有新增违规
  == 死键：537 条（存量已冻结 537，新增 0）==
    ✓ 没有新增死键
  == 说明句复述标题：0 条（存量已冻结 0，新增 0）==
    ✓ 没有新增复述
  ```

  ⇒ 本轮新增文案**没有**超宽、复述、死键。
- 唯一文案层面的形态疑问（不算违规）：Dart 的「最近使用」段是缩略图 + 说明句（说明句是整宽段落），
  在 Kotlin 里被塞进 `ControlCard` 的副标题位（`SettingsBackdropFlowPage.kt:104-113`），
  位置语义变了 —— 记在 F6，不重复计违规。

---

## 4. 证据分级汇总（本文所有结论的成色）

| 级别 | 本文里有哪些 | 说明 |
|---|---|---|
| **编译级** | 我**没有**跑 L1（本轮纪律：不跑 `safe-gradle.ps1`）。因此「Kotlin 编得过」这件事**未验**；我只能确认现存文件在 HEAD 上是已提交状态（除 20:38–20:43 三个新文件） | 不可当验收凭据 |
| **单测级** | 只有**模型结构**被断言：`SettingsAppearanceEditorPageTest.kt`（538 行）、`SettingsMaterialModelTest.kt`、`SettingsHomeBackdropFlowPageTest.kt`、`SettingsRecentWallpaperPageTest.kt`、`SettingsBingWallpaperGalleryPageTest.kt` | 见 §4.1 的「牙齿评估」 |
| **未验·真机** | A1–A7、B、C、D、E1、E18、E19、F4–F7、F12、G7–G11、H1 的**观感与交互** | 需要用户在 `PagesShellActivity` dev 变体上操作 |

### 4.1 现有单测的牙齿评估（它们证明不了什么）

- `SettingsAppearanceEditorPageTest.kt:45-53` 断言「预览卡在最上方且没有标题字」——这正是**空卡**的
  授权书：测试把「没内容」写成了期望值。它钉的是「占位节点存在」，不是「预览是那张课表」。
- `:78-94` 断言 `chromeRows()` 是 `["取消","完成"]` 且**不在** spec 里 —— 于是任何渲染器都不画它们，
  测试却是绿的。
- `:64-76` 断言两条底部行 `action == SHEET` —— 但**没有一条**断言 `actionTarget` 在壳里有落点。
  这正是 §3.2 的 no-op 能一路绿过来的原因。
- 全文件**没有**任何一条断言「state 来自 `TimetableSettingsModel`」或「dispatch 后模型变了」。
- ⇒ 依 TEST-POLICY 的「参数透传类改动必须断言目标对象实例字段」，这里缺的正是那一层契约测试。
  B 段要补的探针见 §6。

### 4.2 我实际跑过/没跑过的命令

| 命令 | 结果 |
|---|---|
| `git rev-parse --short HEAD` | `3f3b7354` |
| `git status --porcelain` | 27 项改动（多为其他泳道）；本域新增 `AppearanceEditorState.kt`（未跟踪）、`MaterialSheetBody.kt`、`WallpaperSheetBody.kt` |
| `dart run tool/copy_style_lint.dart` | 新增违规 0 / 死键 0 / 复述 0 |
| `grep` 系列（可达性、键存在性、调用方） | 见各行证据 |
| L0 单测 | **未跑**（A 段尚未有本轮新增代码需要验；B 段跑，避免白烧 600–800MB JVM） |
| L1 编译 / L2 单测 / 真机 | **未跑**（纪律禁止 / 需用户配合） |

---

## 5. A 段的「当前判定分布」（合计 78 条）

| 状态 | 条数 | 条目 |
|---|---|---|
| 已复刻 | 21 | E2、E3、E4、E5、E7、E9、E10、E11、E12、E13、E14、E15、E17、F1、F2、F3、F9、F10、I1、I2、I3 |
| 形态不对 | 9 | C1、C2、C3、D1、E6、E8、E16、F5、F6 |
| 缺数据源 | 8 | B5、F8、F11、F13（同时缺交互，只计一次）、J1、J3、J4、J5 |
| 缺交互 | 7 | A4、D3、F4、F7、G10、J2、J6 |
| 完全没做 | 31 | A1、A2、A3、A5、A6、A7、B1、B2、B3、B4、B6、B7、B8、B9、C4、D2、E1、E19、F12、G1–G9、G11、H1、J7 |
| 未验·真机 | 2 | C5、E18 |

> 21 + 9 + 8 + 7 + 31 + 2 = 78，与表中条目数一致。
> **「已复刻」21 条全部落在模型/文案层**（面板节点树、只读推导、ARB 取值）；
> **屏上能看到的形态一条都没复刻**（A 组 7 条里 6 条完全没做、1 条缺交互）。

---

## 6. B 段（对抗验证）计划 —— 等 Lead 通知「实现完成」后执行

按 T5 描述，B 段要做的四件事，先把「怎么下手」写死，避免到时候凭印象：

1. **逐条复核「已复刻」22 条，找最强反驳**，重点四类：
   - **几何数值**：卡片 `0.86` / 上下净空 / 圆角×scale / 浮影三参数 / 胶囊 84×40 / 圆钮 56×56 间距 40 /
     底栏 `bottomInset+16` / 弹层 `0.5` 屏高 —— 逐项与 §2 表对，差 1dp 也算「不是一模一样」。
   - **状态桥是否真读真键**：`AppearanceEditorBridge.toState` 是否逐键映射（现在只有
     `courseCardSurfaceStyle` + `previewDayView`）；每个字段是否带 Dart 行号；
     `WallpaperPanelState` 是否还在空构造。
   - **取消回滚是否真回滚**：断言「进页快照 → 改 3 处 → 取消 → 模型 == 快照」，
     而不是「按钮存在」。
   - **面板里有没有二级弹层**：`RADIO` / `SLIDER` 行点击行为是否在弹层之上再开路由（会落在面板背面）。
2. **咬合探针**（每条守卫/断言都要能红）：
   - 把 `AppearanceEditorBridge.toState` 里的某个键改成写死值 → 契约测试必须红；
   - 把 `SettingsAppearanceEditorPage.spec` 的 `PREVIEW_CARD` 换成 `CONTROL_CARD` → 结构测试必须红；
   - 把「最近使用」的 `controlCardWiring` 判定改成恒返回 → 死按钮守卫（若新增）必须红；
   - 把 `shellPageIdForRoute` 里新增的 appearance 目标删掉 → 落点守卫必须红；
   - 每一条探针做完立刻还原，并 `git diff -- <被改文件>` 确认干净（本轮纪律：不改实现文件，
     探针若必须碰实现文件，只做「改 → 跑 → 还原」，且必须在报告里列出改过哪几行、还原后的 diff 为空）。
3. **证据分级重写**：把每条「已复刻」标成 `编译级` / `单测级` / `未验·真机` 三档之一；
   任何 `未验·真机` 的项不许出现在「已完成」里。
4. **更新本表状态**：以 B 段开工那一刻的 `git rev` 为新快照，逐行改状态并注明「B 段复核」，
   过期结论一律改写（A 段快照仍是 `3f3b7354` / 20:54）。

### 6.1 已知会被 B 段重点打的三处「假绿」

- **E6/E16 档位滑杆的「10 格节点」**：量程与分格都对，`keyPoints` 这个视觉特征在 Kotlin 行模型里没有
  表达位。若实现者声称「一模一样」，这是最容易被一句「节点呢？」打掉的地方。
- **F6 最近使用缩略图条**：`CONTROL_CARD` 渲染器根本没有横向缩略图能力，
  但它带着 `note`（自述是缩略图条），**结构测试只断言 `id` 存在**，所以绿。B 段必须断言
  「渲染器真的能画缩略图」而不是「节点 id 在里面」。
- **J2/D3 落点**：现在没有任何守卫断言 target 可达。这类「点了没反应」是本仓反复吃过的病
  （见 `ShellPageIndex.kt` 里 2026-10-29 补口那段注释），B 段要把它做成守卫。
