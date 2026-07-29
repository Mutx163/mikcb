# 工作区变更更新日志（2026-07-29）

> 本文档逐一记录本次提交批次中每个已修改 / 新增文件的变更原因、变更内容及影响范围。
> 对应提交：见文末「提交分组」一节。

---

## 主题一：Miuix 时间 / 数值滚轮选择器替换 Material 弹窗

**变更原因**：应用内日期选择已统一为 Miuix 毛玻璃底部 sheet（`showMiuixDatePickerSheet`），但时间选择仍在使用 Material `showTimePicker`、数值选择仍在使用列表式选择 sheet，视觉与手感不一致。本批次补齐时间与数值两类滚轮选择器，全应用统一为 HyperOS/Miuix 弹层风格。

### 新增 `lib/widgets/miuix_time_picker_sheet.dart`
- **内容**：新组件 `showMiuixTimePickerSheet`，HyperOS 底部 sheet 内嵌「时 / 分」双列 `MiuixNumberPicker` 滚轮，恒为 24 小时制；确认返回 `TimeOfDay`，取消 / 点遮罩返回 `null`；支持 `useRootNavigator` 以便在嵌套 sheet 中弹出。
- **影响范围**：作为 Material `showTimePicker` 的统一替代入口，被 5 个调用点使用（见下）。

### 新增 `lib/widgets/miuix_number_picker_sheet.dart`
- **内容**：新组件 `showMiuixNumberPickerSheet`，通用单列数值滚轮 sheet，`label` 回调决定每行文案（如「第 N 周」「第 N 节」），入参自动 clamp 至 `[minValue, maxValue]`。
- **影响范围**：学期周数、上课节次、周次范围等所有数值选择场景的统一底座。

### `lib/widgets/semester_week_count_picker_sheet.dart`
- **原因**：其内部实现与新通用组件完全重复。
- **内容**：删除本地 `_SemesterWeekCountPickerSheetBody`（约 -100 行），改为直接委托 `showMiuixNumberPickerSheet`，仅保留学期周数的标题与行文案定制。
- **影响**：行为不变，代码去重；后续滚轮手感调整只需改一处。

### `lib/screens/add_exam_screen.dart` / `lib/screens/add_schedule_item_screen.dart`
- **原因**：考试与日程的开始 / 结束时间仍是 Material 时钟弹窗。
- **内容**：`_pickTime` 改调 `showMiuixTimePickerSheet`，并传入「选择开始时间 / 选择结束时间」标题。
- **影响**：添加/编辑考试、添加/编辑日程页的时间选择交互。

### `lib/screens/time_scheme_bottom_sheet.dart` / `lib/screens/time_scheme_management_screen.dart`（部分）
- **原因**：编辑节次时间仍用 Material 时钟弹窗。
- **内容**：`_editSectionTime` 的开始 / 结束时间选择改为 Miuix 滚轮 sheet（bottom sheet 版本保留 `useRootNavigator: true`）。
- **影响**：时间方案编辑（快速切换 sheet 与管理页两条路径）的节次时间编辑。

### `lib/widgets/time_scheme_quick_generate_sheet.dart`
- **原因**：快速生成时间方案的「上午/下午/晚上第一节时间」选择同上。
- **内容**：`_pickTime` 增加 `title` 参数并改调 `showMiuixTimePickerSheet`，三个调用点传入各自的字段名作标题。
- **影响**：时间方案快速生成 sheet。

### `lib/screens/add_course_screen.dart`
- **原因**：节次与周次选择使用列表式 select sheet，长列表滚动费力，且与设置页的滚轮风格不一致；周次网格与快捷操作按钮为手写 InkWell / ActionChip，风格漂移。
- **内容**：
  - 新增 `_pickFromNumberWheelSheet`，开始/结束节次、开始/结束周次共 4 个选择点从 select sheet 迁移到数值滚轮（结束项的 `minValue` 联动开始项，保持原约束）；删除不再使用的 `_sectionSelectItems`。
  - 周次网格单元格改用 `HyperosButton`（dense），全选/单周/双周 ActionChip 改用 `HyperosButton` secondary dense；周次摘要文字改用 `HyperosTypography.listDetail`。
  - 周范围选择字段改用 `HyperosPickerField`。
- **影响**：添加 / 编辑课程页的节次、周次选择与周次弹窗视觉。

