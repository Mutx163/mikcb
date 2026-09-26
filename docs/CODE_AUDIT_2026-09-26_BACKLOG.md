# 待处理问题清单 · 2026-09-26

> 配套 `CODE_AUDIT_2026-09-26.md`。那份报告已加第 8 章复核结论；本文件把**仍需动手的条目**
> 按「是否已被独立复核」重新分层，供排期与分派。
>
> **分层依据**：
> - ✅ **已复核** = 有人打开被引用的代码位置、对照行号、读调用链或实算后确认为真
> - ⚠️ **未复核** = 仍是原报告（13 个并行代理）的一面之词，行号可能对、机制可能错，**动手前先核实**
>
> 复核过程中已确认**不成立**的条目不在本文件，见原报告 §8.2、§8.3、§8.6。

---

## 一、已修（2 条）

| 条目 | 提交 | 覆盖测试 |
|---|---|---|
| 课程颜色格式不规范 → 整个考试列表页打不开 | `3966e3f0` | `test/utils/hex_color_test.dart`（5）+ `test/screens/exam_list_malformed_color_test.dart`（6） |
| 日历文件 `RRULE:UNTIL` 失控 → 导入途中耗尽内存 | `f884a87c` | `test/services/ics_import_service_test.dart`（8，含 1 条新增回归） |

第一条修法：删掉 `exam_list_screen.dart` 手写的 `int.parse(hex, radix: 16)`，改调仓库已有的
`parseHexColorOrFallback`。实测旧逻辑对 `''`/`'#'`/`'#GGGGGG'`/`'rgb(1,2,3)'` 均抛 `FormatException`。

第二条修法：ICS 是四条导入链路里唯一没加周次护栏的，补上 `Course.normalizeWeeks`（钳到 1..30），
与存储读取路径已有的钳制对齐。回归测试实测非空转——移除护栏后断言报 `Actual: <416055>`。

---

## 二、A 级：已复核为真、尚未修（建议优先）

### A1. 会永久丢数据 / 让人只能用「清除应用数据」恢复（4 条）

| # | 问题 | 位置 | 复核要点 |
|---|---|---|---|
| 1 | **一个日历文件能在导入途中耗尽内存** ✅ 已修 `f884a87c` | `ics_import_service.dart:189-192` → `course.dart:488` → `import_export_logic.dart:135`,`:143` | 实算 `UNTIL=99991231` = **416,055 周**（回归测试实测值一致）；`activeWeeks` 是不带缓存的 getter，会真的造出 41 万元素 List；去重时 `weeks.join(',')` 拼出 **2,385,225 字符 ≈ 2.4MB**／门课。**严重度已下修**：原文称「已落盘、之后每次开课表都在踩、只能清数据恢复」**不成立**——读取路径 `Course.fromJsonString` → `fromJson` → `normalizeWeeks` 本就钳到 1..30，重启即自愈，损害仅限导入那一刻 |
| 3 | **坏事务记录 = 永久砖机** | `storage_service.dart:282-317`,`:337-339`,`:134` | `:305-307` 抛错发生在任何清理之前，坏记录永远留在盘上，每次保存设置都报错。**注意**：原文「后续重试都不触发」**说反了**——`:128` 会把 `_initFuture` 置 null，重试**会**再跑，只是又撞同一条坏记录 |
| 4 | **云恢复先删后写，缺字段即永久丢** | `warehouse_import_preferences_service.dart:436-488` | 无 journal，`:477`/`:480` 空值不回写。**比原报告更广**：`:440-447` 还清掉自定义导入地址前缀、记忆登录、最近学校、自定义调试记录；`app_sync_snapshot_service.dart:404-408` 把缺失的 `warehouse` 变空 bundle = **全量清空却报成功** |
| 6 | **快照应用无事务，杀进程 = 永久半应用且无法撤销** | `app_sync_snapshot_service.dart:900-968` | 不是「8 次以上」而是 **11 次**无条件落盘；回滚**只在内存**（`:237`，`transfer_undo_service.dart:30-32` 自述）；重启后 `:862-865` 返回 false。回滚本身又是 ~20 次写，也可能失败 |

**另一条原文漏掉的、同属数据安全**：

