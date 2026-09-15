# 轻屿课表

![Flutter](https://img.shields.io/badge/Flutter-3.44.8-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-Only-34A853?logo=android&logoColor=white)
![HyperOS](https://img.shields.io/badge/Focus-HyperOS%20%E8%B6%85%E7%BA%A7%E5%B2%9B-FF6A00)
![Release](https://img.shields.io/github/v/release/Mutx163/mikcb?display_name=tag)
![CI](https://img.shields.io/github/actions/workflow/status/Mutx163/mikcb/ci.yml?branch=main&label=CI)

<p align="center">
  <img src="https://163366.xyz/app-icon.png" width="96" alt="轻屿课表">
</p>

一个面向校园场景的 Android 课表应用，优先适配小米 / HyperOS。

官网：<https://163366.xyz> · [使用文档](https://docs.163366.xyz/docs/) · [下载](https://github.com/Mutx163/mikcb/releases) · [更新日志](https://github.com/Mutx163/mikcb/releases)

课表本身不难做，难的是那几个每天都要回答的问题：还有多久上课、这节上到哪了、下一节在哪、不打开应用能不能知道。轻屿课表把课表、分阶段提醒、通知、桌面小组件和 HyperOS 超级岛接成一条链路，围绕这几件事做。应用截图见[官网](https://163366.xyz)。

## 功能

### 课表与课程

- 周视图左右滑切周、一键回本周；日视图聚焦当天安排
- 课程增删改查，可填简称、颜色、单双周、备注等
- 多套课表独立保存、快速切换，提醒与超级岛跟随当前课表
- 情侣课表：导入 TA 的课表后合并显示，同时段同名课合为「一起课」，桌面小组件也能显示
- 时间模板：按自己学校的作息定义节次；周视图长按空白格可直接加课（可关）
- 教务系统网页登录导入、`.ics` 导入与导出、完整备份导出与恢复
- 二维码面对面传输（喷泉码多帧，不依赖网络）

### 提醒与系统联动

- 上课前 / 课中 / 下课前分阶段提醒
- 上课闹钟：走系统时钟应用，按真实课表批量添加（适合早八）
- HyperOS / 小米超级岛、通知栏、焦点通知联动；超级岛展开的每一行可单独显隐与排序
- 今日桌面小组件、课程统计 2×2 / 2×4 小组件，与课程快照同步
- 应用内检测更新，选好渠道后直接下载安装

### 外观与个性化

- 玻璃四档：实体卡片 / 高斯模糊 / 柔光玻璃 / 液态玻璃
- 首页顶栏玻璃独立选材质（渐进磨砂 / 高斯磨砂 / 柔光 / 液态 / 实体），另有「质感方案」一键套用整套搭配
- 壁纸用自己选的图片，可拖动调整显示位置；「最近使用」保留最近 10 张，切换课表不会跟着变
- 应用形态：经典形态 / 玻璃坞（液态玻璃底部导航）
- 课程统计：学期 / 周双视图、趋势、热力图、教师与教室排行、多课表对比
- 界面语言：简体中文、繁体中文（台湾 / 香港）、English、日本語、한국어

## 下载与更新

| 渠道 | 用途 |
|------|------|
| [GitHub Releases](https://github.com/Mutx163/mikcb/releases) | 正式版与预发布版 |
| [GitCode](https://gitcode.com/mutx/qingyu) | 国内下载（`mutx/qingyu`） |
| [蒲公英](https://www.pgyer.com/qingyu) | 测试分发 |

正式包当前以 `arm64-v8a` 为主。应用内可切换更新源，检测到新版本后直接下载安装。
发行流程见 [docs/RELEASE.md](./docs/RELEASE.md)。

## 教务导入与适配

- 已经支持一部分学校的教务系统网页登录导入，适配脚本来自 `qingyu_warehouse`
- 学校暂时没适配也不影响使用：可以先走 `.ics` 导入或完整备份迁移
- 教务适配仓库：<https://github.com/Mutx163/qingyu_warehouse>
- 如果你会网页调试、抓包、JavaScript，或者愿意维护自己学校的教务系统，欢迎直接参与适配补充

## 开发者

### 环境版本

版本真源：[`.fvmrc`](./.fvmrc) 与 GitHub Actions。当前稳定版为 **Flutter 3.44.8**，最低支持 **Flutter 3.44.2 / Dart 3.12.2**。

| 工具 | 版本 |
|------|------|
| Flutter（当前稳定） | 3.44.8 |
| Flutter（最低支持） | 3.44.2 |
| Dart SDK | >=3.12.2 <4.0.0 |
| JDK | 17 |
| Android SDK | compileSdk 36 / targetSdk 36 / minSdk 26 |
| Android NDK | 28.2.13676358 |
| Gradle | 8.14 |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |

### 本地开发

```bash
flutter pub get
flutter run -d android --flavor dev
```

### 质量检查

```bash
flutter test
flutter analyze --no-fatal-infos
```

### 发布构建

```bash
flutter build apk --release --flavor prod --target-platform android-arm64
```

### 命名说明

| 名称 | 说明 |
|------|------|
| 仓库 `mikcb` | GitHub 仓库名 |
| Dart 包 `university_timetable` | 历史包名（pubspec），与仓库名不同 |
| Android 包名 `com.mutx163.qingyu` | 应用 ID |
| 产品名「轻屿课表」 | 用户可见名称 |

## 相关文档

- 贡献指南：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 行为准则：[CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
- 安全报告：[SECURITY.md](./SECURITY.md)
- 隐私说明：[docs/PRIVACY.md](./docs/PRIVACY.md)
- 第三方许可：[docs/THIRD_PARTY_LICENSES.md](./docs/THIRD_PARTY_LICENSES.md)
- 产品说明（存档）：[docs/PRODUCT.md](./docs/PRODUCT.md)
- 发布流程：[docs/RELEASE.md](./docs/RELEASE.md)
- 网站与国际化协作约定：[docs/WEB_AND_L10N_WORKFLOW.md](./docs/WEB_AND_L10N_WORKFLOW.md)
- 变更日志：[GitHub Releases](https://github.com/Mutx163/mikcb/releases) / [docs/releases/](./docs/releases/)

## 技术栈

- Flutter
- Provider
- SharedPreferences
- liquid_glass_widgets（液态玻璃界面）
- fl_chart（统计图表）
- flutter_miuix（HyperOS 风格组件）
- mobile_scanner / fountain_codes（二维码传输）
- Android Notification / Foreground Service / AlarmClock
- GitHub Actions
- GitHub Releases
- 友盟移动统计 / U-APM

## 使用建议

如果你主要用超级岛或实时通知，建议在系统里同时打开这些能力：

- 通知权限
- 自启动
- 电池无限制
- 焦点通知 / promoted ongoing 权限

这些说明已经放进应用内的「使用引导与权限」页面。

## 当前状态

近期主要在做：玻璃与壁纸的稳定性（进场闪变、静止时的性能开销）、首页菜单与弹层的交互细节、桌面小组件配色，以及发版与官网数据同步的自动化。

## 许可证

本仓库源码使用 [GNU General Public License v3.0](./LICENSE)（SPDX: `GPL-3.0-or-later`）。

随应用分发的第三方 SDK 与资源许可见 [docs/THIRD_PARTY_LICENSES.md](./docs/THIRD_PARTY_LICENSES.md)。
