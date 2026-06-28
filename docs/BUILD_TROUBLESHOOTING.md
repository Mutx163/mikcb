# 构建问题排查

## TUNA pub 镜像的 advisory 告警

如果本机设置了：

```powershell
$env:PUB_HOSTED_URL = 'https://mirrors.tuna.tsinghua.edu.cn/dart-pub'
$env:FLUTTER_STORAGE_BASE_URL = 'https://mirrors.tuna.tsinghua.edu.cn/flutter'
```

`flutter pub get` 或 `flutter build` 可能输出大量类似告警：

```text
Warning: Unable to fetch advisories for "..." from "https://mirrors.tuna.tsinghua.edu.cn/dart-pub/".
```

这是 Dart pub 在查询包安全公告时，镜像源没有完整代理 advisory API 导致的 warning；依赖解析和构建本身仍可继续。

需要临时获得更干净的输出或检查官方源安全公告时，可在当前 PowerShell 会话中切回官方源：

```powershell
Remove-Item Env:PUB_HOSTED_URL -ErrorAction SilentlyContinue
Remove-Item Env:FLUTTER_STORAGE_BASE_URL -ErrorAction SilentlyContinue
flutter pub get
```

如果仍需要使用国内镜像，可以保留 TUNA 设置；这类 advisory warning 不等同于构建失败。

## TUNA 镜像 404：`flutter_infra_release` 引擎产物

如果本机设置了 TUNA 的 `FLUTTER_STORAGE_BASE_URL`，`flutter build` 或 `flutter run` 可能在下载引擎产物时报 404，例如：

```text
Failed to download https://mirrors.tuna.tsinghua.edu.cn/flutter/flutter_infra_release/...
```

原因是镜像未同步或未提供部分 `flutter_infra_release` 路径下的引擎文件。

**解决办法**（任选其一，仅对当前 PowerShell 会话生效）：

```powershell
Remove-Item Env:FLUTTER_STORAGE_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:PUB_HOSTED_URL -ErrorAction SilentlyContinue
flutter pub get
flutter build apk
```

或临时仅对引擎下载使用 Google 官方存储，保留 pub 镜像（若镜像可用）。

### VS Code / Cursor 调试仍走镜像

IDE 从 Windows **用户级**环境变量继承 `FLUTTER_STORAGE_BASE_URL` / `PUB_HOSTED_URL`，与是否在终端里 `Remove-Item Env:...` 无关（除非从已清除变量的终端启动 IDE）。调试面板报同样 404 时，按优先级处理：

**永久修复（推荐）**——删除用户级镜像变量后重启 IDE：

```powershell
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', $null, 'User')
[Environment]::SetEnvironmentVariable('PUB_HOSTED_URL', $null, 'User')
```

也可在「系统属性 → 环境变量 → 用户变量」中删除这两项。改完后完全退出并重新打开 VS Code / Cursor。

**仅当前 IDE 会话**——在已清除镜像变量的 PowerShell 中启动 IDE（子进程不会带上用户级镜像）：

```powershell
Remove-Item Env:FLUTTER_STORAGE_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:PUB_HOSTED_URL -ErrorAction SilentlyContinue
cursor .   # 或 code .
```

**仅本项目**——在工作区 `.vscode/settings.json` 中为 Dart 扩展覆盖环境（不影响其他项目）：

```json
{
  "dart.env": {
    "FLUTTER_STORAGE_BASE_URL": "https://storage.googleapis.com",
    "PUB_HOSTED_URL": "https://pub.dev"
  }
}
```

或在 `.vscode/launch.json` 的调试配置里加 `env`（只对该 launch 配置生效）：

```json
"env": {
  "FLUTTER_STORAGE_BASE_URL": "https://storage.googleapis.com",
  "PUB_HOSTED_URL": "https://pub.dev"
}
```

**预缓存引擎（官方源）**——先按上面任一方式切回官方源，再执行：

```powershell
flutter precache --android
```

然后重新 F5 调试。

## NDK 损坏：`source.properties` 缺失

如果出现：

```text
[CXX1101] NDK at ...\ndk\28.2.13676358 did not have a source.properties file
```

说明该 NDK 版本下载不完整（目录里可能只有 `.installer`）。

**解决办法**：

1. 删除损坏目录，例如：
   ```powershell
   Remove-Item -Recurse -Force "D:\Cache\Android\Sdk\ndk\28.2.13676358"
   ```
2. 重新构建，让 Gradle 自动重装；或手动安装：
   ```powershell
   & "D:\Cache\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "ndk;28.2.13676358"
   ```
3. 若 `jni` 等插件要求 NDK 28.2，确保 `android/app/build.gradle` 中 `ndkVersion` 与之一致。

## Gradle daemon disappeared

如果出现：

```text
Gradle build daemon disappeared unexpectedly
```

优先查看 `C:\Users\<用户名>\.gradle\daemon\<版本>\hs_err_pid*.log`。如果日志包含 `There is insufficient memory for the Java Runtime Environment to continue`，通常是 Gradle/JVM native memory 分配失败。

