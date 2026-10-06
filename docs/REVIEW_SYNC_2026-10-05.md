# 第二台机器审查分支同步说明（2026-10-05）

分支：`review/local-audit-2026-10-05`
本分支只推 `review/*`，**从不推 `main`**（仓库内已装 pre-push 闸门 + `branch.main.pushRemote=.`）。

## 这份分支是什么

第二台机器（GitHub 身份 `mutx6666`）上跑的代码审查产出，已并入主仓库最新 `main`。
合并基线：`origin/main` = `567f6502`。

- 本分支独有提交：**160**（全部为审查/修复类，作者字段是机器内的占位身份 `qingyu-audit <audit@local>`、`Qoder <qoder@localhost>`，仅 committer 为 `Mutx163`）
- 规模：约 280 文件、+22k / −3k
- 与 `main` 的关系：已含 `main` 全部提交，合并回主线**不需要再处理历史分叉**

## 合并时解决的冲突（3 个文件）

原则：**有实质改动的归本分支，纯搬代码的归 main**。

### 1. `lib/providers/timetable_provider.dart`

- `part` 列表取并集：本分支的 `settings_repository` / `location_group_repository` + main 的 `schedule_rule_apply`
- main 的 `a8ae904e`（把批量套用拆进 part 以压行数棘轮）**已采纳**：`_applyLocationTimeRulesToActiveProfileImpl` 用 main 搬进 part 的那份——本分支对该函数体**逐字未改**（326 行完全一致），所以接受搬迁不丢东西
- 本分支的 `_applyDueScheduleDateRulesDetailed` 转发壳**保留**：它指向 `timetable/schedule_date_rule_repository.dart`，那里补了「落盘失败整体回滚」。main 搬进 `schedule_rule_apply.dart` 的是**没有回滚的旧实现**，因此从该文件删掉了这份重复定义（同库重复定义编译不过），并在文件头注明原因
- `updateCourse` / `addCourseGroup` 保留本分支的委托形式（实现分别在 `timetable/course_repository.dart`、`timetable/course_group_repository.dart`，都带回滚口径说明）

### 2. `lib/services/weekly_report_service.dart`

纯加法：两个 import 都要（`locale_utils` 供 `localeFromSettingsTag`，`timed_method_channel` 供 `TimedMethodChannel`），已同时保留。

### 3. `lib/screens/course_import_screen.dart`

- import 取并集：`warehouse_macro_replay_logic`（`bridgeOptionalString` 有 23 处引用）+ main 的 `warehouse_macro_dialog_replay`、`warehouse_session_probe`
- `_startQingyuOnlyExtrasLoad` **取 main 侧**：`_extrasResolved` 这个字段在 2994 行声明、3197 行被读，本分支那版从不置位，若保留本分支侧会让 main 的等待逻辑永久判为「未解析」
- 排序比较器：git 把 main 恢复 AzListView 的 `headerInset` 声明错配到了本分支新加的 `initial` 比较上（两边都以 `);` 收尾）。已取本分支侧；main 真正的 `headerInset` 在 2394 行完好存在，未受影响
- **单选项回放（宏）这一处两边修的是同一个 bug，做了取舍**：
  - 本分支 `c0107f0b`：把 `options` 与 `scriptSelectedIndex` 提到函数外层，用 `matchRecordedOptionIndex(...)`
  - main `2c2a91c8`：在块内重新解析，用 `resolveRecordedSelectionIndex(...)`
  - **结论：改用 main 的 helper**，它严格更强——多覆盖「宿主把值包成数字字符串」这一路（Dart 里 `0 == '0'` 为 false，本分支的 helper 会漏判并静默掉到 fallback）
  - 同时保留本分支的外层变量结构，删掉 main 在块内的重复解析，避免变量遮蔽与未使用告警
  - 兜底下标用 `scriptSelectedIndex`（与 main 的 `selectedIndex` 同源同值）
  - 本分支的 `matchRecordedOptionIndex` 及其测试仍在 `warehouse_macro_replay_logic.dart` 里，只是不再被这里调用

### 4. main 的修复搬进本分支实现（重要）

main 的 `6e8248d4`（节次校验只对**显式绑定**方案的课生效）改了 4 个调用点。本分支已把守卫补进自己的实现：

| 调用点 | 位置 | 状态 |
|---|---|---|
| `addCourse` | `timetable_provider.dart` | 自动合并已带守卫 |
| 单次改课 | `timetable_provider.dart` | 自动合并已带守卫 |
| `updateCourse` | `timetable/course_repository.dart` | **手工补上守卫** |
| `addCourseGroup` | `timetable/course_group_repository.dart` | **手工补上守卫** |

若漏了后两处，这次同步会把 main 的修复吃掉（未绑定方案但钟点齐全的课会被莫名拒写）。

## 复核时建议重点看

1. 宏回放单选项那处：main 与本分支两套 helper 语义是否真的等价，`fallbackIndex` 取 `scriptSelectedIndex` 是否符合预期
2. `_applyDueScheduleDateRulesDetailed`：确认「回滚版实现 + 转发壳」的组合与 main 的行数棘轮意图不冲突
3. 上述 4 个校验守卫是否都到位
