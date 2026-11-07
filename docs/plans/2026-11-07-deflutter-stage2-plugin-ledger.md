# 去 Flutter 化阶段 2 · 插件迁移账（18 个 Android 插件模块）

- 日期：2026-11-07
- 状态：**账本**（只记录现状与摘除难度，不含任何改动）
- 配套：施工顺序与回滚点见 `docs/plans/2026-11-07-deflutter-stage2-workorder.md`；
  阶段 1（编译期依赖切断）见 `.agents/notes/implemented/architecture/2026-11-07-deflutter-stage1-compile-cut.md`
- 数据来源：`.flutter-plugins-dependencies`（插件清单）、`lib/**/*.dart`（引用统计，600 个文件）、
  `android/app/src/main/kotlin`（原生侧现状）、`.dart_tool/package_config.json`（反向依赖）

## 0. 结论先行

`.flutter-plugins-dependencies` 里的 android 插件共 19 项，扣掉只服务测试的 `integration_test`，剩 **18 个模块**：

| 结论 | 数量 | 具体 |
|---|---|---|
| `lib/` 里 0 引用 | **4** | `connectivity_plus`、`device_info_plus`、`dynamic_color`、`jni_flutter` |
| 没有 Dart API 的伴生模块 | 2 | `jni`、`flutter_plugin_android_lifecycle`（`jni_flutter` 归在上面的零引用里，不重复计） |
| 原生落脚点已在壳里（改接线 / 对拍即可） | 10 | `shared_preferences`、`path_provider`、`share_plus`、`url_launcher`、`geolocator`、`package_info_plus`、`flutter_secure_storage`、`file_picker`（SAF 备份在用，导入件未接）、`webview_flutter`（真 WebView 登录页已接）、`mobile_scanner`（CameraX + MLKit 已接） |
| 需要新写原生件 | **0** | 复核后为 0：`open_filex` 的装包在 `AboutUpdateHost` 已有、`image_picker` 的选图在 `LiveDisplayHost` 已有（详见 §6） |

**零引用的 4 个不能手动摘**——它们的去留绑在 Dart 包上，删宿主包才消失：

| 0 引用模块 | 谁把它拉进来 |
|---|---|
| `connectivity_plus` | `flutter_blackbox` 0.7.0（pub 包） |
| `device_info_plus` | `flutter_blackbox` 0.7.0（pub 包） |
| `dynamic_color` | `flutter_miuix`（本仓 fork，git 依赖） |
| `jni_flutter` | `path_provider_android`（其 native 快路径） |

另：`jni` 被 `jni_flutter` 与 `path_provider_android` 同时依赖；`flutter_plugin_android_lifecycle` 被
`file_picker` 与 `image_picker_android` 依赖（纯 Android 侧，没有 Dart API）。

**一条前提事实**（静态核对）：默认包（dev / prod）里 Dart 层已经**没有入口**——启动页是
`PagesShellActivity`，原生侧没有任何启动 `MainActivity` 的 `Intent`（只有 `MainActivity` 自己重启自己那处）；
只有 `itest` 变体通过清单把 launcher 换回 `MainActivity`，集成测试仍走 Dart。

## 1. 计数口径

- **Dart 引用** = `lib/` 下 600 个 `.dart` 中出现 `package:<包名>/` 的文件数 / 引用行数。
  一个文件一行 import，所以两列当前相等；它统计的是「接缝有几处」，不是「调用了几次」。
- **不含** `test/`（578 个）与 `integration_test/`（13 个）：它们随阶段 2 一起删，不参与摘除判断。
- **Android 模块名**取自 `.flutter-plugins-dependencies`；Dart 侧写的是应用层包名
  （例如 `shared_preferences` 对应的 Android 实现是 `shared_preferences_android`）。
- 原生侧"已有实现"按 `android/app/src/main/kotlin` 里**实际被引用**判断；定义存在但没人调用会单独注明。

## 2. 18 个模块全表

难度分级：**易** = 原生等价件已在用，改接线即可；**中** = 有件但调用点多 / 需数据迁移 / 需新写一小段原生件。
本账**已无「难」项**：`open_filex` 复核后从「难」降为「中」（见 §6）。

