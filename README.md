<p align="center">
  <img src="docs/app-icon.svg" width="96" alt="轻屿课表">
</p>

<h1 align="center">轻屿课表</h1>

<p align="center">
  <strong>面向高校教学场景的 Android 质感课表应用，深度整合 HyperOS 焦点通知与实时活动系统。</strong>
</p>

<p align="center">
  <a href="https://kotlinlang.org"><img src="https://img.shields.io/badge/Kotlin-2.4.21-7F52FF?logo=kotlin&logoColor=white" alt="Kotlin"></a>
  <a href="https://developer.android.com/jetpack/compose"><img src="https://img.shields.io/badge/Jetpack%20Compose-1.12-4285F4?logo=jetpackcompose&logoColor=white" alt="Jetpack Compose"></a>
  <img src="https://img.shields.io/badge/Platform-Android%2013%2B-34A853?logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Focus-HyperOS%20%E8%B6%85%E7%BA%A7%E5%B2%9B-FF6A00" alt="HyperOS">
  <a href="https://github.com/Mutx163/mikcb/releases"><img src="https://img.shields.io/github/v/release/Mutx163/mikcb?display_name=tag" alt="Release"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License"></a>
  <a href="https://github.com/Mutx163/mikcb/actions"><img src="https://img.shields.io/github/actions/workflow/status/Mutx163/mikcb/ci.yml?branch=main&label=CI" alt="CI"></a>
</p>

<p align="center">
  <a href="https://163366.xyz">官方站点</a> ·
  <a href="#界面展示">界面展示</a> ·
  <a href="https://docs.163366.xyz/docs/">使用文档</a> ·
  <a href="#获取与安装">下载安装</a> ·
  <a href="https://github.com/Mutx163/mikcb/releases">版本发布</a> ·
  <a href="#教务数据接入与生态支持">教务适配</a>
</p>

---

## 项目概述

轻屿课表以「非侵入式日程感知」为核心设计理念，将教学周历、分阶段动态提醒、通知栏常驻、桌面小组件与系统级灵动胶囊紧密协同。无需频繁开启应用，即可在锁屏、状态栏与桌面上即时获取准确的课程进程。

