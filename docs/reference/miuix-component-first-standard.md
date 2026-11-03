# 软件标准：miuix 组件优先（禁止自研 UI / 交互 / 动画）

> 状态：**生效**。由用户于 2026-10-28 明确拍板。适用于本项目全部前端界面（Flutter 端按 `flutter_miuix`/官方口径对齐；Compose 端 `composeP1` / `composeUi` 全部页面）。
> 关联：`docs/reference/miuix-api-mapping.md`、`docs/reference/miuix-demo/`（官方 demo 只读副本）、`AGENTS.md`。

## 一句话标准

**能用 miuix 组件的，一律用 miuix 组件。不自研。**

## 硬规则

1. **组件**：所有可见 UI（按钮、卡片、列表、顶栏、底栏、弹层、对话框、开关、选择器、图标等）
   必须来自 `top.yukonga.miuix.kmp.*`（`miuix-ui` / `miuix-preference` / `miuix-icons` /
   `miuix-blur` / `miuix-squircle` / `miuix-shader` / `miuix-nav` 等官方 artifact），
   或官方 demo 里对它们的直接用法。
2. **交互与动画/转场**：必须使用 miuix 官方能力，**不得**用底层 Compose/Flutter 原语
   手搓一套替代品。典型禁止项：
   - 页面/视图转场用 `AnimatedContent` / 自写 `slideIn*` `fadeIn*` / `PageRouteBuilder`
     之类自研转场 —— **必须**用 `miuix-nav` 的 `NavDisplay`
     （`NavTransitions.MiuixDefault` + `NavDisplayEffects.Default`）。
   - 手搓弹层、下拉、气泡、设置行 —— 用 `Overlay*` / `*Preference` 等官方组件。
   - 手写模糊/圆角/折射 —— 用 `miuix-blur` / `miuix-squircle`。
3. **本地薄封装只允许「不改变行为」的情形**：例如 `QingyuCard` 仅在内部直接调用 miuix `Card`
   并做主题/内边距透传时才允许；一旦开始自己画形状、自己写动画、自己模拟按压反馈，即视为自研，
   触碰第 2 条。能直接用 miuix 组件的，**优先直接用**，不要为封装而封装。
4. **例外（迫不得已才自研）**：
   - 前提：miuix 明确没有该能力，且无法用现有 miuix 组件组合出来。
   - 流程：**必须先取得用户明确同意**，并在下方「例外审批登记」里写明：自研内容、理由、
     miuix 为何不可行（贴源码出处）、影响范围、后续替换计划。
   - 未经审批的自研 = 违规，评审/守卫应拦截。

## 落地与守卫

- 评审时按本文件逐条核对；发现自研替代 miuix 已有能力即打回。
- 后续应补一条架构守卫（源码级）拦截常见自研转场（如 `AnimatedContent` / `slideInHorizontally`
  出现在页面导航处），把本文件变成可执行的闸门；在守卫落地前，由评审人工把关。
- 本文件由 `AGENTS.md` 引用；新增/修改页面时先读本文件。

## 例外审批登记（当前 5 条：桌面小组件「效果预览」轮播 2026-10-31；壁纸取景页平移/捏合手势 2026-11-01；数值滑杆「点轨道跳值」2026-11-02；首页周/日页内展开 2026-11-02；弹窗玻璃表面 2026-11-03）

