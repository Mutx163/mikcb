# Compose 迁移 · Phase 2 业务族移植顺序（工作底稿）

> 状态：规划中（2026-10-26 盘点）· 读者：Lead 与并行泳道
> 数据契约：`docs/plans/2026-10-26-data-contract.md`（移植时的落盘口径唯一依据）
> 铁律提醒：动任何数据族前，双向测试（`FlutterPrefsCodecTest` + `legacy_prefs_codec_test`）
> 必须保持绿；golden 样本到位前**不写**「读真机盘」的 Kotlin 代码，先做纯逻辑移植。

## 1. 规模盘点（2026-10-26 实测）

| 层 | 文件 | 行数 |
|---|---|---|
| models | 32 | 10 731 |
| domain | 39 | 9 282 |
| services | 108 | 40 697 |
| utils | 40 | 9 206 |
| providers | 9 | 4 750 |
| controllers | 9 | 2 818 |
| 合计 | ~237 | ~77 500 |

（计划书估「逻辑层 ≈6.6 万行」，实测略多——以实测为准分批。）

## 2. 状态架构的关键事实（决定移植形态）

- **业务数据收敛度高**：`StorageService`（1 946 行）只有 5 个消费方
  （main / timetable_provider / app_sync_snapshot / partner_timetable / 自身）；
  其余 20 个服务**各自直连 SharedPreferences**（每服务独立 key 区，见契约 §2）。
  → Kotlin 侧照此形态：一个 `FlutterPrefsStore` 底座（封装契约 §1 编码）+
  每业务族一个 store 类，key 归属一对一映射。
- **`timetable_provider.dart`（3 834 行）是全局状态中枢**，横跨 20+ 服务。
  → Kotlin 侧对应物：单一 `TimetableRepository` + StateFlow，UI（Phase 3）
  经它取数；provider 内的**纯计算**部分（周次推算/课程过滤/排序）已在
  domain/ 与 models/，先移。

## 3. 业务族与移植顺序（每族 = 模型 + 逻辑 + 服务 + 端口测试）

顺序原则：① 纯逻辑先行（无 IO、可直接对拍 Dart 端口测试）；② 数据族过双向测试；
③ UI 强耦合族最后（与 Phase 3 交织）。

| # | 业务族 | Dart 源 | 依赖 | 端口测试现状 |
|---|---|---|---|---|
| 1 | 时间/周次核心 | models/course(630), time_scheme, timetable_profile/settings; domain/time_scheme_logic(508), course_session_stats(345) | 纯 | test/models+domain 丰富 |
| 2 | 日期规则/节假日 | schedule_date_rule, holiday_entry; holiday_service(738), timetable_holiday_service | prefs(节日缓存+自定义) | 有 |
| 3 | 课表 CRUD | domain/month_view_logic 等; timetable_course_service(978) | StorageService | 有 |
| 4 | 统计 | statistics_models; statistics_service(1247), course_session_stats | 课表族 | 有 |
| 5 | 导入导出 | import_export_logic(616), ics_export(745)/ics_import, spreadsheet_import(765), timetable_import_export(987) | 课表族 | 有 |
| 6 | WebDAV 同步 | webdav_sync_*(3 文件), app_sync_snapshot(1448), couple_webdav_* | prefs 凭据(§5) | 有 |
| 7 | 小组件/超级岛数据面 | home_widget_*, timetable_live_activity(1447), live_testing | 原生已就绪 | 有 |
| 8 | 天气/壁纸 | weather_*, bing_wallpaper_*, wallpaper_history, daily_wallpaper | prefs+网络 | 有 |
| 9 | 传输/局域网 | qr_transfer(775), unified_transfer(1129), lan_edit_*(3 文件) | 网络 | 有 |
| 10 | 杂项基础设施 | app_log, app_analytics, update, warehouse_* 等 | 混合 | 有 |

- 族 1/4/5 的纯逻辑部分**不碰落盘**，可立即并行派工（子代理各领一族，
  产出 Kotlin 文件 + 端口测试，跑 `:app:testProdDebugUnitTest`）。
- 族 2/3/6 动数据，等 golden 样本到位再动 Kotlin 读盘部分。
- 每族完成定义：`dart` 源文件清单全数有 Kotlin 对应物 + 端口测试绿 +
  **对拍**（同输入 → Dart 与 Kotlin 输出逐字段一致）。

## 4. 对拍机制（Phase 2 的验收核心）

Kotlin 端口测试的三类输入，期望值一律**独立生成**（红绿纪律的延伸）：
1. 金标准样本（如 GenGolden 系列）；
2. Dart 真实实现跑出的输出快照（`flutter test --plain-name <x>` 打印）——
   由 Lead 在 Windows 侧生成，泳道不跑 Flutter；
3. 人推的边界值（空/极值/非法）。

## 5. 泳道纪律（授权范围内）

- 泳道只写 `android/app/src/main/kotlin/com/mutx163/qingyu/<family>/` 新目录
  与 `android/app/src/test/kotlin/.../<family>/`，**不碰** storage/契约文件/build.gradle；
- 每泳道交付 = Kotlin 源 + JVM 端口测试 + 一段「Dart 对拍证据」说明；
- Lead 逐泳道评审（对照 Miuix 表与契约），合并前跑全量 JVM 测试。
