# 轻屿课表 → Jetpack Compose 迁移计划

> 状态：**proposed（未开工）**
> 日期：2026-10-26
> 分支：`compose-migration`（`main` 保持不动，随时可回）
> 读者：执行迁移的人（含并行的其他 Agent）
> 前置阅读：`docs/architecture/ARCHITECTURE.md`（现状架构与数据现状）

**Goal:** 把轻屿课表从 Flutter 原地换成 Jetpack Compose 实现：用户升级后**数据一条不丢**、
**不需要卸载重装**、**不需要做任何过渡操作**；主分支保持可用，随时可回退。

**Architecture:** 同包名（`com.mutx163.qingyu`）原地替换。**盘上数据格式冻结** ——
Compose 版继续按老格式读写 `FlutterSharedPreferences` 与既有文件目录，
使 Flutter 版与 Compose 版能共用同一份数据。这既是「不丢数据」的实现方式，
也是「可回退」的唯一保证。

**Tech Stack:** Kotlin + Jetpack Compose + 官方 Miuix（`top.yukonga.miuix.kmp:*`）；
原生侧（桌面小组件 / 超级岛 / 无障碍保活 / 前台服务）沿用现有 Kotlin，不重写。

---

## 0. 用户已拍板的硬约束

这六条是需求，不是建议。任何方案只要违反其中一条就不成立。

1. **数据不丢**：升级后课表、作息、地点、日期规则、设置、壁纸、统计全部还在。
2. **原地升级**：不卸载、不重装；用户不需要做任何操作（不需要导出、不需要导入）。
3. **不需要过渡**：不先发一个「桥接版」，用户端只有一次替换。
4. **教务导入的密码可以重输**（用户明确同意）。
5. **主分支必须保持可用**：迁移有可能中途放弃，`main` 要随时能回来接着做。
6. 现阶段全力以赴。

---

## 1. 一句话结论

**技术上可行。真正要守的不是「能不能读到老数据」，而是「能不能继续按老格式写回去」。**

- **读**：仓库里已有现成证据 —— Kotlin 写的桌面小组件就在直接读 Flutter 落盘的课表
  （`android/app/src/main/kotlin/com/mutx163/qingyu/TodayWidgetSupport.kt:151-157`，
  读 `FlutterSharedPreferences` 里的 `flutter.timetable_profiles`）。同一个包名、同一个 UID，
  Compose 版读它没有任何障碍。
- **写**：**这是迁移新增的约束**。一旦 Compose 版换了落盘格式，用户就回不去 Flutter 版
  （硬约束 5 作废），线上出问题时也没有退路。
- 所以本计划的第一条铁律是：**迁移期间，盘上格式一个字节都不许变。**

---

## 2. 铁律：数据格式冻结

### 2.1 为什么是「冻结」而不是「迁移到新格式」

| 选项 | 后果 |
|---|---|
| **冻结老格式**（本计划） | 回退随时可行；灰度期两版能共用同一份数据；不用写一次性数据改写代码 |
| 迁到新格式（如 SQLite / DataStore） | 必须写「老 → 新」一次性迁移；**迁完就回不去**（约束 5 作废）；迁移中途被杀进程要有事务语义；出错即用户数据损坏 |

新格式（SQLite、DataStore/Proto）确实更好用，但那是**迁移完成、回退窗口关闭之后**的独立优化，
不是这次迁移的一部分。本次一律用老格式。

### 2.2 冻结的具体内容

**① SharedPreferences —— 文件 `FlutterSharedPreferences`，key 统一带 `flutter.` 前缀**

- 读法：`context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)`
- 值类型只有 String / Int / Bool / Double（Double 带前缀 `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu`）
- **`List<String>` 是特殊编码**：前缀 `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu`
  + Java `ObjectOutputStream` 序列化 + Base64。Kotlin 读它比 Dart 还顺（同一套 Java 序列化），
  但**必须逐字节按这个格式写回**。本仓有 4 个 key 用它：

  | key | 内容 |
  |---|---|
  | `courses` | legacy 课表（`storage_service.dart:754`，已无生产写入方，只有读方） |
  | `teacher_records` | 教师记录（`:1545`） |
  | `location_records` | 地点记录（`:1564`） |
  | `warehouse_recent_school_ids` | 最近用过的学校（`warehouse_import_preferences_service.dart:451`） |