| 日期 | 位置（文件:行） | 自研内容 | 为什么 miuix 不行（出处） | 影响范围 | 负责人/审批 |
|---|---|---|---|---|---|
| 2026-10-31 | `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/HomeWidgetPreviewCarousel.kt`（`WidgetPreviewSection` / `PreviewDots` / `PreviewImage`） | ① 用 `androidx.compose.foundation.pager.HorizontalPager` 做**卡片位图轮播**；② 自绘 10 个指示点（当前页 14×5、其余 5×5、圆角 3、`animateDpAsState`）；③ 位图本身用 `Modifier.shadow` 加投影（Dart 是 `blurRadius 18 / offset(0,5) / spread -2`） | miuix 0.9.4 的组件清单里**没有轮播 / 图片分页控件**：`miuix-ui` 的 `basic` 包只有 Card/Button/List/Scaffold 等，`utils` 里只有一个 `PagerGestureUtils.kt`（手势接管工具，不含分页容器本身）；`Card` 也没有 elevation/shadow 参数（`basic/Card.kt:163-183` 的 `BasicCard` 只画 `squircleSurface`），指示点更没有对应物。同仓先例：`pages/settings/MaterialSheetBody.kt:208` 的 `HorizontalPager` 也是同一路做法 | 仅「桌面小组件」设置页的效果预览区（10 张真实卡片位图）；不影响其它页面、不影响桌面下发路径 | Lead 代为登记；审批依据「用户要求页面与 Flutter 原版一致」（`settings_home_widget.dart:405-499`） |
| 2026-11-01 | `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/WallpaperPositionPickerPage.kt:138-178`（`rememberTransformableState`）、`:232-238`（`Modifier.transformable`） | 壁纸取景页的**平移 + 捏合手势层**：用标准 Compose `Modifier.transformable` 同时接单指拖动与双指缩放，手势只产出 `alignX` / `alignY` / `scale` 三个数；不写动画、不画形状、不做按压反馈 | miuix 0.9.4 **没有图片取景 / 平移缩放 / 裁剪组件**。实证：解包 7 个 `*-sources.jar`（`miuix-ui` / `miuix-preference` / `miuix-icons` / `miuix-blur` / `miuix-squircle` / `miuix-shader` / `miuix-nav`，共 330 个 `.kt`），`grep -rn "transformable\|detectTransformGestures\|rememberTransformableState\|TransformableState"` **0 命中**；`zoom\|pan\|crop\|pinch` 只命中 `expand` / `TooltipAnchorPosition` 等无关词；`miuix-ui` 没有 `Image` / `AsyncImage` 组件（全包无 `fun Image(`）；`utils/PagerGestureUtils.kt` 只接管 `HorizontalPager` 手势，`Slider` / `SliderPreference` 是数值滑杆；官方 demo 里也没有取景/裁剪页（`docs/reference/miuix-demo` 只找到 `ZoomOut` 图标） | 仅 `WallpaperPositionPickerPage.kt` 的手势接线；取景几何、夹取与落盘都在纯函数 `SettingsWallpaperPositionPage`（`main/.../SettingsWallpaperPositionPage.kt:135-219`），不涉及共享套件 / 主题 / 页面壳 | 用户 2026-11-01 明确同意（「继续做你刚刚建议的」）；本会话登记 |
| 2026-11-02 | `android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/QingyuSlider.kt`（`QingyuSlider` / `QingyuSliderPreference`）、`components/SliderTapMath.kt` | 在官方 `Slider` 的 `modifier` 外层加**一层点击手势**（`awaitEachGesture`：按下即消费、越过 touch slop 就放弃），点击时按官方几何换算出值并回调一次；`QingyuSliderPreference` 是官方 `SliderPreference` 的逐字副本，仅把内层 `Slider` 换成本件。不画形状、不做动画 / 按压反馈 / 触感（这些仍由官方组件产出） | miuix 0.9.4 的 `Slider` **只挂了 `Modifier.draggable`**：纯点一下（不越过 touch slop）`draggable` 不启动，一次回调都不发（源码 `miuix-ui/.../basic/Slider.kt:159-238` 只有 hover 的 `pointerInput` + `draggable` + semantics，无任何 tap 手势；`SliderPreference.kt` 也没把内层 Slider 的 `modifier` 开放出来，行外补点击会被 `BasicComponent` 的行点击抢走且要猜内部几何）。Flutter 侧 `MiuixSlider` 有 `onTapUp → _jumpTo`（fork `flutter_miuix` 的同名文件 `:375-434`），迁移到 Compose 后该能力丢失 | 全部 Compose 数值滑杆：设置行 `QingyuSliderPreference`、显示设置 4 根、颜色通道 3 根、组件展示页 6 根；视觉 / 动画 / 触感仍由官方 `Slider` 产出 | 用户 2026-11-02 明确要求（「点击某一个位置的时候，没有调过去……修复一下」）；本会话登记 |
| 2026-11-02 | `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekPage.kt`（`dayExpand` / 展开窗口的 `drawWithContent`）、`main/.../pages/timetable/HomeViewExpandMotion.kt` | 首页「周 ↔ 日」的**页内展开动画**：一个 `Animatable` 驱动 0..1，选中列按 `homeViewExpandWindow` 的纯几何长到整屏；窗口边界只在 draw 阶段读动画值（不重组 / 不重排）。曲线与时长对齐 Flutter `DayViewExpandMotion`（210ms × 用户倍率、`Cubic(0.25,0,0.75,1)`）。**2026-11-03 按用户真机口径（「直角切口廉价丑陋」）升级为圆角形变窗口**：`clipPath(RoundRect)` 从选中列格插值到整屏，种子圆角 28dp 全程保持满值、只在贴边前最后 0.002 带内收平（逐点照抄 Flutter `anchorExpandRadius`/`anchorExpandCornerSettleBand`，`hyperos_navigation.dart:162-174`、`hyperos_miuix_spec.dart:884`；技法与 miuix 官方内部件 `CascadingMorphContent` 的 RoundRect 插值同款）；含「减少动画」降级（`ANIMATOR_DURATION_SCALE==0` 时双向 snapTo 落定，`dce80419`）。落定帧 progress=1 ⇒ 圆角恰为 0 ⇒ 裁切 no-op。**2026-11-03 阶段 A（摘要卡飞行）**：星期栏选中格 → 日视图摘要卡的元素飞行——起点按星期栏实测宽度与时间列换算成格位、终点取真摘要卡的 `boundsInRoot` 实测（禁写死比例）；几何 / 圆角（14→16dp，终点与 `QingyuShapes.CARD_CORNER` 同值）/ 文案切换（0.45）/ 卡面淡入（前 30%）全部收在纯函数 `HomeViewExpandFlight.kt`（JVM 可测），渲染层只调用不另写插值；飞行层挂在裁切窗口的**兄弟层**（起点在内容区局部 y<0，要越过星期栏）；真摘要卡在飞行期间由 `drawWithContent` 在绘制期门控隐藏（不触发重组）；玻璃卡面零 `alpha`，只对文字 / 图标取 alpha | miuix-nav 只管**路由**转场（`NavTransitions` 作用在 `NavDisplay` 条目上），没有「同一页内两个视图态之间的锚点展开」能力；miuix-ui 的形变件 `CascadingMorphContent`/`MorphHeaderRow` 是 **internal** 且仅下拉菜单专用（0.9.4 sources 实证）；Flutter 原版这一条本身就是自绘几何（`timetable_anchored_day_overlay.dart` + `day_week_morph_layout.dart`），不是任何导航库的预设。若硬用 `NavDisplay` 的 `Replace`，会得到用户实报的「从左侧滑入」。2026-11-03 补充实证：0.9.4 全部 sources 与 `third_party/miuix-ui` 副本中 `SharedTransition` / `sharedElement` / `SharedBounds` **0 命中**，官方不提供「两个层级间的共享元素飞行」，只能由页面按实测 bounds 自算 | 仅首页课表（`c1.week` 宿主）的周/日展开层、摘要卡飞行层与星期栏点击；不涉及设置页、弹层或其它路由转场（那些仍走官方 `NavDisplay`） | 用户 2026-11-02 明确要求「按原版 Flutter 的切换动画补齐」；2026-11-03 真机否掉直角版后用户拍板「直接落方案 A」（圆角形变升级）；本会话登记更新 |
| 2026-11-03 | `components/glass/GlassOverlayDialog.kt` + `components/glass/QingyuDialogGlass.kt`（弹窗表面玻璃封装，**试点唯一调用点**：`pages/course/AddCoursePage.kt` 删除课程确认） | 官方 `OverlayDialog` 容器 + 官方公开参数（`cornerRadius` 32dp 锁定 / `backgroundColor` 半透明压色 亮0.78·暗0.87）+ miuix-blur 官方模块的 `drawBackdrop(colorControls 饱和度1.5 + blur 24dp, highlight=GlassStrokeMiddle*)` 三层玻璃面；`QingyuDialogGlass.enabled=false` 一键回退实心 | 官方 miuix-ui 0.9.4 的 `OverlayDialog` **没有任何玻璃参数**（`overlay/OverlayDialog.kt` 全参实证：仅 title/summary/backgroundColor/enableWindowDim/insideMargin/cornerRadius 等，无 backdrop/blur；`DialogContentLayout.kt` 表面固定 `squircleSurface` 实心）。玻璃效果需要改 `DialogContentLayout` 内部（fork 做法如 NexioSchedule 的 `miuix/` 目录），用户 2026-11-03 拍板「改库」后，为守住「diff = 单文件级别、不整库搬」的红线，改用官方公开参数 + miuix-blur 官方模块组合实现同等材质；`miuix-blur` 的 `drawBackdrop/highlight/colorControls/blur` 均为公开 API（`DrawBackdropModifier.kt:103-108`） | 仅试点弹窗 1 处；`QingyuPageScaffold` 通过新增 `LocalQingyuPageBackdrop` 把既有页面录像带给弹窗复用（不新增图层录制）；其余 46 处弹窗与全部底部弹层保持现状，守卫 `QingyuGlassDialogGuardTest` 钉住调用点数=1；铺开须用户真机看过效果后再批 | 用户 2026-11-03 明确批准（「改库……弹窗可以先改一个，我看看效果」）；本会话登记。上游若官方暴露弹窗玻璃参数即撤回本封装 |

