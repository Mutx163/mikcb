# flutter_miuix API vs Hyperos\* Wrapper API 映射

> 生成日期: 2026-07-29
> 来源: `.tmp/flutter_miuix_fork/` (Apache-2.0) + `lib/ui/hyperos/`

---

## 1. 颜色映射 (Colors)

HyperosColors 是一个静态方法类,每个方法接收 `BuildContext` 并根据浅色/深色模式委托给 `HyperosMiuixLightColors` 或 `HyperosMiuixDarkColors`。后者是从 Miuix 的 `lightColorScheme()` / `darkColorScheme()` 手抄的常量。

MiuixColors 是一个实例类,通过 `MiuixTheme.of(context).colors` 获取。

下表为 `HyperosColors.xxx(context)` → `MiuixColors.xxx` 的映射:

| HyperosColors 方法 | MiuixColors 字段 | 语义 |
|---|---|---|
| `scaffoldBackground(context)` | `background` (浅色用 `HyperosTokens.background` = `surfaceContainer`) | 页面背景 |
| `card(context)` | `surfaceContainer` | 卡片/列表组白色表面 |
| `primaryText(context)` | `onBackground` (浅色用 `HyperosTokens.primaryText`) | 主要文字色 |
| `secondaryText(context)` | `onSurfaceVariantSummary` (浅色用 `HyperosTokens.secondaryText`) | 次要文字色 |
| `actionIcon(context)` | `onSurfaceVariantActions` | 操作图标/折叠箭头色 |
| `rowHighlight(context)` | — (浅色用 `HyperosTokens.pressed` = `0xFFE0E0E0`) | 行按压色 |
| `sectionLabel(context)` | `onSurfaceVariantActions` | 分区标题色 |
| `primary(context)` | `primary` | 主题强调色 |
| `surfaceContainer(context)` | `surfaceContainer` | 表面容器色 |
| `surfaceContainerHighest(context)` | `surfaceContainerHighest` | 最高层表面容器色 |
| `error(context)` | `error` | 错误色 |
| `onError(context)` | `onError` | 错误上文字色 |
| `outline(context)` | `outline` | 描边/边框色 |
| `dividerLine(context)` | `dividerLine` | 分隔线色 |
| `sliderBackground(context)` | `sliderBackground` | 滑块背景色 |
| `onSurface(context)` | `onSurface` | 表面文字色 |
| `windowDimming(context)` | `windowDimming` | 遮罩色 |
| `secondary(context)` | `secondary` | 次要色 |
| `onPrimary(context)` | `onPrimary` | 主要色上文字色 |
| `onSecondary(context)` | `onSecondary` | 次要色上文字色 |
| `secondaryContainer(context)` | `secondaryContainer` | 次要容器色 |
| `secondaryVariant(context)` | `secondaryVariant` | 次要变体色 |
| `onBackground(context)` | `onBackground` | 背景文字色 |
| `onSurfaceVariantSummary(context)` | `onSurfaceVariantSummary` | 摘要文字色 |
| `onSurfaceVariantActions(context)` | `onSurfaceVariantActions` | 操作文字色 |
| `surface(context)` | `surface` | Surface 色 |
| `surfaceContainerHigh(context)` | `surfaceContainerHigh` | 高层表面容器色 |
| `elevatedSurface(context)` | `surfaceContainerHighest`(暗)/`surfaceContainer`(浅) | 浮动面板背景 |
| `inverseSurface(context)` | `surfaceContainerHighest`(暗)/`onSurface`(浅) | 反色表面(提示) |
| `onInverseSurface(context)` | `onSurface`(暗)/`onPrimary`(浅) | 反色表面上文字 |
| `disabledPrimary(context)` | `disabledPrimary` | 禁用主题色 |
| `disabledSecondary(context)` | `disabledSecondary` | 禁用次要色 |
| `disabledOnPrimary(context)` | `disabledOnPrimary` | 禁用主题色文字 |
| `disabledOnSecondary(context)` | `disabledOnSecondary` | 禁用次要色文字 |
| `disabledPrimaryButton(context)` | `disabledPrimaryButton` | 按钮禁用主题色 |
| `disabledOnPrimaryButton(context)` | `disabledOnPrimaryButton` | 按钮禁用主题色文字 |
| `disabledPrimarySlider(context)` | `disabledPrimarySlider` | 滑块禁用主题色 |
| `disabledOnSurface(context)` | `disabledOnSurface` | 禁用表面文字色 |
| `onSecondaryVariant(context)` | `onSecondaryVariant` | 次要变体色文字 |
| `disabledSecondaryVariant(context)` | `disabledSecondaryVariant` | 禁用次要变体色 |
| `disabledOnSecondaryVariant(context)` | `disabledOnSecondaryVariant` | 禁用次要变体色文字 |

