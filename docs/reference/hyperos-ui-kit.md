# mikcb HyperOS UI 库

对标小米 HyperOS / MIUI **系统设置**视觉与交互的 Flutter 组件库。  
代码入口：`lib/ui/hyperos/hyperos.dart`

> 与 Forui 的关系：Forui 只保留为历史/兼容残留；新业务页的默认壳层、列表和交互应使用本项目 HyperOS facade，旧 Forui 约定不再作为新页面规范。
> 历史 Forui 设置约定见 [mikcb-settings-screen-layout.md](./forui/mikcb-settings-screen-layout.md)；新设置页以本文档为准。

## 0. 双层组件体系与新页面硬规则（2026-08）

轻屿课表当前不是“所有页面直接堆一套 `Miuix*` Widget”，而是**官方风格基础库 + 项目自研 HyperOS facade** 两层协作：

### 0.1 外部基础库：项目固定的 `flutter_miuix`

- 依赖位置：`pubspec.yaml` → `flutter_miuix` Git 依赖。
- 当前固定版本：`1.0.10`，commit `8d72a94a72ca4580b43ef2b5872ded3021815ccd`（见 `pubspec.lock`）。
- 唯一公开导入入口：`package:flutter_miuix/miuix.dart`；禁止导入包内 `src/` 私有路径。
- 它是 Miuix / HyperOS 风格的 Flutter port/fork，不是小米官方发布的 Flutter SDK；上游设计参考是 Compose Miuix。
- 能力范围：`MiuixTheme` / `MiuixColors` / `MiuixTextStyles`、图标与 foundation、Squircle/弹簧/Blur、Button/Card/Switch/Slider/TextField、Preference、Scaffold/TopAppBar、Navigation、Overlay/Dialog/BottomSheet、Picker、Snackbar、Tooltip 等基础件。

### 0.2 项目自研层：`lib/ui/hyperos/`

- 统一入口：`lib/ui/hyperos/hyperos.dart`。
- 当前约 47 个 Dart 文件、约 207 个类/枚举；它不是第三方包，而是本项目基于 `flutter_miuix`、Flutter/Material 基础设施和业务约束形成的应用级 facade。
- 负责页面壳层、设置列表与分组、项目 tokens、页面转场、Sheet/Dialog/Toast、玻璃/模糊降级、兼容适配和业务组合。
- 当前生产根仍是 `MaterialApp` + 项目自己的 `HyperosMotionHost` / `FrostedAppearanceScope` / HyperOS facade；`MiuixSystemTheme` 目前主要用于 `miuix_showcase_screen.dart` 的官方组件展示与独立示例，不要在每个业务页重复包一层主题。
- 常用入口：`HyperosRootPage`、`HyperosSubpage`、`HyperosSheet`、`HyperosListView`、`HyperosListGroup`、`HyperosListTile`、`HyperosChoiceTile`、`HyperosSwitchTile`、`HyperosSliderTile`、`HyperosButton`、`HyperosControlCard`、`HyperosSelectTile`、`HyperosTextField`、`HyperosNavigation`、`showAppConfirmDialog`、`showAppToast`。

### 0.3 新页面必须遵守的选型规则

