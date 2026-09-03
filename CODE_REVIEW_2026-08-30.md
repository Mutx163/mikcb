# 代码审核报告：2026-08-30 全天

**审核范围** 2026-08-30 00:00 至 2026-08-31 01:20，共 **80 个提交**，新增 8932 行 /
删除 1789 行，触及 342 个文件。审核为只读，未改动任何业务代码。

**门禁状态**

| 检查项 | 结果 |
|---|---|
| `flutter analyze` | 18 info，与项目基线一致，0 warning / 0 error |
| `flutter test` 全量 | **1558 通过 / 1 失败**（架构守卫棘轮，见 M1） |

> 注：审核期间工作区持续有其他 Agent 提交（新增 `36b06d0d`、`e7f77af4`、
> `236a8872`），结论以审核时读取到的代码为准。

---

## 必须修

### M1. 架构守卫棘轮失败，CI 当前是红的

`timetable_provider.dart` 实际 **4422 行**，而棘轮基线是 4409。

```dart
// test/architecture/dependency_guards_test.dart:21
test('timetable_provider.dart 行数棘轮：只减不增', () {
  const baselineLines = 4409;   // 实际 4422
```

**成因**：`e7f77af4`（桌面卡片 Flutter 侧）给 provider 加了 13 行。这是本次全量测试
唯一的失败项。

**修复**：二选一——把 `buildHomeWidgetSnapshotForProfile` 的快照构建逻辑拆到独立
文件（推荐，该文件已 4400+ 行且昨天被改了 10 次），或按既有约定显式上调基线并在
提交信息里说明正当理由（此前已有两次先例：`694ef923` 4359→4401、`671de2d1`
4401→4409）。

### M2. 仓储层「唯一写入口」承诺实质破窗

`lib/data/timetable_repository.dart` 是这次架构重构收口写入的新层，但云同步恢复
路径**完全没迁移**：

```dart
// lib/services/app_sync_snapshot_service.dart:890-902
await _storageService.saveTeacherRecords(snapshot.teacherRecords);
await _storageService.saveLocationRecords(snapshot.locationRecords);
await _storageService.saveLocationTimeGroups(snapshot.locationTimeGroups);
await _storageService.saveScheduleDateRules(snapshot.scheduleDateRules);
await _storageService.saveScheduleDateRuleLastAppliedSignature(
```

该文件对 `TimetableRepository` 的引用数为 **0**，读路径（:249-250）同样直连。
附带风险：`saveScheduleDateRules` 与 `saveScheduleDateRuleLastAppliedSignature`
是两个 key 的非原子写，中途中断会留下「规则已换、签名未换」，导致规则反复重放。

同类问题：`lib/providers/timetable_provider.dart:665` 在 `_init()` 里直连
`_storageService` 读 `lastAppliedSignature`，而写路径走仓储——读写双源。

**修复**：把这条路径改道 `TimetableRepository`；双 key 改为仓储内的单次事务写。

### M3. 日志页正序读历史会被新日志顶掉

`lib/screens/live_diagnostics_log_viewer_screen.dart`

`_pinnedStartIndex` **只在「加载更早」里赋值**（:889），纯滚动离开最新端时它为
null，于是走滑动窗口：

```dart
// :328
final start = _pinnedStartIndex ?? (end > _pageSize ? end - _pageSize : 0);
```

推演（正序，`_pageSize = 200`）：用户在 200 条里滚到中间读历史，此刻
`total = 200`、`start = 0`、`end = 200`。流式到达 5 条 → `total = 205` →
`start = 5`、`end = 205`。滚动 offset 不变，但窗口起点从第 0 条变成第 5 条，
**用户正在读的内容整体上移 5 条**。持续写入即持续漂移。

倒序侧已用 `_windowEndPin` 冻结末端解决（:322-327），正序侧没有对应保护。

另注意 :319-320 的注释「正序追加在底部天然不位移」**是错的**——它只在
`start` 固定时成立，滑动窗口下不成立。错误注释会误导后续维护。

**修复**：在 `_syncStickToLatest(false)`（:382）里同时钉住起点
（`_pinnedStartIndex ??= _currentStartIndex`），而不是只设 `_windowEndPin`。

### M4. 配色历史「永远有路可回」在第 21 次换色时破产

`lib/services/course_recolor_history_service.dart:77-81`

```dart
if (schemes.length > maxSchemes) {
  final dropCount = schemes.length - maxSchemes;
  bounded = schemes.sublist(dropCount);        // 丢最旧
  boundedIndex = (index - dropCount).clamp(0, bounded.length - 1);
}
```