| # | 问题 | 位置 | 复核要点 |
|---|---|---|---|
| 4b | **凭据的 host 绑定在云同步中丢失** | `WarehouseRememberedLoginEntry.toJson:147-152` 漏写 `host`；`importSyncBundle:469` 写回空 `host` | 结果 `rememberedLoginAllowsUrl:553-555` 降级为**放行任意 host**。现有测试 `warehouse_import_preferences_service_test.dart:212`/`:283` 只验内存对象，所以照样通过——**测试盲区** |

### A2. 会被攻击（5 条）

| # | 问题 | 位置 | 复核要点 |
|---|---|---|---|
| 7 | **教务网页里的任意脚本能弹出本 App 的原生输入框** | `course_import_screen.dart:3752-3761`,`:4889-4998`,`:5035-5086` | 通道注册**零来源校验**；只有 3 种消息有门禁，而门禁判的是**应用自身状态**、不是来源；无 `onNavigationRequest`；地址栏可加载任意 host；跨源 iframe 同样拿得到桥。**比原报告更糟**：原始 `postMessage` 全生命周期可用、无需先跑导入脚本，`:5226` 会重建 `__qingyuResolvers` 供回传。**但「钓密码」框架过头**：`:5075` 硬编码数字键盘且无 `obscureText`，实为数字/验证码外泄 + 社工 |
| 8 | **远程教务脚本在无哈希时跳过校验（fail-open）** | `warehouse_repository_service.dart:157-159` | `:157` 注释原文即 "no verification"；`declared.isEmpty` 即整段跳过。**原报告说「默认源是第三方镜像」是错的**——默认是第一方 `Mutx163/qingyu_warehouse`（GitHub）。**但比原报告更糟**：哈希只覆盖脚本文件，**索引本身未校验**，能投毒索引就能一起换掉哈希 |
| 9 | **精确位置发往境外第三方，隐私政策未披露** | `weather_service.dart:40-41`,`:129-135` | 原始经纬度无取整。**「无条件发送」是错的**——需用户主动操作 + 系统权限。**但比原报告更广**：坐标会**持久化**（`weather_forecast.dart:75-83` → `weather_preferences.dart:43-46`）并每次天气刷新再发给**第二个**境外主机 `api.open-meteo.com`（`:35`,`:206-207`）。`docs/privacy.html` 与 `site/.../privacy.mdx` 均未提及，应用内只写了友盟 |
| 10 | **局域网服务无每请求读超时、无连接数上限** | `lan_edit_server_service.dart:75`；`lan_edit_api_handlers.dart:899`,`:891-906` | `bind(anyIPv4, 0)` 未设 `idleTimeout:`；全仓无信号量／并发上限；`:899` 读 body 无 `.timeout()`。**「无读超时」过头**：Dart 默认有 120 秒 idleTimeout，且 `:191-199` 先返 429、body 有 5MB 上限 |
| 12 | **不校验 Origin、忽略 Content-Type** | `lan_edit_api_handlers.dart:26-29`,`:879-889` | 10 个 `lan_edit*` 文件里**无任何** `Origin` 校验；`OPTIONS` 只回裸 204 无 CORS 头；读 body 从不看 `contentType`。**「锁死编辑页 5 分钟」是错的**：只锁该 IP 的 PIN 尝试额度、且自动滚动 |

**同簇另一条**：

| # | 问题 | 位置 | 复核要点 |
|---|---|---|---|
| 11 | **绑所有网卡 + 二维码里没有令牌** | `lan_edit_server_service.dart:75`;`lan_edit_screen.dart:109` | `anyIPv4` 含蜂窝／VPN／热点；PIN 恰好 6 位（`lan_edit_session.dart:33-34`）。**「PIN 是唯一门槛」过头**：`:38` 生成 UUIDv4 token、`:791-800` 对写请求强制校验 bearer token，PIN 只是引导期凭证。**二维码确实只带 PIN**：`encodeLanEditUrl`(`:238-259`) 预留了 `token` 且 `:246-248` 会写入，但唯一调用方 `lan_edit_screen.dart:109` 只传 `host/port/pin` |

### A3. 会崩（1 条）

| # | 问题 | 位置 | 复核要点 |
|---|---|---|---|
| 14 | **弹窗开合动画每帧把整份菜单重排两遍** | `hyperos_list_popup.dart:576`（在 `:548-551` 的 `AnimatedBuilder` builder 内） | `IntrinsicWidth` 与整棵内容树都在动画 builder 里现场构造。**同仓正确写法**：`hyperos_select.dart:290` 先把子树算好存成局部变量。**原报告时长夸大**：实际 150–200ms（`_listPopupExitDuration=150`/`_submenuRevealDuration=200`），非 300–500ms |

