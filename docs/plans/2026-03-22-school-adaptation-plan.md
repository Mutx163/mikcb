# 轻屿课表学校适配修复计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让轻屿课表从“适配少量常见学校课表”提升到“能稳定支持不同学校的周数、节次、冲突课和提醒规则”。

**Architecture:** 先收敛基础学期模型，把“总周数、周起点、节次合法性”做成统一规则；再补课程冲突检测和 UI 呈现；最后修复提醒链路与导入链路，让设置、展示和原生通知保持一致。

**Tech Stack:** Flutter, Provider, SharedPreferences, Android Kotlin foreground service, flutter_test

---

### Task 1: 把学期总周数从硬编码改成配置项

**Files:**
- Modify: `lib/models/timetable_settings.dart`
- Modify: `lib/screens/timetable_settings_screen.dart`
- Modify: `lib/screens/timetable_screen.dart`
- Modify: `lib/screens/add_course_screen.dart`
- Modify: `lib/screens/course_overview_screen.dart`
- Test: `test/models/timetable_settings_test.dart`

**Step 1: 写失败测试**

- 新增 `semesterWeekCount` 默认值测试，断言默认值存在且可序列化。
- 新增课程编辑周次范围测试，断言可生成 1..`semesterWeekCount` 的周列表。

**Step 2: 跑测试确认失败**

Run: `flutter test test/models/timetable_settings_test.dart`

**Step 3: 最小实现**

- 在 `TimetableSettings` 增加 `semesterWeekCount`，默认建议 `20`。
- 设置页新增“学期总周数”输入或步进器。
- 课表页周翻页、周选择器、`PageView.itemCount` 改为读取设置值。
- 添加/编辑课程时的开始周、结束周下拉范围改为读取设置值。

**Step 4: 跑测试与分析**

Run: `flutter test test/models/timetable_settings_test.dart`
Run: `flutter analyze --no-fatal-infos`

**Step 5: 提交**

```bash
git add lib/models/timetable_settings.dart lib/screens/timetable_settings_screen.dart lib/screens/timetable_screen.dart lib/screens/add_course_screen.dart lib/screens/course_overview_screen.dart test/models/timetable_settings_test.dart
git commit -m "feat: make semester week count configurable"
```

### Task 2: 统一周起点和当前周计算规则

**Files:**
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/screens/timetable_screen.dart`
- Modify: `lib/services/ics_import_service.dart`
- Test: `test/providers/timetable_week_calculation_test.dart`

**Step 1: 写失败测试**

- 测试开学日不是周一时，当前周计算、顶部日期映射、导入周索引保持一致。
- 覆盖周二开学、周三开学、开学前一周、学期第 21 周等场景。

**Step 2: 跑测试确认失败**

Run: `flutter test test/providers/timetable_week_calculation_test.dart`

**Step 3: 最小实现**

- 抽一个统一的“学期周计算”方法，明确“用户设置的是教学周开始日”还是“该周任意开学日”。
- Provider 的 `syncCurrentWeekWithSemesterStart()`、课表日期头、ICS 导入周索引全部复用同一规则。
- 超出 `semesterWeekCount` 时，决定是夹紧显示还是允许继续显示，并统一行为。

**Step 4: 跑测试与分析**

Run: `flutter test test/providers/timetable_week_calculation_test.dart`
Run: `flutter analyze --no-fatal-infos`

**Step 5: 提交**

```bash
git add lib/providers/timetable_provider.dart lib/screens/timetable_screen.dart lib/services/ics_import_service.dart test/providers/timetable_week_calculation_test.dart
git commit -m "fix: unify semester week calculation"
```

### Task 3: 增加课程冲突检测与提示

**Files:**
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/screens/add_course_screen.dart`
- Modify: `lib/screens/timetable_screen.dart`
- Test: `test/providers/course_conflict_detection_test.dart`

**Step 1: 写失败测试**

- 测试同一天、同周次范围、同节次范围课程冲突能被识别。
- 测试单双周互斥时不判冲突。
- 测试编辑自身课程时不会误判成冲突。

**Step 2: 跑测试确认失败**

Run: `flutter test test/providers/course_conflict_detection_test.dart`

**Step 3: 最小实现**

- 在 Provider 中新增课程冲突判断方法。
- 保存课程前先检查冲突。
- 第一阶段建议“允许继续保存，但弹明确冲突提示”；如果你要更保守，再升级成阻止保存。
- 课表页对冲突课程加角标或提示入口，避免“后面的课被前面的课吞掉”却没有任何反馈。

**Step 4: 跑测试与分析**

Run: `flutter test test/providers/course_conflict_detection_test.dart`
Run: `flutter analyze --no-fatal-infos`