## 2026-11-01 例外复核记录（只记录，不是审批）

**口径**：本节列出的未登记项**没有**用户审批，不算例外登记；处理方式只能是「改用官方件 / 补审批 / 明确记为已知差异」。登记表只收用户点头的条目。

**复核方法（可复现）**：

```bash
# 1. 解包 0.9.4 全部 sources（本项目 2026-11-01 实测：7 个 jar、330 个 .kt）
find ~/.gradle/caches/modules-2/files-2.1/top.yukonga.miuix.kmp -path '*0.9.4*' -name '*-sources.jar'
# 2. 逐个解包后搜候选能力
grep -rn "transformable\|detectTransformGestures\|rememberTransformableState" --include='*.kt' .
grep -rnE "Reorder|reorderable" --include='*.kt' .
grep -rnE "\b(Chart|Plot|Graph|Diagram)\b" --include='*.kt' .
grep -rniE "qrcode|barcode" --include='*.kt' .
grep -rnE "fun (Image|AsyncImage|NetworkImage|BitmapImage)\(" --include='*.kt' .
# 3. 官方 demo 同口径再搜一遍
grep -rniE "transformable|crop|pinch|zoom" docs/reference/miuix-demo --include='*.kt'
```

**已登记行复核**：2026-10-31 轮播行仍然成立（无轮播容器、`Card` 无 elevation/shadow、引用的 `MaterialSheetBody.kt:208` 仍是 `HorizontalPager`）。没有需要撤回的旧登记。