> **补充**: `HyperosIconColors` 是独立于 Miuix 的自定义图标着色常量(蓝色/绿色/橙色/紫色/青色/红色/黄色/靛蓝/橙色),无 Miuix 对应项。

---

## 2. 排版映射 (Typography → TextStyles)

HyperosTypography 是静态方法类,每个方法返回动态构建的 `TextStyle`(基于 `HyperosTokens` 中的字号引用)。MiuixTextStyles 是预构建的不可变实例,在 `MiuixTheme` 中提供,通过 `MiuixTheme.of(context).textStyles` 访问。

| HyperosTypography 方法 | MiuixTextStyles 字段 | 字号 (Hyperos → Miuix) |
|---|---|---|
| `title(context)` / `listTitle(context)` | `main` | `HyperosTokens.titleSize`(17sp) → 17sp |
| `listDetail(context)` | `body2` | `HyperosTokens.listDetailSize`(14sp) → 14sp |
| `sectionLabel(context)` | `footnote1` | `HyperosTokens.sectionLabelSize`(13sp) → 13sp |
| `sectionDescription(context)` | `footnote1` | `HyperosTokens.sectionDescriptionSize`(13sp) → 13sp |
| `sheetTitle(context)` | — (继承 `title` → `main`) | 17sp |
| `summaryTitle(context)` | — (继承 `title` → `main`) | 17sp |
| `summarySubtitle(context)` | — (引用 `footnote1` 字号) | `HyperosMiuixTypography.footnote1`(13sp) → 13sp |

**说明**:
- HyperosTypography 始终显式设置 `fontSize`、`fontWeight`、`color`、`height`。
- MiuixTextStyles **仅**定义字号/字重/行高;颜色由 `MiuixTheme` 注入。
- `HyperosMiuixTypography` 是独立常量类(定义字号数字),与 `MiuixTextStyles` 字号一致。
- HyperosTypography 的标题方法直接引用 `HyperosTokens.titleSize`(可调),而 MiuixTextStyles.main 固定为 17sp。

---

## 3. 组件映射 (Components)

