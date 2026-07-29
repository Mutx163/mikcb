# 项目长期记忆

## 关键区分：flutter_miuix vs 自研 HyperOS 层
- 用户提到的「小米澎湃 UI 库 / 新版 UI 库」= **flutter_miuix ^1.0.9**（pub 依赖，包在 `D:\Cache\Pub\hosted\pub.dev\flutter_miuix-1.0.9`，入口 `lib/miuix.dart`）。
- 仓库内 `lib/ui/hyperos/*` 是**自研的 HyperOS 封装层**，很多文件内部包装/重导出 miuix 组件（如 `HyperosListPopup` 替代原生 `MiuixOverlayListPopup`）。两者不是同一回事，统计「miuix 接入」时要按 `miuix.dart` 导出清单逐项比对项目 `lib/` 引用。
- **2026-07-29 决定**：逐步淘汰自研 Hyperos* 层，全部改用 flutter_miuix 的 **Miuix*** API（MiuixColors, MiuixTextStyles, MiuixButton 等）。审计和导入方式需同步更新。
- **2026-07-29 完成**：`lib/ui/hyperos/hyperos_theme.dart` 重写为委托 `MiuixTheme.of(context)`。HyperosColors 的 40+ 方法和 HyperosTypography 的 7 个方法现在全部走 Miuix 数据源。`dart analyze` 通过。其他 6 层（组件/设置行/页面壳/弹层/审计/清理）待后续 AI 继续。
- API 映射表：`docs/reference/miuix-api-mapping.md`
- 完整交接文档：`.workbuddy/memory/HANDOVER.md`

## 现有 UI 迁移跟踪机制
- HyperOS 页面级合规用 `docs/reference/hyperos-page-compliance.json` + `tool/hyperos_audit.py`（非 flutter_miuix 组件级统计）。