1. **先用项目 facade，再用官方基础件。** 新页面优先使用 `lib/ui/hyperos/hyperos.dart` 的页面壳、列表、设置行、控制件、导航和弹层；只有 facade 没覆盖的基础能力才直接使用 `flutter_miuix` 的 `Miuix*` API。
2. **页面壳层固定。** 根页面用 `HyperosRootPage`，二级页面用 `HyperosSubpage`，底部面板用 `HyperosSheet` / `showHyperosSheet`；不要为业务页重新手写一套 `Scaffold`、顶栏、返回转场或 sheet chrome。
3. **语义组件固定映射。** `ArrowPreference` → `HyperosListTile`；`SwitchPreference` → `HyperosSwitchTile`；Checkbox/Radio Preference → `HyperosChoiceTile`；`SliderPreference` → `HyperosSliderTile`；`OverlayBottomSheet` → `HyperosSheet`；`OverlayDialog` → `HyperosDialog` / `lib/widgets/app_dialogs.dart`；Dropdown Preference → `HyperosSelectTile` / `showHyperosSelectPopup`。
4. **主题与视觉令牌不能绕过。** 颜色优先 `HyperosColors.*(context)` 或 `MiuixTheme.of(context).colors`，文字优先 `HyperosTypography` 或 `MiuixTheme.of(context).textStyles`；不要在业务页散落硬编码颜色、字号、圆角、padding 和按下态。
5. **禁止新增旧/平行体系。** 新业务页不得使用 Flutter 原生 `ListTile`、`MaterialPageRoute`、`SnackBar`、`FDialog`、已删除的 `SettingsSectionCard`，也不得新建第三套通用组件库。`MaterialApp` / 根 `ThemeData` / 基础 `Scaffold` 只保留在应用根、平台基础设施和 facade 内。
6. **Forui 只作为历史兼容边界。** 不为新页面引入新的 Forui 业务组件；已有 `context.theme`、`FTheme`、`FHeaderAction` 等仅在迁移边界明确且不改变行为时保留，新代码默认使用 HyperOS facade 与 Miuix 语义主题。
7. **交付必须可审计。** 新页面或页面重做要更新 `hyperos-page-compliance.json`，运行 `python tool/hyperos_audit.py --strict`；涉及颜色、字号、圆角、间距、深色或玻璃效果时再运行 `--perfect` 并完成必要的真机人工核对。
8. **例外必须留痕。** 如果确实需要绕过 facade 或使用 Material/Forui 兼容件，必须在 PR/Issue 中写明原因、影响范围和后续收敛计划。

---

## 1. 库结构

```
lib/ui/hyperos/
  hyperos.dart           # barrel export
  hyperos_miuix_spec.dart # Miuix 源数据对照表（只读参考）
  hyperos_tokens.dart    # 运行时 tokens（默认取自 Miuix spec）
  hyperos_theme.dart     # HyperosColors / HyperosTypography / HyperosTheme
  hyperos_widgets.dart   # 列表、卡片、选择行等组件
  hyperos_controls.dart  # HyperosControlCard / HyperosSlider / HyperosButton
  hyperos_select.dart    # HyperosSelectTile / showHyperosSelectSheet
  hyperos_switch.dart    # Miuix 规格开关 49×28
  hyperos_page.dart      # HyperosSubpage / HyperosListView / HyperosSheet
  hyperos_navigation.dart # HyperosPageRoute / HyperosNavigation 子页转场
```

兼容层：`lib/widgets/settings_section_widgets.dart` **已删除**（2026-07）；请直接使用 `lib/ui/hyperos/hyperos.dart`。

---

## 2. 已有组件

### 2.1 Tokens（`HyperosTokens` / `HyperosIconColors`）

> **运行时以固定的 `HyperosTokens` + `HyperosMiuixSpec` settings 值为准。**
> 下表为 HyperOS 系统设置实测覆盖后的默认值；原始 Miuix 通用值见 Spec。  
> **颜色请用 `HyperosColors.*(context)`**，不要直接画 `HyperosTokens` 颜色常量（后者为浅色 light-only）。

| Token | 值（settings 覆盖） | 用途 |
|-------|---------------------|------|
| `background` | `#F2F2F2` | 页面灰底（settings） |
| `card` | `#FFFFFF` | 白卡片（`surfaceContainer`） |
| `primaryText` | `#333333` | 主文字（settings） |
| `secondaryText` | `#999999` | 次要文字（settings） |
| `actionIcon` | `#66000000` | 箭头 40% 黑（Miuix actions） |
| `pressed` | `#E0E0E0` | 行按下高亮 |
| `divider` | `#E0E0E0` | 分割线（请用 `HyperosColors.dividerLine`） |
| `accent` | `#3482FF` | 强调色（请用 `HyperosColors.primary`） |
| `cardRadius` | **24** | 设置组卡片圆角 |
| `sectionGap` | **12** | 卡片组间距 |
| `listPadding` | **16, 4, 16, 24** | 列表页 padding |
| 行内 padding | **16 / 13** | 水平 16、垂直 13（settings 行） |
| 图标间距 | **12** | 图标 → 标题 |
| 字→箭间距 | **4**（title）/ body2（detail） | 见 Tokens |
| Chevron | **7×11** | settings 实测箭头 |
| Switch | **49×28**, thumb **20** | 见 `HyperosSwitch` |

`HyperosIconColors`：blue / green / orange / purple / teal / red / yellow / indigo / cyan