| Hyperos\* 组件 | Miuix 等价组件 | 说明 |
|---|---|---|
| `HyperosSwitch` | `MiuixSwitch` | **直接包装**,完全委托 |
| `HyperosSlider` | `MiuixSlider` | **直接包装**,增加 divisions → steps 转换 |
| `HyperosSliderTile` | `MiuixSliderPreference` | 标题+值+滑块行,包装 MiuixSliderPreference 模式 |
| `HyperosButton` | `MiuixButton` / `MiuixTextButton` | 自定义构建,使用 MiuixButton 尺寸常量(minHeight/cornerRadius/insideMargin) |
| `HyperosFrostedSheetButton` | (无) | 自定义:在 HyperosFrostedSurface 上构建 |
| `HyperosListTile` | `MiuixArrowPreference` | 图标+标题+详情+箭头行 |
| `HyperosNavTile` | `MiuixArrowPreference` | 图标+标题+副标题+详情+箭头 |
| `HyperosSwitchTile` | `MiuixSwitchPreference` | 图标+标题+开关键行 |
| `HyperosChoiceTile` | `MiuixRadioButtonPreference` / `MiuixCheckboxPreference` | 单选/多选行 |
| `HyperosChoiceGroup` | (Miuix 基本组件组) | 包装 `HyperosListGroup` |
| `HyperosSwitchListGroup` | (Miuix 基本组件组) | 包装 `HyperosListGroup` |
| `HyperosActionTile` | (无) | 自定义:蓝色轮廓图标行 |
| `HyperosDangerTile` | (无) | 自定义:红色危险操作行 |
| `HyperosCheckbox` | `MiuixCheckbox` | 等价 |
| `HyperosFAB` | `MiuixFloatingActionButton` | 等价 |
| `HyperosIconButton` | `MiuixIconButton` | 等价 |
| `HyperosBadge` | `MiuixBadge` | 等价 |
| `HyperosSnackbar` | `MiuixSnackbar` | 等价 |
| `HyperosTabRow` | `MiuixTabRow` | 等价 |
| `HyperosTextField` | `MiuixTextField` | 等价 |
| `HyperosTooltip` | `MiuixTooltip` | 等价 |
| `HyperosProgress` | `MiuixProgressIndicator` | 等价 |
| `HyperosNumberPicker` | `MiuixNumberPicker` | 等价 |
| `HyperosNavigationBar` | `MiuixNavigationBar` | 包装 Miuix NavigationBar 尺寸常量 |
| `HyperosFloatingToolbar` | `MiuixFloatingToolbar` | 等价 |
| `HyperosPullToRefresh` | `MiuixPullToRefresh` | 等价 |
| `HyperosDialog` | `MiuixOverlayDialog` | 等价 |
| `HyperosSheet` | `MiuixBottomSheet` | 等价 |
| `HyperosSelect` / `HyperosListPopup` | `MiuixDropdown` / `MiuixDropdownPreference` / `MiuixListPopup` | 选择弹窗 |
| `HyperosListGroup` | (MiuixCard 组) | 列表组卡片,使用 MiuixCard 半径常量(`HyperosMiuixCard.cornerRadius` = 24) |
| `HyperosControlCard` | `MiuixCard` | 自定义:标题+子内容卡片 |
| `HyperosAdaptiveCard` | — | 自适应圆角卡片 |
| `HyperosPressableRow` | `MiuixPressable` | 行按压效果,使用 MiuixPressable 按压语义 |
| `HyperosChevron` | `MiuixArrowPreference` 尾部箭头 | 自定义绘制箭头图标 |
| `HyperosColorChip` | (无) | 自定义颜色色块 |
| `HyperosEmptyState` | (无) | 自定义空状态 |

---

## 4. 无 Miuix 等价的组件 (需自定义处理)

以下 Hyperos\* 组件**没有**对应的 flutter_miuix 组件,由 Hyperos\* 基于 Forui/Framework 自定义构建:

| 组件 | 位置 | 说明 |
|---|---|---|
| `HyperosRootPage` | `hyperos_page.dart` | 基于 `FScaffold` + `FHeader` + 自定义模糊标题栏。Miuix 有 `MiuixTopAppBar` 但无页面壳概念 |
| `HyperosSubpage` | `hyperos_page.dart` | 基于 `FScaffold` + 可折叠大标题 + 返回按钮。Miuix 无子页面壳 |
| `HyperosListView` | `hyperos_page.dart` | 自定义列表视图,带 blur inset/overscroll physics/scroll-to-top。Miuix 无滚动列表壳 |
| `HyperosBlurredHeader` | `hyperos_blurred_header.dart` | 液态玻璃标题壳,使用 `BackdropFilter` + `ImageFilter.blur()` |
| `HyperosCollapsibleTopAppBar` | `hyperos_collapsible_top_app_bar.dart` | 可折叠大标题,HyperOS 系统设置首页模式 |
| `HyperosControlCardInset` | `hyperos_controls.dart` | 控制卡内边距辅助 |
| `HyperosAccordion` | `hyperos_accordion.dart` | 折叠面板组件 |
| `HyperosEmptyState` | `hyperos_empty_state.dart` | 空状态占位 |
| `HyperosColorChip` | `hyperos_color_chip.dart` | 颜色选择圆片 |
| `HyperosNavigation` | `hyperos_navigation.dart` | 页面跳转导航 |
| `HyperosLayoutTuning` | `hyperos_layout_tuning.dart` | 布局微调工具 |
| `HyperosMotion` | `hyperos_motion.dart` | 动画曲线/持续时间 |
| `HyperosOverscroll` | `hyperos_overscroll.dart` | 自定义 overscroll 物理效果 |
| `HyperosOverlayHeader` | `hyperos_overlay_header.dart` | 覆盖层标题助手 |
| `HyperosRadius` | `hyperos_radius.dart` | 半径计算工具 |
| `HyperosPageCollaborators` | `hyperos_page_collaborators.dart` | 路由模糊门/惯性偏移 |
| `HyperosFrostedSheetButton` | `hyperos_controls.dart` | 毛玻璃面板上的按钮 |
| `HyperosFrostedSurface` | `frosted/` | 毛玻璃表面 |
| `HyperosLiquidGlass` | `liquid/` | 液态玻璃效果 |

