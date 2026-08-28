# 第三方组件与许可

本文件说明 mikcb（轻屿课表）**源码之外**随应用分发或运行时依赖的第三方组件。
应用**源码**以 [GPL-3.0-or-later](../LICENSE) 发布；下列组件适用各自许可证。

## Android 原生 SDK（Maven）

| 组件 | 用途 | 许可 / 说明 |
|------|------|-------------|
| Flutter / Dart SDK | 应用框架 | BSD-3-Clause（Flutter 工具链） |
| AndroidX / Kotlin 标准库 | 系统 API 封装 | 各 Apache-2.0 等（随 AGP 引入） |
| 友盟 Common / ASMS / APM / UYumao | 统计与崩溃诊断（用户同意后） | 友盟商业 SDK，[官网协议](https://www.umeng.com/policy) |

> 友盟 SDK 为预编译二进制，**不包含在本仓库源码中**；分发 APK 时一并打包。若你 fork 本仓库自行构建，需自行评估 SDK 使用条款。

## Flutter / Dart 依赖

主要依赖见 [pubspec.yaml](../pubspec.yaml)。`flutter pub licenses` 可生完整列表。

常见依赖包括（非 exhaustive）：

- `provider` — MIT
- `http` — BSD-3-Clause
- `webview_flutter` — BSD-3-Clause
- `fl_chart` — MIT
- 其余见 `pubspec.lock` 与各 package 的 LICENSE

## Bundled 前端资源（局域网 Web 编辑）

局域网 Web 控制台使用自研 shadcn/ui 风格静态 CSS（`assets/lan_edit/lan-timetable.css`），不再捆绑 Tabler Core。

图标字体通过 CDN 加载 `@tabler/icons-webfont`（仅在用户主动开启局域网编辑、用浏览器访问时拉取）。

局域网编辑页仅在用户主动开启本地 Web 服务时使用。

## 远程服务（非随 APK 打包）

| 服务 | 用途 |
|------|------|
| GitHub Releases / raw | 应用更新、release notes、`latest.json` |
| 用户配置的 WEBDAV | 可选云同步 |
| 学校教务系统 | 用户主动导入 |
| 友盟后端 | 统计 / APM（可选，需同意） |

## 商标

「小米」「HyperOS」「澎湃OS」等均为其各自所有者商标。本应用为非官方第三方作品，详见 [docs/PRIVACY.md](./PRIVACY.md) 与应用内免责声明。

## 更新

发版时若新增重大第三方依赖，应更新本文件。Last updated: 2026-08-27.