本项目已在 `android/gradle.properties` 中降低 Gradle JVM 内存占用、限制 worker 数量并禁用长期驻留 daemon，以减少 Windows 本地调试时 daemon 崩溃概率。

## 如何查看调试记录

mikcb 是 Flutter Android 应用，日志分散在 IDE 调试控制台、Debug Console+ 持久化文件和 `adb logcat` 中。按症状选择来源，避免在错误的地方找堆栈。

### VS Code / Cursor F5 调试控制台

F5 启动 `.vscode/launch.json` 中的 Flutter 调试后，**调试控制台**（Debug Console）会输出：

- `flutter run` / Dart VM 的 `print`、`debugPrint`、`log`
- Flutter/Dart 未捕获异常及堆栈
- 部分插件桥接日志

**局限**：原生 Android 进程崩溃（Kotlin/Java、`SecurityException`、前台服务等）时，控制台往往只显示 `Lost connection to device`，**不会**给出完整 Java 堆栈。这类问题必须查 `adb logcat`（见下文）。

### Debug Console+ 扩展与 MCP

本项目在 `.mcp.json` 中配置了 **Debug Console+** MCP，可将调试控制台输出持久化，供 Cursor Agent 查询。

| 方式 | 说明 |
|------|------|
| MCP 工具 | `debug_console_plus_query_debug_logs`（按关键词、级别、时间过滤） |
| 直接读文件 | 扩展将日志写入 `logs.json`，路径见 `.mcp.json` 里 `debug-console-plus` 的 `--logs-dir` 参数 |

当前工作区示例路径（`mikcb-868ab89f` 为工作区哈希，换机器或重开工作区可能变化；通用模式见下）：

```text
%APPDATA%\Code\User\globalStorage\pomisoft.debug-console-plus\workspaces\<workspace-hash>\logs.json
c:\Users\34045\AppData\Roaming\Code\User\globalStorage\pomisoft.debug-console-plus\workspaces\mikcb-868ab89f\logs.json
```

**前置条件**：