**Step 5: 提交**

```bash
git add lib/providers/timetable_provider.dart lib/screens/add_course_screen.dart lib/screens/timetable_screen.dart test/providers/course_conflict_detection_test.dart
git commit -m "feat: detect course conflicts"
```

### Task 4: 给节次时间和学期设置补合法性校验

**Files:**
- Modify: `lib/screens/timetable_settings_screen.dart`
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/models/timetable_settings.dart`
- Test: `test/providers/timetable_settings_validation_test.dart`

**Step 1: 写失败测试**

- 测试节次结束时间早于开始时间时报错。
- 测试相邻节次重叠时报错。
- 测试学期总周数小于已有课程最大结束周时报错。

**Step 2: 跑测试确认失败**

Run: `flutter test test/providers/timetable_settings_validation_test.dart`

**Step 3: 最小实现**

- 保存布局与节次设置前，集中校验时间范围和顺序。
- 把已有的“不能小于最大节次”校验扩展到“不能小于最大周次”。
- 错误信息直接回传到设置页 `SnackBar`。

**Step 4: 跑测试与分析**

Run: `flutter test test/providers/timetable_settings_validation_test.dart`
Run: `flutter analyze --no-fatal-infos`

**Step 5: 提交**

```bash
git add lib/screens/timetable_settings_screen.dart lib/providers/timetable_provider.dart lib/models/timetable_settings.dart test/providers/timetable_settings_validation_test.dart
git commit -m "feat: validate timetable settings"
```

### Task 5: 修正提醒启动时机与原生调度不一致的问题

**Files:**
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/services/miui_live_activities_service.dart`
- Modify: `android/app/src/main/kotlin/com/example/university_timetable/LiveUpdateScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt`

**Step 1: 写失败测试或验证脚本**

- 对 Flutter 侧生成的 payload 做断言，确认包含“上课后多久开始展示”的设定。
- 准备人工验证清单，覆盖“上课立刻显示”“下课前 10 分钟显示”“仅下课前秒级提醒”。

**Step 2: 先验证现状**

Run: `flutter analyze --no-fatal-infos`

**Step 3: 最小实现**

- 把 `liveClassReminderStartMinutes` 明确传入原生调度层。
- `LiveUpdateScheduler` 的未来阶段选择和前台服务的阶段判断统一使用同一时机规则。
- 避免前台刚被系统重启后，提醒时机退回默认逻辑。

**Step 4: 验证**

- 真机验证通知启动时机。
- Run: `flutter analyze --no-fatal-infos`

**Step 5: 提交**

```bash
git add lib/providers/timetable_provider.dart lib/services/miui_live_activities_service.dart android/app/src/main/kotlin/com/example/university_timetable/LiveUpdateScheduler.kt android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt
git commit -m "fix: align live reminder scheduling"
```

### Task 6: 提升 ICS 导入的兼容性

**Files:**
- Modify: `lib/services/ics_import_service.dart`
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/screens/timetable_screen.dart`
- Test: `test/services/ics_import_service_test.dart`

**Step 1: 写失败测试**

- 覆盖不同 `.ics` 样式、缺少 `RRULE`、多行 `DESCRIPTION`、单双周和停课周场景。
- 断言导入后周次、节次、教师地点解析正确。

**Step 2: 跑测试确认失败**

Run: `flutter test test/services/ics_import_service_test.dart`

**Step 3: 最小实现**

- 弱化对单一描述格式的依赖。
- 导入后如果发现周次数超出当前学期总周数，给出修正或提示。
- 导入时增加“检测到冲突课程”的摘要提示。

**Step 4: 跑测试与分析**

Run: `flutter test test/services/ics_import_service_test.dart`
Run: `flutter analyze --no-fatal-infos`

**Step 5: 提交**

```bash
git add lib/services/ics_import_service.dart lib/providers/timetable_provider.dart lib/screens/timetable_screen.dart test/services/ics_import_service_test.dart
git commit -m "feat: improve ics import compatibility"
```

### Task 7: 最后一轮回归与文案更新

**Files:**
- Modify: `README.md`
- Modify: `docs/PRODUCT.md`
- Modify: `lib/screens/user_guide_screen.dart`

**Step 1: 更新说明**

- README 增加“支持自定义学期周数/节次时间/冲突提示”说明。
- 引导页补充“开学日期如何设置才准确”的文案。

**Step 2: 回归验证**

Run: `flutter analyze --no-fatal-infos`
Run: `flutter test`

**Step 3: 提交**

```bash
git add README.md docs/PRODUCT.md lib/screens/user_guide_screen.dart
git commit -m "docs: update school adaptation guidance"
```