---

## 5. 基础设施映射

| Hyperos\* | Miuix 等价 | 说明 |
|---|---|---|
| `hyperos_miuix_spec.dart` (HyperosMiuixSpec) | `miuix_colors.dart` + `miuix_button.dart` + `miuix_switch.dart` + 其他组件的 Defaults | 手抄的 Miuix 常量:颜色、字号、组件尺寸 |
| `HyperosMiuixLightColors` | `lightColorScheme()` | 浅色方案手抄 |
| `HyperosMiuixDarkColors` | `darkColorScheme()` | 深色方案手抄 |
| `HyperosMiuixTypography` | `defaultTextStyles()` | 字号手抄(不含颜色/行高) |
| `HyperosMiuixButton` | `MiuixButtonDefaults` | 按钮尺寸常量 |
| `HyperosMiuixSwitch` | `MiuixSwitchDefaults` | 开关尺寸常量 |
| `HyperosMiuixCard` | `MiuixCard` | 卡片组间距 |
| `HyperosMiuixBasicComponent` | `MiuixBasicComponentDefaults` | 基本组件内边距 |
| `HyperosMiuixArrowPreference` | `MiuixArrowPreferenceDefaults` | 箭头组件尺寸 |
| `HyperosMiuixTopAppBar` | `MiuixTopAppBar` | 顶部栏常量 |
| `HyperosMiuixDropdown` | `MiuixDropdownDefaults` | 下拉选择常量 |
| `HyperosMiuixNestedHeader` | (无) | 嵌套标题尺寸,无 Miuix 对应 |

---

## 6. 总结:架构差异

```
                     Hyperos* 封装层
                     ┌─────────────────────────────────┐
                     │  HyperosColors (上下文感知静态)   │
                     │  HyperosTypography (动态构建Text) │
                     │  HyperosTokens (布局标记常量)      │
                     ├─────────────────────────────────┤
                     │  组件包装层                       │
                     │  HyperosSwitch → MiuixSwitch     │
                     │  HyperosButton → 构建式包装       │
                     │  HyperosSlider → MiuixSlider     │
                     │  HyperosSwitchTile → 包装模式     │
                     ├─────────────────────────────────┤
                     │  自定义组件 (Forui + 模糊 + 玻璃) │
                     │  HyperosSubpage / RootPage       │
                     │  HyperosListView                 │
                     │  HyperosBlurredHeader            │
                     └─────────────────────────────────┘
                              │ 依赖
                              ▼
                     flutter_miuix (Apache-2.0)
                     ┌─────────────────────────────────┐
                     │  MiuixTheme/Colors/TextStyles     │
                     │  Miuix* 组件 (Switch/Slider/Button)│
                     │  Miuix*Preference 系列           │
                     │  MiuixPressable/MiuixContentColor │
                     │  MiuixSquircle/MiuixBlur         │
                     └─────────────────────────────────┘
```

关键差异:

1. **颜色访问模式**: HyperosColors 是静态方法 + BuildContext; MiuixColors 是实例 + `MiuixTheme.of(context).colors`
2. **排版**: HyperosTypography 每次构建 TextStyle; MiuixTextStyles 预构建,通过主题注入颜色
3. **组件风格**: Miuix 使用 `MiuixBasicComponent` 作为所有 Preference 行的基础; Hyperos\* 使用 `HyperosPressableRow` + `hyperosListRowShell` + `HyperosTokens.rowPadding` 模式
4. **页面壳**: Hyperos\* 基于 Forui 的 `FScaffold`,带有液态玻璃/模糊效果; Miuix 有 `MiuixTopAppBar` 但无完整页面壳
5. **依赖**: flutter_miuix 是 Compose Multiplatform → Flutter 移植的独立包; Hyperos\* 是项目内自定义封装,可独立于 Miuix 运行
