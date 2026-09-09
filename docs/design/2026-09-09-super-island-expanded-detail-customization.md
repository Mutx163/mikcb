# 超级岛「展开状态详细信息」自定义 — 设计方案

> 日期：2026-09-09　|　状态：已实施（方案 A + 一期顺带完成排序）
> 目标：让用户自定义超级岛/焦点通知**展开态**（大卡片）里显示哪些详细信息、按什么顺序显示。

---

## 1. 结论（TL;DR）

**可以做，且是低风险改动。** 整条链路（设置 → Flutter payload → MethodChannel → Intent extras → 原生拼文本）已经为「逐项开关」完全打通——折叠态早就这么做了（showCourseName / showLocation / showCountdown 等）。展开态只是缺一组**字段级开关**。

- 建议数据结构：**一个有序字段列表** expandedDetailFields（`["stage","shortName","progress","status","time","location","teacher","next","note"]`），一次搞定「显隐 + 顺序」，而不是 8 个孤立布尔。
- **默认值「缺省 = 全显示」**，老快照/老版本无需任何迁移，天然向后兼容。
- 主要工作量在 **处透传**（Flutter payload → scheduler intent → service），每处都是照抄现有字段的模式，机械但量大。

---

## 2. 现状链路（两条路径，最终汇入同一处）

```
【前台路径】App 活着
live_activity_controller.dart:888 startLiveUpdate(...)
  → miui_live_activities_service.dart _buildData()  [payload map, "islandConfig" 子 map]
  → MethodChannel "startLiveUpdate"
  → MainActivity.startLiveUpdateService()(1762)
  → LiveUpdateScheduler.buildServiceIntentFromMethodPayload()(883)  [读 islandConfig, 逐 key 默认值兜底]
  → LiveUpdateScheduler.buildServiceIntent()(1609)  [putExtra]
  → LiveUpdateService.onStartCommand()  [getXxxExtra, 默认值兜底](~400)
  → buildNotification()(1735)  ← ★展开态文本在这里拼

【后台路径】App 被杀 / AlarmManager / WorkManager
Flutter:_liveSyncScheduleSnapshot() → settings.toJson() 写入 snapshot JSON
  → Kotlin: LiveUpdateScheduler.syncSnapshot() → parseSnapshot()(1376)  [NativeLiveSettings.读默认值]
  → selectionToPayload()(1895~)  [根据 stage 选 beforeClass / duringEnd 档]
  → buildServiceIntent()(1609)  [汇入同样的 Intent]
  → LiveUpdateService 同上

【结论】两条路径在 LiveUpdatePayload + buildIntent() 处**汇合**。新字段只需从这里补上，前后台行为就一致，最后统一在 buildNotification() 消费。
```

## 3. 展开态现状字段盘点（精确到行）

LiveUpdateService.buildNotification() 里有两个 builder：

**expandedDetailText（非提升态·状态栏通知展开，Line 1838–1860）**，目前固定顺序：

| 行号 | 字段 key（方案用） | 内容 | 格式串 |
|---|---|---|---|
| 1839 | stage | 阶段标题（课前/课中/下课前） | 无前缀（首行） |
| 1840–1842 | shortName | 课程编写（有且 != 课程名时） | detail_short_name |
| 1843–1851 | progress | 课中倒计时：下一节点 + 下课/结束 | detail_next_milestone / detail_final_dismiss |
| 1852–1854 | status | 状态文字（非倒计时、非提升时） | detail_status |
| 1855 | time | 上课时间 start - end | detail_time |
| 1856 | location | 地点（原始 location，不受 showLocation 门控） | label_location |
| 1857 | teacher | 老师 | detail_teacher |
| 1858 | next | 下节课 | detail_next |
| 1859 | note | 备注 | detail_note |

**promptedExpandedDetailText（提升通知·超级岛展开，行 1875–1891）**：内容相同，顺序是 progress/status → time → location → teacher → shortName → next → note，**无 stage 首行**。