### 2.2 主题解析（`HyperosColors` / `HyperosTypography` / `HyperosTheme`）

- 浅色：HyperOS / Miuix light；深色：组件语义色走 `HyperosMiuixDarkColors`，页面壳背景/文字六方法仍可回落 Forui `FColors`
- 字体：`listTitle` 16/w400、`listDetail` 14、`sectionLabel` 16/w600、`sheetTitle` 20/w600
- `nestedHeaderStyle`：居中、**不加粗** 20sp 顶栏标题
- `cardStyle` / `cardShape`：供 `FCard.raw` 等 Forui 容器套 HyperOS 圆角

### 2.3 组件（`hyperos_widgets.dart`）

| 组件 | 说明 | 状态 |
|------|------|------|
| `HyperosListGroup` | 白圆角卡片容器 | ✅ |
| `HyperosListTile` | 导航行：彩底图标 + 标题 + 可选 details + **仅 chevron** | ✅ |
| `HyperosActionTile` | 蓝色线框图标操作行 | ✅ |
| `HyperosChoiceTile` / `HyperosChoiceGroup` | 单选/多选 + 勾选 | ✅ |
| `HyperosSectionLabel` / `HyperosSectionDescription` | 分组标题 / 脚注 | ✅ |
| `HyperosSectionGap` | 卡片组竖向间距 | ✅ |
| `HyperosCard` | 独立白卡片 | ✅ |
| `HyperosIconBadge` | 左侧彩色图标 | ✅ |
| `HyperosChevron` | 自绘细箭头 | ✅ |
| `HyperosColorDot` | 主题色圆点（用于 choice 前缀） | ✅ |
| `HyperosSelectedCheckmark` / `HyperosInsetDivider` | 勾选 / 缩进分割线 | ✅ |
| `HyperosSwitch` / **`HyperosSwitchTile`** | Miuix 规格开关 / 开关行 | ✅ |
| **`HyperosSummaryCard`** | 顶部概要卡（学期、账号等） | ✅ |
| **`HyperosControlCard`** | 包 slider、按钮组、自定义控件的白卡片 | ✅ |
| **`HyperosSlider`** / **`HyperosSliderTile`** | Miuix 滑条 / 带标题滑条行 | ✅ |
| **`HyperosButton`** | primary / secondary / destructive | ✅ |
| **`HyperosSelectTile`** | 点击弹出 HyperosSheet 单选 | ✅ |
| `showHyperosSelectSheet` | 底部单选 sheet | ✅ |

**交互约定（已实现）**

- 列表行用 `HyperosPressableRow`：短按补闪 + 延迟高亮，滑动起手不变暗
- 按下态为**无圆角**长方形 `#E0E0E0`
- `HyperosListTile` **不支持 trailing**；右侧只允许 chevron（当前值走 `details` 文字）

### 2.4 子页转场（`hyperos_navigation.dart`）

| API | 说明 |
|-----|------|
| `HyperosNavigation.push` | 推荐：打开子页 |
| `HyperosNavigation.route` | 返回 `HyperosPageRoute` 供 `Navigator.push` |
| `HyperosPageRoute` | 不透明横向 shared-axis（新页右进、旧页略左移） |
| `HyperosNavigation.pageTransitionsTheme` | 已挂到 `MaterialApp.theme` 作兜底 |

- 基础时长 **450ms**（AOSP Settings），乘以 Android `Transition animation scale`
- 新页左侧 **圆角** = 屏幕 `RoundedCorner`（Android 12+ 经 platform channel 读取；fallback 28dp）
- 新页 **左下投影**（顶光打下来、卡片落在下层页上的阴影；转场中段最强）
- **不要**再用 `MaterialPageRoute`；全 app 已统一为 `HyperosPageRoute`
- 特殊 zoom 入场（如顶部菜单弹出）保留独立 route，不走 HyperOS 转场

```dart
await HyperosNavigation.push(
  context,
  settings: const RouteSettings(name: '/settings/appearance'),
  builder: (_) => const AppearanceSettingsScreen(),
);
```

### 2.5 页面壳（`hyperos_page.dart`）