`schemes[0]` 恒为「导入原色快照」（`course_recolor_sheet.dart:104-106` 首次换色时
存入）。历史满 20 套后再换一批 → 丢掉 `schemes[0]` → **用户再也无法回到导入时
的原始配色**，与 `737efdf1` 写明的设计承诺直接冲突。

触发路径可达：`_applyNewBatch` 每次在末尾追加（:117-118），`index` 恒指向末位，
因此长度会单调增长到 21。

**修复**：淘汰时豁免第一条 snapshot 记录（或所有 `isSnapshot` 记录），只淘汰种子
方案；或把原色快照存到独立 key 永久保留。

### M5. 卡片绑定记录清理依赖 `onDeleted`，force-stop 后失效

`android/app/src/main/kotlin/com/mutx163/qingyu/WidgetBindingStore.kt:36`

```kotlin
fun remove(context: Context, appWidgetId: Int) {
    prefs(context).edit().remove(key(appWidgetId)).apply()
}
```

仅在 6 个 `TodayXxxWidgetProvider.onDeleted` 里调用。Android 对处于 stopped 状态
的应用不投递广播，force-stop 后用户删除卡片不会触发清理 → 绑定记录残留 → 系统
复用该 `appWidgetId` 时**新卡片继承旧绑定而串到别的课表**；残留记录还会让
`HomeWidgetStorage.rescheduleRefresh`（:98）持续排无谓闹钟。

**修复**：在 `onUpdate` 里补一次有效性校验/惰性清理，不依赖 `onDeleted` 单一入口。

---

## 建议修

- **S1 正序/倒序切换不重置 `_stickToLatest`**（`live_diagnostics_log_viewer_screen`
  :135-139、:596-600）。切到正序后列表会重新锚到底部并把 `_stickToLatest` 置回
  true，此刻之前的阅读位置丢失，新日志会持续把内容往上推。切排序时应显式重置
  窗口状态。
- **S2 `autoFailureReportedKeys` 非线程安全**（`BeforeClassQuickActionRestore.kt`
  :56）。无同步，跨线程存在数据竞争；它是防诊断日志刷爆的限流器，漏去重会导致
  诊断日志膨胀。改用 `ConcurrentHashMap.newKeySet()` 或配 `synchronized`。
- **S3 主动解绑时残留专属快照**：`onDeleted` 路径已同时清理绑定档案与专属快照
  （`TodayCompactWidgetProvider.kt:47-48`），但 `setWidgetBinding` 传
  `profileId=null` 的**主动解绑**路径（`MainActivity.kt:681`）只调
  `setBoundProfileId`，未调 `clearWidgetSnapshot`，专属快照会残留并继续参与刷新。
  建议在 `setBoundProfileId` 的解除分支里补一次清理，与 `onDeleted` 同口径。
- **S4 `apply()` 无落盘确认**：`WidgetBindingStore` 全部用 `apply()` 异步落盘，
  绑定后若进程立即被杀，绑定可能丢失。绑定是低频但高价值操作，建议 `commit()`
  并接受主线程开销，或对绑定写入单独 `commit()`。
- **S5 排课规则无时间窗**：`ScheduleDateRule` 只有日期没有时刻，无法表达「9 月 1
  日 14:00 起生效」。多条同日规则同序号时按列表顺序取第一条，行为依赖用户维护
  顺序。
- **S6 死代码**：`timetable_repository.dart:26` 的 `storageSchemaVersion` 零引用；
  `glass_debug_probe.dart` 已随探针移除，状态干净（这点做得好）。
- **S7 测试缺口**：`0d47e101` 新增 9 组仓储方法但**零测试配套**（`updateProfiles`
  仅一条透传断言）；配色历史超限用例只测 `index == length-1`，未覆盖
  `index < dropCount`；种子确定性只测同列表，未测增删课程后重放。
- **S8 大文件持续膨胀**：`timetable_screen.dart` 8772 行、`course_import_screen.dart`
  6601 行、`timetable_provider.dart` 4422 行。棘轮只守住了 provider 一个文件。

---

## 亮点

- **领域层纯度经全量扫描确认干净**：本次新增的 4 个文件（`course_domain`、
  `holiday_resolver`、`schedule_item_expander`、`week_calculator`）对
  `DateTime.now()` / `Random` / `dart:io` / `BuildContext` / `package:flutter`
  的引用数**全为 0**，时间/随机源全部显式注入。守卫测试「lib/domain 保持无 UI
  框架依赖（纯领域层）」通过——注意 `lib/domain/` 实际有 11 个文件，其中
  `import_export_logic.dart` 导入 `foundation.dart` 属守卫豁免的既存例外，非本次
  新增。旧 `_startOfWeek` 四处实现已全删，无双份并存的伪重构。