详细界面演示与设计规范请参阅 [官方站点](https://163366.xyz)。

当前 3.0 处于预发布阶段：界面层已整体迁移到 Jetpack Compose（miuix 组件库），安装包不再包含 Flutter 运行时；下方界面截图仍来自 2.x（Flutter 版），待 3.0 新包就绪后替换。

---

## 界面展示

> **截图状态**：下方 8 张为 2.x（Flutter 版）实机截图。3.0 起界面已由 Compose 重写，新版截图需维护者用 3.0 安装包在真机重新截取后替换，当前仅作界面示意。

<p align="center">
  <a href="docs/screenshots/01-week-timetable.png"><img src="docs/screenshots/01-week-timetable.png" width="23%" alt="周课表全貌" /></a>
  <a href="docs/screenshots/02-day-agenda.png"><img src="docs/screenshots/02-day-agenda.png" width="23%" alt="今日日程视图" /></a>
  <a href="docs/screenshots/03-super-island.png"><img src="docs/screenshots/03-super-island.png" width="23%" alt="HyperOS 超级岛联动" /></a>
  <a href="docs/screenshots/04-home-widgets.png"><img src="docs/screenshots/04-home-widgets.png" width="23%" alt="桌面小组件矩阵" /></a>
</p>
<p align="center">
  <a href="docs/screenshots/05-weather-integration.png"><img src="docs/screenshots/05-weather-integration.png" width="23%" alt="天气与日程感知" /></a>
  <a href="docs/screenshots/06-appearance-customization.png"><img src="docs/screenshots/06-appearance-customization.png" width="23%" alt="外观与液态材质" /></a>
  <a href="docs/screenshots/07-timetable-settings.png"><img src="docs/screenshots/07-timetable-settings.png" width="23%" alt="课表设置中心" /></a>
  <a href="docs/screenshots/08-about-app.png"><img src="docs/screenshots/08-about-app.png" width="23%" alt="纯粹克制与开源" /></a>
</p>

---

## 核心特性

### 1. 深度系统协同与动态提醒
* **HyperOS 超级岛联动**：深度接入小米 HyperOS 焦点通知系统，支持灵动胶囊毫秒级调度与大卡片展开，展开行内容支持自定义显隐与排序。
* **分阶段智能调度**：支持上课前、课中进行、临近下课多阶段动态流转与差异化视觉反馈。
* **桌面小组件矩阵**：提供今日课程、多规格课程概览（2×2 / 2×4）等小组件，与原生数据快照实时同步。
* **系统闹钟批量编排**：基于真实节次作息，通过系统时钟服务一键编排并批量注册早八上课闹钟。

### 2. 液态美学与视觉呈现
* **两档全局材质**：实体卡片与液态玻璃；液态玻璃走 miuix-blur 的 RuntimeShader 效果链（背景捕获 + 模糊 + 染色 + 边缘高光），不是截图缩放出来的假玻璃。
* **界面结构自适应**：支持经典布局与液态玻璃底部导航（玻璃坞）双重形态自由切换。
* **壁纸系统独立布局**：支持自定义壁纸位置拖拽微调与历史壁纸缓存管理，切换课表不破坏当前视觉方案。
* **多语言环境支持**：原生支持简体中文、繁体中文（台湾 / 香港）、英语、日语、韩语。

### 3. 全链路日程与协作体系
* **多课表独立隔离**：多套课表数据沙箱隔离与毫秒级即时切换，提醒系统与桌面部件实时跟随。
* **双人情侣课表协同**：支持课表交叉合并比对，智能识别同名同时段课程并聚合呈现，支持桌面组件透出。
* **无网面对面传输**：集成多帧喷泉码（Fountain Codes）二维码传输协议，无网络环境下实现完整课表秒级互传。
* **通用格式导入与导出**：支持标准 `.ics` 日历格式互转与全量数据加密备份迁移。

### 4. 学业统计与多维看板
* **全周期学业分析**：提供周视图与学期视图双维度学时分布与走势分析。
* **课程密度热力图**：直观反映一周日程负荷峰值与空余时段分布。
* **多维结构统计**：按授课教师、教学场地及多课表维度展开结构化汇总。

---

## 获取与安装

当前安装包只提供 `arm64-v8a`，最低兼容 Android 13（API Level 33）。

| 发布渠道 | 渠道类型 | 说明 |
| :--- | :--- | :--- |
| **[蒲公英下载](https://www.pgyer.com/qingyu)** | 国内快速下载通道 | 适合国内移动网络环境，支持手机直接扫码或高速直链免登录下载 |
| **[GitHub Releases](https://github.com/Mutx163/mikcb/releases)** | 官方全量发布渠道 | 正式版与预发布版首发渠道，含完整发布日志与校验文件 |
| **[GitCode 镜像](https://gitcode.com/mutx/qingyu)** | 国内代码与发布镜像 | 国内代码托管镜像，同步提供安装包发布附件 |

> **提示**：应用内已集成多更新源检测服务，用户可根据自身网络环境自由切换更新通道。

---

## 教务数据接入与生态支持

轻屿课表支持主流高校教务系统的网页鉴权导入。适配规则由独立生态仓库持续维护：

* **教务适配中心**：[Mutx163/qingyu_warehouse](https://github.com/Mutx163/qingyu_warehouse)
* **标准格式兼容**：尚未适配教务系统的高校，推荐使用标准 `.ics` 日历文件导入或通过全量数据备份进行迁移。
* **共建规范**：欢迎高校开发者参与教务解析脚本编写，具体接入协议与开发指南请参考教务仓库规范。

---

## 运行环境与权限建议

为确保 HyperOS 超级岛胶囊、实时通知与后台调度服务的稳定运行，建议在系统设置中为本应用授予以下权限：

1. **通知与焦点通知权限**：允许发送常驻通知及在 HyperOS 状态栏展示灵动胶囊；
2. **后台无限制与自启动**：防止系统电源优化机制在锁屏或息屏状态下中断节次轮询调度；
3. **免打扰访问权限**（可选）：若启用了上课前自动静音或免打扰自动化策略，需授予此权限。

相关配置指引亦可在应用内「设置 - 维护与自检 - 后台保活」中查阅与验证。

---

## 开发者指南

### 环境依赖矩阵

| 运行环境 / 工具链 | 版本 |
| :--- | :--- |
| **JDK** | 21（`:app` 的 Java / Kotlin 目标为 21） |
| **Android SDK** | compileSdk 37 / targetSdk 36 / minSdk 33 |
| **Android NDK** | 28.2.13676358 |
| **Gradle** | 9.8.2（由 `android/gradle/wrapper` 锁定） |
| **AGP** | 9.4.1 |
| **Kotlin** | 2.4.21（Compose 编译器由 Kotlin 插件接管） |
| **Compose / miuix** | Compose 1.12 · miuix 0.9.4（本地 fork：`android/third_party/miuix-ui`） |

### 编译与测试（统一走仓库脚本）

```powershell
# L0：单模块 JVM 单测（最快，改哪个域就跑哪个）
pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/<域>"

# L1：编译验证（全机互斥闸门，同一时刻只允许一个 Gradle）
pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin

# L2：全量 JVM 单测
pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest

# 页面样式守卫（只跑自己域；-Write 只删过期例外，绝不新增）
pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain <域>
```

### 生产环境构建

```bash
# 正式包：arm64-v8a，release 变体（R8 混淆 + 资源压缩）
./gradlew :app:assembleProdRelease
```

> `assemble*` / `bundle*` 属于 L3 出包，与真机安装一样**由维护者在 Windows 侧执行**；自动化 agent 不跑这两类任务、不碰设备。

### 工程命名规范与架构映射

| 命名标识 | 作用域与类型 | 规范说明 |
| :--- | :--- | :--- |
| `mikcb` | GitHub 仓库命名 | 项目主代码仓库标识 |
| `com.mutx163.qingyu` | Android Application ID | Android 包名及应用系统唯一标识 |
| `composeP1` | 源集目录 | Compose 页面整树（`android/app/src/composeP1/kotlin`，随 `main` 源集一起编译） |
| **轻屿课表** | 产品可见名称 | 面向终端用户的正式产品名称 |

---

## 技术架构

* **UI 框架**：Jetpack Compose（Kotlin 2.4.21）+ [miuix](https://github.com/compose-miuix-ui/miuix) 0.9.4 组件库（其中 `miuix-ui` 为本地 fork：`android/third_party/miuix-ui`）
* **状态与数据**：`TimetableRepository` + 不可变设置模型（`TimetableSettingsModel`）+ Compose 状态提升；落盘用 SharedPreferences
* **升级兼容**：设置存储键沿用旧版的 `flutter.*` 前缀，覆盖安装不会清空课表与设置
* **图形渲染**：miuix-blur（Android 13+ `RuntimeShader`）实现背景捕获与液态玻璃效果链；设备不支持或系统关闭动画时自动降级为实体卡片
* **系统底层集成**：Android Notification / Ongoing Promoted Activity / Foreground Service / AlarmClock
* **数据离线传输**：自研多帧喷泉码二维码（`QrFountainLt`）+ ML Kit 扫码
* **工程集成与监控**：GitHub Actions CI/CD · 友盟移动统计 (U-APM)

---

## 文档索引

* [贡献指南 (CONTRIBUTING.md)](./CONTRIBUTING.md)
* [行为准则 (CODE_OF_CONDUCT.md)](./CODE_OF_CONDUCT.md)
* [安全策略 (SECURITY.md)](./SECURITY.md)
* [隐私合规声明 (docs/PRIVACY.md)](./docs/PRIVACY.md)
* [第三方开源许可 (docs/THIRD_PARTY_LICENSES.md)](./docs/THIRD_PARTY_LICENSES.md)
* [发布流程规范 (docs/RELEASE.md)](./docs/RELEASE.md)
* [国际化协作规范 (docs/WEB_AND_L10N_WORKFLOW.md)](./docs/WEB_AND_L10N_WORKFLOW.md)

---

## 贡献者致谢

感谢所有为轻屿课表生态贡献力量的开发者与高校志愿者：

<a href="https://github.com/Mutx163/mikcb/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Mutx163/mikcb" alt="轻屿课表代码贡献者" />
</a>

### 教务适配生态致谢

教务解析脚本依托于 [qingyu_warehouse](https://github.com/Mutx163/qingyu_warehouse)，持续同步自上游开源项目 [shiguang_warehouse](https://github.com/XingHeYuZhuan/shiguang_warehouse)。特向所有参与高校教务解析规则适配的贡献者致以崇高敬意：

<!-- CONTRIBUTORS:AUTO:START -->
<img src="docs/contributors/upstream.svg" alt="XingHeYuZhuan/shiguang_warehouse 贡献者" />
<!-- CONTRIBUTORS:AUTO:END -->

以下开发者直接向教务适配仓库提交过代码，谨此致谢：

<!-- CONTRIBUTORS_DIRECT:AUTO:START -->
<img src="docs/contributors/direct.svg" alt="Mutx163/qingyu_warehouse 直接贡献者" />
<!-- CONTRIBUTORS_DIRECT:AUTO:END -->

*(教务适配贡献者名单由自动化构建任务定期同步生成)*

---

## Star History

<a href="https://www.star-history.com/?repos=mutx163%2Fmikcb&type=timeline&logscale=&releases=&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=mutx163/mikcb&type=timeline&theme=dark&legend=bottom-right" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=mutx163/mikcb&type=timeline&legend=bottom-right" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=mutx163/mikcb&type=timeline&legend=bottom-right" />
 </picture>
</a>

---

## 开源许可证

本项目源码采用 [GNU General Public License v3.0 (GPL-3.0-or-later)](./LICENSE) 协议授权。

随应用集成的第三方 SDK 及依赖库许可证清单请参阅 [docs/THIRD_PARTY_LICENSES.md](./docs/THIRD_PARTY_LICENSES.md)。
