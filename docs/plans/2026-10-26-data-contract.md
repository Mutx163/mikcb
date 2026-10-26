# 数据契约（Compose 迁移 · Phase 0 冻结件）

> 状态：**冻结中**（Phase 0 产出；golden 样本核对完成后转「已冻结」）
> 日期：2026-10-26
> 上游计划：`docs/plans/2026-10-26-compose-migration-plan.md` §2
> 读者：Compose 迁移的实现者（含并行 Agent）。**落盘格式以本文为准，一个字节都不许变。**
> 本文由静态扫描 `lib/` 与插件源码（`shared_preferences_android-2.4.26`）生成；
> 「示例值」列与 key 集合的最终核对以真机 golden 样本为准（Task 1，待用户配合）。

---

## 0. 对上游计划的三处修正（以本文为准）

1. 计划 §2.2 估的「33 个 key 常量」**实际是 54 个**（含跨行声明、单标识符声明、动态前缀族）。
2. 计划 §2.2 的 `unparsed_profile_items` 是笔误，真实 key 是 **`courses_unparsed_items`**。
3. 计划 §2.2 把 `webdav_sync_password` / `couple_webdav_password` 列在 SharedPreferences 清单里——
   **它们实际存放在 `FlutterSecureStorage`**（凭据文件，见 §5），不在 prefs。prefs 里同名 key 不存在。

## 1. 编码规范（SharedPreferences 文件 `FlutterSharedPreferences`）

Kotlin 侧必须按以下规则读写（与插件 `LegacySharedPreferencesPlugin.java` 逐字节一致）：

### 1.1 文件与 key 前缀

- 文件名：`FlutterSharedPreferences`（`context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)`）。
- **所有 key 带 `flutter.` 前缀**（Dart 侧由插件自动加；Kotlin 侧必须显式加）。
  本文下文所有 key 均省略该前缀。
- 原生侧已有 3 个消费方（Compose 版必须保持兼容，它们就是活的参考实现）：
  `TodayWidgetSupport.kt` / `FairMemoryAdapter.kt` / `UmengDiagnosticReporter.kt`。

### 1.2 值类型编码

| Dart 类型 | 落盘形态 | Kotlin 读法 | Kotlin 写法 |
|---|---|---|---|
| `String` | 原样 | `getString` | `putString` |
| `int` | 原样 | `getInt` | `putInt` |
| `bool` | 原样 | `getBoolean` | `putBoolean` |
| `double` | 字符串 `"VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu" + double值文本` | 剥前缀后 `toDouble` | 前缀 + `toString` |
| `BigInt`（本仓未用） | 前缀 `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBCaWdJbnRlZ2Vy`（无末尾句点） | — | 本仓无写方，不需实现 |
| `List<String>` | 前缀 `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu` + 编码体（见 1.3） | 见 1.3 | 见 1.3 |

### 1.3 `List<String>` 编码（本仓 4 个生产 key，迁移的核心难点）

编码 = `java.util.Base64.getMimeEncoder(76, "\n")`？**不是，精确规则是：**

```
写：ObjectOutputStream 序列化 ArrayList<String> → 字节流
    → android.util.Base64.encodeToString(bytes, 0)   // flag=0：标准字母表 + 每 76 字符插 '\n'
读：android.util.Base64.decode(s, 0)                  // 容忍换行
    → ObjectInputStream.readObject() → List<String>
```

**Kotlin 侧换算（JVM 标准库等价实现，供 `FlutterPrefsCodec.kt` 使用）**：

- encode：`Base64.getMimeEncoder(76, byteArrayOf(0x0A))`。android flag=0 的换行符是 `\n`（不是 `\r\n`）。
- decode：`Base64.getMimeDecoder()`（容忍任意换行，读侧兼容两种历史形态）。
- 序列化只允许 `ArrayList` + `String` 元素（插件用 `StringListObjectInputStream` 限死了类型）。

⚠️ **本仓 4 个用这个编码的 key**：`courses`（legacy，只读不再写）、`teacher_records`、
`location_records`、`warehouse_recent_school_ids`。B→A 回退测试必须逐字节覆盖这 4 个。

### 1.4 并发与事务语义（Compose 版必须复刻的行为，不只是格式）

- `app_global_settings_mirror_tx_v1` 是**跨 key 事务日志**：全局设置与课表镜像一次逻辑保存、
  多个物理 key，进程中途被杀后下次启动按旧快照恢复（`storage_service.dart:41-50`）。
- 损坏自愈：读到损坏值时写 `{key}_corrupt_backup_{微秒时间戳}` 留档再删原 key
  （`storage_service.dart:557-576`）。Compose 版必须保留同样的留档行为，否则用户坏数据被静默吞掉。

## 2. Key 总表（54 项）

「类型」列为 Dart 侧存储类型；「写方/读方」为唯一归属文件（均在 `lib/services/` 下，
另有原生 Kotlin 读方单独标注）。示例值待 golden 样本回填。