- **33 个 key 常量**（从 `static const ... Key = '...'` 数出，完整清单以真机 prefs 文件为准）：

  ```
  timetable_profiles            timetable_settings           timetable_profiles_schema_version
  active_timetable_profile_id   time_schemes                 location_time_groups
  schedule_date_rules           schedule_date_rule_last_applied_signature
  semester_start                current_week                 courses
  teacher_records               location_records             custom_holidays
  partner_timetable_binding     warehouse_recent_school_ids  warehouse_maintainers_cache_v1
  warehouse_custom_debug_records
  accepted_privacy_policy       has_completed_onboarding     has_seen_user_guide
  has_handled_package_migration did_migrate_app_logs_default did_migrate_live_hide_prefix_default
  app_global_settings_mirror_tx_v1 (事务日志)   unparsed_profile_items（损坏留档）
  bing_wallpaper_v1 / bing_wallpaper_items_v1 / bing_wallpaper_items_at_v1
  webdav_sync_password          webdav_sync_device_id        webdav_sync_device_label
  couple_webdav_password        fair_memory_recovery_snapshot_v1
  course_auto_refresh_last_attempt_v1 / course_auto_refresh_last_success_v1
  blackbox_overlay_visible      debug_tuning_panel_visible   diagnostics_log_time_sort
  ```

  ⚠️ 还有若干**内联字面量 key**（没有走 key 常量），Phase 0 必须**按真机文件全量核对**，
  不要以这份列表为唯一依据。

**② 文件目录**

| 目录 | 内容 | 出处 |
|---|---|---|
| `getApplicationDocumentsDirectory()` | 壁纸原图、预模糊位图、导出的课表图 | `utils/managed_image_storage.dart:50` |
| `getApplicationSupportDirectory()` | 性能探针导出、诊断文件 | `utils/perf_probe.dart:879` |

**③ 原生侧自己的 prefs（8 个文件，原样保留即可，不参与冻结讨论）**

`native_runtime_prefs`、`home_widget_prefs`、`stats_widget_prefs`、`exam_reminder_prefs`、
`weekly_report_prefs`、`live_update_scheduler`、`before_class_quick_action_prefs`、
`FlutterSecureStorage`（凭据，见 §4）

### 2.3 冻结怎么验证（这是验收门槛，不是口号）

1. **golden 样本**：在真机上取一份「升级前」的数据快照（prefs 文件原文 + 目录清单 +
   文件大小/哈希），存进仓库外的本地目录，作为所有后续验证的基准。
   *需要用户配合在设备上取一次 —— 按本仓设备纪律，Agent 不主动碰设备。*
2. **双向兼容测试**（Phase 0 的核心产出）：
   - **A→B**：Flutter 写 → Compose 读，逐 key 断言值相等；
   - **B→A**：Compose 写 → Flutter 读，逐 key 断言值相等 —— **这一条才是回退的保证**。
3. 之后**每次动数据层**（models / storage / 同步）都要跑这两个方向。

---

## 3. 数据清单：要保住什么

| 类别 | 内容 | 升级时会发生什么 |
|---|---|---|
| SharedPreferences | 课表主数据、作息、地点、日期规则、设置、壁纸索引、开关（见 §2.2） | 原地不动（同 UID 同目录） |
| 文件 | 壁纸与预模糊图、导出文件、诊断日志 | 原地不动 |
| 凭据 | WebDAV / 情侣同步 / 教务「记住登录」三组 | **解不开，需要重输**（见 §4） |
| 原生 prefs | 小组件快照、超级岛调度、保活状态等 8 个文件 | 原地不动 |
| 系统侧状态 | 小组件实例、无障碍开关、通知渠道偏好、已排定的闹钟 | 原地不动 —— **前提是组件名不变**（见 §5） |