两句最终被 shouldPromote 二选一赋值给 notificationExpandedText（1973–1979），塞进 BigTextStyle().bigText(...)（2065–2070）。

### ⚠ 平台限制（必须先讲清）

- **Android 16（SDK 36）+ 课中带进度条**：走 Notification.ProgressStyle()（2041–2063），由系统绘制进度环/节点，**完全不使用 notificationExpandedText**。即「课中 + Android 16」时展开态无法自定义文字。
- 其余场景（课前、下课提醒、Android 15 及以下的课中）都用 BigTextStyle，**9 个字段全部可定制**，纯文本行，无字体/颜色排版自由度。

## 4. 方案选型

### 方案 A（推荐）：有序字段列表 expandedDetailFields

- 新枚举 LiveExpandedDetailField { stage, shortName, progress, status, time, location, teacher, nextCourse, note }
- LiveDisplaySettings 增加一个字段 List<LiveExpandedDetailField>（**可空 = null 代表全部显示**；顺序即行序）
- 序列化：TimetableSettings 里存两个字符串 liveExpandedDetailFields / liveDuringEndExpandedDetailFields（课档各一组，跟随已有 liveDuringEndFollowBeforeClass 逻辑）
- Kotlin：Intent extra 为 ArrayList<String>（putStringArrayListExtra）；缺失 = 显示
- UI：每项 = 开关 + 上下移排序（实施时一期完成，非二期）

**优点**：一个字段同时承载显隐+顺序；缺省=全显示永远不破坏老用户；二期腾讯排序直接复用。
**缺点**：需定义一个枚举+序列化约定（很小）。

### 方案 B：每字段一个布尔（timeShow/locationShow/teacherShow…）

- 与现有 liveXxx 风格完全同构，心智低。
- 缺点：8 字段 × 双档 = 16 个 pref + 16 copyWith 字段，样板代码量是 A 的 2–3 倍，且没有排序。

**建议：方案 A。** 只需要开关不需要排序时，A 的字段列表本身就是开关。

### 二期可选：展开行排序 + 自定义模板

- 排序：重新排列列表（Hyperos 有对应组件）+ 同一字段列表，改动仅在 UI 层。
- 自定义模板（如 {course} {time} {location}）：需要模板解析 + 失败兜底，复杂度高，不建议首期。

## 5. 详细改动清单

### 5.1 Flutter 侧（4 个文件）

| 文件 | 改动 |
|---|---|
| lib/models/timetable_settings.dart | ① 新增 enum LiveList<LiveExpandedDetailField>（含 name 序列化值）；② LiveDisplaySettings 增加 List<LiveExpandedDetailField>? live（null=全显示）+ constructor + copyWith；③ 双档 getter 映射新 prefs；④ toJson/从Json 加 liveExpandedDetailFields/liveDuringEndExpandedDetailFields（缺失默认 null） |
| lib/services/miui_live_activities_service.dart | startLiveUpdate/_buildData/测试 payload/live_testing_trigger.dart 同步补参 expandedDetailFields，写入 islandConfig['expandedDetailFields'] |
| lib/providers/timetable/live_activity_controller.dart | 行 888 调用处传 displaySettings.expandedDetailFields?.map((f)=>f.name).toList() |
| lib/screens/live_settings_subpages.dart | 显示副页「展开图标」卡片下新增「展开详情」分组：可见/隐藏分区 + 每项开关 + 上下移排序 + 恢复默认；onChanged 走 _updateDisplay 即时刷新；课中档跟随 liveDuringEndFollowBeforeClass 时整组置灰 |

> 注意：设置保存路径 updateTimetableSettings（timetable_provider.dart:3692）会自动 sync 快照 + 刷新 live activity，所以开关改完**即时生效**。

### 5.2 原生 Kotlin（2 个文件）