### l10n：`app_en/ja/ko/zh/zh_HK/zh_TW.arb` + 生成文件 `app_localizations*.dart`
- **原因**：时间滚轮 sheet 需要标题文案。
- **内容**：新增 `selectTimeTitle`、`selectStartTimeTitle`、`selectEndTimeTitle` 三条词条（6 语言）；`app_localizations*.dart` 为 `flutter gen-l10n` 生成产物同步更新。
- **影响**：仅新增词条，无既有文案变动。

---

## 主题二：卡片圆角策略统一为上游 flutter_miuix 固定 16dp squircle

**变更原因**：此前 `HyperosAdaptiveCard` 采用「按测量高度自适应圆角」策略（矮卡 16 / 高卡 24），并通过 `HyperosMiuixCardRadiusScope` 在设置首页临时启用上游策略做 A/B 对比。对比结论为采纳上游 flutter_miuix 策略：所有卡面固定 16dp squircle。本批次移除自适应策略及对比开关。

### `lib/ui/hyperos/widgets/adaptive_card.dart`
- **内容**：
  - `HyperosAdaptiveCard` 从 StatefulWidget（测高 + 动态圆角）简化为 StatelessWidget，恒用 `MiuixSquircleBorder(cornerRadius: MiuixCardDefaults.cornerRadius)`；删除 `preferredRadius` 参数与 `HyperosSizeReporter` 测高逻辑。
  - 删除 `HyperosMiuixCardRadiusScope`（对比开关已完成使命）。
  - `HyperosSurfaceRadiusScope.of` 的 fallback 从 `HyperosTokens.cardRadius`(24) 改为 `MiuixCardDefaults.cornerRadius`(16)，行按压高亮跟随卡面圆角。
- **影响**：全应用所有基于 `HyperosAdaptiveCard` 的卡面（设置组、列表卡、摘要卡等）圆角统一为 16dp squircle；不再有高度测量引起的首帧圆角跳变与重建。

### `lib/ui/hyperos/hyperos_radius.dart`
- **内容**：文档重写——`surfaceRadiusForHeight` 不再被卡面使用，保留给比例式 chip 圆角与弹层/控件的 clamp 场景。无行为变更。
- **影响**：仅注释 / 语义说明。

### `lib/screens/exam_list_screen.dart`、`lib/ui/hyperos/hyperos_accordion.dart`、`lib/ui/hyperos/widgets/cards.dart`
- **内容**：随 `preferredRadius` 参数删除，移除 3 处调用点传参（各 -1 行）。
- **影响**：考试总览卡、提示横幅、摘要卡外观并入统一 16dp 策略。

### `lib/screens/timetable_settings_screen.dart`
- **内容**：移除设置首页包裹的 `HyperosMiuixCardRadiusScope`（策略已全局生效，无需 scope 启用）；diff 行数大（±468）主要为包裹层删除后的整体缩进回退，无其它逻辑变更。
- **影响**：设置首页卡面圆角行为不变（对比开关期间已是 16dp），代码回归单一路径。

---

## 主题三：子页大标题折叠修复（标准列表路径迁移）

**变更原因**：多个子页使用 `Material + HyperosBlurredBodyInset + HyperosListView(includeHeaderInset: false)` 的旧组合。该组合会吞掉纵向滚动通知，导致顶栏大标题不随滚动折叠（冻结）。修复方式是迁回标准列表路径：header inset 由可滚动区内部提供 + 滚动通知正常冒泡。

### `lib/screens/course_import_screen.dart`
- **内容**：导入方式首页、ICS / AI 图片 / 课表仓库 / 表格导入共 5 个页面壳统一去掉旧包装，改为直接 `HyperosListView` / `Column(Expanded(HyperosListView))` 结构；diff ±1500 行主要为解除包裹后的缩进回退,逻辑无变化。
- **影响**：全部课程导入子页的大标题现随滚动正常折叠；底部操作按钮区结构不变。

### `lib/screens/changelog_screen.dart`
- **内容**：同上迁移；加载态（非滚动居中视图）单独保留 `HyperosBlurredBodyInset` 手动让出顶栏高度。
- **影响**:更新日志页大标题折叠恢复正常。

### `lib/screens/time_scheme_management_screen.dart`（部分）
- **内容**：时间方案编辑页去掉 `HyperosBlurredBodyInset + includeHeaderInset:false` 包装，迁移到标准列表路径（与主题一的时间选择器替换同文件不同段落）。
- **影响**：时间方案编辑页大标题折叠恢复正常。