**未登记清单（自研且 0.9.4 无对应物，按规则 4 应补审批）**：

| # | 位置 | 自研内容 | 0.9.4 核对结论 | 建议 |
|---|---|---|---|---|
| 1 | `pages/timetable/month/MonthPanelDragArea.kt:81-90`、`MonthGridHandle.kt:72-84`、`MonthViewPage.kt:97` / `:206-210` | 日历/议程两段式面板的纵向拖拽 + 松手吸附（`pointerInput` + `Animatable`） | 无折叠面板组件；`OverlayBottomSheet` 是浮层，`PullToRefresh` 是刷新，`Snackbar` 内部的 `anchoredDraggable` 不是公共组件 | 补审批或改官方方案 |
| 2 | `pages/settings/DockMenuEditors.kt:524-544` | 底栏 / 八宫格「已启用」长按拖动排序（`detectDragGesturesAfterLongPress` + `graphicsLayer`） | 无 reorderable list / 拖动排序组件（`Reorder` 0 命中） | 补审批或改官方方案 |
| 3 | `pages/statistics/charts/*.kt`、`pages/statistics/CourseStatisticsPage.kt:441` / `:772` / `:915` | 统计图表 `Canvas` 自绘（柱 / 环 / 折线 / 排名等） | 无 chart / plot / graph 组件（词边界搜 0 命中） | 补审批（图表属数据可视化，不是设置行） |
| 4 | `pages/transfer/QrMatrixCanvas.kt:38` | 二维码矩阵 `Canvas` 绘制 | 无 QR / barcode 组件（0 命中） | 补审批或记为已知差异 |
| 5 | `pages/guide/UserGuidePage.kt:145`、`pages/timetable/TimetableWeekPage.kt:207`、`pages/timetable/day/DayViewPage.kt:331`、`pages/settings/MaterialSheetBody.kt:208`、`pages/settings/WallpaperSheetBody.kt:346` | 页面 / 内容分页用 Compose `HorizontalPager` | 无分页容器；`PagerGestureUtils.kt` 只接管 `HorizontalPager` 手势 | 已登记行只覆盖 `HomeWidgetPreviewCarousel`；其余需补登记或归入同一条「分页容器」例外 |
| 6 | `pages/timetable/TimetableWeekdayHeader.kt:314`、`pages/settings/SettingsWeekPreview.kt:117`、`pages/timetable/TimetableWeekGrid.kt` | 星期栏 / 本周课表缩略图 / 周网格自绘 | 无课表网格组件 | 旧选型白名单（`docs/plans/2026-10-26-compose-miuix-components.md` §「必须自绘」②）有依据，但未迁入本表 |