| # | Android 模块 | 版本 | 对应 Dart 包 | Dart 引用 | 这个插件在干什么 | 原生侧现状 | 难度 |
|---|---|---|---|---|---|---|---|
| 1 | `shared_preferences_android` | 2.4.26 | `shared_preferences`（直接） | 23 文件 / 23 行 | 全 App 的键值持久化：设置、课表缓存、日志开关、壁纸历史 | `PrefsKeyValueStore`（20 处引用，壳里在用） | 中（调用点最多，键名要逐一对拍） |
| 2 | `path_provider_android` | 2.3.1 | `path_provider`（直接） | 11 文件 / 11 行 | 缓存目录 / 导出目录 / 日志目录 / 图片目录 | `Context.filesDir` / `cacheDir`，`PerfProbe` 已直接用 | 中（目录语义要对齐：support vs files） |
| 3 | `package_info_plus` | 9.0.1 | `package_info_plus`（直接） | 11 文件 / 11 行 | 版本号 / 构建号：关于页、更新检查、日志头、WebDAV UA | `BuildConfig.VERSION_NAME` / `VERSION_CODE` | 易 |
| 4 | `share_plus` | 12.0.2 | `share_plus`（直接） | 9 文件 / 9 行 | 分享课表图 / 统计 / ICS / 日志 / 数据迁移 | `AndroidShareAdapter` + `AndroidTransferShareAdapter`（壳里已用） | 易 |
| 5 | `file_picker` | 11.0.3 | `file_picker`（直接） | 8 文件 / 8 行 | 选文件导入：ICS、Excel/CSV 课表、备份包 | `ImportHosts`（`OpenDocument`）已做选文件；`AndroidSafBackupAdapter`（7 处）管备份；`AndroidImportFileGateway` **已写但 0 引用**（被 `ImportHosts` 直接走 SAF 顶掉） | 易 |
| 6 | `url_launcher_android` | 6.3.32 | `url_launcher`（直接） | 3 文件 / 3 行 | 打开下载页 / 官网 / 仓库详情 | `LAUNCH_URL_CHANNEL` 通道已在 | 易 |
| 7 | `flutter_secure_storage` | 10.3.4 | `flutter_secure_storage`（直接） | 3 文件 / 3 行 | WebDAV 凭据、教务登录记忆的加密存取 | `SecretCipher` / `KeystoreSecretCipher`（10 处） | 易～中（要迁已存数据，否则用户掉登录） |
| 8 | `webview_flutter_android` | 4.14.1 | `webview_flutter`（直接） | 2 文件 / 2 行 | 教务网页登录 + 宏回放（仓库导入） | `WarehouseWebLoginHost`（真 WebView，`g2.webLogin` 已接）+ `WarehouseCookieExtraction` 取 Cookie；`WarehouseMacroReplayer` 在 | 中（登录态与 Cookie 要逐校对拍） |
| 9 | `open_filex` | 4.7.0 | `open_filex`（直接） | 1 文件 / 1 行 | 打开下载好的 APK 触发安装 | `AboutUpdateHost.finishDownload`：`DownloadManager` → SHA-256 校对 → `ACTION_VIEW` 拉起系统安装器（已实现）；清单已有 `REQUEST_INSTALL_PACKAGES` | 易 |
| 10 | `image_picker_android` | 0.8.13+19 | `image_picker`（直接） | 1 文件 / 1 行 | 选图（壁纸 / 头像来源） | `LiveDisplayHost` 已用 `ActivityResultContracts.GetContent()` 选图并复制进私有目录（可优化为 `PickVisualMedia`，非必需） | 易 |
| 11 | `mobile_scanner` | 7.4.2 | `mobile_scanner`（直接） | 1 文件 / 1 行 | 二维码传输扫码 | `QrCameraHost.kt`（CameraX `PreviewView` + MLKit `BarcodeScanning`，`g3.qrScan` 已接）+ `QrScanSessionCoordinator` 决策层 | 易 |
| 12 | `geolocator_android` | 5.1.1+1 | `geolocator`（直接） | 1 文件 / 1 行 | 天气的「使用当前位置」 | `AndroidWeatherLocationSource`（`ShellWiring` 已接）+ `LocationFix` 通道 | 易 |
| 13 | `connectivity_plus` | 7.3.1 | — | **0** | 网络状态监听（本仓 Dart 未直接用） | 需要时用 `ConnectivityManager` | 零引用（随 `flutter_blackbox` 走） |
| 14 | `device_info_plus` | 12.4.0 | — | **0** | 设备信息（本仓 Dart 未直接用） | `Build.*` 一行可得 | 零引用（随 `flutter_blackbox` 走） |
| 15 | `dynamic_color` | 1.9.0 | — | **0** | 系统动态取色（本仓 Dart 未直接用） | Compose 侧用 `dynamicColorScheme` | 零引用（随 `flutter_miuix` 走） |
| 16 | `jni` | 1.0.0 | — | **0** | JNI 互操作底座 | — | 伴生（`jni_flutter` / `path_provider_android` 依赖） |
| 17 | `jni_flutter` | 1.0.1 | — | **0** | 同上，Flutter 侧封装 | — | 伴生（`path_provider_android` 依赖） |
| 18 | `flutter_plugin_android_lifecycle` | 2.0.35 | — | **0** | 插件用 Activity 生命周期代理 | — | 伴生（`file_picker` / `image_picker_android` 依赖） |