### `lib/ui/hyperos/hyperos_overlay_header.dart`
- **内容**：新增 `HyperosScrollRevealedTitle`——MIUI 系统更新器风格的标题：页面静止时顶栏为空，内容滚入毛玻璃条下方后小标题淡入（show 300ms / hide 150ms，easeOutCubic + 轻微上浮），读取 `HyperosBlurredHeaderScope.contentUnderHeader`。
- **影响**：供覆盖式顶栏页面壳使用的新能力，当前被检查更新页采用。

### `lib/screens/about_screen.dart`
- **内容**：检查更新页改为 MIUI 更新器样式——`collapsibleLargeTitle: false` + `HyperosScrollRevealedTitle` 包裹小标题；列表路径同步迁移（去掉 `includeHeaderInset: false`），非滚动的「检查中」居中视图单独用 `HyperosBlurredBodyInset` 让位。
- **影响**：关于页-检查更新子页的顶栏视觉与滚动行为。

---

## 主题四：设置预览与首页视觉一致性

### `lib/widgets/timetable_week_preview.dart`
- **原因**：设置页里的课表周预览与真实首页存在两处不一致：(1) 预览内的毛玻璃 chrome 带直接复用 `HomePageChromeGlassFill`（BackdropFilter），但在预览这种内部小矩形里采样范围被自身边界 clamp，四边出现「相框」状拖影；(2) 首页的标题墨色与 scrim 极性由壁纸顶带亮度采样驱动，预览没有采样，回退主题亮度后可能画出相反的墨色。
- **内容**：
  - 组件升级为 StatefulWidget：按壁纸路径异步采样顶带亮度（`sampleHomePageWallpaperTopLuminance`），路径变化时重采样。
  - 新增 `_PreviewChromeGlassBand`：借鉴日视图摘要卡方案——对预览自己的壁纸整图做 `ImageFiltered` 预模糊（全采样范围、无边界 clamp），裁出条带区域，再叠加等效 wash 色；液态玻璃模式下用近似 sigma（`blur * 0.45`，clamp 2~8）。
  - 顶栏标题 / 副文案墨色接入 `homePageChromeForegroundForLuminance` 自动反色，仅在毛玻璃 chrome 实际显示壁纸时反转。
- **影响**：课表设置相关页面的周预览（含首页背景、毛玻璃开关预览）观感与真实首页对齐；不影响首页本体渲染。

---

## 主题五：假期设置日期选择重构

### `lib/screens/settings/settings_holiday.dart`
- **原因**：自定义假期的日期范围此前用 Material `showDateRangePicker` 全屏日历，风格与应用内 Miuix 日历 sheet 不一致。
- **内容**：拆为「开始日期 / 结束日期」两个 `HyperosPickerField`，各自打开 `showMiuixDatePickerSheet`（与日程日期规则弹窗同款范围模式）；选开始日期晚于结束日期时自动顶推结束日期，结束日期的 `firstDate` 锁定为开始日期；窄屏 (<300dp) 自动改纵向排列；新增 `_formatFullDate` (yyyy-MM-dd)。
- **影响**：假期设置-自定义假期弹窗的日期选择交互。

---

## 提交分组

| # | 提交 | 包含文件 |
|---|------|---------|
| 1 | UI：卡片圆角统一为上游 Miuix 固定 16dp squircle | adaptive_card, hyperos_radius, exam_list_screen, hyperos_accordion, cards, timetable_settings_screen |
| 2 | 功能：新增 Miuix 时间/数值滚轮选择器并全局替换 | miuix_time/number_picker_sheet(新), semester_week_count_picker_sheet, add_exam/add_schedule_item/add_course_screen, time_scheme_bottom_sheet, time_scheme_quick_generate_sheet, time_scheme_management_screen, l10n×11 |
| 3 | 修复：子页迁回标准列表路径恢复大标题折叠 | course_import_screen, changelog_screen, about_screen, hyperos_overlay_header |
| 4 | 优化：周预览毛玻璃带与墨色对齐首页真实观感 | timetable_week_preview |
| 5 | 优化：假期日期选择改用 Miuix 日历 sheet | settings_holiday |
| 6 | 文档：本更新日志 | 本文件 |

> 注：`time_scheme_management_screen.dart` 同时含主题一与主题三的变更，且位于同一 diff hunk 内无法整洁拆分，归入提交 2，并在提交说明中注明附带的列表路径迁移。