### 3.1 系统侧状态（不在文件里，最容易漏）

| 项 | 具体值 | 改了会怎样 |
|---|---|---|
| 桌面小组件 Provider | `TodayCompactWidgetProvider` / `TodayMiniListWidgetProvider` / `TodayMediumWidgetProvider` / `TodayLargeWidgetProvider` / `TodayStripWidgetProvider` / `TodayWideWidgetProvider` / `StatsCompactWidgetProvider` / `StatsMediumWidgetProvider` / `StatsStripWidgetProvider` / `ExamCountdownWidgetProvider`（共 10 个） | 类名/包名一改，用户桌面上已有的小组件**全部变成「无法加载」**，得手动删了重加 |
| 无障碍保活服务 | `KeepAliveAccessibilityService` | 系统按「包名+类名」记住用户是否开启；改名 = 服务被关掉，用户要重新去设置里开 |
| 通知渠道 | `live_update_channel_v2` / `exam_reminder_channel` / `weekly_report_channel` / `lan_edit_channel` | 改 ID = 新建渠道，用户之前设的静音/重要性偏好归零 |
| 广播接收器 / 服务 | `LiveUpdateService` / `LanEditForegroundService` / `LiveUpdateReceiver` / `ExamReminderReceiver` / `WeeklyReportReceiver` / `HomeWidgetRefreshReceiver` | `PendingIntent` / `AlarmManager` 里存的是**显式类名**，改名后已排定的闹钟与刷新失效或崩溃 |

---

## 4. 凭据：不做自动解密，用到时重输

**现状**：三组凭据在 `flutter_secure_storage` 里（文件 `FlutterSecureStorage.xml`），
密文由 Android Keystore 里**设备绑定的密钥**保护，密钥派生逻辑是插件私有的（Tink + Keystore）。
`backup_rules.xml` / `data_extraction_rules.xml` 里都把它排除在系统备份之外，理由也写在注释里。

**决定：不做自动解密。**

- 理论上同一个 UID 能复刻插件的解密逻辑，但那是**逆向一个第三方插件的私有密钥派生**：
  做对了收益只有「用户少输一次密码」，做错了是**永久解不开**。收益风险比不成立。
- 具体行为：需要用到时才提示重输（WebDAV 同步页、情侣同步页、教务登录页），不做首启弹窗。
- ⚠️ **一个重要澄清**：教务的登录**会话**（WebView 的 Cookie）存在 App 私有目录里，
  会跟着升级保留。所以用户不是「要重新登录」，只是「自动填充的密码没了」——输一次就恢复原样。

**待用户确认**：教务侧已确认可重输；**WebDAV 主密码、情侣同步密码**是否也接受重输一次？
（这是本计划唯一需要用户再拍板的一处。）

---

## 5. 升级机制（「不卸载重装」的硬前提）

| 项 | 现状 | 迁移要求 |
|---|---|---|
| `applicationId` | `com.mutx163.qingyu` | **一个字符都不能改** |
| 签名密钥 | `android/app/upload-keystore.jks`（`key.properties`） | **绝对不能换** —— 换了就是「签名不一致」，只能卸载重装 = 数据全丢。这是全计划唯一一条「做错就全丢」的红线 |
| `versionCode` | `flutter.versionCode + 100000`（偏移是为 ABI 拆分加的，见 `android/app/build.gradle` 注释） | 重算后必须 **≥ 当前线上值**，否则系统按「降级安装」拒绝，用户看到「应用未安装」 |
| `minSdk` | 26 | **不要抬高**（抬高等于老设备收不到升级 = 丢掉这批用户） |
| ABI | 只打 `arm64-v8a` | 保持一致 |
| 组件类名 | 见 §3.1 | 全部保留 |

---

## 6. 阶段计划

每阶段都有**可验收的产出**；上一阶段没过门槛不进下一阶段。

### Phase 0 · 冻结数据契约（不写产品代码）