- **日志页性能优化思路正确**：窗口恒按时间正序建模、倒序只在渲染层反转，这个
  决策让「贴最新 / 加载更早 / 新增不位移」三组语义在两个方向同时成立，避免了
  按显示方向建模必然导致的窗口倒置。450 条级别的边界测试也补了。
- **坏数据一律「丢弃该条」而非兜底默认值**：配色历史从裸 cast（`as String?` 抛
  TypeError 穿透到整体 catch，一条坏数据静默清空全部历史）改为类型守卫返回
  null，并补了两层回归测试。这是这批改得最扎实的一处。
- **「先落历史再应用」的顺序修正**：识别到「颜色已变、历史未存」的中间态会让
  首次换色的原色快照永久丢失，调换顺序把不可恢复的失败降级为可自愈的冗余。
- **Dart 与 Kotlin 的 channel 协议逐条对齐**：方法名、参数键、`profileId` 为 null
  的解绑语义两端一致，绑定档案是零迁移设计（未登记即跟随当前课表，老用户升级
  无感）。
- **临时诊断代码清理彻底**：`[GlassDbg]` 探针埋点 → 定位根因 → 移除埋点 →
  补删探针文件本体，四步闭环，无残留。
- **启动画面最终决策正确**：与系统遮罩缠斗三版后（`36b06d0d`），放弃系统启动画面
  改应用自绘，不再在不可控的系统链路上反复试错。

---

## 流程观察

修复类提交 **27 个**，功能类 **12 个**——自我纠错能力很强，但首次实现质量不稳定：
日志页修 4 次、课表重新配色修 3 次、CI 修 3 次、启动画面连改 4 版。集中在分页
窗口、异步持久化顺序、系统图标缩放这几类**难以靠静态检查发现、必须真机或精确
推演才能暴露**的问题上。建议在动手前先补边界用例，比事后回归便宜。

多语言 6 语种 key 数一致（各 3095），`l10n_untranslated.json` 为空，无遗漏。
未发现密钥或凭据泄漏；CI 的签名占位是 dummy 值，处理得当。

---

## 复核记录（2026-08-31 10:20）

对上表全部结论逐条回读源码重验。复核期间工作区新增 1 个提交（`ad8c67cc`
启动画面首帧时序），不影响结论。

| 结论 | 复核方式 | 结果 |
|---|---|---|
| M1 棘轮 4409 / 实际 4422 | 重跑 `dependency_guards_test` | ✅ 仍失败，该文件 3 通过 / 1 失败 |
| M2 云同步零引用仓储 | `grep -c TimetableRepository` = 0 | ✅ 成立（6 处写 + 2 处读直连） |
| M2 provider 直连读 | `sed -n 663,667p` | ✅ 成立 |
| M3 `_pinnedStartIndex` 仅在加载更早赋值 | 6 个赋值点，5 个置 null，1 个在 :889 | ✅ 成立 |
| M3 冻结条件排除正序 | :322 `!_latestAtBottom` | ✅ 成立 |
| M4 淘汰丢最旧 | :79 `sublist(dropCount)` | ✅ 成立 |
| M4 `schemes[0]` 为原色快照 | `sheet:104-106` | ✅ 成立 |
| M5 `remove` 仅 6 处且全在 `onDeleted` | 逐文件确认 | ✅ 成立 |
| S1 切排序不重置 `_stickToLatest` | :131-139、:596-600 只清两 pin | ✅ 成立 |
| S2 `mutableSetOf<Long>()` 无同步 | `:23` | ✅ 成立 |
| S3 解绑残留快照 | `MainActivity.kt:681` | ⚠️ **已修正表述**：仅主动解绑路径残留，`onDeleted` 路径已清 |
| S6 `storageSchemaVersion` 零引用 | 全仓 grep 仅定义处 | ✅ 成立 |
| 亮点：领域层纯度 | 四文件依赖计数全 0 + 守卫测试通过 | ✅ 成立（**已补充** `lib/domain` 实为 11 个文件的说明） |
| analyze 18 info | 重跑 | ✅ 一致 |
| l10n 3095 × 6 | 重跑 | ✅ 一致 |

**两处主动纠偏**

1. 子任务报的「超限裁剪导致指针错位（`index < dropCount` 时 clamp 到 0）」经推演
   **不可达**，已不采纳：`_applyNewBatch` 的 `index` 恒为 `schemes.length - 1`
   （`sheet:118`），恒 `>= dropCount`，clamp 不会触发。M4 的真实危害是丢原色快照，
   与指针无关——两者不要混为一谈。
2. 另一子任务引用的 `clearPendingQrTransferWindow`、`_masked` 等符号及提交
   `52039cd`、`dc4d428` **在本仓库不存在**，属幻觉内容，已全部弃用；日志页与配色
   两块改用 `general-purpose` 重跑并重新核实。
