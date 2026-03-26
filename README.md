# 轻屿课表

![Flutter](https://img.shields.io/badge/Flutter-3.27.0-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Platform-Android-34A853?logo=android&logoColor=white)
![HyperOS](https://img.shields.io/badge/Focus-HyperOS%20%E8%B6%85%E7%BA%A7%E5%B2%9B-FF6A00)
![Release](https://img.shields.io/github/v/release/Mutx163/mikcb?display_name=tag)
![CI](https://img.shields.io/github/actions/workflow/status/Mutx163/mikcb/android-build.yml?branch=main&label=android%20build)

一个面向校园场景的 Flutter 课表应用。

轻屿课表不只是“看课表”，核心目标是把课程安排、实时提醒、课间状态和系统通知体验连起来，尤其针对 HyperOS / 小米超级岛做了专门优化。

## 核心特性

- 周视图课表，支持左右滑动切周
- 多课表独立保存与快速切换
- 开学日期同步当前周，支持一键回本周
- 课程新增、编辑、删除、颜色区分、课程简称
- `.ics` 课表导入
- 完整备份导出与恢复
- HyperOS / 小米超级岛、实时通知、焦点通知联动
- 上课前 / 上课中 / 下课前提醒独立配置
- 主题色、页面背景、课程卡片配色自定义
- GitHub Releases 应用内更新检测

## 适合谁

- 想要一个更轻、更快、更适合日常打开的课表应用的学生
- 使用小米 / HyperOS 设备，希望把课程提醒接进系统实时通知体验的用户
- 需要从 WakeUp 等应用迁移课程，或在同学之间直接共享课表备份的人
- 同时管理多个学期、多个身份或多套课程安排的人

## 技术栈

- Flutter
- Provider
- SharedPreferences
- 友盟移动统计 / U-APM
- Android Notification / Foreground Service
- GitHub Actions
- GitHub Releases

## 本地运行

```bash
flutter pub get
flutter run -d android
```

## Android 构建

```bash
flutter build apk --release --split-per-abi
```

当前仓库仅保留 Android 发布与维护所需内容，正式发布包以 `arm64-v8a` 为主。

## 应用内更新

“关于软件”页面会读取 GitHub Releases 最新版本，并支持：

- 显示最新版本号
- 显示本地时区下的 Release 更新时间
- 优先跳转到 Release 里的 APK
- Android 端应用内下载更新包
- 原版下载 / 镜像下载切换

## 多课表

当前版本已经支持：

- 多个课表独立保存
- 首页快速切换当前课表
- 不同课表分别拥有自己的课程、周数、节次、开学日期和通知设置
- 通知与超级岛仅跟随当前选中的课表

## 使用建议

为了让超级岛和实时通知更稳定，建议在系统设置中同时打开：

- 通知权限
- 自启动
- 电池无限制
- 焦点通知 / promoted ongoing 权限

这些说明已经集成在应用内“使用引导与权限”页面。

## 当前状态

这是一个持续迭代中的开源项目，当前重点仍然放在功能打磨和 Android 体验完善上。

接下来仍会持续补强：

- 仓库展示图和演示资源
- 更新日志规范
- 更多导入方式
- 继续补强稳定性与使用体验

## 仓库地址

- GitHub: https://github.com/Mutx163/mikcb

## License

本仓库已附带 `LICENSE` 文件。
