# Forui 历史参考（项目已不再使用 Forui）

> **项目从 miuix + Compose 路线开始就不再使用 Forui**（`forui: ^0.23.0` 已于提交 `2b19a896` 移除，
> `pubspec.yaml` / `pubspec.lock` 里现在 0 处）。本目录保留的只是**历史参考**，
> 不是当下写页面该看的东西。**写新的 Compose 页面请读
> [`docs/reference/compose-page-style-rules.md`](../compose-page-style-rules.md)。**

## 文件

| 文件 | 说明 |
|------|------|
| `mikcb-settings-screen-layout.md` | mikcb 项目内 Forui 时代设置页/表单页的布局约定（源自 `.trellis/spec/flutter/settings-screen-layout.md`）。**这是本目录唯一一份我们自己写的内容**，其中「不要在分组卡片里再套卡片」这条仍然适用 |

## 官方文档镜像已删除（2026-10-31）

原先这里还有 `llms.txt` / `llms-full.txt`（Forui 官方文档的本地镜像，共 456 KB）。
项目已不用 Forui，且这两份是纯第三方文本、随时可从上游重新拉取，因此清掉，为仓库减重。
需要时按原样重新拉：

```powershell
curl.exe -sL "https://forui.dev/docs/llms.txt"      -o docs/reference/forui/llms.txt
curl.exe -sL "https://forui.dev/docs/llms-full.txt" -o docs/reference/forui/llms-full.txt
```