| 组件 | 说明 | 状态 |
|------|------|------|
| `HyperosSubpage` | 灰底 + nested header + 返回 | ✅ |
| `HyperosRootPage` | 无返回键的根列表页 | ✅ |
| `HyperosListView` | 标准 list padding 的 ListView | ✅ |
| `HyperosSheet` | 灰底 bottom sheet 容器 + 标题 | ✅ |

### 2.6 对话框 / 表单 / 反馈（2026-07 增补）

| 组件 | 说明 | 状态 |
|------|------|------|
| `HyperosDialog` / `showHyperosDialog` | 底部浮动圆角卡片 + 实心按钮；支持 `useRootNavigator` | ✅ |
| `showHyperosConfirmDialog` | 底部双按钮确认（次要/主色或危险） | ✅ |
| `HyperosTextField` / `HyperosTextFieldTile` | 对话框 / 卡片内输入 | ✅ |
| `HyperosCheckbox` / `HyperosRadio` + Tile 变体 | 勾选 / 单选 | ✅ |
| `HyperosTabRow` / `HyperosSegmentedControl` | 顶部分段 / Tab | ✅ |
| `HyperosNumberPicker` + Tile | 数字步进 | ✅ |
| `HyperosEmptyState` / `HyperosSearchBar` / `HyperosDivider` | 空态 / 搜索 / 分割线 | ✅ |
| `showHyperosSnackBar` | 轻提示 | ✅ |
| `HyperosNavTile` / `HyperosDangerTile` | 纯文字导航 / 红色警示行 | ✅ |
| `HyperosSwitchListGroup` | 多开关分组 | ✅ |
| `HyperosIconButton` | 图标按钮 | ✅ |
| `HyperosCircularProgress` / `HyperosLinearProgress` | 进度指示 | ✅ |
| `HyperosBadge` | 角标 | ✅ |
| `showHyperosListPopup` | 列表弹出菜单 | ✅ |
| `HyperosFloatingToolbar` | 浮动工具条 | ✅ |
| `HyperosColorChip` / `HyperosHexColorChipGroup` | 色块选择 | ✅ |
| `HyperosFab` | FAB | ✅ |
| `HyperosRefreshIndicator` | 下拉刷新 | ✅ |
| `HyperosNavigationBar` | 底栏导航 | ✅ |
| `HyperosTooltip` | 工具提示 | ✅ |
| `HyperosDateTile` | 日期选择行 | ✅ |
| `HyperosTag` | 行内文字胶囊（替代 `FBadge` 非角标场景） | ✅ |
| `HyperosAccordion` / `HyperosHintBanner` | 折叠分组 / 信息横幅（替代 `FAccordion` / `FAlert`） | ✅ |
| `showHyperosRichSnackBar` | 带图标与副标题 SnackBar（`showAppToast` 同款） | ✅ |
| `showHyperosSheet` / `HyperosSheetFrame` | 底部面板壳；**两种 chrome**：`floating`（四边圆角+外边距，同 Dialog）/ `edge`（贴边、仅上圆角，首页菜单） | ✅ |
| `showHomeHyperosSheet` | 首页专用：默认 `edge` + 浅遮罩 | ✅ |
| `showHyperosSelectPopup` | 锚点下拉单选 | ✅ |
| `HyperosPressableRow` | 列表行按下态底层 | ✅ |
| `HyperosOverscrollPhysics` | Miuix 橡皮筋滚动物理 | ✅ |
| `HyperosBlurredHeaderShell` 等 | 模糊顶栏（Android 默认 tint-only） | ✅ |
| `HyperosShowcaseScreen` | 非 Release 视觉验收页 | ✅ |

统一对话框入口：`lib/widgets/app_dialogs.dart`（`showAppConfirmDialog` / `showAppTextInputDialog` / `showAppTripleActionDialog` 等）。  
Toast 入口：`lib/utils/app_toast.dart` → [app-toast.md](./app-toast.md)。

## 3. 界面迁移状态

> **2026-07 起：** 迁移进度不再在本节手工维护。  
> **唯一真相来源：** [`hyperos-page-compliance.json`](./hyperos-page-compliance.json) + `python tool/hyperos_audit.py`（见 [`hyperos-page-compliance.md`](./hyperos-page-compliance.md)）。

下列表格为 **历史快照**，仅供对照组件选型；发版 / PR 请以 audit 流水线输出为准。

图例：**✅ 已用 HyperOS** · **🟡 部分** · **❌ 仍 Forui 旧样式**

