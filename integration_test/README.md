# `integration_test/` —— 真机 / 模拟器上的端到端路径

这一层验的是「东西在真设备上真能用」，组件测试证明不了。定位见
`AGENTS.md` 的 `TEST-POLICY` 节（本目录是允许新增的位置之一）。

**一条路径一个文件，跑通再补下一条。** 现在有五条优先级排好的路径：

| # | 路径 | 状态 |
|---|---|---|
| 1 | 冷启动 → 首页渲染出来 | `cold_start_home_test.dart`（已写，见下） |
| 2 | 加一门课 → 保存 → 首页能看到 | 未开始 |
| 3 | 导入课表 → 解析 → 首页能看到 | 未开始 |
| 4 | 改设置 → 杀进程重开 → 设置还在 | 未开始 |
| 5 | 备份恢复 → 数据回来 | 未开始 |

## 前置条件

1. **依赖**：`pubspec.yaml` 的 `dev_dependencies` 要有 `integration_test: sdk: flutter`。
   缺它 `flutter test` 会直接拒绝执行（不是跑失败，是拒绝跑）。
   加完必须在 **Windows 侧**跑一次 `flutter pub get`；**WSL 侧禁止**
   （会改写两边共用的 `.dart_tool/package_config.json`，见 `docs/WSL_DEVELOPMENT.md`）。
2. **设备**：真机或已启动的模拟器，`flutter devices` 能列出来即可。
   **未经用户明确许可，不要驱动实体设备**——见下面「设备安全」。

## 怎么跑

```bash
# 指定设备（不要省略 -d，理由见「设备安全」）
flutter test integration_test/cold_start_home_test.dart -d <device-id>

# 本仓 android 有 dev / perf / prod 三个 flavor（android/app/build.gradle:79）
flutter test integration_test/cold_start_home_test.dart -d <device-id> --flavor dev
```

单个文件跑，不要整目录（`flutter test integration_test/` 也行，但一次一条路径更容易定位）。

## 设备安全（硬红线，来自 AGENTS.md 的 DEVICE-CONTROL 节）

- **必须显式 `-d <device-id>`。** 不指定时 flutter_tools 会自己挑设备
  （`flutter_command.dart:2044` 的 `findTargetDevice`）——只要机器上接着一台手机，
  它就会把测试 App 装上去并跑起来。那是在控制用户的实体设备。
- 跑 integration test 会在设备上**安装并启动** App（同包名的 debug 构建）。
  用户没说过「可以」就不要做。
- 不能用 `-d windows` / `-d chrome` 绕开：本仓没配 Windows 桌面工程
  （`No Windows desktop project configured`），web 则被 flutter_tools 明确拒绝
  （`Web devices are not supported for integration tests yet.`）。
  所以**这台机器上目前没有能安全跑的目标**，除了用户点头的真实设备。

## 写这一类测试的纪律

- **调真的入口**（`import 'package:university_timetable/main.dart' as app;` 然后
  `app.main()`），不要手工拼一个 `MaterialApp` —— 那样测的就不是同一条启动管线了。
- **用轮询等待，不要 `pumpAndSettle()`**。首页永远不会静止（常驻动画、玻璃表面、
  下拉回弹），`pumpAndSettle` 只会等到超时。参考 `cold_start_home_test.dart` 的 `_pumpUntil`。
- **断言落在用户看得见的东西上**：某个具体 widget 有面积、某段文字在屏上。
  「widget 树非空」不算证据。
- **判成败只能靠行为**：`main()` 会装自己的 `FlutterError.onError`
  （`main.dart:311`），顶掉 flutter_test 的异常收集器，启动期的框架异常不会自动让用例变红。
- **注意共享设备上的真实数据**：integration test 与 App 同包名。需要独立存储时用
  `SharedPreferences.setMockInitialValues` 换成内存实现（见 `cold_start_home_test.dart`），
  否则会读写这台设备上用户真实的课表与设置。
