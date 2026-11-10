# 构建变体（Build Variants）中文对照

Android Studio 的 Build Variants 下拉框里显示的是 Gradle 的构建标识，不是界面文案：
它同时是任务名（`assemblePerfBench`）、源集目录名（`src/bench`）和 CI / 脚本的参数
（`testProdDebugUnitTest`、`compileDevDebugKotlin`）。所以**不能改成中文**，也没有单独的
「显示名」可以本地化。这份表是它的中文对照，改变体时以本表为准。

变体名 = 渠道（flavor）+ 构建类型（build type）。4 个渠道 × 4 个构建类型原本会生成
16 个组合；`android/app/build.gradle` 里的 `keepVariants` 白名单只保留下面 5 个，
其余组合已被禁用（不会出现在下拉框里，对应任务也不存在）。

## 保留的 5 个

| 变体 | 中文名 | 包名 | 签名 | 版本号示例 | 用途 |
|---|---|---|---|---|---|
| `devDebug` | 调试版 | `com.mutx163.qingyu.debug` | debug | `3.0.0-0-debug` | 日常开发、L1/L2 闸门 |
| `itestDebug` | 集成测试版 | `com.mutx163.qingyu.itest` | debug | `3.0.0-0-itest` | 集成测试专属包名（与正式版数据隔离）；`integration_test` 已随 Dart 层删除，现无自动化用途 |
| `perfBench` | 性能版 | `com.mutx163.qingyu.profile` | release | `3.0.0-0-profile-bench` | 性能测量；Compose 壳；带 `<profileable>`，可抓帧/采样 |
| `prodDebug` | 正式渠道·调试包 | `com.mutx163.qingyu` | debug | `3.0.0-0` | **只给 CI 单测用，不要装机** |
| `prodRelease` | 正式版 | `com.mutx163.qingyu` | release | `3.0.0-0` | 发版、正式数据 |

版本号示例按当前 `android/version.properties`（`versionName=3.0.0-0`）；换成新版本号时只是
`versionName` 前缀变，后缀（`-debug` / `-itest` / `-profile-bench` / `-bench`）不变。

## 已禁用的组合

| 组合 | 禁用原因 |
|---|---|
| `devBench` | 包名是 `.debug` 但用 release 签名，和日常调试包同包名不同签名，装不上 |
| `prodBench` | 与正式版同包名同签名，一装就覆盖手机上的正式版 |
| `devProfile` / `perfProfile` / `prodProfile` / `itestProfile` | profile 档测出的性能数字不作数（只认 Bench 或 release） |
| `devRelease` / `perfRelease` / `perfDebug` | 没有实际使用场景；性能版统一走 `perfBench` |
| `itestRelease` / `itestBench` | 集成测试只用 debug 档 |

## 临时恢复某个组合

编辑 `android/app/build.gradle` 里的 `keepVariants`，把变体名加进去，重新 Sync 即可。
例如要恢复 `devProfile`（在 Android Studio 里用 profile 档临时排查启动、卡顿问题；注意
profile 档的数字不作数，性能只认 Bench 或 release）：

```groovy
def keepVariants = ['devDebug', 'devProfile', 'itestDebug', 'perfBench', 'prodDebug', 'prodRelease'] as Set
```

性能版只能从 Android Studio 选 `perfBench` 运行，或用 Gradle 的 `:app:assemblePerfBench`
打包；旧的 `flutter build apk --release --flavor perf` 入口已随 Dart 层删除，不存在了。

## 各变体打开哪个界面

启动入口只在 `src/main/AndroidManifest.xml` 声明（`.pages.PagesShellActivity`），四个渠道共用；
`dev` / `perf` / `itest` 源集**现在没有自己的清单覆盖层**，也不存在第二个启动页。Flutter 的
`MainActivity` 与 itest「把启动页换回 Flutter」那层覆盖已随去 Flutter 化删除（P4-B 删
`MainActivity.kt`，P4-C 删 Dart 层）。

| 渠道 | launcher | 界面 |
|---|---|---|
| `prod` | `.pages.PagesShellActivity`（`src/main`） | Compose 壳 |
| `dev` | 同上 | Compose 壳 |
| `perf` | 同上 | Compose 壳 |
| `itest` | 同上 | Compose 壳 |

其余清单覆盖层只做与启动入口无关的事：`src/debug` 注册 `mikcb-debug://` 调试深链（另带
INTERNET 权限），`src/profile` 只加 INTERNET 权限，`src/bench` 只声明
`<profileable android:shell="true"/>`。

**没有「回退到 Flutter 入口」这条路了**：`MainActivity` 与 Dart 层已删，当前树里不存在第二个
入口；要对比旧版行为只能装 `v2.1.4.1` 及更早的正式包。

## 两个坑

1. `prodDebug` 是 debug 签名 + 正式包名，装到已有正式版的手机上会撞签名，只能用于
   JVM 单测（CI 的 `:app:testProdDebugUnitTest`）。
2. APK 落点按变体分目录：`android/app/build/outputs/apk/<渠道>/<构建类型>/`，文件名是
   `<模块>-<渠道>-<构建类型>.apk`（如 `apk/prod/release/app-prod-release.apk`、
   `apk/perf/bench/app-perf-bench.apk`）。旧的 `build/app/outputs/flutter-apk/` 目录已随
   Flutter Gradle 插件删除，现在不存在；发版只认 `apk/prod/release/app-prod-release.apk`。