### A4. 会静默丢数据 / 导出导入不对称（4 条）

| # | 问题 | 位置 | 复核要点 |
|---|---|---|---|
| 2 | **导入无体积上限** | `course_import_screen.dart:669-673`,`:677`,`:689`;`spreadsheet_import_service.dart:247-262` | `FilePicker(withData: true)` 整文件进内存，`:689` 直送解析，**中间无任何体积检查**。Android 上 OOM 是进程被杀，try/catch 救不回来。**注**：原文「10MB→10GB」是教科书膨胀比，**非本仓实测** |
| 5 | **一条坏记录同时打死调试记录页和云同步** | `warehouse_import_preferences_service.dart:362`;`course_import_screen.dart:2334`,`:2337-2344` | `jsonDecode` 无 try/catch；`initState` 里调用且无 try → `_isLoading` 永不清除。**范围要收紧**：卡死的是「自定义调试记录」**子页**，不是整个教务页。`webdav_sync_service.dart:262` 使整体上传失败 |
| 20 | **第三方日历文件基本导不进来**（原报告只说「自己的导不回」） | `ics_import_service.dart:112-149` | `_buildCourseFromEvent` 返回 `Course?`：SUMMARY／DESCRIPTION／DTSTART／DTEND 任一缺失、描述为空、或**首行不含中文「第X-Y节」**（`:139`），整门课**静默丢弃**。Google／Apple／Outlook 均不写中文节次 |
| 21 | **ICS 的 SUMMARY/LOCATION 从不反转义** | 导出 `_escapeText` `ics_export_service.dart:665-670`；导入 `:201`,`:203-205` | 导出转义 `\ ; ,` 与换行；导入侧 DESCRIPTION 确实还原了 `\n`（`:129`），但 SUMMARY／LOCATION 没有 → 课程名冒出反斜杠 |

### A5. 一致性分歧（4 条，均已复核为真）

| # | 问题 | 位置 |
|---|---|---|
| 23 | **周次算法有夏令时时区少算一周** | `timetable_provider.dart:3994-3997` 用本地 `DateTime.difference().inDays`；`WeekCalculator.getWeekIndex:17-32` 用 `DateTime.utc` 构造规避。原文「该处该用 WeekCalculator」**完全正确** |
| 24 | **「从教室名提取楼栋」只认字母开头** | `statistics_service.dart:721-723` 的 `RegExp(r'^[A-Za-z]+')`；`WidgetStatsLogic.kt:104`/`:106` 固定 `86_400_000L`（DST 下每天不恒等 24h），而同文件 `:132-153` 用 `Calendar` 并自带 DST 说明注释 |
| 25 | **统计服务完全不知道有节假日** | `statistics_service.dart:11-18` 的 `calculate` 签名里没有节假日参数 |
| 26 | **正式包丢弃绝大多数日志** | `lib/logging/app_debug_log.dart:4-11`：非 `kDebugMode` 且标签不在 `forensicTags`（**仅** `LocationTimeApply`/`LocationTimeApplyUI`）白名单内即 `return`。**这是下面多条「静默失效」的共同放大器** |

### A6. 已复核的合规 / 隐私（4 条）

| # | 问题 | 位置 | 复核要点 |
|---|---|---|---|
| 17 | **「用系统下载器」把 APK 哈希校验全绕过** | `about_screen.dart:947-951` | 该分支**不传** `expectedApkSha256`，而 else 分支 `:955-956` 传了 |
| 16 | **隐私同意无法撤回** | `storage_service.dart:703`；`main.dart:1129` | 全仓只找到写入 `true` 的路径，无任何置 false 的入口；撤回不了就连友盟采集也停不掉 |
| 18 | **精确闹钟权限申请入口只在「桌面小组件」页** | `settings_home_widget.dart:593` | `requestScheduleExactAlarm` **全仓唯一调用点**；考试提醒页零提示，用户不知道自己少了一次提醒 |
| 72 | **局域网用明文 HTTP 传整份课表，且令牌在 URL 里** | `lan_edit_server_service.dart:238-259` | URL 会进浏览器历史／Referer／截图 |

### A7. 工具链会毁文件（4 个在毁 + 1 个潜伏）

`site/content/docs/dev/contributing.mdx:38-39` 原文引导贡献者「改文案前先看一眼 tool/ 下有没有现成脚本」——等于把人领到坑前面。

