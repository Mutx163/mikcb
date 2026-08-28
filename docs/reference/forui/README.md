# Forui 文档镜像（AI 参考）

本目录存放 [Forui 官方文档](https://forui.dev/docs) 的本地镜像，供 AI 与离线查阅。

## 文件

| 文件 | 说明 | 在线源 |
|------|------|--------|
| `llms.txt` | 文档索引（标题 + 描述 + 链接） | https://forui.dev/docs/llms.txt |
| `llms-full.txt` | **全量**文档正文（Markdown，含代码示例与 API） | https://forui.dev/docs/llms-full.txt |
| `mikcb-settings-screen-layout.md` | mikcb 项目内 Forui 设置页/表单页布局约定 | 源自 `.trellis/spec/flutter/settings-screen-layout.md` |

## 使用建议

- 查 Forui 组件 API、主题、Sheet/Dialog 等：**优先读 `llms-full.txt`**
- 快速定位某一页：**先读 `llms.txt` 索引**
- 改 mikcb 设置页、表单页、Bottom Sheet：**同时参考 `mikcb-settings-screen-layout.md`**

## 更新

Forui 文档会随版本更新。需要刷新时：

```powershell
curl.exe -sL "https://forui.dev/docs/llms.txt" -o docs/reference/forui/llms.txt
curl.exe -sL "https://forui.dev/docs/llms-full.txt" -o docs/reference/forui/llms-full.txt
```

当前项目已移除 `forui` 依赖（历史版本 `forui: ^0.23.0`，见提交 2b19a896）；本目录仅保留文档镜像供离线查阅。