**待核清单（可能可直接换官方件，优先整改而不是登记）**：

| # | 位置 | 现状 | 官方可替代 |
|---|---|---|---|
| 1 | `pages/course/CourseOverviewPage.kt:506` | 裸 `Popup` + 自拼三行 | `overlay/OverlayListPopup.kt:37`、`popup/OverlayDropdownPopup.kt:35`、`basic/ListPopup.kt:79` |
| 2 | `pages/timetable/TimetableProfilesPage.kt:291-301` | 自绘 Toast 浮层 + `AnimatedVisibility` | `basic/Snackbar.kt`（需确认壳里有无统一宿主） |
| 3 | `pages/timetable/day/DayViewCourseCard.kt:96-105`、`DayViewScheduleCard.kt:76-85` | `animateFloatAsState` 驱动的卡片内进度填充 | `basic/ProgressIndicator.kt`（视觉是否必须为卡片内填充需拍板） |
| 4 | `pages/guide/HyperosShowcasePage.kt:499-502`、`pages/settings/AppearanceEditorChrome.kt:410-416` | 内容展开 / 加载罩的 `AnimatedVisibility` | 无展开/收起组件；若判定属「自研动画」，需补登记 |

**判为非例外（已核实，不登记）**：

- `pages/shell/GlassDockNavigationBar.kt:141` + `components/liquid/*`：`lens` / `vibrancy` / `innerShadow` / `CombinedBackdrop` / `DampedDragAnimation` / `InteractiveHighlight` 六个件在 0.9.4 发布物里 **0 命中**，但整段来自官方 demo（`docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/component/`，Apache-2.0），按硬规则 1 的「官方 demo 直接用法」判为不构成自研例外。风险：0.9.x 升级时 demo 与发布物可能继续分叉，升级时要重验。
- `pages/settings/AppearanceEditorScreen.kt` 的 `consumeAllPointerEvents`：命中测试兜底，不产生可见 UI / 动画，不属于本标准管的自研 UI。
- `pages/shell/HomeWallpaperBackdrop.kt` 的壁纸 `drawRect`：miuix 无 `Image` 组件，属位图渲染而不是组件替代；本次登记行的「无 Image 组件」已把这条事实写死。

