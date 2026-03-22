# Time Scheme And Conflict Badge Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为轻屿课表增加全局共享的课表时间模板库，并让每个课表可选择应用任意一套模板，同时支持首页冲突小胶囊及其设置开关。

**Architecture:** 在现有 `TimetableSettings.sections` 之上新增全局 `TimeScheme` 模型与存储层，课表设置只保存 `activeTimeSchemeId` 和当前已应用的节次快照，避免一次性重构所有时间读取逻辑。升级时从现有 profile 的节次配置自动迁移出全局模板。首页冲突标记复用现有真实冲突判定，只新增轻量胶囊显示与布尔开关。

**Tech Stack:** Flutter, Provider, SharedPreferences, flutter_test

---

### Task 1: 新增时间模板模型与迁移

**Files:**
- Create: `lib/models/time_scheme.dart`
- Modify: `lib/models/timetable_settings.dart`
- Modify: `lib/services/storage_service.dart`
- Test: `test/models/time_scheme_test.dart`
- Test: `test/services/storage_service_profile_test.dart`

### Task 2: 让 Provider 管理全局时间模板

**Files:**
- Modify: `lib/providers/timetable_provider.dart`
- Test: `test/providers/timetable_provider_profiles_test.dart`

### Task 3: 接入时间模板设置界面

**Files:**
- Modify: `lib/screens/timetable_settings_screen.dart`
- Possibly create: `lib/screens/time_scheme_management_screen.dart`

### Task 4: 首页冲突小胶囊与开关

**Files:**
- Modify: `lib/widgets/course_card.dart`
- Modify: `lib/screens/timetable_screen.dart`
- Modify: `lib/models/timetable_settings.dart`
- Test: `test/widgets/course_overview_conflict_test.dart`

### Task 5: 全量验证

**Run:**
- `flutter test test/models/time_scheme_test.dart`
- `flutter test test/services/storage_service_profile_test.dart`
- `flutter test test/providers/timetable_provider_profiles_test.dart`
- `flutter test test/widgets/course_overview_conflict_test.dart`
- `flutter analyze --no-fatal-infos`