| 文件 | 改动 |
|---|---|
| LiveUpdateScheduler.kt | LiveUpdatePayload 加 expandedDetailFields: List<String>?；buildServiceIntentFromMethodPayload 读 islandConfig 新 key（默认全）；selectionToPayload 从 NativeLiveSettings 镜像；NativeLiveSettings 加 liveExpandedDetailFields（parseSnapshot 缺省 → null → 全显示）；buildServiceInfoIntent 加 putStringArrayListExtra |
| LiveUpdateService.kt | ① ~440 解析 expandedDetailFields 为 List<String>；② 新 fun showExpandedField(key)；③ 两个 builder 每个 append 套 if (showExpandedField(...))；④ 空列表/未传 → 全显示 + 空文本保护 |

### 5.3 i18n（6 个 arb × 12 keys）

lib/l10n/app_zh.arb（+ zh_TW/zh_HK/en/ja/ko）新增：
- liveExpandedDetailGroupTitle；liveExpandedDetailHiddenCaption；resetExpandedDetailDefaultAction
- 九个字段标题 keys：liveExpandedDetailFieldStage / ShortName / Progress / Status / Time / Location / Teacher / Next / Note
- 无 liveExpandedDetailGroupSubtitle（实施时未用副标题键）

### 5.4 预览组件（可选加分）

live_island_preview.dart:19 现注释明确「展开态不在此预览范围内」——首期可**不加**预览（与现状一致），二期补「展开态文本预览」。

## 6. 向后兼容

| 兼容面 | 机制 |
|---|---|
| 老用户设置（无新 pref） | LiveDisplaySettings 默认 null → 不传/传空 → Kotlin 得到 null → 全显示 |
| 老快照 snapshot_json | parseSnapshot 缺省 → 空 → 全显示 |
| 老版 APK 解新快照 | 未知 key 被忽略 |

无版本迁移、无数据清理、无破坏性更新。

## 7. 测试计划

- flutter test：模型默认值、双档 getter、序列化往返
- flutter test：设置页开关切换后 draft/持久化正确
- Kotlin：现有 LiveUpdateScheduler 测试补 buildIntent extra 断言
- 真机/模拟器验收：课前把「下节课」「备注」关掉展开态不出现该两行；全关只剩首行（无空通知）；Android 16 课中进度条确认不受影响

## 8. 风险管理

| 风险 | 等级 | 对策 |
|---|---|---|
| 课中 Android 16 进度态无法自定义 | 中 | 设置页注明 |
| 全关后空通知内容 | 低 | 未做额外 summaryText 兜底：setBigContentTitle 已保留阶段标题，全关后仍有标题行 |
| 新增行忘记加开关 | 低 | 由枚举驱动，每行必须来自某枚举成员 |
| 改动量大于预期 | 低 | 实施时排序与开关一并完成 |

## 9. 工作量估计

| 阶段 | 内容 | 预估 |
|---|---|---|
| 1 | Dart 模型+枚举+序列化+单测 | 0.5–1h |
| 2 | 系统中透传+测试trigger | 0.5h |
| 3 | 设置页 UI + 六语言 | 1–1.5h |
| 4 | scheduler 三处透传+单测 | 1h |
| 5 | build 过滤+冗余保护 | 0.5h |
| 6 | analyze + 定向测试 | 0.5h |

合计约 **4–5 工作小时**，与现有模式平行、无迁移。

## 10. 实施结论（2026-09-09）

1. 显隐 + 排序一期一并完成（上/下移 + 隐藏分组 + 恢复默认）。
2. 未做「展开详情预览」（与 live_island_preview 现状一致，二期可选）。
3. 展开态 location 独立开关，不跟随折叠态 showLocation（与方案 §3 现状一致）。
4. Kotlin 空文本兜底未额外实现：全关后 setBigContentTitle 仍显示阶段标题。
5. 定向验证：flutter analyze 0 issues；timetable_settings_test 53 例全过（含新增 4 例序列化/双档/重置）；LiveUpdateSchedulerLogicTest 含 parseExpandedDetailFields 3 例。
