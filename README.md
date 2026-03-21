# mikcb

一个面向校园场景的 Flutter 课表应用，重点支持 HyperOS / 小米超级岛实时提醒。

## 项目定位

`mikcb` 不是单纯的静态课表查看器，核心目标是把“课程安排”和“实时上课状态”连起来：

- 周视图课表，支持左右滑动切周
- 课程新增、编辑、颜色区分、课程简称
- `.ics` 课程表导入
- 主题色、课表背景、课程卡片颜色自定义
- HyperOS / 小米实时通知、超级岛、焦点通知联动
- 上课前、上课中、下课提醒三时段可独立开关

## 当前特性

### 课表体验

- 细顶栏周次切换
- 星期栏随周次一起滑动
- 支持回本周
- 支持课程总览
- 支持节次时间和课表密度自定义

### 超级岛 / 实时通知

- 上课前、上课中、下课提醒三时段自由组合
- 课程简称优先显示
- 上课前弹出时间可配置
- 下课前秒级提醒阈值可配置
- 上课中超级岛和通知栏通知可分别控制
- 测试通知支持完整时序测试

### 个性化

- 应用主题色切换
- 课表页面背景色切换
- 课程卡片统一配色
- 新应用图标和关于页

## 技术栈

- Flutter
- Provider
- SharedPreferences
- Android Notification / Foreground Service
- GitHub Releases 更新检测

## 仓库地址

- GitHub: https://github.com/Mutx163/mikcb

## 本地运行

```bash
flutter pub get
flutter run
```

## 构建

```bash
flutter build apk
```

如果你要发布正式版，先更新 `pubspec.yaml` 的版本号，再推送到 `main`。

## GitHub 自动打包

仓库已经接入 GitHub Actions 自动打包和自动发版：

- 推送到 `main`：自动执行依赖安装、静态检查、`release APK` 构建，并自动创建或更新对应版本的 GitHub Release
- 推送 `v*` 标签：仍然兼容，会按标签名创建/更新对应 Release
- 手动触发：可在 Actions 页面直接运行工作流

当前工作流文件在：

- `.github/workflows/android-build.yml`

当前工作流会：

- 使用 `flutter build apk --release --split-per-abi`
- 只发布 `arm64-v8a` 正式包，减小包体
- 应用内更新检测也优先识别这个正式包

推荐发版流程：

```bash
git add .
git commit -m "release: cut 1.0.2"
git push origin main
```

这样 GitHub 会自动生成/更新对应 Release，应用内的“检查更新”也会开始识别这个版本。

## 正式签名

正式版更新要保持同一套签名，不能再用 debug 签名。

项目现在已经支持两种签名来源：

- 本地：`android/key.properties`
- GitHub Actions：仓库 Secrets

本地模板文件：

- `android/key.properties.example`

本地实际文件默认不进 Git：

- `android/key.properties`
- `android/app/*.jks`
- `android/app/*.keystore`

GitHub Actions 需要配置这 4 个 Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

其中 `ANDROID_KEYSTORE_BASE64` 需要填你的 keystore 文件 base64 内容。
Windows 示例：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/upload-keystore.jks"))
```

## 更新检测

应用内“关于软件”页面会读取 GitHub Releases 最新版本：

- 有新版本时显示最新版本号
- 优先跳转到 Release 里的安装包
- 如果当前仓库还没有发布 Release，会提示未发布

## 使用建议

为了让超级岛和实时通知稳定工作，建议用户在系统里同时打开：

- 通知权限
- 自启动
- 电池无限制
- 焦点通知 / promoted ongoing 权限

这些引导已经集成在应用内的“使用引导与权限”页面。

## 开源说明

这是一个持续迭代中的开源项目。当前仓库仍以功能推进为主，后续可以继续补：

- Release 发布流程
- 更新日志规范
- 截图与演示资源
- License