1. VS Code / Cursor 已安装 [Debug Console+](https://marketplace.visualstudio.com/items?itemName=pomisoft.debug-console-plus) 扩展
2. 至少在本机用 F5 跑过一次调试，才会有 `logs.json`
3. MCP 需在 Cursor 会话中启用；未启用时 Agent 仍可直接读取上述 `logs.json`

Debug Console+ 内容与 F5 调试控制台同源，同样**无法替代**原生崩溃的 logcat 堆栈。

### adb logcat（原生 Android 崩溃）

设备通过 USB 调试连接后，用 SDK 里的 `adb`（可能不在 PATH，请写全路径）。本机常见路径：

```text
D:\Cache\Android\Sdk\platform-tools\adb.exe
```

**崩溃后立刻抓取**（`-d` 转储已有日志后退出，`-t N` 只保留最近 N 行）：

```powershell
# crash 缓冲区：Java/Kotlin 未捕获异常、FATAL EXCEPTION 堆栈（首选）
D:\Cache\Android\Sdk\platform-tools\adb.exe logcat -d -b crash -t 50

# 按 tag 过滤：AndroidRuntime 错误 + Flutter 引擎错误
D:\Cache\Android\Sdk\platform-tools\adb.exe logcat -d -s AndroidRuntime:E flutter:E -t 100

# 复现闪退时实时跟踪（另开终端）
D:\Cache\Android\Sdk\platform-tools\adb.exe logcat -b crash AndroidRuntime:E flutter:E
```

| 命令 | 何时使用 |
|------|----------|
| `logcat -d -b crash` | 进程已崩溃、需要完整 Java 堆栈（如 `SecurityException`、FGS 权限、Manifest 缺失） |
| `logcat -d -s AndroidRuntime:E` | 同上，或 crash 缓冲区为空时的补充 |
| `logcat -d -s flutter:E` | 怀疑 Flutter 引擎 / 平台通道原生侧错误 |
| F5 调试控制台 / Debug Console+ | Dart 层异常、`print`、热重载、构建与部署过程 |

复现步骤：先 `adb logcat -c` 清空，再操作 app 触发崩溃，然后执行上表命令。

**示例**：`LanEditForegroundService` 因前台服务类型缺少 `CHANGE_NETWORK_STATE` 导致 `SecurityException` 时，F5 控制台仅见断连，`-b crash` 中可见完整堆栈与缺失权限名（已在 Manifest 修复）。

```text
E AndroidRuntime: FATAL EXCEPTION: main
E AndroidRuntime: java.lang.SecurityException: Starting FGS with type connectedDevice ...
```

### 症状 → 去哪里查（速查）

| 症状 | 优先查看 |
|------|----------|
| Dart 红屏、`Exception` 带 `.dart` 路径 | F5 调试控制台 / Debug Console+ |
| `print` / 业务日志 | 同上 |
| 点击功能后 app 直接闪退、控制台 `Lost connection to device` | `adb logcat -d -b crash` |
| `Lost connection to device` 但需看断连前 Dart/构建上下文 | 先 `adb logcat -d -b crash`，再查 `logs.json` 末尾 |
| Kotlin 服务、权限、Manifest、FGS 相关 | `adb logcat -d -b crash`，必要时加 `AndroidRuntime:E` |
| 需看真机当前页面/控件（不依赖用户描述） | `android layout --pretty`、`android screen capture` |
| FGS 是否在跑、与 UI 是否一致 | `adb shell dumpsys activity services <package>` + layout |
| Android API / 权限迁移文档 | `android docs search <关键词>` |
| 需要 Agent 检索历史调试输出 | Debug Console+ MCP 或 `logs.json` |
| 构建失败、Gradle/NDK 错误 | 调试控制台 + 本文档前文「构建问题」各节 |

**原则**：Flutter/Dart 异常看 IDE 调试控制台；原生 Android 崩溃看 `adb logcat` 的 **crash** 缓冲区。

### Android CLI（`android` 命令）— 何时优先使用

mikcb 是 Flutter 应用，但 `android/` 下有大量 Kotlin 原生层（Widget、前台服务、通知、平台通道）。**Android CLI 不能替代 `flutter run`**，但在以下场景应**优先于**只靠 F5 控制台或手写 adb：

| 场景 | 优先用 Android CLI | 原因 |
|------|-------------------|------|
| 真机/模拟器上 UI 与预期不符，需确认当前页面元素 | `android layout` / `android screen capture` | 不依赖 Dart 源码，直接读设备上的 accessibility 树与截图 |
| 前台服务是否在跑、通知渠道是否注册 | `adb shell dumpsys activity services`（CLI 无等价物时用 adb） | 验证 FGS 与 UI 状态是否脱节（如 LAN 编辑已返回但通知仍在） |
| 原生层闪退、权限/`SecurityException` | 先 `adb logcat -d -b crash`，再用 `android info` 确认 SDK 路径 | crash 堆栈仍以 logcat 为准；CLI 辅助环境诊断 |
| SDK 组件缺失、模拟器起不来 | `android sdk list` / `android emulator start` | 比手动找 SDK Manager 更快 |
| 查 Android API 迁移、FGS 类型所需权限 | `android docs search` | 官方文档检索，适合 targetSdk 升级（如 API 36 `connectedDevice` FGS） |
| 已构建 APK 快速装到设备 | `flutter build apk` 后 `android run --apks=...` | 跳过完整 `flutter run` 热重载链路，只验证安装运行 |
| Agent 自动化排查「app 在设备上实际长什么样」 | `android layout --pretty`、`android screen capture -o <path>` | Cursor Agent 可直接读截图与布局 JSON |

**不必优先用 Android CLI 的情况**：

| 场景 | 更合适工具 |
|------|-----------|
| Dart 业务逻辑、红屏、`print` | F5 调试控制台 / Debug Console+ |
| 热重载、断点调试 | `flutter run` / VS Code 调试 |
| 单元/Widget 测试 | `flutter test` |
| 完整 Java 崩溃堆栈 | `adb logcat -d -b crash`（CLI 不替代 logcat） |

**常用命令**（Windows；`adb` 可能不在 PATH，SDK 路径以 `android info` 为准）：

```powershell
# 环境与版本
android --version
android info

# 设备 UI（默认连第一台已连接设备）
android layout --pretty
android screen capture -o "$env:TEMP\mikcb_screen.png"
android screen capture -a -o "$env:TEMP\mikcb_annotated.png"   # 带控件边框标注

# 模拟器
android emulator list
android emulator start <avd-name>

# 文档（例：前台服务 connectedDevice 权限）
android docs search connectedDevice foreground service permission
```

**与本项目相关的实战结论**（2026-06-27 真机调试）：

1. `LanEditForegroundService` 在 Android 16 上因缺少 `CHANGE_NETWORK_STATE` 崩溃时，F5 只显示断连；`adb logcat -d -b crash` 才能看到 `SecurityException` 与缺失权限列表。
2. `android layout` 可确认局域网编辑页是否处于「进行中」或「待开启」状态，无需用户口述。
3. `dumpsys activity services` + 布局/截图组合，可发现 **HTTP 服务已停但 FGS 通知仍在** 的状态不同步问题。

**工具选择速记**：

```
Dart 异常     → F5 / Debug Console+
原生崩溃      → adb logcat -b crash
UI 长什么样   → android layout / screen capture
FGS/服务状态  → adb dumpsys activity services
SDK/模拟器    → android sdk / android emulator
API 怎么写    → android docs search
日常开发      → flutter run
```

Agent 技能：仓库外已安装 `android-cli` skill（`C:\Users\34045\.claude\skills\android-cli\SKILL.md`），处理 Android 原生调试任务时可先加载该 skill。