### 3.1 课表设置链路（`timetable_settings_screen.dart`）

| 界面 | 状态 | 说明 |
|------|------|------|
| 设置首页 | ✅ | `HyperosSubpage` + `HyperosListView` + `HyperosListGroup/Tile` |
| 学期概要卡 `_SemesterOverviewCard` | ✅ | `HyperosSummaryCard` |
| 主题管理 `_ThemeManageScreen` | ✅ | HyperOS 列表 + choice/action |
| 外观 `_AppearanceSettingsScreen` | ✅ | HyperOS 卡片 + select + slider |
| 布局 `_LayoutSettingsScreen` | ✅ | HyperOS 开关 + select + slider |
| 桌面小组件 `_HomeWidgetSettingsScreen` | ✅ | 同上 |
| 节假日 `_HolidaySettingsScreen` | ✅ | 同上 |
| Live 设置 `_LiveSettingsScreen` / `_LiveTestingSettingsScreen` | ✅ | 调试区按钮已换 `HyperosButton`；色盘仍用 `ColorPicker` |

### 3.2 设置入口跳转的独立页

| 界面 | 文件 | 状态 |
|------|------|------|
| 云同步 | `cloud_sync_screen.dart` | ✅ |
| 数据传输 | `data_transfer_screen.dart` | ✅ |
| 局域网编辑 | `lan_edit_screen.dart` | ✅ |
| 关于 | `about_screen.dart` | ✅ |
| 反馈 | `feedback_screen.dart` | ✅ |
| 使用指南 | `user_guide_screen.dart` | ✅（`HyperosAccordion` / `HyperosHintBanner`） |
| 课表管理 | `timetable_profiles_screen.dart` | ✅ |
| 考试列表 | `exam_list_screen.dart` | ✅ |
| 课程总览 | `course_overview_screen.dart` | ✅ |
| 时间方案 | `time_scheme_management_screen.dart` | ✅ |

### 3.3 Live / 诊断

| 界面 | 文件 | 状态 |
|------|------|------|
| 超级岛子页群 | `live_settings_subpages.dart` | ✅ |
| Live 诊断日志 | `live_diagnostics_log_viewer_screen.dart` | ✅ |

### 3.4 弹层 / 选择器

| 界面 | 文件 | 状态 |
|------|------|------|
| 学期周数选择 | `semester_week_count_picker_sheet.dart` | ✅ `HyperosSheet` + `HyperosChoiceGroup` |
| 时间方案 bottom sheet | `time_scheme_picker_sheet.dart` | ✅ |

### 3.5 表单 / 业务页

| 界面 | 文件 | 状态 |
|------|------|------|
| 添加/编辑课程 | `add_course_screen.dart` | ✅ 壳层 + 对话框 HyperOS 化 |
| 添加考试 | `add_exam_screen.dart` | ✅ |
| 添加日程 | `add_schedule_item_screen.dart` | ✅ |
| 课程导入 | `course_import_screen.dart` | ✅ |
| 课程统计 | `course_statistics_screen.dart` | ✅ 壳层 + 列表 |
| 主课表 | `timetable_screen.dart` | ✅ `HyperosRootPage` |

顶栏 `FHeaderAction` 与 `main.dart` 的 `FTheme` 为预期 Forui 残留，非业务组件。

---

## 4. 仍缺 / 低优先级

P0–P2 核心组件与 **全 app 对话框迁移** 已完成（§2.6）。仍缺或按需增强：

| 类别 | 项 | 说明 |
|------|-----|------|
| 按钮 | `HyperosButton` 前缀图标 / outline 变体 | 按需增强 |
| 取色 | 全屏 `ColorPicker` 封装 | 外观页仍直接用 `flutter_colorpicker` |
| 导航 | `NavigationRail` | 宽屏暂无需求 |
| 弹出 | `OverlayCascadingListPopup` | 暂无场景 |
| 视觉 | `miuix-squircle` / Android live blur | 非阻塞；Android blur 因 Impeller/ANR 暂 tint-only |
| 依赖 | 去掉 `FScaffold` / `FHeader` 页壳 | 远期；当前稳定可用 |

### P4 — 质量与工程化

