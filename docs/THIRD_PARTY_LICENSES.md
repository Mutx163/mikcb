# 第三方组件与许可

本文件说明 mikcb（轻屿课表）**源码之外**随应用分发或运行时依赖的第三方组件。
应用**源码**以 [GPL-3.0-or-later](../LICENSE) 发布；下列组件适用各自许可证。

> App 内「关于 → 开源许可」页读的是 APK 打包的 `assets/licenses/NOTICES.gz`（逐条许可全文，
> 由 `tool/license_notices/generate_notices.py` 从 release 运行时依赖树重生成）；
> 本文件是给人看的清单与说明，两者应保持同一口径。

## Android / Kotlin 运行时依赖（随 APK 打包）

| 组件 | 用途 | 版本 | 许可 |
|------|------|------|------|
| AndroidX（core / activity / lifecycle / work / camera 等） | 系统 API 封装、相机、后台任务 | 随 AGP 解析 | Apache-2.0 |
| Kotlin 标准库 / kotlinx.coroutines | 语言运行时与协程 | 2.4.21 / 传递依赖 | Apache-2.0 |
| Jetpack Compose（runtime / ui / foundation） | 声明式 UI | 1.12 | Apache-2.0 |
| miuix（ui / preference / icons / blur / nav） | HyperOS 风格组件、导航运行时与玻璃效果（其中 `miuix-ui` 为本地 fork：`android/third_party/miuix-ui`） | 0.9.4 | Apache-2.0 |
| OkHttp / Okio | HTTP 客户端 | 4.12.0 / 传递依赖 | Apache-2.0 |
| CameraX（core / camera2 / lifecycle / view） | 相机预览与扫码取流 | 1.6.1 | Apache-2.0 |
| androidx.core:core-splashscreen | 启动画面兼容 | 1.0.1 | Apache-2.0 |
| androidx.compose.ui:ui-tooling-preview | `@Preview` 注解（渲染器 `ui-tooling` 只在 debug 变体，不进正式包） | 1.12.1 | Apache-2.0 |

> 上表只列直接声明的组件；传递依赖的完整清单与逐条许可正文以 App 内许可页为准。

## 闭源商业 SDK（随 APK 打包，**不是开源**）

| 组件 | 用途 | 条款 |
|------|------|------|
| 友盟 common / asms / apm / uyumao（9.6.3 / 1.8.0 / 2.1.0 / 1.1.2） | 统计与崩溃诊断（用户同意后才初始化） | 闭源商业 SDK，[友盟协议](https://www.umeng.com/policy) |
| Google ML Kit barcode-scanning 17.3.0（bundled 模型） | 离线二维码识别 | 闭源，[ML Kit 条款](https://developers.google.com/ml-kit/terms) |

> 两者都是预编译二进制，**不包含在本仓库源码中**；分发 APK 时一并打包。若你 fork 本仓库自行构建，需自行评估 SDK 使用条款。
> 许可页对它们如实写「闭源组件 + 条款链接」，不会伪装成开源许可。
>
> 注意一个容易看错的点：友盟四个构件的 **Maven POM 里把 `<licenses>` 写成了 Apache-2.0**，
> 与《友盟 SDK 使用协议》不一致。许可清单按「闭源商业 SDK」处理，并在条目里写明这处出入；
> 有疑问时以官方协议为准，不要因为有 Apache 字样就当开源。

**不随 APK 分发**：`junit:junit:4.13.2`（`testImplementation`）、`androidx.compose.ui:ui-tooling`（`debugImplementation`）。

## 内联移植 / 内联打包的第三方代码（源码内）

| 来源 | 许可 | 位置 |
|------|------|------|
| [Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass) | Apache-2.0 | `android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/liquid/` 下 6 个文件：`LiquidLens` / `LiquidCombinedBackdrop` / `LiquidDampedDrag` / `LiquidInnerShadow` / `LiquidInteractiveHighlight` / `LiquidVibrancy`，每个文件头都带 `Adapted from …` 署名 |
| [Tabler Icons](https://github.com/tabler/tabler-icons) v3.31.0 | MIT | 局域网控制台图标子集 `android/app/src/main/assets/lan_edit/tabler-icons-subset.css`（38 个 outline 图标，本地内联，不走 CDN） |

> 历史署名：[bokeh-lava-gradient](https://github.com/keepYaoung/bokeh-lava-gradient)（MIT，© keepYaoung / tommy / joon shin）——
> 2026-09-13 内置壁纸功能整体移除时，随之删掉了唯一的内联移植代码。

## 自带资源与数据

- 应用图标、捐赠二维码、局域网控制台页面（HTML / CSS / JS）：自有。
- 节假日表 `assets/holidays/*.json`：公开放假安排的整理快照，不含第三方代码。
- 字体：不打包第三方字体，全部跟随系统。
- 壁纸：用户自选，或运行时从 Bing 每日壁纸下载，不随包分发。

## 远程服务（不随 APK 打包）

| 服务 | 用途 |
|------|------|
| GitHub Releases / raw | 应用更新与发布说明 |
| GitCode（API + 发布页） | 国内镜像与备用更新源 |
| 蒲公英 | 备用下载页 |
| Open-Meteo（含 BigDataCloud 反查城市） | 天气与定位反查 |
| holiday.ailcc.com | 节假日数据更新 |
| Bing 每日壁纸 | 壁纸图库 |
| 用户配置的 WebDAV（如坚果云） | 可选云同步 |
| 学校教务系统 | 用户主动导入 |
| 友盟后端 | 统计 / APM（可选，需同意） |
| GitHub 镜像加速前缀（ghfast.top 等） | 更新包下载加速，可在设置里切换 |

## 商标

「小米」「HyperOS」「澎湃OS」等均为其各自所有者商标。本应用为非官方第三方作品，详见 [docs/PRIVACY.md](./PRIVACY.md) 与应用内免责声明。

## 更新

- 发版前若新增或移除重大第三方依赖，**同一批改动**里更新本文件，并重跑
  `tool/license_notices/generate_notices.py --write` 重生成 App 内清单；
  之后按 `tool/license_notices/README.md` 更新 `FlutterAssetsDecouplingGuardTest` 里的 SHA-256 钉值。
- 去 Flutter 化（2026-11 完成）后，本文件与 `NOTICES.gz` 都不再与 Flutter / Dart 的依赖有关。

Last updated: 2026-11-10（Compose 重构版 3.0.0 发版前）。
