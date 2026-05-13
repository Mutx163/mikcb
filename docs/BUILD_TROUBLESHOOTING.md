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

## Gradle daemon disappeared

如果出现：

```text
Gradle build daemon disappeared unexpectedly
```

优先查看 `C:\Users\<用户名>\.gradle\daemon\<版本>\hs_err_pid*.log`。如果日志包含 `There is insufficient memory for the Java Runtime Environment to continue`，通常是 Gradle/JVM native memory 分配失败。

本项目已在 `android/gradle.properties` 中降低 Gradle JVM 内存占用、限制 worker 数量并禁用长期驻留 daemon，以减少 Windows 本地调试时 daemon 崩溃概率。