- [x] Widget 测试：`test/ui/hyperos/`（40+ 项）
- [ ] 深色模式逐屏对照截图
- [x] 删除 `settings_section_widgets.dart` 兼容层（2026-07）
- [x] 全 app 用户可见 Forui 组件清零（2026-07）
- [x] `HyperosShowcaseScreen` 组件验收页（非 Release）
- [ ] 深色模式 Showcase 对照

---

## 5. 分阶段实施路线

建议按「先库、后页面、先设置链路、后业务表单」推进。

### 阶段 A — 库基础 ✅

- [x] tokens / theme / 列表导航 / 选择 / 页面壳 / sheet

### 阶段 B — 表单控件 ✅

- [x] `HyperosSwitchTile`、`HyperosControlCard`、`HyperosSliderTile`、`HyperosButton`
- [x] `HyperosSelectTile`、`HyperosSummaryCard`
- [x] widget tests under `test/ui/hyperos/`

### 阶段 C — 课表设置子页 ✅

- [x] 外观 / 布局 / 小组件 / 节假日 / Live 入口与调试页
- [x] 学期概要卡 → `HyperosSummaryCard`
- [x] `timetable_settings_screen.dart` 内 `SettingsSectionCard` 归零

### 阶段 D — 设置入口独立页 ✅

- [x] cloud / data_transfer / lan_edit / feedback / user_guide / about

### 阶段 E — Live 集群 ✅

- [x] `live_settings_subpages.dart`
- [x] `live_diagnostics_log_viewer_screen.dart`

### 阶段 F — 弹层与次要页 ✅

- [x] `time_scheme_management_screen.dart`
- [x] `time_scheme_picker_sheet.dart`
- [x] `timetable_profiles_screen.dart`
- [x] `course_overview_screen.dart`

### 阶段 G — 业务表单页 ✅

- [x] `add_course_screen.dart`、`add_exam_screen.dart`、`add_schedule_item_screen.dart` — 壳层 `HyperosSubpage`；对话框 HyperOS 化
- [x] `course_statistics_screen.dart` — 壳层 + 列表 + 空态
- [x] `course_import_screen.dart` — HyperOS 列表 + 对话框 + sheet
- [x] `timetable_screen.dart` — `HyperosRootPage`

### 阶段 H — 对话框统一 ✅

- [x] `lib/widgets/app_dialogs.dart` 全部走 HyperOS
- [x] 全 app `showFDialog` / `FDialog` 清零（含 `main.dart` 备份导入、`theme_manage_sheets.dart` 等）

---

## 6. 使用示例

```dart
import '../ui/hyperos/hyperos.dart';

return HyperosSubpage(
  onBack: () => Navigator.pop(context),
  title: Text(l10n.settingsTitle),
  child: HyperosListView(
    children: [
      HyperosListGroup(
        children: [
          HyperosListTile(
            icon: Icons.palette_outlined,
            iconAccent: HyperosIconColors.blue,
            title: l10n.appearanceEntryTitle,
            onTap: openAppearance,
          ),
        ],
      ),
      const HyperosSectionGap(),
    ],
  ),
);
```

---

## 7. 下一步建议

**设置链路迁移已基本完成。** 建议按优先级继续：

1. **工程化** — 深色模式逐屏对照截图、更新 `.trellis/spec/flutter/` UI 约定
2. **按需** — `course_import_screen` 等业务 UI 继续 HyperOS 化

---

## 8. Miuix 来源与 `flutter_miuix` 关系

### 8.1 Compose Miuix：设计参考，不直接作为 Flutter 依赖

