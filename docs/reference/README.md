# 参考手册（docs/reference）

这里是**长期有效的规范与查表**：写页面时该用哪个组件、文案怎么写、构建/变体怎么配。
一次性审计与调研报告不放这里（见 [docs/archive/](../archive/)）。

## 1. Compose 页面与组件规范

| 文档 | 用途 |
|---|---|
| [compose-page-style-rules.md](compose-page-style-rules.md) | **写页面先读。** R1–R7 共享套件规则、配方与例外边界；守卫 `ComposePageStyleGuardTest` 的判据来源 |
| [miuix-component-first-standard.md](miuix-component-first-standard.md) | miuix 组件优先的硬标准与「例外审批登记」表 |
| [miuix-api-mapping.md](miuix-api-mapping.md) | miuix 组件/参数与我们页面的对照速查 |
| [hyperos-ui-kit.md](hyperos-ui-kit.md) | HyperOS 观感的设计语言与尺寸/色板口径 |
| [hyperos-blurred-header.md](hyperos-blurred-header.md) | 顶栏模糊/玻璃头部的实现口径 |
| [hyperos-page-compliance.md](hyperos-page-compliance.md) / [.json](hyperos-page-compliance.json) | 逐页合规快照（清单见同目录 `hyperos-audit-*.yaml`） |
| [2号高斯模糊总结.md](2号高斯模糊总结.md) | 毛玻璃在 Android 上的实现笔记（RenderEffect / stack blur） |
| [app-toast.md](app-toast.md) / [app-toast-spec.md](app-toast-spec.md) | 应用内提示胶囊的外观与行为规格 |
| [page-index.md](page-index.md) | **生成物**：全部页面 → 源码路径索引（`python tool/page_index.py` 重新生成，勿手改） |

## 2. 构建与工程

| 文档 | 用途 |
|---|---|
| [build-variants.md](build-variants.md) | dev / prod、Bench、无 Flutter 构型等变体怎么配、怎么编 |
| [changelog-2026-07-29-worktree.md](changelog-2026-07-29-worktree.md) / [changelog-2026-07-30-sheet-fixes.md](changelog-2026-07-30-sheet-fixes.md) | 两次较大改动的过程记录（历史参考） |

## 3. `miuix-demo/`：上游只读副本（教科书）

[miuix-demo/](miuix-demo/) 是 **vendored 的第三方参考副本，不是本仓代码**：

- 内容：miuix 官方 demo 与组件文档的只读快照（上游 commit `bb7bde3`，2026-10-27 取回，Apache-2.0）；
- **只读**：不要在 `docs/reference/miuix-demo/**` 里改任何东西——上游一升级，改动就丢；
- 查用法从这里开始：`miuix-demo/docs/zh_CN/components/*.md`（中文文档）→
  `miuix-demo/docs/demo/src/commonMain/kotlin/*Demo.kt`（最聚焦的可运行示例）→
  `miuix-demo/example/`（带分组上下文的完整 demo）；
- 本仓自己的精读笔记在 `miuix-demo/CHEATSHEET-*.md`（那几份可以改，是我们写的）。

完整说明（来源、版本对应、搬进来时剔除了什么、怎么用）见 [miuix-demo/README.md](miuix-demo/README.md)。

## 4. 其他参考

| 文档 | 用途 |
|---|---|
| [forui/](forui/) | 旧 Forui 组件库的迁移参考（legacy，新代码不要再用） |