## 3. 零引用的 4 个（单列）

| 模块 | 版本 | 谁引入 | 现在能不能删 | 说明 |
|---|---|---|---|---|
| `connectivity_plus` | 7.3.1 | `flutter_blackbox` 0.7.0 | **不能单独删** | 删了 pub 解析失败；随 `flutter_blackbox` 下线一起消失 |
| `device_info_plus` | 12.4.0 | `flutter_blackbox` 0.7.0 | **不能单独删** | 同上 |
| `dynamic_color` | 1.9.0 | `flutter_miuix`（本仓 fork） | **不能单独删** | `flutter_miuix` 是 Dart UI 包，随 Dart 层一起走 |
| `jni_flutter` | 1.0.1 | `path_provider_android` | **不能单独删** | 只有 `path_provider` 下线后才消失 |

要点：**"零引用"说的是本仓 Dart 代码没直接用，不等于可以现在摘。** 这四个的正确处理时机是
「删 `lib/` + 改 `pubspec.yaml`」那一步，它们会自动从构建里消失，不需要单独写代码。

## 4. 建议顺序

按「先摘零风险、后碰用户可见流程」排：

1. **第 0 批（不需要写代码）**：`connectivity_plus`、`device_info_plus`、`dynamic_color`、`jni_flutter`
   —— 等 `pubspec.yaml` 里 `flutter_blackbox` / `flutter_miuix` 与 `path_provider` 一起下线，自动消失。
2. **第 1 批（易，能力已在壳里）**：`url_launcher`、`geolocator`、`package_info_plus`、`share_plus`、`mobile_scanner`
   —— 每摘一个只需删对应 Dart 调用点，原生侧不用新写。
3. **第 2 批（中，要接线或迁数据）**：`flutter_secure_storage`（凭据迁移）、`shared_preferences`（键名对拍）、
   `path_provider`（目录语义）、`webview_flutter`（登录态对拍）。

不再有「第 3 批」：复核后 18 个模块**全部**在原生侧有落脚点（`open_filex` → `AboutUpdateHost`、`image_picker` →
`LiveDisplayHost`、`file_picker` → `ImportHosts`），没有需要从零写的件。

`jni`、`flutter_plugin_android_lifecycle` 不单独排期：跟着 `path_provider_android` / `file_picker` /
`image_picker_android` 一起消失。

## 5. 边界与未验证项

- 只做了**静态核对**：没有跑构建、没有真机验证；「Dart 层默认包无入口」是按清单与 `Intent` 搜索得出的，
  不排除通过反射/字符串启动的可能（未发现）。
- 引用数只统计 `lib/`；`test/`、`integration_test/` 的引用随阶段 2 一起删，未计入。
- 原生侧"已有实现"是"被 Kotlin 代码引用"，不代表**功能等价**：例如 `PrefsKeyValueStore` 与
  `shared_preferences` 的键名/类型映射需逐一对拍，`AndroidImportFileGateway` 目前没有任何调用方。