| 脚本 | 实测后果 |
|---|---|
| `tool/fix_arb_placeholder_commas.py:9-10` | 6 个语言文件全变非法 JSON → `gen-l10n` 失败 → **App 编译不过**。原文行号 `:8` 错 |
| `tool/gen_app_log_l10n.dart:169`,`:242` | 抹掉**约 700 行**（原文说 388）：消息常量 60→2、字段映射 80→72、分类映射 91→67、localizer 的 127 个 `log_` 分支→2，且 `AppLogMessages.*` 被广泛引用 → **编译不过** |
| `tool/append_service_msg_arb.py:366-374` | 无幂等检查，`EN_BLOCK` 的 195 个键在 6 个文件中**全已存在**；跑第二遍 → 被塞英文的是 **4 个**文件（ja/ko/zh_TW/zh_HK，原文说 3 个） |
| `tool/fix_zh_service_msg_arb.py:160-165` | 不丢键，但改 46 条文案、其中 **5 条中文回退成英文**；diff 是 +787/−632 = 1419 行（原文说 3441） |
| `tool/_build_arb.dart:65` | **当前 0 个键处于风险**，是**潜伏坑**不是正在发生的破坏（原文列为「已验证会毁文件」略重） |

### A8. 零测试缺口（已修正为 16 个文件）

原报告说 17 个文件／3,363 行。**`import_export_logic.dart` 须移除**——它有专门测试
`import_dedup_test.dart`（经 `timetable_provider.dart:68` re-export），原文「11 个公开函数 7 个未测」
也对不上（实为 7 个顶层公开函数、4 个无测试引用）。剩余已核实为零直接测试引用：

| 文件 | 行数 |
|---|---|
| `lib/services/lan_edit_api_handlers.dart` | 965 |
| `lib/services/couple_webdav_service.dart` | 230 |
| `lib/services/home_widget_service.dart` | 292 |

`ci.yml:95` 确为 `run: flutter test`、**无 `--coverage`**，所以这类缺口没有任何自动化能发现。

### A9. 工程门禁漏洞（已复核，4 条）

| 问题 | 位置 | 要害 |
|---|---|---|
| 两条最该开的 lint 被注释掉 | `analysis_options.yaml:54-59` | 注释自述 127 处 + 195 处违规；`discarded_futures` 是「Future 未处理」的**唯一**防线 |
| HyperOS 合规门禁可被一个 JSON 布尔值绕过整页 | `hyperos_audit.py:367-369` | `allowLegacy: true` 即直接返回 `pass`，不做任何扫描 |
| 颜色规则「文件里出现过一次就整文件关闭」 | `hyperos_audit.py:231-233` | 出现一次 `HyperosColors.`/`HyperosTypography.` 即豁免整个文件的硬编码色检查 |
| 仓库里有个 UTF-16 编码的 Dart 副本 | `tool/week_expression_parser_head.dart` | **3,332 个 NUL 字节**；`flutter analyze` 对它报 "No issues found!"（静默跳过） |

另：`verify_release_pubspec.sh` 确实**未接入任何流程**（无 pre-commit hook、无 workflow），
脚本 `:2` 自称 "Pre-commit guard" 却无人安装；其 `:31` 的版本正则只接受**三段**版本，
而 `docs/RELEASE.md:606` 记录的是**四段**（`v1.1.10.7`）——意味着发版没有
「tag ↔ pubspec 版本一致」关卡。

---

## 三、B 级：原报告提出、**尚未独立复核**（约 47 条，动手前先核实）

这些**可能是真问题，但目前只是原报告的一面之词**。本轮复核精力集中在前两章，
第 3 章的 P1 摘要大部分没验。按文件名粗略比对，72 条 P1 中**至多** 39 条碰到第 8 章
提过的文件，据此得出「未复核 ≥ 33 条」——但这个比对**偏高估覆盖率**（第 8 章提到某文件
≠ 验了该文件对应的那一行），逐条清点后未复核项约 **47 条**，即下表所列。