- 产出：
  - `docs/architecture/data-contract.md`：§2 的清单扩到「每个 key 的 JSON schema + 示例值」；
  - golden 样本（真机取一次）；
  - **双向兼容测试**骨架（A→B / B→A），跑在 Flutter 侧即可，不需要 Compose 版存在。
- 验收：双向测试在 Flutter 与「模拟 Compose 读写的纯 Kotlin 脚本」之间能红能绿（先故意写错一次，确认它会红）。

### Phase 1 · 同包名 Compose 空壳（**全计划风险最大的一步，先做**）

目的：把「数据能不能留住」从讨论变成实证，同时把升级链路打通。

- 产出：一个 `applicationId = com.mutx163.qingyu` 的最小 Compose 工程，
  启动后读同一份 prefs / 同一张壁纸文件并显示出来；能写回一个 key。
- 验收（**真机**）：
  1. 在已经装了 Flutter 版、且有真实数据的机器上**直接覆盖安装**（不卸载）；
  2. 启动后能看到那台机器上真实的课表数据；
  3. 写回后，**Flutter 版仍能正常读到**（这一条就是回退能力的实证）；
  4. 桌面小组件、无障碍开关、通知渠道偏好全部没变。

### Phase 2 · 逻辑层移植（约 6.6 万行）

`models` / `domain` / `services` / `utils` / `providers` / `controllers` → Kotlin。
按业务族分批（课表、作息、日期规则、导入导出、同步、统计、天气、日志），
**每族带自己的端口测试**（对齐现有 `test/services/` 的口径）。

### Phase 3 · UI 层移植（约 12.3 万行）

`screens` / `widgets` / `ui` → Compose + Miuix（官方 Compose 版）。
按页面分批，每批真机对照。**这一层是保真度风险集中处**（玻璃、模糊、转场、动效）。

### Phase 4 · 原生能力对齐

小组件 / 超级岛 / 无障碍保活 / 前台服务 / 日历同步 / 通知 —— 这部分**本来就是 Kotlin**
（`android/app/src/main/kotlin/` 54 个文件 1.95 万行，其中只有 5 个耦合 Flutter），
预期大部分原样复用，只需换掉与 Flutter 通信的那几条 `MethodChannel`。

> **现状（2026-11-03 注记，逐项证据见派工大表 §五）**：本阶段已**大体完成**——桌面小组件刷新已接线（`480bf611`）、
> 前台服务与保活页已接真状态、通知渠道与点击路由已换 Kotlin 侧（`bd1bbeb0`，超级岛/考试/周报/局域网四处
> `NotificationLaunchTarget.intent` 不再写死 `.MainActivity`）、相机与扫码已进构建、局域网收发/撤销/整份恢复
> 已交付（`eb32ae25`/`45cfb149`）。**仍缺**：超级岛展示层方案未拍板（`P3-L` ⏸，RemoteViews vs Glance）、
> 通知点击落页参数壳侧未消费、宽屏适配 0 处使用（方案文档编写中）、埋点管道/截屏提示面板/教务网页原生对话框进行中。

### Phase 5 · 收尾

删 Flutter 依赖与两个 fork（`flutter_miuix` / `inspire_blur`）、删 Dart 代码与测试、
确认回退窗口关闭（此时才允许考虑换新格式）。

> **现状（2026-11-03 注记）**：**未开始**。前置条件已就绪一半：正式包启动页已切到 Compose 壳
> `PagesShellActivity`（`1158ee20`，回退方式写在 `main/AndroidManifest.xml:159-160`）；Compose 读路径资产已独立
> （`android/app/src/main/assets`，守卫 `FlutterAssetsDecouplingGuardTest` 钉死）。回退窗口仍开着，`lib/**` 保持只读对照物；
> 删除动作等真机逐页对照走完、且 Phase 4 剩余项收口后再做（归 Lead + 用户）。

### Phase 0 的具体任务（开工第一刀）

> 这一阶段不写任何产品代码，产出全部落在测试与文档里。