- `open_filex` 判定为"原无原生实现"后来两次复核都推翻：第一次漏看了清单里已有的 `REQUEST_INSTALL_PACKAGES`
  与 `FileProvider`；第二次发现首轮搜索**只扫了 `main/kotlin`，漏了 `src/composeP1/kotlin`**（Compose 壳的
   host 都在那里），于是 `AboutUpdateHost` 的装包、`LiveDisplayHost` 的选图、`ImportHosts` 的选文件全部漏判。
  教训：原生侧搜索必须同时覆盖 `main/` 与 `composeP1/` 两个源集。

## 6. 原生替代件选型（能力 → Kotlin）

前提：**不需要往 `app/build.gradle` 新增任何依赖**。CameraX 1.6.1、MLKit barcode 17.3.0、`activity-compose` 1.13.0、
`work-runtime-ktx` 2.10.1、okhttp 4.12.0 都已在；`minSdk 33` 让 Photo Picker 与动态取色都是系统原生能力，不需要兼容库。

| 能力 | Dart 插件 | Kotlin / Android 原生替代 | 仓里状态 |
|---|---|---|---|
| 键值持久化 | `shared_preferences` | `SharedPreferences`（或用 `androidx.datastore`） | `PrefsKeyValueStore` 已在（共用 Flutter 的 `flutter.` 前缀，老数据能读） |
| 文件目录 | `path_provider` | `Context.filesDir` / `cacheDir` / `getExternalFilesDir` | 已有代码直接这么用 |
| 版本号 / 构建号 | `package_info_plus` | `PackageManager.getPackageInfo` / `BuildConfig` | 零成本，一行 |
| 分享 | `share_plus` | `Intent.ACTION_SEND` + `FileProvider`（或 `ShareCompat`） | `AndroidShareAdapter`、`AndroidTransferShareAdapter` 在用 |
| 选文件 | `file_picker` | SAF：`ActivityResultContracts.OpenDocument` + `ContentResolver` | `AndroidImportFileGateway` 读取已写好，缺 Composable 侧接线 |
| 打开链接 | `url_launcher` | `Intent.ACTION_VIEW`（Custom Tabs 可选，`androidx.browser`） | `LAUNCH_URL_CHANNEL` 已在（带 scheme 白名单） |
| 安全存储 | `flutter_secure_storage` | `AndroidKeyStore` + AES-256-GCM | `KeystoreSecretCipher` 已在（**不复刻** Flutter 的私有密文格式） |
| 网页登录 | `webview_flutter` | `android.webkit.WebView` + `AndroidView` + `CookieManager` | `WarehouseWebLoginHost` 已接 `g2.webLogin` |
| 扫码 | `mobile_scanner` | CameraX + MLKit `barcode-scanning` | `QrCameraHost` 已在（`g3.qrScan`） |
| 定位 | `geolocator` | `LocationManager`（不依赖 GMS，国行可用） | `AndroidWeatherLocationSource` 已在（`ShellWiring`） |
| 选图 | `image_picker` | `ActivityResultContracts.PickVisualMedia`（系统 Photo Picker，API 33+ **免权限**） | **缺**；契约在 `activity-compose 1.13` 里，不用加库 |
| 装 APK | `open_filex` | `FileProvider` + `ACTION_VIEW`（`application/vnd.android.package-archive`）+ `Settings.canRequestPackageInstalls()` 引导 | 权限、FileProvider、下载（`DownloadManager`）都在；**缺「拉起安装」一段** |
| 网络状态 | `connectivity_plus` | `ConnectivityManager.registerDefaultNetworkCallback` | 不需要（0 引用） |
| 设备信息 | `device_info_plus` | `Build.*` / `Settings` | 不需要（0 引用） |
| 动态取色 | `dynamic_color` | material3 `dynamicColorScheme`（Android 12+） | 不需要（miuix 主题未用） |
| JNI / 生命周期 | `jni`、`jni_flutter`、`flutter_plugin_android_lifecycle` | 直接 JNI / NDK；生命周期用 `LifecycleOwner` | 无对应物（Flutter 专用胶水），随 Dart 层消失 |

三条选型结论：

1. **`open_filex` 也有实现了**：`AboutUpdateHost.finishDownload` 先算 SHA-256 校对，再把
   `DownloadManager` 的 content Uri 交给 `Intent.ACTION_VIEW` 拉起系统安装器；清单已声明
   `REQUEST_INSTALL_PACKAGES`。→ 难度「易」，不需要新写安装器。
