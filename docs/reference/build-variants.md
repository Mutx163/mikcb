# 构建变体（Build Variants）中文对照

Android Studio 的 Build Variants 下拉框里显示的是 Gradle 的构建标识，不是界面文案：
它同时是任务名（`assembleProdBench`）、源集目录名（`src/bench`）和 CI / 脚本的参数
（`testProdDebugUnitTest`、`compileDevDebugKotlin`）。所以**不能改成中文**，也没有单独的
「显示名」可以本地化。这份表是它的中文对照，改变体时以本表为准。

变体名 = 渠道（flavor）+ 构建类型（build type）。4 个渠道 × 4 个构建类型原本会生成
16 个组合；`android/app/build.gradle` 里的 `keepVariants` 白名单只保留下面 5 个，
其余组合已被禁用（不会出现在下拉框里，对应任务也不存在）。

## 保留的 5 个

| 变体 | 中文名 | 包名 | 签名 | 版本号示例 | 用途 |
|---|---|---|---|---|---|
| `devDebug` | 调试版 | `com.mutx163.qingyu.debug` | debug | `2.1.4-1-debug` | 日常开发、L1/L2 闸门 |
| `itestDebug` | 集成测试版 | `com.mutx163.qingyu.itest` | debug | `2.1.4-1-itest` | `integration_test` 专用，数据可丢 |
| `perfBench` | 性能版 | `com.mutx163.qingyu.profile` | release | `2.1.4-1-profile-bench` | 性能测量；Compose 壳；带 `<profileable>`，可抓帧/采样 |
| `prodDebug` | 正式渠道·调试包 | `com.mutx163.qingyu` | debug | `2.1.4-1` | **只给 CI 单测用，不要装机** |
| `prodRelease` | 正式版 | `com.mutx163.qingyu` | release | `2.1.4-1` | 发版、正式数据 |

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
例如要恢复 `devProfile`（`flutter run --profile --flavor dev` 需要它）：

```groovy
def keepVariants = ['devDebug', 'devProfile', 'itestDebug', 'perfBench', 'prodDebug', 'prodRelease'] as Set
```

性能版只能从 Android Studio 选 `perfBench` 运行，或用 Gradle 的 `:app:assemblePerfBench`
打包；`flutter build apk --release --flavor perf` 已不再可用（`perfRelease` 已禁用）。

## 各变体打开哪个界面

启动入口由 manifest 源集决定，和构建类型无关。自 2026-11-02 起**启动页声明在 `src/main`**
（正式包也是 Compose 壳），各渠道只按需覆盖「关掉 / 换回哪个入口」：

| 渠道 | launcher | 界面 |
|---|---|---|
| `prod` | `.pages.PagesShellActivity`（`src/main`） | Compose 壳 |
| `dev` | `.pages.PagesShellActivity`（`src/main`；`src/dev` 只把 `MainActivity` 设 `enabled=false`） | Compose 壳 |
| `perf` | 同上（`src/perf` 覆盖同样只关 `MainActivity`） | Compose 壳 |
| `itest` | `.MainActivity`（`src/itest` 把启动页换回 Flutter） | Flutter（集成测试宿主） |

`dev` / `perf` 的覆盖层会把 Flutter 的 `MainActivity` 设成 `enabled=false`，所以这两个渠道
没有 Flutter 入口；`itest` 相反——`flutter test integration_test` 必须拉起 Flutter 的 Activity，
`src/itest` 把 `PagesShellActivity` 从清单里移除，并给 `MainActivity` 加回 `MAIN/LAUNCHER`。

**回退到 Flutter 入口**（不改代码，只动清单）：把 `src/main/AndroidManifest.xml` 里
`PagesShellActivity` 那段 `MAIN/LAUNCHER` intent-filter 挪回 `.MainActivity` 即可。

## 两个坑

1. `prodDebug` 是 debug 签名 + 正式包名，装到已有正式版的手机上会撞签名，只能用于
   JVM 单测（CI 的 `:app:testProdDebugUnitTest`）。
2. `build/app/outputs/flutter-apk/` 里的文件名按 Flutter 的**构建模式**命名，不认自定义
   构建类型：`prodBench` 的产物也会被写成 `app-prod-release.apk`。发版只认
   `build/app/outputs/apk/prod/release/app-prod-release.apk`。