**Task 1 · 取 golden 样本（需要用户配合真机）**
- 用户操作：在一台装了当前版本、有真实数据的设备上，把 `shared_prefs/` 整体只读导出
  （按本仓设备纪律，Agent 不主动碰设备）。
- 产出：本地私有目录下的 prefs 原文 + 文件清单 + 大小。
- 验收：能用脚本把 `FlutterSharedPreferences.xml` 解析成 `key → 值` 表。

**Task 2 · 写数据契约文档**
- 把本文 §2 扩成逐字段契约（每个 key 的 JSON schema + 一个真实示例值）。
- 依据：golden 样本 + `lib/models/*.dart` 的 `toJson/fromJson`。
- 验收：契约里列出的 key 集合与 golden 样本里的 key 集合**完全一致**（多一个少一个都算没过）。

**Task 3 · A→B 方向验证（Flutter 写 → Kotlin 读）**
- Flutter 侧写出 fixture，Kotlin/JVM 侧读出来逐字段断言。
- 覆盖：全部 key + 4 个 Java 序列化 List + 文件目录。
- 验收：故意改错一个字段名，这条 probe **必须红**（咬合探针）。

**Task 4 · B→A 方向验证（Kotlin 写 → Flutter 读）—— 回退的保证**
- 反过来：Kotlin 侧按老格式写出，Flutter 侧 `StorageService` 读出来逐字段断言。
- 验收：故意把 List 编码换掉（不写前缀），Flutter 侧必须读失败 —— 证明这条测试有牙齿。

---

## 7. 回退方案（用户明确要求：可能放弃迁移）

| 情形 | 怎么回 |
|---|---|
| 还没发布 Compose 版 | 直接 `git switch main`，什么都没发生 |
| 已发布 Compose 版，决定放弃 | 发一个 **versionCode 更高**的 Flutter 版覆盖回去 —— **前提是 §2 的格式冻结没被破坏** |
| 用户设备上数据被弄坏 | 已有兜底：WebDAV 全量快照 / 全量备份 JSON / 二维码与局域网传输（版本化 JSON，跨版本可用） |

**回退窗口的关闭时机**：Phase 5 结束、且确认不再需要回退。在此之前，任何「顺手改成新格式」的改动都是破坏回退能力。

---

## 8. 明确不承诺的（避免误解）

- **不承诺视觉 100% 一致**：玻璃、模糊、转场都要在新框架里重新调参，会有可感知的差异。
- **Android 8~12 的模糊可能退化**：官方 `miuix-blur` 要求 API 33+，低于它自动退化成不模糊，
  而现在的 Flutter 侧在这批机器上是有模糊的。**待定项**：抬 minSdk 到 33 / 自己写 26~32 的回退。
- **教务导入的远端脚本仓库不受影响**（脚本跑在 WebView 里，与 UI 框架无关）。
- **不做 iOS / 桌面**：仓库 2026-03 已精简为仅安卓。

---

## 9. 被否掉的方案（记下最强理由，避免以后重走）

**混合壳（Compose 外壳内嵌 FlutterEngine，逐屏替换）** —— 这是纯工程视角最优解：
风险分散、每步可验证、数据层天然共用。**否掉的理由是硬约束 3（不要过渡）**：
混合期用户端同时跑两套 UI，包体变大、两套渲染管线共存、双写者问题（Flutter 与原生各自
在内存里缓存 SharedPreferences，互相看不见对方的写入）都要长期背在身上。
用户已明确不要过渡，所以本计划走**一次性原地替换**，把风险压到「数据契约 + Phase 1 实证」上。

---

## 10. 需要用户拍板的三件事

1. **WebDAV 主密码 / 情侣同步密码**是否也接受重输一次？（教务已确认可重输）
2. **minSdk 是否允许抬高到 33**（换官方模糊；代价是 Android 8~12 用户收不到升级）。
3. **Phase 1 真机验证**需要用户配合：在一台有真实数据的设备上覆盖安装测试包，并取一份 golden 样本。