2. **`image_picker` 也有实现了**：`LiveDisplayHost` 用 `ActivityResultContracts.GetContent()`（SAF 通用选图）
   选完直接复制进私有目录。换成 `PickVisualMedia` 只是体验优化（省一道文件选择器面板），不是迁移前置。
3. **不新增依赖**：唯一可选的是 `androidx.browser`（Custom Tabs），现有 `ACTION_VIEW` 够用，不引。

## 7. 数据迁移的两个坑（比代码更值钱）

1. **`flutter_secure_storage` 的旧密文解不开。** `KeystoreSecretCipher` 的注释写明「不复刻那套私有格式」，
   所以 Flutter 侧存的 WebDAV 凭据**无法平移**——摘除后用户会被要求重新输一次密码。
   更麻烦的是现在**两套存储并存**（Dart 一份、Compose 壳一份），摘除前必须先定哪个是真源，
   否则会出现「教务登录记得、WebDAV 不记得」这类分裂。
   另：`res/xml/data_extraction_rules.xml` 已把 `FlutterSecureStorage.xml` 排除出备份，摘除时那两条排除规则要一起清。
2. **`shared_preferences` 反而是最省心的。** `PrefsKeyValueStore` 读的就是 Flutter 那份文件、同一套 `flutter.` 前缀，
   课表与设置能无缝继承——这是它引用最多（23 个文件）却只算「中」的原因。
   但**键名 / 类型映射要逐一对拍**（`FrozenValueCodec` 的冻结值语义、`corruptBackupKey` 的损坏备份分支都要保持）。

## 8. 第 1 批逐点对标（只读核对，2026-11-07）

范围：`url_launcher` / `geolocator` / `package_info_plus` / `share_plus` / `mobile_scanner`。
目的：确认「删掉 Dart 调用不会丢功能」。原生侧搜索同时覆盖 `src/main/kotlin` 与 `src/composeP1/kotlin`。

### 8.1 `url_launcher`（6 处，全部无损）

| Dart 位置 | 打开什么 | 原生对应 |
|---|---|---|
| `screens/about_screen.dart:579` | 应用仓库主页（`AppUpdateService.repositoryUrl`） | `LAUNCH_URL_CHANNEL`（白名单含 `https`） |
| `screens/about_screen.dart:601` | 仓库适配源仓库（`github.com/Mutx163/qingyu_warehouse`） | 同上 |
| `screens/about_screen.dart:1225` | 任意 URL（反馈 / 协议等） | 同上 |
| `screens/about_screen.dart:2541` | 更新发布页 | 同上 |
| `screens/import/warehouse/warehouse_adapter_detail_screen.dart:246` | 适配器仓库地址（可能是 `http` 校内站） | 同上（白名单也含 `http`） |
| `controllers/timetable_update_download_controller.dart:362` | 更新下载页 | 同上 |

六个目标全是 `http` / `https`，`ALLOWED_LAUNCH_SCHEMES` 全覆盖；Dart 侧不检查返回值（只 `await`），
与通道「失败静默」一致 ⇒ **无行为差异**。

### 8.2 `geolocator`（4 个 API，3 无损 + 1 需补底）

| Dart API | 用途 | 原生对应 | 结论 |
|---|---|---|---|
| `checkPermission()` / `requestPermission()` | 定位权限，区分 `denied` / `deniedForever` / `whileInUse` | `WeatherSettingsHost` 的 `RequestMultiplePermissions` launcher | 无损（注意保留「永久拒绝」分支） |
| `isLocationServiceEnabled()` | 系统定位总开关 | `AndroidWeatherLocationSource.isLocationEnabled()`（`isLocationEnabled` + NETWORK/GPS 双 provider 兜底） | 无损 |
| `getCurrentPosition(timeLimit: budget)` | **仅兜底**：通道不可用时的第二层 | `AndroidWeatherLocationSource.currentFix()`：先 `getLastKnownLocation`，再 `getCurrentLocation` 单次请求（预算 6s），拿不到走网络估算 | **无损**：原生类本身就是落地实现（权限/开关/6s 预算/网络兜底全有）；Dart 那一层兜的是「通道没注册」，Dart 一删通道就不存在了 |

结论：**4 项全部无损，不需要补代码**。README 式的“第二层兜底”担忧是 Flutter 桥的产物：
壳里直接调用 `AndroidWeatherLocationSource`，没有可供故障的通道层。