### 2.1 课表主数据（`storage_service.dart`）

| key | 类型 | 内容 schema 摘要 | 原生读方 |
|---|---|---|---|
| `timetable_profiles` | String(JSON) | 课表全量 JSON 数组，v1 布局（`profilesSchemaVersion=1`） | TodayWidgetSupport |
| `timetable_profiles_schema_version` | int | 当前恒为 1；写路径自动盖章 | — |
| `active_timetable_profile_id` | String | 当前激活档案 id | TodayWidgetSupport |
| `timetable_settings` | String(JSON) | 显示设置（圆角、高度微调等，小组件兜底值见 `DEFAULT_CORNER_RADIUS_DP=22`） | TodayWidgetSupport |
| `time_schemes` | String(JSON) | 作息时间方案数组 | — |
| `location_time_groups` | String(JSON) | 地点-时间分组 | — |
| `schedule_date_rules` | String(JSON) | 日期规则数组 | — |
| `schedule_date_rule_last_applied_signature` | String | 规则应用签名（幂等去重） | — |
| `semester_start` | int | 学期起点（epoch millis 或天序，见模型） | — |
| `current_week` | int | 当前周次 | — |
| `courses` | **List<String>** | legacy 课表；**无生产写方，只有读方**（迁移后 Kotlin 只需读兼容） | — |
| `courses_unparsed_items` | String(JSON) | 坏课表条目隔离留档 `{archivedAt, count, items}` | — |
| `teacher_records` | **List<String>** | 教师记录 | — |
| `location_records` | **List<String>** | 地点记录 | — |
| `partner_timetable_binding` | String(JSON) | 情侣课表绑定（周偏移+三色） | TodayWidgetSupport |
| `custom_holidays` | String(JSON) | 用户自定义节假日 | TodayWidgetSupport |

### 2.2 动态 key 族（静态清单最容易漏，迁移必须按前缀兼容）

| 前缀 | 类型 | 写方 | 读方 | 说明 |
|---|---|---|---|---|
| `holiday_data_{年份}`（如 `holiday_data_2026`） | String(JSON) | `holiday_service.dart:239` | **原生 TodayWidgetSupport.kt 也在读**（`flutter.holiday_data_` 前缀枚举） | 节假日缓存，按年一条；远程源失败走内置资产兜底 |
| `{key}_corrupt_backup_{微秒时间戳}` | 与原 key 同型 | `storage_service.dart:557,586` | 仅人工排查 | 损坏留档；`_sweepOldCorruptBackups` 会清理旧份 |

### 2.3 节假日/壁纸/天气

| key | 类型 | 内容 | 归属 |
|---|---|---|---|
| `custom_holidays` | String(JSON) | 见 2.1 | holiday_service |
| `bing_wallpaper_v1` | String(JSON) | 必应壁纸当前态 | bing_wallpaper_store |
| `bing_wallpaper_items_v1` | String(JSON) | 壁纸条目缓存 | bing_wallpaper_store |
| `bing_wallpaper_items_at_v1` | int | 条目拉取时间（epoch millis） | bing_wallpaper_store |
| `bing_wallpaper_auto_apply_v1` | bool | 自动应用开关 | bing_wallpaper_store |
| `wallpaper_history_v1` | String(JSON) | 壁纸历史 | wallpaper_history_service |
| `wallpaper_history_v1_migrated` | bool | 迁移标记 | wallpaper_history_service |
| `weather_city_v1` | String(JSON) | 天气城市 | weather_preferences |
| `weather_enabled_v1` | bool | 天气开关 | weather_preferences |
| `weather_forecast_v1` | String(JSON) | 预报缓存 | weather_preferences |

### 2.4 同步与凭据（⚠️ 密码本体在 FlutterSecureStorage，见 §5）

| key | 类型 | 内容 | 归属 |
|---|---|---|---|
| `webdav_sync_config_v1` | String(JSON) | WebDAV 配置（URL/账号，**不含密码**） | webdav_sync_config |
| `webdav_sync_device_id` | String | 设备 id | webdav_sync_credentials_store |
| `webdav_sync_device_label` | String | 设备名 | webdav_sync_credentials_store |
| `couple_webdav_config_v1` | String(JSON) | 情侣同步配置（不含密码） | couple_webdav_config |
| `fair_memory_recovery_snapshot_v1` | String(JSON) | 恢复快照 | fair_memory_service |
| `warehouse_recent_school_ids` | **List<String>** | 最近学校 id | warehouse_import_preferences_service |
| `warehouse_maintainers_cache_v1` | String(JSON) | 维护者缓存（写在 about_screen） | about_screen |
| `warehouse_custom_debug_records` | String(JSON) | 调试记录 | warehouse_import_preferences_service |
| `warehouse_macro_record_index` | String(JSON) | 宏录制索引（写在 models） | warehouse_macro_models |

