# 全量代码审查报告 · 2026-09-26

> 13 个并行子代理按功能域审查 `lib/`(375 文件)、`test/`(297 文件/78,979 行/2,637 个用例)、
> `android/`、`tool/`、`scripts/`、`site/`、`shaders/`、`docs/`。
> 基线：`flutter analyze --no-pub` **零问题**——lint 层面干净，问题全在逻辑/安全/一致性层。
> 所有发现均给出真实 `file:line`；标注「需确认」的表示需真机或额外核实。
>
> ⚠️ **本报告已复核，请先读 [§8 复核结果](#8-复核结果)。** 原文一字未删，但其中约 6 条硬错误、
> 5 处夸大与若干数字需要以 §8 为准：行号与代码位置引用几乎全对（可继续当地图用），
> 而部分「为什么会坏」的机制诊断是错的，照原文去查会走错方向。
>
> **统计口径更正（原「163,876 行」无对应口径）**：`lib/` 共 375 个 Dart 文件、252,515 行，
> 其中自动生成的 `app_localizations*` 占 87,501 行；**排除生成物后为 165,025 行**
> （原报告的 163,876 最接近此口径但仍差 1,149 行）。原文把「全部文件数 375」与
> 「排除生成物的行数」并列，口径混用。`test/` 原写 298 文件/79,266 行/2,650 用例，
> 实为 297 文件/78,979 行/2,637 个 `test`/`testWidgets`/`testGoldens` 声明。
> 提交数原写 2,631，实为 2,633。`timetable_screen.dart` 原写 10,448 行，实为 10,460 行。

## 0. 分数总览

| # | 领域 | 分数 | 最刺眼的一条 |
|---|---|---|---|
| 7 | 安全 / 隐私 / 凭据 | **5** | 教务网页里的脚本能弹出 App 原生输入框钓密码 |
| 1 | 同步 / 云备份 / 情侣同步 | **5.5** | 快照恢复中途被杀 = 永久半应用且无法撤销 |
| 13 | 工具链 / 脚本 / 文档站 | **4** | `tool/` 有 5 个已验证会毁文件的脚本 |
| 5 | 导入 / 导出 | **6** | 一个日历文件能让 App 内存爆掉并永久卡死 |
| 2 | 局域网联机编辑 / 传输 | **6** | HTTP 层约 4 分：无超时无连接上限，任意设备可挂住服务 |
| 10 | 页面层 / 设置页 | **6.5** | 一条课程颜色格式不规范 → 整个考试列表页打不开 |
| 4 | 课表核心逻辑 | **7** | 同一个问题在主界面/小组件/超级岛有三个答案 |
| 3 | 存储 / 持久化 / 设置 | **7.5** | 30 字节坏记录 → 必须清除应用数据才能恢复 |
| 6 | UI 设计系统 / 玻璃渲染 | **7.5** | 外观编辑转场瞬时 GPU 纹理峰值 250MB |
| 8 | 应用更新 / 网络服务 | **7.5** | 「用系统下载器」这条路径把哈希校验全绕过了 |
| 9 | 后台服务 / 平台集成 | **7.5** | Android 8–11 上「课前 15 分钟提醒」会迟到 15–60 分钟 |
| 11 | 测试 / 工程规范 | **7.5** | 3,363 行业务代码零测试，且没有任何自动化能发现 |
| 12 | 功能一致性 | **8** | 非安卓手机上「超级岛」整页设置空转，入口还显示"已启用" |

**整体约 6.8/10**：不是"写得差"，是"**正常路径做得很细、异常路径和跨模块一致性没人管**"。

---

## 1. 四个系统性问题（比任何单条发现都重要）

单条问题修完还会再来。这 4 条是根因，13 个代理里有 8 个独立撞到。

### 1.1 「静默失效」是本项目最普遍的死法

不是崩溃，是**用户以为有、实际没有，且没有任何提示**。至少 6 个模块：

| 表现 | 位置 | 用户感知 |
|---|---|---|
| 课前/考试提醒迟到 15–60 分钟 | `LiveUpdateScheduler.kt:2540-2545`（条件写反）、`ExamReminderScheduler.kt:344-357` | 以为有提醒，实际考前一小时才响 |
| 精确闹钟权限的申请入口只在「桌面小组件」页 | `settings_home_widget.dart:575-593` | 考试提醒页零提示 |
| 考试提醒重排中途抛异常 → 旧闹钟已取消、新闹钟没排完 | `exam_reminder_service.dart:380-387` | 所有考试提醒静默消失，线上零日志痕迹 |
| 导入解析失败的行被静默丢弃 | `course_import_screen.dart:5531-5562`（仓库宏）、`ics_import_service.dart:138-143` | 以为 50 门全导进去了，实际 30 门 |
| 设置保存失败完全静默 | `settings_live.dart:599-601`、`:886-892` | 界面显示已改，重启变回去 |
| 日历同步失败只有笼统「同步失败」 | `sync_error_localizer.dart:21` 兜底 | 云端数据已损坏（唯一信号）被显示成"网断了" |

**根因**：`AppLogService` 在 release 包默认不落盘（`app_log_service.dart:414-419`），所以"静默"连排查线索都没有。
**修法**：① 错误码 → 本地化文案映射补齐（`sync_error_localizer.dart`）；② 提醒调度链路补 `AppLogService.warn`；③ 这类降级一律在 UI 上显式呈现当前档位（精确/近似/缺失）。

> **🔍 复核（见 §8.4、§8.5）**：上表**首行已复核为不成立**——`LiveUpdateScheduler.kt:2531-2552`
> 不是「条件写反」，而是正确的降级分支；`ExamReminderScheduler.kt:358-363` 在 Android 6–11 走的是
> `setExactAndAllowWhileIdle`（精确），所以「迟到」对考试提醒不成立。**第 5 行（根因）引错行号**：
> `app_log_service.dart:414-419` 是 `_shouldRecord`（只判 `_privacyAccepted` 与 `_loggingEnabled`），
> 该文件不含任何 `kReleaseMode`/`kDebugMode`；真实机制在 `lib/logging/app_debug_log.dart:4-11`。
> 结论「release 普遍无日志」仍成立，且因此**第 3 行为真**：`exam_reminder_service.dart:385` 用的
> 标签是 `ExamReminder`，不在 `forensicTags`（仅 `LocationTimeApply`、`LocationTimeApplyUI`）白名单内，
> release 下这条日志被直接丢弃。第 2 行与第 6 行复核为成立。

### 1.2 「同仓两套标准」

同一个仓库里，**一个实现把规矩做对了，另外 5 个各自重写一遍且都是错的**：

| 领域 | 做对的 | 做错的 |
|---|---|---|
| 存储写入 | `StorageService`（检查返回值 / 失败 reload / 坏数据留档 / 写入串行排队） | `WarehouseImportPreferences`、`WallpaperHistoryService`、`WarehouseMacroService`、`ImportRandomColorPreferences`、`DiagnosticsLogViewerPreferences` —— 全部丢弃 `setString` 返回值、全部无坏数据兜底 |
| l10n 生成 | `sync_arb.dart`（有存在性判断） | 5 个脚本已验证会毁文件（见 §2.4） |
| adb 定位 | `tool/qa.ps1:53-69`（LOCALAPPDATA + PATH 双候选） | `android_cli_install.ps1:26-27`（本机必然失败）、`logcat_app.ps1:12-16`（硬编码路径，本机不存在） |
| 失败风格 | `homePage` 未知 key 抛异常 | `resolveSettingsSubpage` 静默 return（`home_menu_catalog.dart:423-425`） |

**修法**：抽一个 `CheckedPrefs` 薄封装（检查 + reload + 抛错 + 串行），让 5 个服务统一走它。约 100 行，消掉一整类问题。

> **🔍 复核（见 §8.6）**：存储行**结论对、后半句说错**。「5 个全部丢弃 `setString` 返回值」为真；
> 但「全部无坏数据兜底」为**假**——`WallpaperHistoryService:142-152`（try/catch 回退 `const []`）、
> `WarehouseMacroService:33-46`/`:68-83`/`:131-143`（try/catch 回退 `null` 或空列表）、
> `DiagnosticsLogViewerPreferences:11-18`（白名单降级）都有兜底，`WarehouseImportPreferences`
> 也有 `_decodeRememberedLogin:320-339` 的 try/catch。站得住的表述是：**5 个全部忽略写入失败，
> 且没有一个会把坏数据另存备份、或在写失败后 reload**。报告对 `StorageService` 的正面描述经复核全部为真
> （`:415-421` 检查 `setString` 返回值否则抛 `StateError`、`:399-413` 失败后 reload、
> `:475-495` 的 `_backupAndRemoveCorruptString` 隔离坏数据、`:1012-1026` 串行写）。
> 该行其余三行（l10n 生成、adb 定位、失败风格）复核为成立。

### 1.3 「同一问题多个答案」

| 问题 | 分歧点 |
|---|---|
| 今天第几周 / 停课周算不算上课 | 主界面用「浏览周次 + 含停课周」，超级岛/桌面用「真实日历周 + 排除停课周」，统计小组件用「用户正在浏览的周次」。桌面统计卡在用户翻周时会跟着回退 5 周（`live_activity_controller.dart:1065`） |
| 节假日当天算不算课 | 课表页**照常显示**只打标记；桌面小组件**整天空课**（`timetable_controller.dart:502-504`）；ICS 导出**跳过**；统计页**完全不知道有节假日**（`statistics_service.dart:11-18`，签名里没有节假日参数） |
| 「从教室名提取楼栋」 | 桌面小组件走 Kotlin，App 内走 Dart，正则只认字母开头 → 中文校区「第一教学楼」失效，两端口径还会随夏令时分叉（`WidgetStatsLogic.kt:104/106` 固定 86,400,000ms，而同文件 `:132-153` 已用正确的 `Calendar`） |
| 「今天」 | 主界面用 Provider 缓存的星期（30 秒 tick 刷新），超级岛用实时时钟 |

**修法**：抽一个共享的「某天有效课程」纯函数，四处统一调用。至少先给 `StatisticsService.calculate` 补 `holidayData` + `markingEnabled` 参数。

### 1.4 「注释承诺了不存在的东西」——4 个代理各自独立发现

这一条单独列出来，因为它让后续维护者会**基于错误前提做决策**：

> 🚨 **🔍 复核结论：本节 4 条中 3.5 条已复核为「不成立」，仅第 2 条部分成立。原标题「4 个代理各自独立发现」不成立，请勿把本节当根因。** 逐条见 §8.3。

| 注释说 | 实际 |
|---|---|
| 「the next sync can safely retry or garbage-collect it」`webdav_sync_service.dart:370-371` | 回收逻辑根本不存在，云盘随每次同步无限膨胀 |
| 「CI 与 `verify_release_pubspec.sh` 会在 PR 与发布前拦截」`docs/RELEASE.md:593` | 那个脚本**没有任何 pre-commit hook、没接进任何 workflow**（版本格式那一半是假的） |
| 「镜像下载走 dart:io，不受本策略管辖」`network_security_config.xml:16-20` | 系统 `DownloadManager` **受**管辖。这条错误前提正是"两条下载路径防护不对等"的源头 |
| 「即使 cnb 上存在本地已不可达的旧提交，也不可能覆盖远端新数据」`scripts/sync-main.ps1:19-20` | `--force-with-lease` 挡的是并发覆盖，不是覆盖别人的新提交 |

---

## 2. P0 清单（18 条，按修复顺序）

### 2.1 数据会被永久毁掉 / 污染（6 条）

| # | 问题 | 位置 | 一句话 |
|---|---|---|---|
| 1 | **一个日历文件就能让 App 内存爆掉并永久卡死** | `ics_import_service.dart:362-386` → `course.dart:488` → `import_export_logic.dart:135`/`:401-409` | `RRULE:UNTIL=99991231` 让周次变成 **41 万**（实测）。`activeWeeks` 是 getter，每次调用现造 41 万元素 List；去重时对它拼字符串（每门课每次导入约 2.4MB）；且课程**已落盘**，之后每次开课表都在踩，只能清数据恢复 |
| 2 | **导入文件无体积上限，xlsx = 压缩炸弹** | `course_import_screen.dart:669-689`、`spreadsheet_import_service.dart:247-262` | `FilePicker(withData: true)` 整文件进内存，10MB xlsx 可解压 10GB。Android 上 OOM 是**进程直接被杀**，try/catch 救不回来 |
| 3 | **30 字节坏记录 = 永久砖机** | `storage_service.dart:282-317`、`:337-339`、`:134` | 事务恢复日志解析失败就抛错，但**坏记录永远留在盘上**，`_prefs` 已在抛错前赋值 → 后续所有重试都不触发 → 每次保存设置都报错，重启无解，用户只能"清除应用数据" |
| 4 | **云恢复先删后写，缺字段即永久丢** | `warehouse_import_preferences_service.dart:436-488` | 先删本地全部教务凭据，再写回；而空值不写回。三个触发路径都真实：恢复旧快照 / 中途被杀 / keystore 单条抛异常 |
| 5 | **一条坏记录同时打死教务页和整个云同步** | `warehouse_import_preferences_service.dart:362`、`:70-75` | `jsonDecode` 无保护。`getCustomDebugRecords` 三个上游全裸 await，其中一个在 `initState` 无 try/catch → 页面永久转圈；另一个让 **WebDAV 上传整体失败** |
| 6 | **快照应用无事务，杀进程 = 永久半应用且无法撤销** | `app_sync_snapshot_service.dart:900-968` | 8 次以上独立落盘，回滚只存内存。重启后 `undoLastApply` 直接 return false → 用户既没有干净状态，也没法撤销 |

**🔍 复核（逐条见 §8.7）**

- **#1 成立，且行号全对。** 实算 `UNTIL=99991231` 得 **416,055** 周（"41 万"准确）；`weeks.join(',')`
  连成的数字为 2,385,225 字符（约 2.4MB，原报告数字准确）；`activeWeeks`（`course.dart:482`）确为
  每次重算的 getter，`:531` 另有一处调用。`course.dart:222-227` 解析失败确实返回 `0`，
  `week_calculator.dart:64` 确有 `0` 哨兵；`course.dart:489-494` 单双周同时为真确实产出空表。
- **#2 成立**（本轮新增复核）：`course_import_screen.dart:669-673` 确为 `FilePicker.pickFiles(withData: true)`，
  `:677` 取 `file.bytes`、`:689` 直接送去解析，**中间无任何体积检查**；
  `spreadsheet_import_service.dart:247-262` 的 `_decodeXlsxRows` 亦无上限。
  唯一保留：文中「10MB xlsx 可解压 10GB」是 zip 炸弹的教科书级膨胀比，非本仓实测。
- **#3 结论成立，但「后续所有重试都不触发」机制说反了。** `storage_service.dart:123-131` 的 `init()`
  在 catch 里把 `_initFuture` 置 `null` 后 rethrow，所以**重试会再次执行 `_doInit`**，
  只是又撞上同一条从未被清除的坏记录（`:305-307` 的抛错发生在任何清理之前，
  而 `_prefs` 已在 `:134` 赋值）。**「必须清应用数据才能恢复」的结论仍成立**，理由是记录永不被清。
- **#4 成立，且比原文更广**：`:440-447` 除凭据外还清掉自定义导入地址前缀、记忆登录、最近学校、
  自定义调试记录；`app_sync_snapshot_service.dart:404-408` 把缺失的 `warehouse` 变成空 bundle
  即**全量清空却报成功**。第三路径（keystore 单条抛异常）经 `:698-716` 的内存回滚兜底，
  仅当回滚本身也失败才永久丢。另有一处原文漏掉的缺陷：
  `WarehouseRememberedLoginEntry.toJson:147-152` **漏写 `host`**，配合 `importSyncBundle:469`
  写回空 host，会把凭据自动填充降级为放行任意 host。
- **#5 成立，但「打死整个教务页」应收紧为「卡死自定义调试记录子页」**：
  `course_import_screen.dart:2334` 在 `initState` 调用、`:2337-2344` 无 try/catch，
  导致 `_isLoading` 永不清除。「WebDAV 上传整体失败」为真（`webdav_sync_service.dart:262` 经
  `collectSnapshot`）。原文「三个上游全裸 await」不准：直接 UI 调用方只有一处。
- **#6 成立，且比原文更严重**：不是「8 次以上」而是 **11 次无条件落盘**
  （含 `importFullAppDataBackup` 内部 6 次、`importAllMacros` 3 次），回滚仅内存
  （`:237`），重启后 `:862-865` 返回 false——均经复核确认。

**建议顺序**：3 → 4 → 5（同一文件，一起改成本最低）→ 1 → 2 → 6

### 2.2 会被攻击（6 条）

| # | 问题 | 位置 | 一句话 |
|---|---|---|---|
| 7 | **网页里的任意脚本能弹出 App 原生输入框钓密码** 🔴最高 | `course_import_screen.dart:3752-3761`、`:4889-4998`、`:5035-5086` | `prompt`/`confirm`/`singleSelection`/`toast` **无来源门禁**，只有 3 种消息被特权门禁挡住。用户看到的是**本 App 的原生对话框**（不是网页样式，极具可信度），输入的学号密码直送攻击者。CVSS 思路约 8.0 |
| 8 | **远程教务脚本在无哈希时跳过校验**（7 的放大器） | `warehouse_repository_service.dart:153-168` | `:157` 注释明说 "no verification"。默认源是**第三方镜像**。脚本继承 `QingyuBridge` 全部权限 → 把"需要中间人一次"变成"投毒一次批量命中"。**fail-open，与更新通道的 fail-closed 恰好相反** |
| 9 | **精确位置发往境外第三方，隐私政策未披露** 🔴已上线违规 | `weather_service.dart:40-41`、`:125-144` | 全精度经纬度 → `api.bigdatacloud.net`（美国公司）。政策只说"默认保存在设备本地"。违反 PIPL 第 29/38 条，是**应用商店合规检查最容易命中**的一条 |
| 10 | **局域网 HTTP 服务无读超时无连接数上限** | `lan_edit_server_service.dart:75`、`lan_edit_api_handlers.dart:893-906`、`:201` | 任意同网段设备**不需要 token 就能挂住服务**。`/auth/verify` 在鉴权**之前**读 body，是最便宜的靶子 |
| 11 | **局域网服务绑所有网卡 + 6 位 PIN 当唯一门槛** | `lan_edit_server_service.dart:75`、`lan_edit_session.dart:32-42` | `bind(anyIPv4)` 监听所有网卡（含蜂窝/VPN/热点）。二维码里只带 PIN 而**代码已预留 token 参数却从没用过**。⚠️ 严重度取决于威胁模型，见 §5 分歧说明 |
| 12 | **不校验 Origin，忽略 Content-Type** | `lan_edit_api_handlers.dart:26-29`、`:879-889` | 用户在同一 Wi-Fi 上逛的**任意网页**都能打到这个 API，把机主的 5 次尝试烧光、锁死编辑页 5 分钟，可无限重复 |

**修法要点**：7 → 加来源白名单 + 删掉页面可控的原生弹窗类型（这些交互 adapter 脚本自己在页面里用 DOM 做即可）；8 → 改 fail-closed（`declared.isEmpty` 时抛错）；9 → 隐私政策补披露 + 独立同意开关，或改用境内反查服务（最低成本是加披露和开关）；10–12 → `idleTimeout` + body `.timeout` + 16 并发信号量；二维码改带 token；绑具体局域网 IP；加 Origin 校验 + 强制 `Content-Type: application/json`。

**🔍 复核（逐条见 §8.7）**

- **#7 机制成立，但「钓密码」框架过头，且原文低估了暴露面。** 三处行号全对；门禁只有
  `_isExecutingImport/_isMacroReplay` 这类**应用自身状态**、**不是来源校验**，对恶意页面零保护；
  全文无 `onNavigationRequest`/`shouldOverrideUrlLoading`，地址栏可加载任意 host，跨源 iframe 同样拿得到
  `QingyuBridge`。**过头处**：`course_import_screen.dart:5075` 输入框硬编码 `TextInputType.number`
  且**无 `obscureText`**，准确描述是「数字与验证码外泄 + 攻击者可控文案的社工」，而非钓密码。
  **低估处**：原始 `QingyuBridge.postMessage` 在 WebView 整个生命周期可用，**无需先执行导入脚本**，
  且 `:5226` 会重建 `__qingyuResolvers`，所以无需任何 shim 即可回传——比原文描述的更易利用。
- **#8 前半成立，「默认源是第三方镜像」为假。** `:157` 注释确为 "no verification"，
  `:158-159` 确在 `declared.isNotEmpty` 才校验（fail-open），脚本确继承全部桥权限。
  **但默认源是第一方** `Mutx163/qingyu_warehouse`（`warehouse_repository_models.dart:16-21`、`:38`、
  `:123-130`，即 `raw.githubusercontent.com/Mutx163/...`）；`ghfast.top` 只是主地址失败后的备选，
  且 `warehouse_repository_service.dart:208-211` 注释明确「优先主地址以免被投毒镜像抢跑」。
  原文漏掉的两点反而**加重**该条：哈希只覆盖脚本文件、**索引本身未校验**；
  且 assets 内未随包附带 `adapters.yaml`，有无 sha256 完全取决于远端索引。
- **#9「无条件发送」为假，「未披露」为真，且原文低估了范围。** 全精度经纬度与
  `api.bigdatacloud.net` 均为真；但需**用户显式操作**（`settings_weather.dart:216-234` 与
  `weather_city_picker_screen.dart:93` 两个入口）**加**系统权限，非后台自动发送。
  「未披露」为真：`docs/privacy.html` 与 `site/content/docs/guide/privacy.mdx` 均未提及定位、天气或境外传输。
  **低估处**：坐标会被持久化（`weather_forecast.dart:75-83` → `weather_preferences.dart:43-46`），
  并在每次天气刷新时再发给**第二个境外主机** `api.open-meteo.com`（`weather_service.dart:35`、`:206-207`），
  即披露缺口覆盖两个主机与重复传输。「违反 PIPL 第 29/38 条」属法律结论，代码无法证实。
- **#10「无读超时」过头。** Dart `HttpServer` **默认就有 120 秒 `idleTimeout`**，
  未配置的是**每请求读超时**；`lan_edit_api_handlers.dart:891-906` 另有 5MB 上限，
  且 `:191-199` 在 `:201` 之前已先返回 429。「不需要 token 就能挂住服务」应收紧为
  「N 路慢速滴灌可占满」。**§3.1 同簇「锁死编辑页 5 分钟」为错**：
  `lan_edit_session.dart:10-11`、`:85-148` 只锁**该来源 IP 的 PIN 尝试次数**且为自动滚动的窗口，
  不锁编辑，其他 IP 的正确 PIN 与已签发 token 不受影响。
- **#11 前两句成立，「6 位 PIN 当唯一门槛」过头。** `lan_edit_server_service.dart:75` 确为
  `HttpServer.bind(InternetAddress.anyIPv4, 0)`（全网卡、无 `idleTimeout` 参数）；
  `lan_edit_session.dart:34` 确为 `100000 + rng.nextInt(900000)` 即 6 位。
  但 `:38` 同时生成了 UUIDv4 token，且 `lan_edit_api_handlers.dart:791-800` 对写请求**强制校验
  bearer token**——PIN 只是**引导期**凭证，token 才是持续门禁。「二维码只带 PIN」本轮未能定位到
  对应构造点，**存疑未判**。
- **#12 前半成立，后半「锁死编辑页 5 分钟、可无限重复」为错。**
  `lan_edit_api_handlers.dart` 全文**无任何 `Origin` 头校验**，
  也**无请求 `Content-Type` 校验**（`:916` 只是设置响应头），行号 `:26-29`/`:879-889` 无反证。
  但 `lan_edit_session.dart:10-11`、`:85-148` 的限流**只锁该来源 IP 的 PIN 尝试次数**、
  且是自动滚动的 5 分钟窗口，**不锁编辑**：其他 IP 的正确 PIN 与已签发 token 均不受影响，
  因此「烧光机主机会话、锁死编辑页」不成立（能烧的只有该 IP 自己的 PIN 尝试额度）。

### 2.3 会崩（2 条）

| # | 问题 | 位置 | 一句话 |
|---|---|---|---|
| 13 | **一条课程颜色格式不规范 → 整个考试列表页打不开** | `exam_list_screen.dart:685-692` | 全仓唯一手写 `int.parse(hex)`。仓库已有安全实现 `lib/utils/hex_color.dart:3` 被 14+ 处调用，兄弟页也用了，唯独这里漏。颜色来自导入/用户数据，**必现** |
| 14 | **弹窗开合动画每帧把整份菜单重排两遍** | `hyperos_list_popup.dart:576`（驱动它的 builder 在 `:548-551`） | `IntrinsicWidth` 在 `AnimatedBuilder` builder 内部 + 内容树现场构造，300~500ms 每帧双遍布局 + 每帧重建 `TextStyle` → 每帧重新断行。**同仓 `hyperos_select.dart:290-353` 已写对**，照抄即可 |

**🔍 复核（逐条见 §8.7）**

- **#13 成立，行号全对，「14+ 处」偏保守。** 确为全仓**颜色语境下**唯一裸 `int.parse`
  （其余 `int.parse` 都在解析日期时间）；`parseHexColorOrFallback` 实有 **28 处**调用。
  颜色取自 `course.color`（`:526`）而非考试颜色，§0 措辞正确。
  **已修复**（commit `3966e3f0`）：改用 `parseHexColorOrFallback`、兜底色沿用
  `HyperosIconColors.blue`，并补单元 + 真渲染页面的回归测试。实测旧逻辑对 `''`、`'#'`、
  `'#GGGGGG'`、`'rgb(1,2,3)'` 均抛 `FormatException`；`'#FFF'` 不抛但会算错颜色。
- **#14 成立，但动画时长夸大。** `hyperos_list_popup.dart:576` 确为 `IntrinsicWidth`，
  且确在 `:551` 的 `AnimatedBuilder` builder **内部**构造（`:562` 起每帧重建 `panelChild`、
  `:581-585` 每帧重建全部菜单项）；对照 `hyperos_select.dart:290` 的 `popupChild` 是在
  build 里**先建好**再交给动画层，确实「已写对」。**但实际时长是 150–200ms**
  （`_listPopupExitDuration=150ms`、`_submenuRevealDuration=200ms`），不是「300~500ms」。

### 2.4 工具链会毁文件（1 条，含 5 个脚本）

已**在临时副本上实测验证**后果：

| 脚本 | 实测后果 |
|---|---|
| `tool/fix_arb_placeholder_commas.py:8` | 6 个语言文件全变非法 JSON → `gen-l10n` 失败 → **App 编译不过**（实测破坏 202 处） |
| `tool/append_service_msg_arb.py:366-374` | 跑第二遍 → 6 文件各 144 个重复 key；**日/韩/繁体被塞进整块英文文案** |
| `tool/gen_app_log_l10n.dart:169`/`:242` | 抹掉 **388 行**手写代码 → 日志本地化映射清空，用户看到原始英文 key |
| `tool/_build_arb.dart:65` | 整份重写目标语言文件，未翻译的键**直接写中文**；目标文件独有的键被删 |
| `tool/fix_zh_service_msg_arb.py:160-165` | 先删中文译文再从英文回填，硬编码表缺项时**中文静默变英文**（当前跑不丢内容但产生 3441 行 diff） |

**更麻烦的是**：`site/content/docs/dev/contributing.mdx:38-39` 明确告诉贡献者"改文案前先看一眼 tool/ 下有没有现成脚本"——等于把人领到坑前面。

**🔍 复核（见 §8.8）：危险成立，但 4 个在破坏 + 1 个仅潜伏，且几处数字要改。**

- `fix_arb_placeholder_commas.py`：破坏来自 **`:9-10`** 而非 `:8`；「202 处」是**每文件**数，需乘 6。
- `append_service_msg_arb.py:366-374`：无幂等检查为真；`EN_BLOCK` 的 195 个键在 6 个文件中**全已存在**，
  但被塞英文的是 **4 个**文件（ja、ko、zh_TW、zh_HK），不是原文说的 3 个。
- `gen_app_log_l10n.dart:169`/`:242`：抹掉的不是 388 行而是**约 700 行**
  （消息常量 60→2、字段映射 80→72、分类映射 91→67、localizer 的 127 个 `log_` 分支→2）；
  且 `AppLogMessages` 被广泛引用，会直接编译不过。
- `_build_arb.dart:65`：**当前 0 个键处于风险**（ja、ko、zh_TW、zh_HK、zh 均无 `app_zh.arb` 之外的键），
  是**潜伏坑**而非正在发生的破坏。
- `fix_zh_service_msg_arb.py:160-165`：不丢键，但会改 **46 条**文案、其中 **5 条**中文回退成英文
  （`serviceMsgImportRollbackIncomplete`、`serviceMsgUpdateDownloadHashMismatch`、
  `serviceMsgUpdateSha256UnverifiedRefused`、`serviceMsgWarehouseScriptChecksumFailed`、
  `serviceMsgTimetableShareFailed`；`ZH_VALUES` 144 条对 149 键）；diff 为**加 787 减 632 共 1419 行**，
  不是 3441。
- `contributing.mdx:38-39` 的引导**原文确在**，这条为真。

---

## 3. P1 摘要（按领域，不逐条展开）

### 3.1 一致性/正确性

| 问题 | 位置 |
|---|---|
| 2 个写入口漏了并发闸门，能让刚加的课被整体覆盖抹掉（界面还显示在，重启没了） | `timetable_provider.dart:3825`、`:2096-2128` |
| 停课周的课主界面仍打"正在上课"标，超级岛不显示 | `timetable_provider.dart:4348` vs `:4287-4297` |
| provider 手写周次算法，**有夏令时的时区少算一周**（实测美东 2026-03-16 差 1 周）；`_currentWeek` 停 3 而界面显示 4 | `timetable_provider.dart:3994-3997`（该处该用 `WeekCalculator`） |
| 导入解析失败的周次被当成"第 0 周"，撞上开学前 `calendarWeekForDate` 的 0 哨兵 → **开学前超级岛显示不该有的课** | `course.dart:222-227` + `week_calculator.dart:64` |
| 单双周两个标志同时为真 → 课程永久隐身且 UI 改不回来 | `course.dart:489-494`、`:254-255` |
| 课表页的「教学楼数量」统计**对中文教室名完全失效** → 桌面卡与 App 内给两个数字 | `statistics_service.dart:721-723`（正则只认 `^[A-Za-z]+`） |
| 覆盖导入会**悄悄清空用户所有自定义日程**，弹窗只字未提 | `import_export_service.dart:279` |
| 冲突详情页周次区间拼错：输出"第 1 周-10" | `course_conflict_screen.dart:149-152` |
| 日期选择器不跟随应用语言（`DateFormat.Md()` 不传 locale，落到手机系统语言） | `add_exam_screen.dart:744`、`:818`、`:876` |
| 考试日期选择器 → 改配置后周次不重算，预览与实际不一致 | `course_import_screen.dart:1294` vs `:1425` |
| AI 导入的节次/周次**完全无上界**（其余三条链路都有），超出静默填 `00:00` | `ai_course_import_service.dart:236-241`、`:348`、`:362` |
| 导出的 .ics **导不回自己**（导出写 `Sections: 1-2` 英文，导入硬要求中文「第X-Y节」），且失败完全静默 | `ics_export_service.dart:318` vs `ics_import_service.dart:138-143` |
| ICS 导入忽略 TZID；全天事件（`VALUE=DATE`）被整条丢弃 | `ics_import_service.dart:336`、`:86` |
| ICS 的 SUMMARY/LOCATION **从不反转义**，而导出端会转义 → 课程名冒出反斜杠 | `ics_import_service.dart:201` |

> **🔍 复核（见 §8.9）**：上面三条**均成立，但前两条被严重低估**。
> 「导不回自己」实际范围远大于自导自回：`_buildCourseFromEvent`（`ics_import_service.dart:112-149`）
> 返回 `Course?`，**SUMMARY、DESCRIPTION、DTSTART、DTEND 任一缺失、描述为空、或首行无「第X-Y节」，
> 整门课都被静默丢弃**——即 Google / Apple / Outlook 等任何第三方日历文件都基本导不进来，
> 不只是本项目自己导出的 .ics。
> 「从不反转义」需补精确：导出侧 `_escapeText`（`ics_export_service.dart:665-670`）会转义反斜杠、
> 分号、逗号与换行；导入侧 `DESCRIPTION` **确实**做了换行还原（`ics_import_service.dart:129`），
> 但 `SUMMARY`（`:201` 的 `_cleanSummary`）与 `LOCATION`（`:203-205`）不还原——结论成立，仅范围要收窄到这两处。| 非安卓手机上「超级岛」整页设置空转，入口还显示"已启用"（`!Platform.isAndroid` 返回 `true`） | `miui_live_activities_service.dart:79`、`:180` + `home_menu_catalog.dart:315-319` |
| 「用系统下载器」路径把哈希校验 + HTTPS 白名单全绕过 | `about_screen.dart:947-951`、`support_creator_service.dart:293-305` |
| 非安卓自动上传永久硬失败且零可观测性（`getRemoteEtag` 严格字符串比较 + 服务端不支持 LOCK） | `webdav_sync_service.dart:405-409`、`webdav_client_service.dart:267-291` |
| 配置无 CAS 整块覆盖，设置页与同步引擎互相回滚字段 → **自动同步可永久卡死** | `webdav_sync_config.dart:204-210` |
| `deleteBackup` 先删远端文件再改索引，索引 PUT 失败 → 备份永远恢复不了但报"删除失败" | `webdav_sync_service.dart:837-850` |
| 批量删除非原子（每次各拿一次锁、各写一次盘），后台被杀 = 删一半 + 审计零条 | `lan_edit_provider_host.dart:145-155` |
| 两台局域网客户端共用一个 `boundProfileId`，先切课表的把另一个**永久卡死** | `lan_edit_session.dart:19`、`lan_edit_api_handlers.dart:663` |
| `_ensureWriteProfileTarget` 是典型检查-使用竞态 → **写入落进与请求声称不同的课表** | `lan_edit_api_handlers.dart:841-865` vs `:241`/`:298`/`:328` |
| `scope:all_data` + 空 `profiles` 能过守卫但必然落库失败（预览说可以、实际不行） | `lan_edit_provider_host.dart:186-190` vs `import_export_service.dart:347-349` |
| **凭据自动填充对未绑定 host 的旧数据放行到任意页面** | `warehouse_import_preferences_service.dart:546-558` |
| 隐私同意**无法撤回**（全仓只找到写入 `true` 一处，无任何 false 路径） | `storage_service.dart:703`、`main.dart:1129` |
| 折叠标题栏 `headerExtension` **被同时挂载两份**（隐藏量尺 + 实际），含 GlobalKey 即崩 | `hyperos_collapsible_top_app_bar.dart:1411-1412` vs `:1363-1369` |
| 课表页天气 provider 挂在整屏粒度 → 天气一变**整屏重建**（含玻璃采样） | `timetable_screen.dart:6729`（且违反了自家 `timetable_week_preview.dart:63-66` 的契约注释） |
| `retryDispose` 无重试上限 → 最坏情况**每帧整屏重建 1 万行首页、用户无路可退** | `timetable_screen.dart:1719-1754` |
| 滑动删除丢弃 Future（`onDismissed` 是 `VoidCallback`），删失败卡片弹回无提示 | `exam_list_screen.dart:68`、`:87`、`:680` |
| 编辑页删考试不等写盘就返回 → 弹回列表但考试还在，零提示 | `add_exam_screen.dart:973-976` |
| 「首页与导航」恢复默认漏掉菜单形态与菜单内容，确认文案却说会重置 | `settings_reset.dart:143-155` |
| `copyWith` 声明了参数却从不使用 → `copyWith(timetableShowCurrentWeekCourses: false)` 编译通过、静默无效 | `timetable_settings.dart:2659` vs `:2859-3408` |
| APK 下载**全仓唯一没有超时的网络调用**，且无体积上限 | `app_update_service.dart:413-440` |
| **节假日集成测试是死代码**：CI 从不执行 + 断言用的三个中文串在代码里早改过名 | `test_integration/holiday_api_integration_test.dart:24`、`:215-228` |
| 各类 fatal 强转（`as num` / `as String?`）让单行坏数据掀翻整次导入，且把 Dart 异常原文弹给用户 | `course_import_screen.dart:5546`/`:5519`、`warehouse_import_preferences_service.dart:70-75` |
| 表格里 `1e400` 这类单元格 → `UnsupportedError` 被报成"xlsx 解析失败"，误导排查方向 | `spreadsheet_import_service.dart:690-693`/`:707-712` |

### 3.2 性能 / 内存

| 问题 | 位置 |
|---|---|
| 外观编辑转场同帧持有 2~3 份 dpr 密度全屏纹理，峰值 **250MB+ GPU** | `preview_bake_boundary.dart:341-344` + `hyperos_zoom_route.dart:351-353`/`:176` |
| 每块玻璃挂一个**永不停止的每帧** post-frame 回调（首页 ≥5 块 = 每帧 5 次 `localToGlobal`） | `liquid_glass_surface.dart:581-600` |
| 每次玻璃 paint 重复 4~5 次整条祖先链遍历 | `liquid_glass_surface.dart:727`、`:822`、`:789-800` |
| 弹层动画期间每帧整页重绘 + 每采样区一次同步 GPU 回读 | `hyperos_glass_backdrop_host.dart:991-1002`、`:790`、`:828` |
| 冷启动把全量课表反序列化 **4 遍**（每次 `getProfiles()` 都重跑） | `storage_service.dart:906-939`（实际点 `:1347`/`:1482`/`:1604`/`:950`） |
| 每次增删改课程都把全部任务 JSON 编码两遍，且卡在首帧路径 | `timetable_provider.dart:2609`/`:2665`、`:786` |
| 每改一门课整体重写全 app 最大 JSON，且镜像字段在每张课表各存一份 → 成本随课表数线性增长 | `storage_service.dart:973-983` |
| `HyperosListView(children:)` **无虚拟化**，29 个文件走这个模式、只有 9 个用 `itemBuilder` | `hyperos_page.dart:913-922` |
| 桌面统计小组件每次推送重算 4 遍全量统计，去重放在计算之后 | `stats_widget_service.dart:59-77` |
| 冲突检测每次重算，产生上万次临时集合（`normalizedCustomWeeks` 是每次重算的 getter） | `course.dart:460-467` + `course_domain.dart:52-67` |
| 日志每条一次 `flush:true` 同步落盘，裁剪前先全量读文件 | `app_log_service.dart:227`、`:491-505` |
| 诊断日志页以 1Hz 轮询 120KB 日志全文，去重发生在跨进程传输**之后** | `miui_live_activities_service.dart:243-282` |
| 二次竞速从不取消输家，一次检查最多打出 **11 个并发请求** | `async_utils.dart:32-66` |
| 局域网服务全部逻辑跑 UI 线程；`expression` 字段 5MB 无长度限制（可 250 万次迭代） | `lan_edit_api_handlers.dart:757-778`、`transfer_diff_service.dart:426-443` |

> **🔍 复核（见 §8.9）**：本条**实质为真，但第二个文件引错**。`transfer_diff_service.dart:426-443`
> 实为 diff 的 JSON 规范化，**不在表达式解析链路上**。正确位置是
> `lib/domain/week_expression_parser.dart:41-101`：`:41` 一次 `split` 切出约 250 万 token，
> `:62` 每个 token 走一次 `RegExp` 与 `int.parse`；且整条链路**无任何 `Isolate` 或 `compute`，
> 全跑 UI 线程**。| `_foldLine` 每读一个字符分配一个 List | `ics_export_service.dart:684-695` |
| 内置节假日兜底只有 2026 一年，**三个月后（2027）离线会静默按无假期处理** | `holiday_service.dart:235-243` + `assets/holidays/` |
| 4 条导入链路的解析全部跑主线程 | `course_import_screen.dart:708`、`:442`、`:5261`、`:1348` |
| 同步每次上传「整份重传 + 整份回读逐字节比对」→ 带宽翻倍、易撞 30s 超时 | `webdav_sync_service.dart:416-426`、`:478-493` |
| 长图导出峰值 >500MB 且全在 UI isolate | `image_export_capture.dart:136-175`、`:364-381` |

### 3.3 安全 / 隐私（P1 补）

| 问题 | 位置 |
|---|---|
| release 全局放开明文 HTTP，使教务 WebView 可被中间人（是 7 号的**前置条件**） | `network_security_config.xml:28` |
| 局域网编辑用明文 HTTP 传整份课表，token 就在 URL 里（会进浏览器历史/Referer/截图） | `lan_edit_server_service.dart:238-259` |
| 友盟 `preInit` 在用户同意前于进程启动执行（合规灰区） | `UmengApplication.kt:20-24` |
| 未显式声明 `android:allowBackup`，当前靠平台默认值恰好关闭（脆弱） | `AndroidManifest.xml:83-87` |
| 错误详情和完整堆栈原样发给第三方统计 SDK | `umeng_analytics_service.dart:67-98` |
| WebView 未关闭文件访问（理论风险，纯成本为零的纵深防御） | `course_import_screen.dart:3752-3761` |
| Dependabot 未覆盖 Gradle 生态（okhttp/work-runtime 固定版本无 CVE 通道） | `.github/dependabot.yml` |
| 未撤销隐私同意即无法停掉友盟采集 | `storage_service.dart:703` |

### 3.4 工程规范

| 问题 | 位置 / 数字 |
|---|---|
| **17 个文件 / 3,363 行业务代码零测试**，且无覆盖率采集 → 这类缺口无法自动发现 | `ci.yml:95` 无 `--coverage`；缺口含 `lan_edit_api_handlers.dart`(965)、`import_export_logic.dart`(536，11 个公开函数 7 个未测)、`couple_webdav_service.dart`(230)、`home_widget_service.dart`(292) |

> **🔍 复核（见 §8.10）：`import_export_logic.dart` 须从「零测试」清单移除——原文此格自相矛盾。**
> 该文件有**专门的测试** `test/.../import_dedup_test.dart`（经 `lib/providers/timetable_provider.dart:68`
> 的 `export '../domain/import_export_logic.dart'` re-export 引入），其中
> `dedupeImportedCourses`、`mergeImportedCourseWithExisting`、
> `replaceImportedCoursesPreservingLocalFields` 均被测试引用，因此它不是「零测试」文件。
> 原文括注「11 个公开函数 7 个未测」也对不上：实测顶层公开函数为 **7 个**
> （`buildImportedCourseDedupKey`、`dedupeImportedCourses`、`mergeImportedCourseWithExisting`、
> `preserveImportedCourseLocalFields`、`mergeImportedSharedFieldsIntoExistingSchedule`、
> `replaceImportedCoursesPreservingLocalFields`、`courseListsEqual`），
> 其中 4 个（`buildImportedCourseDedupKey`、`preserveImportedCourseLocalFields`、
> `mergeImportedSharedFieldsIntoExistingSchedule`、`courseListsEqual`）无测试引用。
> **清单里其余 3 个文件确实零直接测试引用，已复核为真**：测试目录对
> `lan_edit_api_handlers`(965 行)、`couple_webdav_service`(230 行)、`home_widget_service`(292 行)
> 的 URI 引用数**均为 0**，且这 3 个行数原文完全正确。
> `ci.yml:95` 确为 `run: flutter test` 且**无 `--coverage`**，为真。| 两条最该开的 lint 被配置注释掉（自述 127+195 处违规），且这两条正是"Future 未处理"的唯一防线 | `analysis_options.yaml:54-59` |
| 50 处「只有注释、零日志」的静默吞异常 | 见报告 §3.1 Top 20 清单 |
| 322 处已知违规零机器检测；`--strict` 只判 error，31 页全 pass，**设置页 16 个文件全在门禁之外** | `analysis_options.yaml` + `ci.yml:84` |
| HyperOS 合规门禁可被一个 JSON 布尔值绕过整页；颜色规则「文件里出现过一次就整文件关闭」 | `hyperos_audit.py:367-369`、`:231-233` |
| 基线文件（74 条中文硬编码豁免）可被人手加行合法化新问题，diff 里看不出 | `cjk_hardcode_baseline.txt` + `audit_cjk_hardcode.py:80-92` |
| 发版无「tag ↔ pubspec 版本一致」关卡，tag 打错会产出文件名与内部版本不符的 APK | `android-build.yml:96-104` |
| 仓库里有个 **UTF-16 编码的 Dart 副本**，`flutter analyze` 对它报 "No issues found!"（静默跳过） | `tool/week_expression_parser_head.dart`（3332 个 NUL 字节） |
| 71 处 ≥500ms 的硬等 `pump()`；7 处 `pumpAndSettle` 带 2~3s 上限（慢 CI 定时炸弹） | 见报告 §2.3 |
| 3 个测试名承诺的行为没有任何断言 | `holiday_service_test.dart:1043-1061`（2 处）、`wallpaper_history_test.dart:253` |
| l10n 生成物入库但无同步校验；一次翻译更新 = 7000 行 diff 无法评审 | `l10n.yaml:5` + `sync_arb.dart:36-48` vs `merge_*.py` |
| 文档与代码不一致（抽查 5 项 3 项错）：UI 库 pin **版本号和 commit 双错**、文件数少 14、受控文件数少 131 | `hyperos-ui-kit.md:16`/`:24`、`WSL_DEVELOPMENT.md:12` |
| `flutter_secure_storage` 凭据读取全在 `try` 之外 → 平台异常直接冒泡 | `webdav_sync_service.dart:253`/`:581`/`:715`/`:812`/`:871` |
| 测试替身 `TestMiuiLiveActivitiesService` 混在 `lib/`（会打进正式包） | `miui_live_activities_service.dart:661` |
| 日期选择器「年/月/日」硬编码中文，6 语言 App 会露出中文单位 | `miuix_date_picker_sheet.dart:337`/`:349`/`:361` |
| 未使用依赖：`animations`、`cupertino_icons` | `pubspec.yaml:49`、`:23` |

---

## 4. 明确「不是问题」的项（避免误伤）

13 个代理都主动做了反向验证，以下经确认**健康，不要动**：

| 项 | 证据 |
|---|---|
| **更新包校验** | 强制 HTTPS + 域名白名单用 `==`/`.endsWith('.')` 而非 `contains`（仿冒域名过不了）+ 摘要与 URL 强制同源 + 无摘要即拒绝安装 + 对落盘文件流式算 SHA-256 + 常量时间比对 + 无降级 + 预发布默认关。**结论：即使 GitHub 和所有镜像全被攻陷，攻击者也装不进恶意包** |
| 17 条平台通道方法名/参数 | 逐一比对 Dart↔Kotlin，**零错配**（同类项目最常见的坑） |
| 调试代码三道闸 | Dart 两道 `kReleaseMode` + 原生包名一道，**正式包一个都进不去**（已追调用链验证） |
| 提交历史 | 2,631 提交零 WIP/fixup/squash，小步中文提交，最近 300 个触及 lib 的提交里 **74% 同时改了测试** |
| 架构棘轮测试 | `test/architecture/dependency_guards_test.dart` 把重构目标做成只许降不许升，行数基线余量正好 0 |
| 资源释放 | 200+ 个 `State` 的 controller/timer/stream/focus 字段与 `dispose()` 对应关系，**零漏项** |
| 列表 key | 全仓零处用序号作 key，不会有列表状态串位 |
| 原子性 | 课表导入全程内存算完只落一次盘，不会"导了 50 行第 50 行炸了留半份" |
| JS 桥注入防护（仓库宏） | `requestId` 逐字符白名单 + `jsonEncode` 而非拼接，且 3 个特权操作有门禁 |
| 传输包解码 | 必填字段在 `fromJson` 之前就查、ID 非空且唯一、**无按名落盘动作 → 无 zip slip 面**、解压跑在可 kill 的 isolate |
| ICS 序列化 | 转义顺序正确、按 UTF-8 字节数折行且逐 rune 不断多字节字符、UID 用内容哈希不泄漏内容 |
| 存储写入原子性 | 全部走 `setString` 平台侧按 key 原子落盘，无「先 truncate 再写」窗口 |
| `toJson`/`fromJson` 对称性 | 脚本比对 180 vs 180 完全对称（3 个写死不读 + 3 个只读不写都有注释） |
| 6 语言本地化 | 应用内 6×3300 key **零缺口**，官网 6×264 key 零缺口，`l10n_untranslated.json` 为空 |
| 设置项生效 | **181 个字段全部有真实消费方**，逐个验证，零「改了没反应」 |
| 入口完整性 | 42 条目录零断链、零孤儿注册、零占位页 |
| 死代码 | 656 个 public class 零引用的只有 6 个（全在同一规格说明文件）；33 个「孤儿文件」逐一核验后**全部证伪**；零注释掉的死代码 |
| 密钥卫生 | 无凭据入库、无硬编码 API key、无 `badCertificateCallback`、密码一律进 Keystore 且云同步显式剥除 |
| CI 纪律 | 全量 action commit pin + 有校验门禁 + `analyze --fatal-infos`（罕见地严格）+ 双 Flutter 版本矩阵 |
| 文档站 | 62 个文件全是源文件、0.7MB，**无构建产物误提交**、无硬编码密钥、lock 文件入库 |
| 注释质量 | 大量注释解释「为什么」而非「做了什么」；多处疑点是靠注释先发现再读代码确认的 |

---

## 5. 代理间的一处分歧（保留，不强行统一）

**局域网 DoS（§2.2 第 10 条）的实际严重度取决于威胁模型**：

- 审查代理 #2 定为 **P0**，理由：公共 Wi-Fi（咖啡厅/校园网，AP 不做客户端隔离）下真实可利用
- 安全代理 #7 评为 **P1**，理由：纯家用 Wi-Fi 下风险很低；且该模块已有 6 位 PIN + 每 IP 5 次/5 分钟限流 + UUIDv4 token + 30 分钟空闲/2 小时硬超时 + 严格 CSP + 静态资源白名单（无目录穿越）

**建议**：按「产品是否支持在公共网络使用」决定。若支持 → 修 Top 3（`idleTimeout` + body `.timeout` + 并发信号量，成本 <30 行，无脑修）。若明确只在受信网络 → 降为 P1 + UI 加一句环境声明。其余 LAN 相关发现（Origin 校验、token 出 URL、多客户端 profile 绑定、批量删除原子性）两种定级下都成立。

---

## 6. 建议的修复顺序

分 5 批，每批可独立验证、独立提交。

### 第 1 批：投入产出比最高的 5 个（约 150 行，1~2 天）
1. `exam_list_screen.dart:685` 换 `parseHexColorOrFallback`（3 行）→ 消掉一个必现崩溃 ✅ **已修复**（commit `3966e3f0`）
2. `hyperos_list_popup.dart:576` 提到 `AnimatedBuilder` 之外（照抄同仓 `hyperos_select.dart:290-353`）→ 消掉最高频弹层的每帧双遍布局
3. 删 5 个已验证会毁文件的 `tool/` 脚本 + 改掉 `contributing.mdx:38-39` 的引导（30 分钟）→ 消掉一整类事故源
4. ~~`LiveUpdateScheduler.kt:2540` 条件写反（单行）→ Android 8–11 恢复精确闹钟~~ 🚫 **已删除：复核为不成立**
5. `network_security_config.xml:16-20` + `about_screen.dart:947` 补白名单校验（<10 行）→ 补上系统下载器路径

> **🔍 复核（见 §8.2、§8.3）**：**第 4 项必须删除。** `LiveUpdateScheduler.kt:2531-2552`
> 不是「条件写反」，而是**正确的降级分支**：`SDK>=S` 且 `canScheduleExactAlarms()` 为真走
> `setExactAndAllowWhileIdle`；否则 `SDK>=M` 走 `setAndAllowWhileIdle`；更低走 `set`。
> 分支顺序正确、无反转、无崩溃（`canScheduleExactAlarms()` 需要 API 31+，已被 `SDK>=S` 短路保护）。
> Android 8–11 上「课前提醒可能迟到」是**为避免精确闹钟权限弹窗而刻意接受的降级取舍**，
> 不是 bug；而**考试提醒**（`ExamReminderScheduler.kt:358-363`）在 Android 6–11 走的是
> `setExactAndAllowWhileIdle`（**精确**），所以「迟到 15–60 分钟」对考试提醒**不成立**。
> 若产品确实要 Android 8–11 上的课前提醒也精确，那是一条**产品决策**（是否申请
> `SCHEDULE_EXACT_ALARM`），不是一行代码的 bug 修复。
>
> 第 5 项**去掉 `network_security_config.xml` 后成立**：`about_screen.dart:947-951` 确证
> 「用系统下载器」路径不传 `expectedApkSha256`，而 else 分支 `:955-956` 传了，
> 故更新包完整性校验在这条路上确实被绕过（这条**为真**，见 §8.3 第 4 条）。

### 第 2 批：数据安全（3~5 天）
- 存储事务日志自愈（§2.1 #3）+ `importSyncBundle` 改「先算后写、最后清残留」（#4）+ `getCustomDebugRecords` 补兜底（#5）—— **同一文件，一起改**
- 导入入口加体积/条数上限（#2）+ `_parseEndWeek` 夹到 30（#1）
- 错误码本地化补齐（`sync_error_localizer.dart`）

### 第 3 批：安全（3~5 天）
- WebView 桥加来源白名单 + 删掉页面可控的原生弹窗类型（§2.2 #7）
- 远程脚本改 fail-closed（#8）
- 隐私政策补披露 + 独立同意开关，或改境内反查（#9）
- 加撤回同意入口（§3.3）

### 第 4 批：一致性收口（1~2 周）
- 抽「某天有效课程」纯函数，四处统一（节假日 + 周次 + 停课）
- 统一「从教室名提取楼栋」（Dart + Kotlin 双端，共享测试向量）
- 给非安卓的 Android 专属功能加平台门控 + 修正假状态
- 抽 `CheckedPrefs` 薄封装，5 个存储服务统一走它
- 补齐 `CheckedPrefs` 之后的 `copyWith` 漏字段与 `setString` 返回值检查

### 第 5 批：工程（持续）
- 覆盖率接进 CI + 「未覆盖文件黑名单棘轮」（照抄现成的 `dependency_guards_test.dart` 范式，约 30 行）
- 两条被注释掉的 lint 改用棘轮模式还债
- 拆 `timetable_screen.dart`（实为 **10,460** 行，非 10,448）：先抽日视图子树（~1600 行，依赖最少），**每拆一块把行数基线往下压一格**

> **🔍 复核（见 §8.10）：「行数基线」指错了文件。** `test/architecture/dependency_guards_test.dart:71-75`
> 的 `baselineLines = 4647` 对应的是 **`lib/providers/timetable_provider.dart`**（当前 4647 行，
> 余量确为 0），**不是**要拆的 `timetable_screen.dart`。
> 也就是说：拆 `timetable_screen.dart` **不会**推动那道棘轮，拆 `timetable_provider.dart` 才会。
> 若本意是拆 `timetable_screen.dart`，需要**先为它新增一条行数棘轮**再拆。
- 局域网 API 层（965 行零测试）建第一批契约测试

---

## 7. 一句话总评

**这不是一个"写得差"的仓库。** 提交纪律、架构棘轮、注释质量、静态分析严格度、CI 门禁都在同类项目里属优秀水平；导入的原子性、更新包的完整性校验、凭据存储、隐私同意门禁、甚至无障碍与 token 纪律，都有明显高于平均线的处理。

**失分集中在一处：作者把精力投在了"让正常路径正确且优雅"，而"异常路径"和"跨模块一致性"这两件事没有人负责。** 于是出现了同一个问题三个答案（周次、节假日、楼栋）、同一个仓库五套标准（存储、工具链）、同一句话在四处承诺了不存在的东西（注释）。加上 18 条 P0 里绝大多数的共同特征——**用户不会收到任何提示**。

第 1 批 5 个改动约 150 行，能挡掉全部 18 条 P0 中的 5 条最刺眼的，且互不耦合。建议先做这批。

> **🔍 复核后修正**：第 1 批实际只有 **4 项**成立——第 4 项（`LiveUpdateScheduler.kt` 条件写反）
> 已复核为不成立并删除（§8.2），第 5 项去掉 `network_security_config.xml` 后成立（§8.3）。
> 第 1 项已于 commit `3966e3f0` 落地。

---

## 8. 复核结果

> 本节是 2026-09-26 在原报告之后的**独立复核**，方法是逐条打开被引用的代码位置、对照行号、
> 读调用链与反例，再对可计算的数字实算。**原文一字未删**，但请以本节为准。
>
> **给后续维护者的一句话**：原报告的**行号与代码位置引用几乎全对，可以继续当地图用**；
> 但**部分「为什么会坏」的机制诊断是错的**，照原文去查会走错方向。下面标 🔴 的六条是硬错误。

### 8.1 结论总览

| 类别 | 条数 | 含义 |
|---|---|---|
| ✅ 成立 | 多数 | 结论与机制均经复核成立，可直接照原文动手 |
| 🟡 结论对、机制说错 | 4 | 现象真实，但原文给的因果链是错的，别按它去修 |
| 🟠 夸大 | 5 | 结论对但说法过头，按原文的严重度排期会浪费工时 |
| 🔴 不成立 | 6 | 结论或诊断为假，其中 1 条已被当作「单行修复」排进第 1 批 |
| ⚪ 存疑未判 | 1 | 本轮未定位到对应构造点 |

### 8.2 🔴 硬错误 1：闹钟「条件写反」不成立（影响 §0 第 9 行、§1.1 首行、§6 第 1 批第 4 项）

| 项 | 内容 |
|---|---|
| 原文 | 「课前/考试提醒迟到 15–60 分钟」，`LiveUpdateScheduler.kt:2540-2545`「条件写反」；建议「单行修复」 |
| 实测 | `LiveUpdateScheduler.kt:2531-2552` 是**正确的降级分支**：`SDK>=S && canScheduleExactAlarms()` → `setExactAndAllowWhileIdle`；否则 `SDK>=M` → `setAndAllowWhileIdle`；更低 → `set`。顺序正确、**无反转**、无崩溃（`canScheduleExactAlarms()` 需 API 31+，已被 `SDK>=S` 短路保护） |
| 考试提醒 | `ExamReminderScheduler.kt:358-363` 在 Android 6–11 走的是 **`setExactAndAllowWhileIdle`（精确）**，所以「迟到」对考试提醒**根本不成立** |
| 判定 | 🔴 **不成立**。Android 8–11 上课前提醒可能迟到，是**为避免 `SCHEDULE_EXACT_ALARM` 权限弹窗而刻意接受的降级取舍**，属产品决策，不是 bug |
| 处置 | §6 第 1 批第 4 项已删除并划掉 |

### 8.3 🟡 §1.4「注释承诺了不存在的东西」整节：4 条中 3.5 条不成立

原文称此节由「4 个代理各自独立发现」并列为四大系统性问题之一。**逐条复核后该标题不成立，请勿把本节当根因。**

| # | 原文指控 | 复核结论 |
|---|---|---|
| 1 | `webdav_sync_service.dart:370-371` 承诺的回收逻辑不存在，云盘无限膨胀 | 🔴 **不成立**。回收逻辑**存在**：`:1100-1106` 调 `_backupIndexService.prune`，`:1108-1113` 逐个 `deleteRemoteFile`；上限见 `webdav_sync_config.dart:18-19`（`defaultMaxBackupCount=15`、`defaultMaxBackupAgeDays=30`）；快照写在固定路径（`webdav_sync_config.dart:63`），不会膨胀 |
| 2 | `docs/RELEASE.md:593` 称 CI 与 `verify_release_pubspec.sh` 会拦截 | 🟡 **部分成立**。「无 pre-commit hook、未接进任何 workflow」为真（无 `.githooks`、无 `core.hooksPath`，只有 Qoder 遥测的 post-commit/post-checkout）。但原文「**版本格式那一半是假的**」为**假**：`:31` 的正则与 `:50-61` 的预发布/正式模式检查**都真会 exit 1**。**真实缺陷另有两点**：脚本 `:2` 自称 Pre-commit guard 却无人安装；其正则只接受**三段**版本，而 `docs/RELEASE.md:606` 记录的是**四段**（`v1.1.10.7`） |
| 3 | `network_security_config.xml:16-20` 说 DownloadManager 受管辖 | 🔴 **不成立**。注释针对的是「**镜像下载**」（走 `dart:io`，不受 `NetworkSecurityConfig` 约束）；而 `DownloadManager` 那条路是**安装包更新**（`MainActivity.kt:1587-1621`，经 `appUpdateUseSystemDownloader` 偏好，`about_screen.dart:632-636`、`:947-951`），**不是镜像下载**，不构成矛盾 |
| 4 | `scripts/sync-main.ps1:19-20` 的 `--force-with-lease` 挡不住覆盖别人新提交 | 🔴 **不成立**。脚本**不是裸 `--force-with-lease`**：`:78-80` 先用 `git ls-remote` 读 cnb 当前 tip，`:83` 拼 `--force-with-lease=refs/heads/main:<该 tip>`，`:84` 推送。锁值是**数秒前读到的实时 tip**，比默认写法（信任可能过期的跟踪引用）**更强**。「拒绝覆盖并发推送」与「拒绝覆盖别人的新提交」不是两件事 |

**但第 2 条暴露的真缺陷值得单独立项**：`verify_release_pubspec.sh` 未接入任何流程（三段版本正则 vs
文档四段版本），意味着**发版无「tag ↔ pubspec 版本一致」关卡**——这条对应 §3.4 的
`android-build.yml:96-104`，仍然成立。

### 8.4 🟡 硬错误 2：`AppLogService` 根因引错行号（结论仍成立）

| 项 | 内容 |
|---|---|
| 原文 | 「`AppLogService` 在 release 包默认不落盘（`app_log_service.dart:414-419`）」 |
| 实测 | `app_log_service.dart:414-419` 是 `_shouldRecord`，**只判** `_privacyAccepted` 与 `_loggingEnabled`；该文件**不含任何** `kReleaseMode`/`kDebugMode` 引用。真实机制在 **`lib/logging/app_debug_log.dart:4-11`**：非 `kDebugMode` 且标签不在 `forensicTags`（**仅** `LocationTimeApply`、`LocationTimeApplyUI`）白名单内即 `return` |
| 判定 | 🟡 **结论对、引用错**。修法建议（提醒链路补日志）依然正确，但补日志时必须注意：**只有白名单那两个标签才留痕**，新增标签要同步进 `forensicTags` |
| 连带确认 | ✅ 由此**确认 §1.1 第 3 行为真**：`exam_reminder_service.dart:385` 用的标签是 `ExamReminder`，**不在白名单**，release 下这条日志被直接丢弃——「线上零日志痕迹」属实 |

### 8.5 🟡 硬错误 3：存储「5 个服务全部无坏数据兜底」为假

| 项 | 内容 |
|---|---|
| 原文 | 「5 个服务**全部**丢弃 `setString` 返回值、**全部**无坏数据兜底」 |
| 实测 | 前半句**为真**。后半句**为假**：`WallpaperHistoryService:142-152`（try/catch 回退 `const []`）、`WarehouseMacroService:33-46`/`:68-83`/`:131-143`（try/catch 回退 `null` 或空列表）、`DiagnosticsLogViewerPreferences:11-18`（白名单降级）**都有兜底**；`WarehouseImportPreferences` 也有 `_decodeRememberedLogin:320-339` 的 try/catch |
| 站得住的表述 | **5 个全部忽略写入失败，且没有一个会把坏数据另存备份、或在写失败后 `reload`** |
| 正面确认 | ✅ 报告对 `StorageService` 的描述**全部为真**：`:415-421` 检查 `setString` 返回值否则抛 `StateError`、`:399-413` 失败后 `reload`、`:475-495` 的 `_backupAndRemoveCorruptString` 隔离坏数据、`:1012-1026` 串行写 |

### 8.6 🔴 硬错误 4：远程脚本「默认源是第三方镜像」为假

| 项 | 内容 |
|---|---|
| 原文 | 「默认源是**第三方镜像**」 |
| 实测 | 默认源是**第一方** `Mutx163/qingyu_warehouse`（`warehouse_repository_models.dart:16-21`，`host` 默认 `github` 见 `:38`，URI 构造见 `:123-130`，即 `raw.githubusercontent.com/Mutx163/...`）。`ghfast.top` 只是**主地址失败后的备选**（`warehouse_repository_service.dart:197-205`），且 `:208-211` 注释明确「**优先主地址以免被投毒镜像抢跑**」 |
| 仍然成立 | ✅ `:157` 注释确为 "no verification"；`:158-159` 确在 `declared.isEmpty` 时**跳过校验（fail-open）**；脚本确继承 `QingyuBridge` 全部权限 |
| 原文漏掉（反而加重） | 哈希**只覆盖脚本文件**，**索引本身未校验**；且 assets 内未随包附带 `adapters.yaml`，有无 sha256 完全取决于远端索引 |

### 8.7 🟠 硬错误 5、6：位置「无条件发送」与 ICS 两条低估

见 §2.2 `#9` 与 §3.1 的就地标注。要点：

- **#9**：「无条件」为**假**（需 `settings_weather.dart:216-234` / `weather_city_picker_screen.dart:93`
  两个入口之一 + 系统权限）；「未披露」为**真**。**低估处**：坐标会被持久化
  （`weather_forecast.dart:75-83` → `weather_preferences.dart:43-46`）并在每次天气刷新时
  再发给**第二个境外主机** `api.open-meteo.com`（`weather_service.dart:35`、`:206-207`）。
- **§3.1「导出 .ics 导不回自己」低估**：`_buildCourseFromEvent`（`ics_import_service.dart:112-149`）
  返回 `Course?`，SUMMARY/DESCRIPTION/DTSTART/DTEND 任一缺失、描述为空、或首行无「第X-Y节」，
  **整门课静默丢弃** → 任何第三方日历文件都基本导不进来，不只是自导自回。
- **§3.1「SUMMARY/LOCATION 从不反转义」需收窄**：`DESCRIPTION` **确实**还原了换行
  （`ics_import_service.dart:129`），只有 `SUMMARY`（`:201`）与 `LOCATION`（`:203-205`）没有。
- **§3.1「锁死编辑页 5 分钟」为错**：`lan_edit_session.dart:10-11`、`:85-148` 只锁**该来源 IP 的
  PIN 尝试次数**且为自动滚动窗口，**不锁编辑**，其他 IP 的正确 PIN 与已签发 token 不受影响。
- **§3.2「expression 无长度限制」引错文件**：`transfer_diff_service.dart:426-443` 实为 diff 的
  JSON 规范化，不在表达式链路上；正确位置是 `lib/domain/week_expression_parser.dart:41-101`。

### 8.8 ✅ / 🟠 已核对无误、保留不动的项

以下原文说法经复核**准确**，可直接照用：

| 项 | 证据 |
|---|---|
| §1.1 精确闹钟入口只在桌面小组件页 | `requestScheduleExactAlarm` **全仓唯一调用点**是 `settings_home_widget.dart:593` |
| §1.1 同步错误兜底 | `sync_error_localizer.dart:21` 确为 `_ => l10n.syncErrorSyncFailed`，`:12-19` 已映射 8 个码 |
| §1.2 失败风格 | `home_menu_catalog.dart:423-425` 确为静默 `return` |
| §1.3 统计不知节假日 | `statistics_service.dart:11-18` 的 `calculate` 签名确无节假日参数；`:721-723` 确用只认字母开头的 `RegExp(r'^[A-Za-z]+')` |
| §1.3 楼栋提取夏令时分叉 | `WidgetStatsLogic.kt:104`/`:106` 确用固定 `86_400_000L`，而同文件 `:132-153` 的 `semesterStartMondayMillis` 用 `Calendar` 且自带 DST 说明注释 |
| §1.3 周次少算一周 | `timetable_provider.dart:3994-3997` 确用本地 `DateTime.difference().inDays`（有 DST 少算一周风险），而 `WeekCalculator.getWeekIndex:17-32` 用 `DateTime.utc` 构造规避——原文「该处该用 `WeekCalculator`」**完全正确** |
| §3.1 非安卓假状态 | `miui_live_activities_service.dart:79`、`:180` 确在非安卓返回 `true` |
| §3.4 CI 无覆盖率 | `ci.yml:95` 确为 `run: flutter test`，无 `--coverage` |
| §3.4 两条 lint 被注释 | `analysis_options.yaml:54-59` 确为 `cascade_invocations`（注释自述 127 处）与 `discarded_futures`（自述 195 处） |
| §3.4 UTF-16 副本 | `tool/week_expression_parser_head.dart` 确为 **3,332 个 NUL 字节** |
| §3.4 未使用依赖 | `pubspec.yaml:23` `cupertino_icons`、`:49` `animations` 确未使用 |
| §3.4 HyperOS 门禁可绕过 | `hyperos_audit.py:367-369` 确可用一个 JSON 布尔 `allowLegacy` 绕过整页；`:231-233` 确为「文件里出现过一次 `HyperosColors.`/`HyperosTypography.` 就整文件豁免颜色规则」 |
| §3.1 系统下载器绕过校验 | `about_screen.dart:947-951` 确不传 `expectedApkSha256`，而 else 分支 `:955-956` 传了 |
| 基线零问题 | ✅ 实测出现的 3 个 issue **全部**来自他人未提交的 `test/widgets/glass_dock_drag_route_entry_test.dart` 与 `lib/ui/hyperos/liquid/liquid_glass_surface.dart`；**已提交版本自洽**，原文「零问题」为真 |
| 零测试清单其余 3 项 | `lan_edit_api_handlers`(965 行)、`couple_webdav_service`(230 行)、`home_widget_service`(292 行) 测试目录 URI 引用数**均为 0**，行数原文**完全正确** |

### 8.9 📋 P0 逐条判定表（覆盖原文全部 15 个编号条目）

> **顺带更正一处内部矛盾**：原文写「P0 清单（**18 条**）」，但其小节标题自报为
> §2.1（6 条）+ §2.2（6 条）+ §2.3（2 条）+ §2.4（1 条，含 5 个脚本）= **15 条**。
> 下表覆盖原文**全部 15 个编号条目**（#1–#14 + §2.4 工具链条），逐条有判定。

| # | P0 条目 | 判定 | 关键证据 / 须改正之处 |
|---|---|---|---|
| 1 | 日历文件撑爆内存 | ✅ **成立** | `ics_import_service.dart:362-386`=`_parseEndWeek`；`course.dart:488` 无界循环；`import_export_logic.dart:135`+`:143` `weeks.join(',')`。实算 `UNTIL=99991231`=**416,055** 周（"41 万"准），数字串 **2,385,225** 字符（"2.4MB"准）；`activeWeeks`(`:482`) 确为每次重算的 getter |
| 2 | 导入无体积上限 | ✅ **成立**（本轮新增复核） | `course_import_screen.dart:669-673` 确 `FilePicker(withData: true)`、`:677` 取 bytes、`:689` 直送解析，**中间无体积检查**；`spreadsheet_import_service.dart:247-262` 亦无上限。保留：「10MB→10GB」是教科书膨胀比，非本仓实测 |
| 3 | 30 字节坏记录=永久砖机 | 🟡 **结论对、机制说反** | 「后续所有重试都不触发」**为假**：`storage_service.dart:123-131` 的 `init()` 在 catch 里把 `_initFuture` 置 `null` 后 rethrow，**重试会再次执行** `_doInit`，只是又撞同一条从未清除的坏记录（`:305-307` 抛错在任何清理之前，`_prefs` 已在 `:134` 赋值）。**「必须清应用数据」结论仍成立** |
| 4 | 云恢复先删后写 | ✅ **成立，且更广** | `:440-447` 除凭据外还清自定义导入地址前缀/记忆登录/最近学校/自定义调试记录；`app_sync_snapshot_service.dart:404-408` 把缺失 `warehouse` 变空 bundle = **全量清空却报成功**。第三路径（keystore 抛异常）经 `:698-716` 内存回滚兜底。**原文漏掉**：`WarehouseRememberedLoginEntry.toJson:147-152` 漏写 `host`，配合 `:469` 写回空 host 会把凭据自动填充降级为放行任意 host |
| 5 | 一条坏记录打死教务页+云同步 | 🟡 **成立，但范围要收紧** | `:362` `jsonDecode` 无 try 确凿；`course_import_screen.dart:2334` 在 `initState`、`:2337-2344` 无 try 致 `_isLoading` 永不清除**为真**——但卡死的是「**自定义调试记录子页**」，非整个教务页。「WebDAV 上传整体失败」为真（`webdav_sync_service.dart:262`）。「三个上游全裸 await」不准：直接 UI 调用方只有一处 |
| 6 | 快照应用无事务 | ✅ **成立，且更严重** | 不是「8 次以上」而是 **11 次无条件落盘**（含 `importFullAppDataBackup` 内 6 次、`importAllMacros` 3 次）；回滚仅内存（`:237`）；重启后 `:862-865` 返回 false。均已复核确认 |
| 7 | 网页脚本弹原生输入框 | 🟠 **机制成立，框架过头且低估暴露面** | 门禁只判应用自身状态、**非来源校验**；无 `onNavigationRequest`；跨源 iframe 同样可得桥。**过头**：`:5075` 硬编码 `TextInputType.number` 且**无 `obscureText`** → 是数字/验证码外泄与社工，非钓密码。**低估**：原始 `postMessage` 全生命周期可用、**无需先执行导入脚本**，`:5226` 会重建 `__qingyuResolvers` |
| 8 | 远程脚本无哈希即跳过校验 | 🟡 **前半成立，「第三方镜像」为假** | 见 §8.6。fail-open 与索引未校验**加重**该条 |
| 9 | 精确位置发往境外 | 🟡 **「无条件」为假，「未披露」为真，且低估** | 见 §8.7。需用户操作 + 系统权限；坐标持久化并再发第二个境外主机 |
| 10 | 局域网无超时无连接上限 | 🟠 **「无读超时」过头** | Dart `HttpServer` **默认就有 120 秒 `idleTimeout`**，未配的是**每请求读超时**；`lan_edit_api_handlers.dart:891-906` 另有 5MB 上限、`:191-199` 已先返 429。应收紧为「N 路慢速滴灌可占满」 |
| 11 | 绑所有网卡 + 6 位 PIN | 🟠 **前两句真，「唯一门槛」过头** | `:75` 确 `bind(anyIPv4, 0)`；`lan_edit_session.dart:34` 确 6 位。但 `:38` 同时生成 UUIDv4 token 且 `:791-800` 对写请求**强制校验 bearer token**——PIN 只是引导期凭证。「二维码只带 PIN」⚪ **本轮未定位到构造点，存疑未判** |
| 12 | 不校验 Origin、忽略 Content-Type | 🟡 **前半成立，后半为错** | 全文**无 `Origin` 校验**、**无请求 `Content-Type` 校验**（`:916` 只设响应头）为真。但「锁死编辑页 5 分钟」**为错**：只锁该 IP 的 PIN 尝试额度且自动滚动，其他 IP 与已签发 token 不受影响 |
| 13 | 课程颜色崩考试列表页 | ✅ **成立，已修复** | 行号全对；全仓颜色语境下唯一裸 `int.parse`；`parseHexColorOrFallback` 实有 **28 处**调用（原文「14+」偏保守）。commit `3966e3f0` 已改并补回归测试；实测旧逻辑对 `''`/`'#'`/`'#GGGGGG'`/`'rgb(1,2,3)'` 均抛 `FormatException` |
| 14 | 弹窗每帧双遍布局 | ✅ **成立，时长夸大** | `:576` 确在 `:551` 的 `AnimatedBuilder` builder 内构造；对照 `hyperos_select.dart:290` 确「已写对」。**但实际时长 150–200ms**（`_listPopupExitDuration=150ms`、`_submenuRevealDuration=200ms`），非「300~500ms」 |

**统计**：✅ 成立 9 条（#1、#2、#4、#6、#13、#14 及 §2.4 工具链整条 + §1.1 第 2/6 行 + §1.3 全部）、
🟡 结论对机制错 4 条（#3、#5、#8、#12）、🟠 夸大 4 条（#7、#9、#10、#11）、
⚪ 存疑 1 条（#11 的二维码子项）。**没有一条需要推翻「先修数据安全（§6 第 2 批）」这个优先级。**

### 8.10 📌 数字更正汇总

| 位置 | 原文 | 实测 |
|---|---|---|
| §2 标题 | 「P0 清单（**18 条**）」 | 小节自报 6+6+2+1 = **15 条**，原文内部矛盾；本节已按 15 条逐条判定 |
| 开头统计 | `lib/` 163,876 行 | **无对应口径**。共 375 文件 / 252,515 行，其中生成物 `app_localizations*` 占 87,501 行；**排除生成物为 165,025 行**（原文混用了「全部文件数」与「排除生成物的行数」） |
| 开头统计 | `test/` 298 文件 / 79,266 行 / 2,650 用例 | **297 文件 / 78,979 行 / 2,637 个声明** |
| 开头统计 | 2,631 提交 | **2,633** |
| §3.4 / §6 | `timetable_screen.dart` 10,448 行 | **10,460 行** |
| §6 第 5 批 | 「每拆一块把行数基线往下压一格」 | **指错文件**：`dependency_guards_test.dart:71-75` 的 `baselineLines=4647` 对应 `lib/providers/timetable_provider.dart`（当前 4647 行、余量 0），**不是**要拆的 `timetable_screen.dart` |
| §2.4 | `fix_arb_placeholder_commas.py:8` / 「202 处」 | 破坏来自 **`:9-10`**；「202 处」是**每文件**数，需乘 6 |
| §2.4 | `append_service_msg_arb.py` 「日/韩/繁体」3 个文件 | 被塞英文的是 **4 个**（ja、ko、zh_TW、zh_HK）；`EN_BLOCK` 195 个键在 6 文件中全已存在 |
| §2.4 | `gen_app_log_l10n.dart` 抹掉 388 行 | **约 700 行**（消息常量 60→2、字段映射 80→72、分类映射 91→67、localizer 的 127 个 `log_` 分支→2）；且会直接编译不过 |
| §2.4 | `_build_arb.dart:65` 「正在破坏」 | **当前 0 个键处于风险**，是**潜伏坑** |
| §2.4 | `fix_zh_service_msg_arb.py` 3441 行 diff | **加 787 减 632 共 1419 行**；不丢键，但改 46 条文案、其中 **5 条**中文回退成英文 |
| §3.4 | 零测试清单含 `import_export_logic.dart` | **须移除**：它有专门测试 `import_dedup_test.dart`（经 `timetable_provider.dart:68` re-export）；且「11 个公开函数 7 个未测」对不上（实为 7 个顶层公开函数、4 个无测试引用） |
