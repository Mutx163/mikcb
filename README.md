# 轻屿课表

![Flutter](https://img.shields.io/badge/Flutter-3.27.0-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-Only-34A853?logo=android&logoColor=white)
![HyperOS](https://img.shields.io/badge/Focus-HyperOS%20%E8%B6%85%E7%BA%A7%E5%B2%9B-FF6A00)
![Release](https://img.shields.io/github/v/release/Mutx163/mikcb?display_name=tag)
![CI](https://img.shields.io/github/actions/workflow/status/Mutx163/mikcb/android-build.yml?branch=main&label=android%20build)

一个为校园场景设计的 Android 课表应用。

轻屿课表的重点不是“把课程列出来”，而是把课表、课前提醒、课中状态、下课提醒、桌面小组件和 HyperOS 超级岛尽量接成一条完整链路。它更像一个围绕“今天接下来要上什么课”来优化的日常工具，而不是传统的静态课表页。

## 项目定位

- 面向 Android 维护，重点适配小米 / HyperOS 设备
- 适合希望把课程提醒接进系统通知体验的学生用户
- 支持一人维护多套课表，适合不同学期、身份或课程方案并行管理
- 支持从 `.ics` 导入、完整备份导出与恢复，方便迁移和分享

## 核心能力

- 周视图课表，支持左右滑动切周和一键回本周
- 多课表独立保存、快速切换，通知与超级岛跟随当前课表
- 课程增删改查，支持课程简称、颜色、单双周、备注等信息
- 时间模板系统，可按学校作息自定义节次时间
- 上课前、课中、下课前提醒分阶段配置
- HyperOS / 小米超级岛、通知栏、焦点通知联动
- 今日桌面小组件与课程快照同步
- `.ics` 导入、完整备份导出、恢复为当前课表或新课表
- 关于页读取 GitHub Releases，支持应用内更新检测

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

## 运行与构建

本仓库当前只保留 Android 发布和维护所需内容。

本地运行：

```bash
flutter pub get
flutter run -d android
```

Android 构建：

```bash
flutter build apk --release --split-per-abi
```

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
- 导入、备份和更新体验完善

## 许可证

本仓库使用 [GNU General Public License v3.0](./LICENSE)。