### 2.5 开关、引导与迁移标记

| key | 类型 | 内容 | 归属 |
|---|---|---|---|
| `accepted_privacy_policy` | bool | 隐私政策已同意 | storage_service |
| `has_completed_onboarding` | bool | 引导已完成 | storage_service |
| `has_seen_user_guide` | bool | 指南已看过 | storage_service |
| `has_handled_package_migration` | bool | 包迁移已处理 | storage_service |
| `did_migrate_app_logs_default` | bool | 日志默认值迁移标记 | storage_service |
| `did_migrate_live_hide_prefix_default` | bool | 超级岛隐藏前缀默认值迁移标记 | storage_service |
| `app_global_settings_v1` | String(JSON) | 全局设置镜像（事务日志保护，见 1.4） | app_global_settings_service |
| `app_global_settings_v1_migrated` | bool | 镜像迁移标记 | app_global_settings_service |
| `app_global_settings_mirror_tx_v1` | String(JSON) | 跨 key 事务日志 | storage_service:45 |
| `import_random_course_colors_enabled` | bool | 随机配色开关 | import_random_color_preferences |
| `import_random_course_color_group` | String | 配色组 id | import_random_color_preferences |
| `course_auto_refresh_v1` | String(JSON) | 自动刷新状态 | course_auto_refresh_store |
| `course_auto_refresh_last_attempt_v1` | int | 上次尝试时间 | course_auto_refresh_store |
| `course_auto_refresh_last_success_v1` | int | 上次成功时间 | course_auto_refresh_store |
| `diagnostics_log_time_sort` | String | 诊断日志排序偏好 | diagnostics_log_viewer_preferences |
| `blackbox_overlay_visible` | bool | 调试悬浮窗开关 | blackbox_overlay_preferences |
| `debug_tuning_panel_visible` | bool | （旧 key，legacy 读方保留） | blackbox_overlay_preferences |

### 2.6 blackbox 适配层（`lib/blackbox_adapters.dart`，生成代码）

blackbox（调试黑匣子）经适配层以**任意类型**写 prefs（`write()` 按值类型分发，
`readAll()` 全量读）。它写哪些 key 由 blackbox 运行时决定，**契约上按「动态、不可枚举」处理**：
Compose 版必须提供等价的任意类型读写入口，且同样落 `flutter.` 前缀。

## 3. 文件目录（prefs 之外的第二块冻结面）

| 目录 | 内容 | 出处 |
|---|---|---|
| `getApplicationDocumentsDirectory()` | 壁纸原图、预模糊位图、导出课表图 | `utils/managed_image_storage.dart:50` |
| `getApplicationSupportDirectory()` | 性能探针导出、诊断文件 | `utils/perf_probe.dart:879` |

Compose 侧对应：`context.filesDir`（= documents）与 `context.filesDir` 上一级的
app_support 目录（Flutter 的 support 目录是 `<files>/../app_support`，**路径必须精确复刻**，
迁移前用 golden 样本核实实际路径形态）。

## 4. 原生侧自有 prefs（原样保留，不参与冻结改写）

`native_runtime_prefs`、`home_widget_prefs`、`stats_widget_prefs`、`exam_reminder_prefs`、
`weekly_report_prefs`、`live_update_scheduler`、`before_class_quick_action_prefs`（7 个，
均已实锤于 `android/app/src/main/kotlin/`）+ `FlutterSecureStorage`（见 §5）。
这些文件本来就有 Kotlin 写方，Compose 版继续用即可，**禁止改名**。

## 5. FlutterSecureStorage（凭据，不做自动解密）

- 文件：`FlutterSecureStorage.xml`，密钥在 Android Keystore（插件私有派生，Tink）。
- 本仓 key：`webdav_sync_password`、`couple_webdav_password`、教务「记住登录」账密
  （见 `webdav_sync_credentials_store.dart` / `couple_webdav_credentials_store.dart`）。
- 行为契约：**密钥失效时绝不能删数据**——本仓显式传 `AndroidOptions(resetOnError: false)`
  （插件默认 true 会删光全部凭据，见该文件 10-24 注释）。Compose 侧等价实现必须保留这条语义。
- 迁移行为：不解密、不搬迁；用到时提示重输（WebDAV 同步页 / 情侣同步页 / 教务登录页）。

## 6. 验收对账（Phase 0 关门条件）

1. golden 样本（真机 `shared_prefs/` 导出）解析出的 key 集合 ⊇ 本文列出的全部 key
   （多出来的逐个补录 + 判定归属；**少一个都不行**）。
2. §2.2 两个动态族在样本中按前缀枚举对账。
3. A→B / B→A 双向测试（`test/services/legacy_prefs_codec_test.dart` 等）能红能绿（咬合探针留痕）。
4. 此后每次动数据层，双向测试必须重跑且保持绿。
