# 工作区变更更新日志（2026-07-30）

> 本文档记录本次提交的变更原因、变更内容及影响范围。
> 对应提交：见文末「提交分组」一节。

---

## 主题一：滑块/弹窗压暗层全面重构

**变更原因**：一周前的提交 `515e620` 将 `HyperosSlider` 从原生 `SliderTheme+Slider` 切换为 `MiuixSlider`，同时自研了 `_HyperosSheetRouteBody`（Stack + evenOdd 路径挖孔的压暗层）。该方案存在一系列未解决的缺陷：

1. **evenOdd 孔是方形的**：弹窗有圆角，压暗孔却是矩形，视觉上圆角弹窗周围露出方形的阴影边界，极不协调。
2. **孔位置只测首帧**：键盘弹出/收回时弹窗位置变化，压暗孔仍留在原地，造成阴影错位（"老人慢慢收"）。
3. **孔底部没算 keyboardInset**：弹窗底部阴影缺失（见下），在无安全区设备上底部 12px 压暗带完全不可见。
4. **弹窗颜色不一致**：选择弹窗（popup）用了 `nestedTile` 角色 + `contentLegibilityFill: false`，与对话框（dialog）的 `sheet` 角色使用不同的液态玻璃参数，亮度和质感明显不同。
5. **滑块字体粗细不受 MiuixFontWeightScope 补偿**：系统调粗字体后，可折叠大标题硬编码的 `FontWeight.w400` 被叠加上系统增量变粗，而下方走 MiuixTheme 补偿的标题正常。

### 变更详情

#### `lib/ui/hyperos/hyperos_sheet.dart` — 弹窗压暗方案彻底重写
- **移除** `_HyperosSheetRouteBody`（StatefulWidget，~140 行）+ `_SheetDimPainter`（CustomPainter，~90 行）
- **新增** `_HyperosSheetPanel`：纯布局组件（StatelessWidget，~30 行），只做键盘避让，不含任何压暗层
- **压暗方案**：在 `HyperosSheetFrame._buildFloatingPanel` 中用 `DecoratedBox(boxShadow: [BoxShadow(...)])` 替代全屏挖孔方案。阴影是卡片的一部分，四边都有、圆角天然匹配、随卡片移动、玻璃采样的是亮的页面内容（阴影在玻璃背后）。
- `showHyperosSheet`：`barrierDismissible` 改为直接使用 `isDismissible` 参数（由 `showGeneralDialog` 原生处理）
- 移除不再需要的 `resolvedDim` 临时变量，`barrierColor` 参数保留（API 兼容，当前未使用）

#### `lib/ui/hyperos/hyperos_select.dart` — 选择弹窗液态玻璃统一
- `_HyperosSelectPopupGlass`：液态玻璃角色从 `nestedTile` 改为 `sheet`，与对话框使用相同玻璃参数（`thickness:20, blur:10, glassColor:0x33FFFFFF`）
- `contentLegibilityFill` 改为 `true`，加上白色衬底，跟对话框视觉效果一致

#### `lib/ui/hyperos/hyperos_dialog.dart` — 弹窗内边距调整
- 对话框 `padding` 从 `HyperosMiuixDialog.insideMarginHorizontal/Vertical`（24dp）改为 `EdgeInsets.fromLTRB(16, 16, 16, 16)`，与选择弹窗一致

#### `lib/ui/hyperos/hyperos_theme.dart` — 滑块底色修复
- `sliderBackground` 亮色模式从 `Color(0x33000000)`（20% 黑）改回 `HyperosMiuixLightColors.sliderBackground`（`0x0F000000`，≈6% 黑），与 Miuix 默认值一致

#### `lib/ui/hyperos/hyperos_collapsible_top_app_bar.dart` — 折叠标题字重补偿
- 新增 `_fontWeightDelta` 属性，读取 `MiuixTheme.maybeOf(context)?.fontWeightAdjustment`
- `_largeTitleStyle` / `_smallTitleStyle` / `_subtitleStyle` 从硬编码 `FontWeight.w400`/`w500`/`w400` 改为减去系统增量后 clamp 到合法范围，与 MiuixFontWeightScope 的补偿逻辑保持一致

#### `lib/ui/hyperos/hyperos_controls.dart` — 滑块修复
- `HyperosSlider` 外层 `SizedBox` 增加 `width: double.infinity`，修复 `MiuixSlider` 在首次布局时因松宽度约束导致 `CustomPaint(sizedByParent:true)` 取到零宽度的 bug
- 新增 `hapticEffect` 参数（有 divisions 时用 `step` 模式，连续时用 `edge`），恢复步进滑块震动反馈

#### `lib/widgets/timetable_text_color_settings.dart` — 文字颜色设置迁移
- 移除 `flex_color_picker` 导入，替换为 `flutter_miuix`（`MiuixColorPicker`）
- `_showColorPicker` 中的 `ColorPicker`（flex_color_picker）替换为 `MiuixColorPicker`
- `_ModeColorSettings` 容器从 `Container+BoxDecoration` 改为 `Material` + `MiuixCardDefaults.cornerRadius`
- 顶部加 `HyperosSectionGap()` 修复与上方卡片间距
- 颜色选择弹窗 padding 统一为 16dp

#### `lib/screens/settings/settings_course_card.dart` — 预览区橡皮筋禁用
- `SingleChildScrollView` 增加 `physics: const ClampingScrollPhysics()`，预览区拖到底/顶时硬停，不再弹跳

---

## 提交分组

| 分组 | 文件 |
|------|------|
| 弹窗压暗方案重写 | `hyperos_sheet.dart` |
| 选择弹窗玻璃统一 | `hyperos_select.dart` |
| 弹窗内边距 | `hyperos_dialog.dart` |
| 滑块修复 | `hyperos_controls.dart`， `hyperos_theme.dart` |
| 标题字重补偿 | `hyperos_collapsible_top_app_bar.dart` |
| 文字颜色设置迁移 | `timetable_text_color_settings.dart` |
| 预览区橡皮筋 | `settings_course_card.dart` |
