# HyperOS 页面合规清单

> **唯一真相来源（机器可读）：** [`hyperos-page-compliance.json`](./hyperos-page-compliance.json)  
> **组件/API 参考：** [`hyperos-ui-kit.md`](./hyperos-ui-kit.md)  
> **验收样板页：** `lib/screens/hyperos_showcase_screen.dart`

UI 迁移已从「逐页 feature 任务」改为 **持续 audit 流水线**。不再靠对话里肉眼问「这页澎湃了吗？」——改跑脚本 + 查 registry。

---

## 流水线

```
改 UI 代码
    ↓
python tool/hyperos_audit.py              # 完整报告（圆角/间距/字体/暗色/标题…）
    ↓
python tool/hyperos_audit.py --strict     # CI：error 级（禁用旧 API）
    ↓
python tool/hyperos_audit.py --perfect    # 严格完美合规（error + warn）
    ↓
（可选）python tool/hyperos_audit.py --sync-status
    ↓
核对 manual 规则 + 真机抽检
```

**CI：** `.github/workflows/ci.yml` 在 `flutter analyze` 前执行 `python tool/hyperos_audit.py --strict`。

**Agent：** 用户问「XX 页面是否符合澎湃 UI」→ 读 `mikcb-hyperos-audit` SKILL，不要即兴 grep。

---

## 合规规则

完整规则见 [`hyperos-audit-checklist.yaml`](./hyperos-audit-checklist.yaml)（圆角 / 间距 / 字体 / 暗色 / 标题 / 对话框等）。

**用户历史要求（对话提炼）：** [`hyperos-audit-user-history.yaml`](./hyperos-audit-user-history.yaml) — 你在过去会话里让改的具体 UI 项；`python tool/hyperos_audit.py --history` 逐条核对。

| 级别 | 含义 | CI |
|------|------|-----|
| **error** | 禁用旧 API（ListTile、MaterialPageRoute…） | `--strict` 失败 |
| **warn** | 字体、硬编码色、圆角、ListView 结构等 | `--perfect` 失败 |
| **info** | 间距网格、HyperosColors 使用率 | 仅报告 |
| **manual** | 箭头对称、暗色逐屏、CFH、导入子流程 | Agent/真机必查 |

### 标准值（与 `hyperos_miuix_spec.dart` 一致）

| 项 | 值 |
|----|-----|
| 卡片圆角 | **24**（`HyperosTheme.cardShape`） |
| 列表水平 padding | **16** |
| 卡片组间距 | **12** |
| 列表标题 | **17sp / w400** |
| 摘要/details | **14sp** |
| Section 标签 | **13sp / w400**（`HyperosSectionLabel`） |
| 顶栏 nestedHeader | **20sp / w400 / 居中** |
| 暗色 | `HyperosColors` 浅色 token；深色回落 Forui `FColors` |

### P0 阻断（error）

| 规则 | 说明 |
|------|------|
| 不得 `ListTile(` | 用 `HyperosListTile` |
| 不得 `MaterialPageRoute` | 用 `HyperosPageRoute` |
| 不得 `SnackBar` | 用 `showAppToast` |
| 不得 `FDialog` | 用 `showAppConfirmDialog` |
| 不得 `SettingsSectionCard` | 已删除 |

### P1 壳层

| 页面类型 | 壳层 |
|----------|------|
| 主课表 | `HyperosRootPage` |
| 二级页 | `HyperosSubpage` |
| Sheet | `HyperosSheet` / `showHyperosSheet` |

`FScaffold` / `FHeader` 为预期 Forui 残留，**不计违规**。

---

## Registry 字段

| 字段 | 含义 |
|------|------|
| `id` | 稳定标识 |
| `file` | 相对仓库根的 Dart 路径 |
| `label` | 中文页面名（报告用） |
| `category` | home / settings / form / import / live / sheet / qa … |
| `expectedShell` | `HyperosSubpage` 或 `HyperosRootPage` |
| `manualStatus` | `pass` / `partial` / `fail` / `review` |
| `allowLegacy` | `true` 时跳过 strict（如 Showcase） |
| `notes` | 人工备注；`--sync-status` 可追加 `[audit]` 前缀 |

`inferredStatus` 由脚本实时计算，不与 registry 混写（除非 `--sync-status`）。

---

## 人工抽检（脚本无法覆盖）

发版前或改 import / 表单页后，额外核对：

1. **箭头对称**：chevron 距右缘 = 标题距左缘（16dp 体系）
2. **空状态**：不顶到状态栏（`HyperosEmptyState` + 安全区）
3. **弹窗关闭后**：不误聚焦到下方 `TextField`（考试页曾出现）
4. **overlayHeader 页**：返回后 CFH 模糊不丢失（见 blurred-header spec）
5. **导入子页**：教务 WebView / 表格 / 宏录制 4 条子流程各走一遍

---

## 与旧「UI 迁移任务」的关系

- Trellis `liqkit-ui-migration` / ui-kit §3 表格：**只读历史**，不再手动维护双份状态。
- 新页面入库：在 `hyperos-page-compliance.json` 追加条目 → 跑 audit → PR 附带报告。
- 「这页有没有遗漏」的标准答案 = **`python tool/hyperos_audit.py` 输出 + registry `notes`**。

---

## 常用命令

```bash
# 人类可读报告
python tool/hyperos_audit.py

# CI / 发版 gate（禁用旧 API）
python tool/hyperos_audit.py --strict

# 严格完美澎湃 UI（含字体/颜色/圆角/间距 warn）
python tool/hyperos_audit.py --perfect

# 更新 registry 中的 manualStatus（谨慎，会改 JSON）
python tool/hyperos_audit.py --sync-status

# JSON 输出（给 agent / 脚本消费）
python tool/hyperos_audit.py --json

# 仅用户历史修改要求核对清单（对话提炼）
python tool/hyperos_audit.py --history
```
