# AI Handover — flutter_miuix 迁移项目（2026-07-29）

接手这个会话的 AI 你好，以下是当前状态、已做工作和未做工作的完整清单。

---

## 项目背景

用户卢裕天（Mutx163）的 Flutter 课表项目 `mikcb`，原使用自研 `lib/ui/hyperos/*` 封装层（37+ 模块）实现 HyperOS 风格 UI。
现在要**全部改为直接使用 `flutter_miuix: ^1.0.9` 包的 Miuix* API**。

依赖已在 `pubspec.yaml`（`flutter_miuix: ^1.0.9`），来自 pub.dev。本地 fork 在 `.tmp/flutter_miuix_fork/`。

---

## 已做的

### 1. 审计违规修复（270 条）
- 修复了 Colors.xxx → HyperosColors/HyperosIconColors 的批量替换
- 修复了 FontWeight 不规范（bold/w600→w400）
- 修复了非标准圆角和间距
- 修复了审计脚本的假阳性（HyperosIconColors.blue 被 Colors.blue 正则匹配）
- **已回退**审计正则修改（`docs/reference/hyperos-audit-checklist.yaml` 恢复原样）
- 剩余 37 条需人工判断（主要 chez TextStyle 手写字号 + 半透明 hex + textTheme 引用）
- 批量修复脚本在 `tool/fix_colors.py` 和 `tool/fix_audit_all.py`（可删）

### 2. API 映射调研
产出 → `docs/reference/miuix-api-mapping.md`
包含了颜色、字体、组件的完整 Hyperos* → Miuix* 映射表

### 3. Layer 1：主题层（已全部完成 ✅ 编译通过）
文件：`lib/ui/hyperos/hyperos_theme.dart`
- `HyperosColors` 的 40+ 个方法全部委托 `MiuixTheme.of(context).colors.xxx`
- `HyperosTypography` 的 7 个方法委托 `MiuixTheme.of(context).textStyles.xxx.copyWith(color: ...)`
- 删除了对 `forui` 包和 `hyperos_miuix_spec.dart` 的 import 依赖
- `HyperosTheme` 的 shape/style 辅助方法保持不动（它们不涉及颜色）
- 业务代码无需改动，import `ui/hyperos/hyperos.dart` 不变

---

## 未做的（按优先级排序）

### 🔴 Layer 2：基础组件替换（下个活）
替换以下组件为直接使用 Miuix*：
| 当前写法 | 目标 |
|---------|------|
| `HyperosSwitch` | `MiuixSwitch` |
| `HyperosButton` | `MiuixButton` |
| `HyperosSlider` / `HyperosSliderTile` | `MiuixSlider` / `MiuixSliderPreference` |
| `HyperosCheckbox` | `MiuixCheckbox` |
| `HyperosFAB` | `MiuixFloatingActionButton` |
| `HyperosIconButton` | `MiuixIconButton` |
| `HyperosBadge` | `MiuixBadge` |
| `HyperosTabRow` | `MiuixTabRow` |
| `HyperosTextField` | `MiuixTextField` |
| `HyperosTooltip` | `MiuixTooltip` |
| `HyperosProgress` | `MiuixProgressIndicator` |
| `HyperosNumberPicker` | `MiuixNumberPicker` |
| `HyperosNavigationBar` | `MiuixNavigationBar` |
| `HyperosFloatingToolbar` | `MiuixFloatingToolbar` |
| `HyperosPullToRefresh` | `MiuixPullToRefresh` |
| `HyperosPressableRow` | `MiuixPressable` |

**策略**：逐个改对应的 `lib/ui/hyperos/hyperos_xxx.dart` 文件，让它直接返回 Miuix 组件并逐步废弃。

### 🟠 Layer 3：设置行组件
| 当前写法 | 目标 |
|---------|------|
| `HyperosListTile` / `HyperosNavTile` | `MiuixArrowPreference` |
| `HyperosSwitchTile` | `MiuixSwitchPreference` |
| `HyperosChoiceTile` | `MiuixRadioButtonPreference` / `MiuixCheckboxPreference` |
| `HyperosSelectTile` | `MiuixDropdownPreference` |
| `HyperosListGroup` | `MiuixCard` 组合 |
| `HyperosControlCard` | `MiuixCard` |
| `HyperosSelect` / `HyperosListPopup` | `MiuixDropdown` / `MiuixListPopup` |

### 🟡 Layer 4：页面壳层（Custom — 无 Miuix 等价）
需要保留或重写，Miuix 没有等价物：
- `HyperosRootPage` — 基于 Forui `FScaffold`
- `HyperosSubpage` — 基于 Forui `FScaffold` + 可折叠大标题
- `HyperosListView` — 自定义列表+模糊inset
- `HyperosBlurredHeader` — 液态玻璃效果
- `HyperosCollapsibleTopAppBar` — 可折叠大标题
- `HyperosNavigation` — 页面转场路由
- `HyperosOverlayHeader` — 覆盖层标题

### 🟢 Layer 5：弹层/反馈
| 当前写法 | 目标 |
|---------|------|
| `HyperosDialog` / `showHyperosDialog` | `MiuixOverlayDialog` |
| `HyperosSheet` / `showHyperosSheet` | `MiuixBottomSheet` |
| `HyperosSnackbar` | `MiuixSnackbar` |
| `showHyperosListPopup` | `MiuixListPopup` |

### 🔵 Layer 6：审计规则重写
把 `tool/hyperos_audit.py` + `docs/reference/hyperos-audit-checklist.yaml` 改为检查 Miuix* API 合规

### ⚪ Layer 7：清理旧封装
删掉不再使用的 `lib/ui/hyperos/hyperos_xxx.dart` 文件

---

## 关键文件一览

| 文件 | 说明 |
|------|------|
| `lib/ui/hyperos/hyperos.dart` | 封装层 barrel export（37 个模块） |
| `lib/ui/hyperos/hyperos_theme.dart` | ✅ 已改为委托 MiuixTheme |
| `lib/ui/hyperos/hyperos_widgets.dart` | 列表/卡片组件 |
| `lib/ui/hyperos/hyperos_controls.dart` | 按钮/Slider/ControlCard |
| `lib/ui/hyperos/hyperos_page.dart` | 页面壳层 |
| `lib/ui/hyperos/hyperos_switch.dart` | 开关（已包装 MiuixSwitch） |
| `lib/ui/hyperos/hyperos_sheet.dart` | 底部面板 |
| `lib/ui/hyperos/hyperos_dialog.dart` | 对话框 |
| `lib/ui/hyperos/hyperos_navigation.dart` | 转场路由 |
| `lib/ui/hyperos/hyperos_miuix_spec.dart` | Miuix 常量手抄 → 逐步废弃 |
| `docs/reference/miuix-api-mapping.md` | ✅ API 映射表 |
| `docs/reference/hyperos-audit-checklist.yaml` | 审计规则（需重写） |
| `tool/hyperos_audit.py` | 审计脚本（需重写） |

---

## 环境注意事项
- `.git` 被沙箱损坏（refs/heads/ 缺失），Git 命令基本不可用
- 当前工作目录有 `lib/` 下多个文件的修改（之前的审计修复代码）
- `tool/fix_colors.py` 和 `tool/fix_audit_all.py` 是之前审计批量修复用的临时脚本，可删
- `dart analyze` 当前通过（No issues found）
- 使用托管 Python：`C:\Users\34045\.workbuddy\binaries\python\envs\default\Scripts\python.exe`