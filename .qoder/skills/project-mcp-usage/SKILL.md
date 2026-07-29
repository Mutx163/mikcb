---
name: project-mcp-usage
description: 当需要分析 Dart/Flutter 代码（静态分析、运行测试、pub 依赖、热重载/检查运行中应用）或读取 VS Code 调试会话的 Debug Console 日志时使用。说明本项目两个 MCP（dart-mcp-server、debug-console-plus）各自的适用任务、验证边界与 CLI 回退方式。
---

# 项目 MCP 使用指引

本项目在 `.mcp.json` 中配置了两个 MCP 服务器。本 Skill 是它们的工作流责任方：约定何时使用、如何验证、失败时如何回退。

## dart-mcp-server

- **适用任务**：Dart/Flutter 代码分析类任务——静态分析、符号解析、pub 依赖查询、运行测试、连接运行中的应用做热重载/检查。
- **验证边界**：分析与测试结果以命令实际输出为准；对运行中应用的操作（热重载等）仅限本地开发会话，不做发布类操作。
- **失败回退**：MCP 不可用或调用失败时，直接使用 `dart` / `flutter` CLI（如 `flutter analyze`、`flutter test`、`dart pub`）。

## debug-console-plus

- **适用任务**：调试日志读取类任务——读取 VS Code 调试会话的 Debug Console 输出，定位运行时报错、验证调试打印。
- **验证边界**：只读日志，不修改调试会话状态。
- **失败回退**：MCP 不可用时，直接读取 `flutter run` 的终端输出，或工作区根目录下的 `flutter_0*.log` 日志文件。

## 相关文档

- 研究/调试阶段何时引入 MCP：参见 `.trellis/workflow.md` 的 Research 一节。
- AGENTS.md 中的"项目 MCP 使用指引"一节是本 Skill 的入口路由。