**旧选型白名单的过期项**（`docs/plans/2026-10-26-compose-miuix-components.md` §「必须自绘」，写于本标准之前）：

| 旧条目 | 现状 | 处理 |
|---|---|---|
| ① 日期 / 日历 / 时间选择器 | **部分过期**：时间选择器已用官方 `NumberPicker` 两列（`composeP1/.../SettingsHost.kt:797-840`）；日期选择器已用三列官方 `NumberPicker`（`SettingsSemesterHost.kt:219-282`）；只有月历层仍无官方对应物（未实现，`SettingsSemesterHost.kt:75-76` 已注明需另行拍板） | 把「时间选择器」从必须自绘里删掉；「月历层」若要 1:1 再单独立项审批 |
| ② 课表网格 / 周视图 | 仍成立（`TimetableWeekGrid` / `SettingsWeekPreview` 自绘） | 迁入本表第 6 条 |
| ③ 中间凸起 notched 导航 | **已不使用**：`grep notch` 只命中外观编辑页的转场预览，不是底栏 | 旧条目可删或标「未采用」 |
| ④ 骨架屏 shimmer | **已不使用**：`composeP1` 里 `shimmer` 0 命中（搜到的「骨架」都是页面骨架） | 旧条目可删或标「未采用」 |
| ⑤ 滚动顶栏实时模糊 | **已过期**：`components/QingyuPageScaffold.kt:82-98` 已按官方 demo 接线 `layerBackdrop` + `textureBlur`，属官方 `miuix-blur` 能力 + 自行接线，不是「必须自绘」 | 从必须自绘里删掉 |

## 当前落地状态（2026-10-28，已落地）

- Compose 页面壳 `PagesShellActivity` 已接入 **miuix-nav 的 `NavDisplay`**：底部四槽与页面层
  都放进返回栈（`ShellRoute = Dock(itemId) | Page(id) | ZoomPage(id)`），转场统一用
  `NavTransitions.MiuixDefault` + `NavDisplayEffects.Default` —— **没有一行自研动画**。
  2026-11-01 补：外观编辑页走 `ZoomPage`，用官方 `NavTransitions.None`（瞬时切换）把
  位移让给页面自己的缩放入场（Dart `HomeMenuEntry.zoomTransition` 同口径）——
  仍然是官方预设 + 官方按路由 `entry(transition = …)`，**不需要登记例外**。
  玻璃坞也由壳层搬进了栈底条目（`pages/shell/HomeGlassDock.kt`），与首页同属一棵子树。
- 因 `miuix-nav` 0.9.4 是 Java21 字节码且 `entry<T>` 为 `inline`，`:app` 已整体迁到 JVM21：
  - 根 `android/build.gradle`：`subprojects` 里 `:app` → `JVM_21`，其余子项目仍 `JVM_17`。
  - `android/app/build.gradle`：`compileOptions` 21 + `miuix-nav` 依赖。
  - `android/gradle/gradle-daemon-jvm.properties`：`toolchainVersion=21`。
  - `.github/workflows/*.yml`：`setup-java` 的 `java-version` 17 → 21。
  - 本机：`~/.gradle/gradle.properties` 的 `org.gradle.java.home` 指向已装的 Temurin JDK 21。
- 验证：`L1 :app:compileComposeUiDebugKotlin` 绿、`L2 :app:testComposeUiDebugUnitTest` 绿（均在 JDK21）。
  真机观感（L4）待用户核对。
- 迁移的坑与结论见 `.agents/notes/proposed/architecture/2026-10-28-compose-shell-page-transition-miuix-nav.md`。