### 8.3 `package_info_plus`（11 个文件，全部无损）

实际只用到三个字段：`version`（9 处）、`buildNumber`（3 处）、`packageName`（1 处，诊断包名判定）；
`appName` / `buildSignature` / `installerStore` **未使用**。

原生替代：`BuildConfig.VERSION_NAME`、`BuildConfig.VERSION_CODE`、`context.packageName`。
注意：Android 上 `buildNumber` 就是 `versionCode` 的字符串形式，别拿 `versionName` 拼。

### 8.4 `share_plus`（9 个文件 / 10 处，**10/10 无损**，差异只剩分享结果三态）

| Dart 位置 | 分享内容 | 原生对应 |
|---|---|---|
| `services/statistics_share_service.dart:104` | 统计 PNG | `pages/statistics/StatisticsShareIntent.shareStatisticsImage` |
| `services/timetable_share_service.dart:82` | 课表 PNG | `app/TimetableHost.shareCurrentView` |
| `screens/ics_export_screen.dart:782` | ICS 文件 + **结果三态** | `app/IcsExportHost` + `AndroidShareAdapter`（`IntentSender` 广播拿真结果） |
| `services/data_transfer_service.dart:452` / `:491` | 迁移包 JSON（内存字节） | `AndroidTransferShareAdapter` / `TransferShareContract` |
| `screens/log_viewer_entry.dart:107` / `:209` | 日志文件 | `app/DiagnosticsLogHost.shareLogText`、`LiveSelfCheckHost.shareTextFile` |
| `screens/time_scheme_management_screen.dart:914` | 时间方案 JSON + 文案 | `TimeSchemeManagementDialogs`（`onShareSystem`） |
| `screens/import/spreadsheet_course_import_screen.dart:129` | 导入模板文件 | `platform/AndroidImportTemplateSharer`（`ImportHosts` 已用） |
| `screens/settings/settings_live.dart:376` | live 诊断导出（服务导出文件；拿不到则当前快照 JSON） | `app/LiveSelfCheckHost.exportDiagnostics()` → `shareLiveDiagnostics`：① `UmengDiagnosticReporter.exportLiveDiagnosticsFile` 导出后分享；② 拿不到则退回 `LiveUpdateService.buildDebugStatus` 快照（**先过 `redactedLiveDebugSnapshot` 脱敏**） |

行为差异（仅此一条）：`ShareResultStatus` 的 `success` / `dismissed` / `unavailable` 三态，原生只有 ICS 那条能拿到真实结果；
其余分支都是「送出即成功」。不影响功能可用，但 Dart 里靠结果弹不同 toast 的几处（如 ICS 取消/失败提示）
在原生侧要保留等价反馈。

`settings_live` 那处已追到底（2026-11-07）：原生 **有** 对应分支，而且对齐得比预期干净——
两条路径、`exportingDiagnostics` 守卫 + `finally` 复位、三个 toast 分支全一致；原生还多一层
（Dart 侧快照也脱敏，原生同样调 `redactedLiveDebugSnapshot`）。

### 8.5 `mobile_scanner`（1 处，无损）

Dart：`MobileScannerController(formats: [qrCode])` + `MobileScanner(onDetect:)` + 页面暂停时 `stop()`。
原生：`QrCameraHost`（CameraX + MLKit）已用 `setBarcodeFormats(Barcode.FORMAT_QR_CODE)` 限定 QR，
组合销毁时 `unbindAll()`；决策层是 `QrScanSessionCoordinator`。⇒ **无损**（无闪光灯 / 切换相机调用）。

### 8.6 小结

| 插件 | 调用点 | 无损 | 有差异 / 待确认 |
|---|---|---|---|
| `url_launcher` | 6 | 6 | 0 |
| `geolocator` | 4 个 API | 4 | 0 |
| `package_info_plus` | 3 个字段（11 文件） | 3 | 0 |
| `share_plus` | 10 | 10 | 0（仅三态结果差异） |
| `mobile_scanner` | 1 | 1 | 0 |

⇒ 第 1 批 **全部无损**，可以直接删。`live 设置导出分享`（§8.4）与 `定位第二层兜底`（§8.2）
两个待确认项都已追到底，结论都是无需补代码。