上游 **[Miuix](https://github.com/compose-miuix-ui/miuix)** 是 Compose Multiplatform 的 HyperOS 风格 UI 库，Apache-2.0。它提供颜色、字号、圆角、Preference 组件清单和动效语义等参考数据，但不是 Dart/Flutter 包，不能在本项目中直接 `pub add` 或导入 Kotlin API。

### 8.2 项目固定的 Flutter port

本项目实际安装和使用的是项目固定的 `flutter_miuix` Git 依赖：

| 项目 | 当前值 |
|------|--------|
| 包名 | `flutter_miuix` |
| 版本 | `1.0.10` |
| Git 来源 | `https://github.com/Mutx163/flutter_miuix.git` |
| 固定 commit | `8d72a94a72ca4580b43ef2b5872ded3021815ccd` |
| 公开入口 | `package:flutter_miuix/miuix.dart` |
| 组件规模 | 45+ 个公开组件/基础能力 |

公开 barrel 当前覆盖：

- 主题与动态取色：`MiuixTheme`、`MiuixColors`、`MiuixTextStyles`、Monet。
- Foundation：`MiuixPressable`、`MiuixSquircleBorder`、弹簧、Popup、Vector Icon、滚动触觉。
- Blur：`MiuixBackdrop`、`MiuixTextureBlur`、`MiuixHighlight`。
- 基础件：Button、Card、Badge、Checkbox、Radio、Switch、Slider、TextField、Divider、Progress、TabRow。
- Preference：Arrow/Switch/Checkbox/Radio/Slider/Dropdown/Spinner Preference。
- 页面与交互：Scaffold、TopAppBar、NavigationBar/Rail、Dialog、BottomSheet、Dropdown、ListPopup、Date/Number Picker、Snackbar、Tooltip、PullToRefresh。

### 8.3 项目自研层与官方基础件的边界

| 需求 | 直接使用 `flutter_miuix` | 优先使用 mikcb 自研 facade |
|------|---------------------------|-----------------------------|
| 主题、语义颜色、文字样式 | `MiuixTheme` / `MiuixColors` / `MiuixTextStyles` | `HyperosColors` / `HyperosTypography`（页面语义包装） |
| 基础按钮、开关、滑条、输入 | `MiuixButton` / `MiuixSwitch` / `MiuixSlider` / `MiuixTextField` | `HyperosButton` / `HyperosSwitchTile` / `HyperosSliderTile` / `HyperosTextField` |
| Preference 行 | `Miuix*Preference` | `HyperosListTile` / `HyperosChoiceTile` / `HyperosSelectTile` |
| 卡片和设置分组 | `MiuixCard` / `MiuixSurface` | `HyperosListGroup` / `HyperosCard` / `HyperosControlCard` |
| 页面与顶栏 | `MiuixScaffold` / `MiuixTopAppBar` | `HyperosRootPage` / `HyperosSubpage` / `HyperosNavigation` |
| 弹层与反馈 | `MiuixOverlayDialog` / `MiuixOverlayBottomSheet` / `MiuixSnackbar` | `HyperosDialog` / `HyperosSheet` / `showAppToast` / `showHyperosSnackBar` |
| 玻璃与降级 | `MiuixTextureBlur` 等基础能力 | `HyperosBlurredHeader` / `HyperosLiquidGlassSurface` 等项目策略封装 |

**原则：** 官方库定义基础行为和 Miuix 语义；自研层定义轻屿课表的页面结构、视觉 token、兼容策略和业务组合。页面代码不应绕过已经存在的自研入口重新实现同一规则。

### 8.4 官方库组合时的关键接线

- `MiuixScaffold.content` 是接收 `EdgeInsets` 的 builder，必须把 padding 应用到内容根部。
- 可折叠顶栏要让 `MiuixTopAppBar.scrollBehavior` 与内容树中的 `MiuixScrollBehaviorListener` 共享同一个 behavior。
- `MiuixOverlayDialog` / `MiuixOverlayBottomSheet` 使用声明式 `show` + `onDismissRequest`，不要自行寻找命令式替代 API。
- `MiuixNavigationBar` / `MiuixFloatingNavigationBar` 的子项数量必须满足库的约束（2–5）。
- 图标优先 `MiuixIcons.basic` 或经过确认的 `MiuixIcons.extended.byName`；`MiuixIcon` 的 `icon` / `vector` / `child` 三种来源只能传一种。
- 颜色优先语义角色，不要把 `Color(0x...)` 直接散落在页面中；自研页面优先走 `HyperosColors`。
- 新页面是否合规以 `docs/reference/hyperos-page-compliance.json` 和 `python tool/hyperos_audit.py` 为准，不以单次截图或对话印象为准。

### 8.5 结论

- 项目已经具备两套协同组件体系，但不是两套平行的“随便选一个”组件库。
- `flutter_miuix` 是固定版本的 Flutter 基础 port；`lib/ui/hyperos/` 是轻屿课表的应用级设计系统与兼容 facade。
- 新页面默认走自研 facade；自研 facade 不覆盖时才直接调用官方 `Miuix*` 基础件；禁止新增第三套通用组件体系。
