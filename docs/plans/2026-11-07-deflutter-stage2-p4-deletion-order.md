# 去 Flutter 化 P4 施工单：删除 Dart 层（四刀切片）

- 日期：2026-11-07
- 状态：**已执行**（四刀按序落地：P4-A `dad3a9359` 版本号 → P4-B `1e8b953b7` 删插件与 3 个 io.flutter 文件 →
  P4-C `303220db1` 删 Dart 整层 → P4-D `297184477` 流水线去 Flutter；本单保留作施工记录）
- 前置已核（2026-11-07）：`lib/`、`test/`、`pubspec` **工作区干净**（0 个未提交），
  只有别的会话 62 个 Kotlin 改动
- 已就位：P1 把 ARB 搬出 `lib/`（`fd7510ee8`）、P2 把发版切到 Gradle（`2af760bf2`）
- 唯一未完成的验证：**P2 的真出包**（Agent 不得跑 `assemble*`，必须用户执行一次）

## 为什么切成四刀

`lib/` 600 个 Dart + `test/` 578 个 + `integration_test/` 13 个，一次删完等于 1200+ 文件不可逆改动，
而且中间任何一处配置错都表现为「删完才发现出不了包」。切成四刀，每刀独立可验收、可单独 revert。

## A 刀：版本源从 `pubspec` 迁到 `android/version.properties`

**为什么必须先做**：现在 `versionCode = (flutter.versionCode as int) + 100000`、`versionName = flutter.versionName`
都由 Flutter Gradle 插件从 `pubspec.yaml` 读。pubspec 一删，两边同时断。

- 现状：`version: 2.1.4-1+140`（versionName `2.1.4-1`、versionCode `140`）。
- 新建 `android/version.properties`：`versionName=2.1.4-1`、`versionCodeBase=140`，`+100000` 偏移保留在
  `app/build.gradle` 里（原注释解释了为什么加：分 ABI 打包的历史 versionCode 不能被新包判成降级）。
- `app/build.gradle` 改读该文件；`OVERRIDE_VERSION_NAME` 优先级不变。
- `.github/workflows/android-build.yml` 的 `Read app version`（第 156-190 行）现在 `grep '^version:' pubspec.yaml`，
  改成读 `android/version.properties`；预发布判定仍看 versionName 里有没有 `-`。
- `.codebuddy/skills/mikcb-release/SKILL.md` 与版本号 bump 脚本同步改（**不改就会在下次发版时改错文件**）。
- 验收：L1 编译通过（版本号不参与编译判定）+ 用户跑一次出包，核对 APK 的 versionName/versionCode。

## B 刀：摘掉最后 3 个 `import io.flutter` 的生产文件

阶段 1 的笔记已确认只剩这些：

- `MainActivity.kt`（`FlutterActivity` 子类，prod/dev/perf 早已不用它当启动页；itest 变体才把 launcher 换回去）
- `FairMemoryFlutterBridge.kt`（MethodChannel 回执桥）
- 以及 `GeneratedPluginRegistrant.java`（Flutter 工具生成，`java/io/flutter/plugins/` 下）

同时：`settings.gradle` 里 `dev.flutter.flutter-plugin-loader` 的请求、`android/noflutter-flutter-loader-stub/` 空实现、
`app/build.gradle` 里 `withFlutter` 门与两处 `KotlinCompile exclude`。

- 验收：L1（`-PwithFlutter=false` 这条路径阶段 1 就是绿的，B 刀等于把它变成唯一路径）。
- 注意：`itest` 变体的 launcher 指向 `MainActivity`，B 刀要同步改 `src/itest/AndroidManifest.xml`，否则该变体没有启动页。

## C 刀：删 Dart 层（一次性，最重）

- `lib/`（600）、`test/`（578）、`integration_test/`（13）、`pubspec.yaml`、`pubspec.lock`、
  `.flutter-plugins-dependencies`、`.metadata`、`l10n.yaml`。
- `tool/` 下的 Dart 工具（`copy_style_rules.dart`、`sync_arb.dart`、`_build_arb.dart`、`merge_*.dart`、
  `gen_app_log_l10n.dart`）随之失效，一并删；`gen_compose_arb_catalog.py` 保留（只读 `i18n/`，不依赖 Dart）。
- **`test/architecture/` 全部消失**——里面 62 条 Dart 守卫读的是 `lib/` 源码。删之前先列一遍：
  哪些能力在 Kotlin 侧已有等价守卫（`god_file_unit_guard_test` 那一族是 Dart 的，Kotlin 侧有
  `ComposePageStyleGuardTest` / `SilentFailureCatchGuardTest` 等），哪些彻底消失要写进笔记。
- 验收：L1 + L2（Gradle 完全不再需要 Flutter SDK）。这条是「去 Flutter 化」的真正判据。

## D 刀：CI 与规则收口

- `android-build.yml` / `.cnb.yml`：撤 `Set up Flutter`、`flutter pub get`、`flutter analyze`、`flutter test` 四步。
- `AGENTS.md` 两条规则必须同批改写（否则下一个人会按旧规则把要删的文件当资产）：
  1. 「`test/{widgets,screens,ui}` 存量一律保留、不删不改」→ 删除说明；
  2. 「CI 里的 `flutter test` 保留不动」→ 删除说明。
- `gradle-cache-warm.yml` 的 `flutter build apk --debug` 改为 `:app:assembleProdDebug`。

## 回滚与顺序

- 每刀一个 tag：`pre-deflutter-p4a` / `-b` / `-c` / `-d`；C 刀前的锚点最重要。
- 顺序不可换：A 不先做，C 删 pubspec 当天发版就断；B 不先做，C 删 `lib/` 后 `MainActivity` 引用不到 Dart 入口。

## 风险清单

| 风险 | 表现 | 规避 |
|---|---|---|
| 版本源改错 | 发版版本号静默回退/不变，装上去才发现 | A 刀单独出一次包核对 |
| C 刀删多/删少 | Gradle 才报「找不到 flutter 扩展」 | 先 `-PwithFlutter=false` 跑 L1 预演 |
| Dart 守卫集体消失 | 文案/行数纪律失去机器兜底 | 删前列清单，把仍在用的判据迁到 Kotlin 侧守卫或写进笔记 |
| `itest` 变体无启动页 | 该变体装上去点图标闪退 | B 刀同步改 `src/itest/AndroidManifest.xml` |