| 分组 | 条数 | 内容概览 |
|---|---|---|
| §3.1 一致性／正确性 | 约 15 | 2 个写入口漏并发闸门；停课周标记两处不一致；单双周同真致课程永久隐身；覆盖导入悄悄清空自定义日程；`copyWith` 声明参数却不使用；`app_update_service.dart:413-440` 是全仓唯一无超时的网络调用；日期选择器不跟随应用语言；冲突页周次区间拼错；AI 导入节次/周次无上界；ICS 忽略 TZID、全天事件被丢；幻灯片日期硬编码中文；`TestMiuiLiveActivitiesService` 混在 `lib/` |
| §3.1 WebDAV / 局域网 | 约 8 | 配置无 CAS 导致自动同步可永久卡死；`deleteBackup` 先删远端再改索引；批量删除非原子；两客户端共用 `boundProfileId` 互相锁死；`_ensureWriteProfileTarget` 检查-使用竞态；`scope:all_data` + 空 `profiles` 必失败；非安卓自动上传永久硬失败 |
| §3.2 性能／内存 | 约 14 | 冷启动反序列化 4 遍；每改一门课重写全 app 最大 JSON；每块玻璃挂永不停止的每帧回调；每帧整页重绘 + 同步 GPU 回读；`HyperosListView(children:)` 无虚拟化（29 文件用 children、9 用 itemBuilder）；二次竞速不取消输家，最多 11 个并发请求；日志每条 `flush:true` 同步落盘；内置节假日兜底只有 2026 一年；4 条导入链路全跑主线程；长图导出峰值 >500MB；`_foldLine` 每字符分配一个 List；外观编辑转场 GPU 峰值 250MB+ |
| §3.3 安全／隐私 | 约 4 | release 全局放开明文 HTTP；友盟 `preInit` 在同意前执行；未显式声明 `android:allowBackup`；完整堆栈发给第三方统计 SDK；WebView 未关文件访问；Dependabot 未覆盖 Gradle 生态 |
| §3.4 工程规范 | 约 6 | 50 处「只有注释、零日志」的静默吞异常；322 处已知违规零机器检测；CJK 硬编码基线可被人手加行合法化；发版无 tag↔pubspec 关卡；71 处 ≥500ms 硬等 `pump()`；3 个测试名承诺行为却无断言；l10n 生成物入库无同步校验；`flutter_secure_storage` 读取全在 `try` 之外；文档与代码不一致 |

**建议**：B 级不要直接进排期。要么先派一轮「只做一件事」的复核（每条给可执行复现步骤），
要么先做 A 级里 A1／A7 这种**已复核且代价明确**的。

---

## 四、已排除，**不用再查**（复核为假，勿当根因）

| 原报告说法 | 复核结论 |
|---|---|
| 闹钟调度「条件写反」，改一行即可 | **不成立**。`LiveUpdateScheduler.kt:2531-2552` 是正确降级分支；考试提醒在 Android 6–11 走的是**精确**闹钟，本就不迟到。属为避开权限弹窗的刻意取舍 |
| §1.4「云盘随每次同步无限膨胀」 | **不成立**。回收逻辑存在（`:1100-1106` prune + `:1108-1113` 逐个删），上限 15 份/30 天 |
| §1.4「同步脚本的 `--force-with-lease` 挡不住覆盖别人新提交」 | **不成立**。它先 `git ls-remote` 读实时 tip 再拿它当锁，比默认写法**更强** |
| §1.4「`network_security_config` 注释说错了，系统下载器也受管辖」 | **不成立**。注释针对镜像下载（走 `dart:io`）；`DownloadManager` 那条是安装包更新，不是镜像下载 |
| §1.1 根因引 `app_log_service.dart:414-419` | **结论对、行号错**。真实机制在 `lib/logging/app_debug_log.dart:4-11`（见 A5 第 26 条） |
| §1.2「5 个存储服务全部无坏数据兜底」 | **后半句为假**。3 个确有兜底。站得住的说法是「5 个全部忽略写入失败，且没有一个会隔离坏数据或失败后 reload」 |
| §2.2 第 9 条「精确位置无条件上传」 | **不成立**。需用户主动操作 + 系统权限（但披露缺口与第二个境外主机是真的，见 A2 第 9 条） |
| §3.4「`import_export_logic.dart` 零测试」 | **不成立**，须从零测试清单移除（见 A8） |
| 开头「P0 清单（18 条）」 | **内部矛盾**：小节自报 6+6+2+1 = **15 条** |
| 开头 `lib/` 163,876 行 | **无对应口径**。共 375 文件／252,515 行；其中生成物 `app_localizations*` 占 87,501；排除生成物为 165,025。原文混用了「全部文件数」与「排除生成物的行数」 |
