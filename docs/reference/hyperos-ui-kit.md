# mikcb HyperOS UI 库

对标小米 HyperOS / MIUI **系统设置**视觉与交互的 Flutter 组件库。  
代码入口：`lib/ui/hyperos/hyperos.dart`

> 与 Forui 的关系：页面骨架仍用 `FScaffold` / `FHeader`，HyperOS 库负责灰底、白卡片列表、字号色值、按下态等「系统设置」层样式。  
> 旧 Forui 设置约定见 [mikcb-settings-screen-layout.md](./forui/mikcb-settings-screen-layout.md)；新设置页以本文档为准。

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
| 时间方案 bottom sheet | `time_scheme_bottom_sheet.dart` | ✅ |

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
- [x] `time_scheme_bottom_sheet.dart`
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

## 8. Miuix 参考来源（Compose，不可直接依赖）

第三方开源库 **[Miuix](https://github.com/compose-miuix-ui/miuix)**（`compose-miuix-ui/miuix`，Apache-2.0，~900⭐）是 **Compose Multiplatform** 的 HyperOS 风格 UI 库，**不是 Flutter 包**，mikcb 不能直接 `pub add`。

| 项目 | Miuix | mikcb `lib/ui/hyperos` |
|------|-------|------------------------|
| 技术栈 | Kotlin + Compose Multiplatform | Flutter + Forui 骨架 |
| 能否直接引用 | ❌ | — |
| 能否抄设计数据 | ✅ 色值、尺寸、组件清单 | 手工移植为 Dart token / Widget |

### 8.1 可移植的「硬数据」

来源：[Colors.kt](https://github.com/compose-miuix-ui/miuix/blob/main/miuix-ui/src/commonMain/kotlin/top/yukonga/miuix/kmp/theme/Colors.kt)

**浅色 `lightColorScheme()` 与 mikcb 已对齐的部分：**

| 语义 | Miuix | mikcb `HyperosTokens` | 备注 |
|------|-------|----------------------|------|
| primary / accent | `#3482FF` | `#3482FF` | ✅ 一致 |
| 页面 surface | `#F7F7F7` | background `#F2F2F2` | 略深，可斟酌 |
| 卡片 surfaceVariant | `#FFFFFF` | card `#FFFFFF` | ✅ |
| 按下高亮 | `#E8E8E8` | pressed `#E0E0E0` | 接近 |
| 分割线 dividerLine | `#E0E0E0` | divider `#E8E8E8` | 接近 |
| 主文字 onSurface | `#000000` | primaryText `#333333` | Miuix 更黑；我们贴近截图取 `#333` |
| 摘要 summary | `#99000000` (~60%) | secondaryText `#999999` | 可改用 alpha 黑 |
| 箭头 actions | `#66000000` (~40%) | chevron 用 secondaryText | Miuix 更淡 |

**Miuix 额外语义色（后续可补进 `HyperosTokens`）：**

- `error` `#E94634`、`tertiaryContainer` `#EAF2FF`（浅蓝底）
- Switch 关轨 `secondary` `#E6E6E6`、Slider 轨道 `#0F000000`
- `windowDimming` 30% 黑（Dialog / Sheet 遮罩）

**尺寸（来源 ArrowPreference / Switch）：**

| 元素 | Miuix | mikcb 现状 |
|------|-------|------------|
| 右箭头 | **10×16 dp** 矢量 | 6×12 自绘 chevron ✅ 已更细 |
| Switch | **49×28 dp**，thumb **20 dp** | 未实现，仍用 `FSwitch` |
| 箭头色 | `onSurfaceVariantActions` 40% 黑 | secondaryText |

默认 Monet 种子色示例也是 `#3482FF`，与 HyperOS 文档一致。

### 8.2 组件对照表（移植目标）

Miuix `miuix-preference` → mikcb HyperOS 映射：

| Miuix (v0.9+) | 用途 | mikcb 对应 | 状态 |
|---------------|------|------------|------|
| `ArrowPreference` | 带摘要的导航行 | `HyperosListTile` | ✅ |
| `SwitchPreference` | 开关行 | `HyperosSwitchTile` | ✅ |
| `CheckboxPreference` | 多选 | `HyperosChoiceTile` | ✅ |
| `RadioButtonPreference` | 单选 | `HyperosChoiceTile` | ✅ |
| `SliderPreference` | 滑条行 | `HyperosSliderTile` | ✅ |
| `OverlayBottomSheet` | 底部弹层 | `HyperosSheet` | ✅ |
| `OverlayDialog` | 对话框 | `HyperosDialog` | 🟡 |
| `OverlayDropdownPreference` | 下拉选择 | — | ❌ |

Miuix `miuix-ui` 基础件：`Switch`、`Slider`、`TabRow`、`Checkbox` 等已实现 **HyperOS3 动效**（弹簧、触觉反馈），Flutter 侧需用 `AnimationController` / `HapticFeedback` 复刻，无法复制粘贴。

### 8.3 推荐用法

1. **只借 spec，不引依赖** — 从 Miuix 源码提取色值、dp、组件 API 命名，写入 `hyperos_tokens.dart` 与本文档。
2. **阶段 B 优先对照** — 实现 `HyperosSwitch` 时参照 Miuix `Switch.kt`：49×28、thumb 20、primary `#3482FF`、关轨 `#E6E6E6`。
3. **图标** — Miuix 有独立 `miuix-icons` 模块；Flutter 可继续 Material Icons，或导出 SVG 到 `assets/`（非必须）。
4. **Squircle / Blur** — Miuix 有 `miuix-squircle`、`miuix-blur`；Flutter 可选 `figma_squircle` 或跳过（设置列表非刚需）。

### 8.4 结论

- **不能**在 Flutter 里直接依赖 Miuix。
- **可以**把它当作 HyperOS 的「开源设计规范 + 参考实现」，尤其 **颜色、Switch/Slider 尺寸、Preference 组件清单**。
- mikcb 当前 tokens 与 Miuix **核心 accent / 卡片 / 按下色已基本同系**；下一步实现 Switch/Slider 时以 Miuix 数值为准，成功率最高。
