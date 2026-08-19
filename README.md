# 轻屿课表

![Flutter](https://img.shields.io/badge/Flutter-3.44.8-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-Only-34A853?logo=android&logoColor=white)
![HyperOS](https://img.shields.io/badge/Focus-HyperOS%20%E8%B6%85%E7%BA%A7%E5%B2%9B-FF6A00)
![Release](https://img.shields.io/github/v/release/Mutx163/mikcb?display_name=tag)
![CI](https://img.shields.io/github/actions/workflow/status/Mutx163/mikcb/ci.yml?branch=main&label=CI)

一个面向校园场景的 Android 课表应用。

🌐 官网：<https://mutx.ccwu.cc> · [下载最新版本](https://github.com/Mutx163/mikcb/releases)

轻屿课表的重点不是单纯展示课程，而是把课表、提醒、通知、小组件和 HyperOS 超级岛串成一条完整链路。它关注的是“接下来要上什么课、现在这节课进行到哪、能不能不打开应用就知道状态”。

## 命名说明

| 名称 | 说明 |
|------|------|
| 仓库 `mikcb` | GitHub 仓库名 |
| Dart 包 `university_timetable` | 历史包名（pubspec），与仓库名不同 |
| Android 包名 `com.mutx163.qingyu` | 应用 ID |
| 产品名「轻屿课表」 | 用户可见名称 |

## 项目定位

- 面向 Android 维护，重点适配小米 / HyperOS 设备
- 适合希望把课程提醒接进系统通知体验的学生用户
- 支持一人维护多套课表，适合不同学期、身份或课程方案并行管理
- 支持教务系统网页登录导入、`.ics` 导入、完整备份导出与恢复

## 核心能力

- 周视图课表，支持左右滑动切周和一键回本周
- 多课表独立保存、快速切换，通知与超级岛跟随当前课表
- 课程增删改查，支持课程简称、颜色、单双周、备注等信息
- 时间模板系统，可按学校作息自定义节次时间
- 上课前、课中、下课前提醒分阶段配置
- HyperOS / 小米超级岛、通知栏、焦点通知联动
- 今日桌面小组件与课程快照同步
- 教务系统网页登录导入、`.ics` 导入、完整备份导出、恢复为当前课表或新课表
- 关于页读取 GitHub Releases，支持应用内更新检测

## 教务导入与适配

- 当前应用已经支持一部分学校的教务系统网页登录导入，适配脚本来自 `qingyu_warehouse`
- 如果你的学校暂时还没有适配，仍然可以先走 `.ics` 导入或完整备份迁移
- 教务适配仓库：<https://github.com/Mutx163/qingyu_warehouse>
- 如果你会网页调试、抓包、JavaScript 或愿意维护自己学校的教务系统，欢迎直接参与适配补充

## 为什么做这个

很多课表应用解决的是“录入课程”和“查看课程”，但真正高频的使用场景是：

- 还有多久上课
- 现在这节课上到哪了
- 下一节在哪
- 不打开应用能不能就看到

轻屿课表主要在解决这类问题，尤其把提醒链路做得更细，把系统通知体验和课表本身连起来。

## 下载与更新

- 发布页：<https://github.com/Mutx163/mikcb/releases>
- 正式包当前以 `arm64-v8a` 为主
- 应用内可读取 GitHub Releases，显示版本号、更新时间和下载入口
- 发行流程见 [docs/RELEASE.md](./docs/RELEASE.md)

## 运行、检查与构建

本仓库当前只保留 Android 发布和维护所需内容。

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
| Gradle | 8.11.1 |
| Android Gradle Plugin | 8.9.1 |
| Kotlin | 2.1.0 |

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
- Android Notification / Foreground Service
- GitHub Actions
- GitHub Releases
- 友盟移动统计 / U-APM

## 使用建议

如果你主要使用超级岛或实时通知，建议在系统里同时打开这些能力：

- 通知权限
- 自启动
- 电池无限制
- 焦点通知 / promoted ongoing 权限

这些说明已经放进应用内的“使用引导与权限”页面。

## 当前状态

项目仍在持续迭代，目前重点放在：

- Android 端提醒链路稳定性
- HyperOS / 超级岛显示细节
- 多课表与时间模板打磨
- 教务导入、备份和更新体验完善

## 许可证

本仓库源码使用 [GNU General Public License v3.0](./LICENSE)（SPDX: `GPL-3.0-or-later`）。

随应用分发的第三方 SDK 与资源许可见 [docs/THIRD_PARTY_LICENSES.md](./docs/THIRD_PARTY_LICENSES.md)。
