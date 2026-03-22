# Multi Timetable Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为轻屿课表增加“完整独立多课表”能力，并支持首页快速切换当前课表，同时保证只有当前课表参与通知和超级岛。

**Architecture:** 在现有单课表模型之上新增 `TimetableProfile` 聚合对象，包含课程、设置、当前周等完整状态；再由 `activeProfileId` 决定应用当前上下文。页面层尽量继续通过 `TimetableProvider` 暴露的当前课表接口工作，减少一次性改动面。升级时做一次自动迁移，把旧的单课表数据包成默认 profile，保证用户无感升级。

**Tech Stack:** Flutter, Provider, SharedPreferences, Android Kotlin foreground service, flutter_test

---

### Task 1: 建立多课表数据模型

**Files:**
- Create: `lib/models/timetable_profile.dart`
- Modify: `lib/models/timetable_settings.dart`
- Test: `test/models/timetable_profile_test.dart`

**Step 1: Write the failing test**

- 覆盖 `TimetableProfile` 的 `toJson/fromJson`。
- 覆盖包含课程、设置、当前周、名称、最近使用时间的序列化恢复。

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/timetable_profile_test.dart`
Expected: FAIL because `TimetableProfile` does not exist

**Step 3: Write minimal implementation**

- 新建 `TimetableProfile`：
  - `id`
  - `name`
  - `courses`
  - `settings`
  - `currentWeek`
  - `createdAt`
  - `lastUsedAt`
- 提供 `toJson`、`fromJson`、`copyWith`
- 保持 `TimetableSettings` 兼容，不把 profile 元数据塞进 settings

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/timetable_profile_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/models/timetable_profile.dart lib/models/timetable_settings.dart test/models/timetable_profile_test.dart
git commit -m "feat: add timetable profile model"
```

### Task 2: 重构存储层并加入单课表迁移

**Files:**
- Modify: `lib/services/storage_service.dart`
- Test: `test/services/storage_service_profile_test.dart`

**Step 1: Write the failing test**

- 覆盖新的 profile 存储读取。
- 覆盖旧版数据存在时，首次读取会自动生成默认 profile。
- 覆盖 `activeProfileId` 持久化。

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/storage_service_profile_test.dart`
Expected: FAIL because profile storage methods do not exist

**Step 3: Write minimal implementation**

- 在 `StorageService` 中新增：
  - `getProfiles()`
  - `saveProfiles()`
  - `getActiveProfileId()`
  - `setActiveProfileId()`
- 保留旧键读取能力：
  - `courses`
  - `timetable_settings`
  - `current_week`
  - `semester_start`
- 首次进入新版本时：
  - 读取旧单课表数据
  - 包装成一个默认 profile
  - 名称先定为 `默认课表`
  - 写入新结构
  - 设置 `activeProfileId`
- 迁移完成后不立即删除旧键，先保持一版向后兼容

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/storage_service_profile_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/storage_service.dart test/services/storage_service_profile_test.dart
git commit -m "feat: persist timetable profiles with migration"
```

### Task 3: 让 Provider 以当前课表为中心工作

**Files:**
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/services/data_transfer_service.dart`
- Test: `test/providers/timetable_provider_profiles_test.dart`

**Step 1: Write the failing test**

- 覆盖切换 `activeProfileId` 后 `courses/settings/currentWeek` 会切到对应课表。
- 覆盖新增课程只影响当前课表。
- 覆盖修改设置只影响当前课表。

**Step 2: Run test to verify it fails**

Run: `flutter test test/providers/timetable_provider_profiles_test.dart`
Expected: FAIL because provider only supports one timetable

**Step 3: Write minimal implementation**

- Provider 内部状态改成：
  - `List<TimetableProfile> _profiles`
  - `String? _activeProfileId`
- 对外尽量维持现有接口：
  - `courses`
  - `settings`
  - `currentWeek`
  - `semesterStartDate`
- 新增接口：
  - `profiles`
  - `activeProfile`
  - `switchProfile()`
  - `createProfile()`
  - `duplicateActiveProfile()`
  - `renameProfile()`
  - `deleteProfile()`
- `DataTransferService` 导出默认只导出当前课表，避免一次把所有课表混进去

**Step 4: Run test to verify it passes**

Run: `flutter test test/providers/timetable_provider_profiles_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/providers/timetable_provider.dart lib/services/data_transfer_service.dart test/providers/timetable_provider_profiles_test.dart
git commit -m "refactor: drive app state from active timetable profile"
```

### Task 4: 让通知和超级岛只跟随当前课表

**Files:**
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/services/miui_live_activities_service.dart`
- Modify: `android/app/src/main/kotlin/com/example/university_timetable/LiveUpdateScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt`

**Step 1: Write verification checklist**

- 当前课表切换前有常驻通知
- 切换课表后旧通知停止
- 新课表若有正在进行的课程则立刻重建通知
- 无课时不残留旧课表通知

**Step 2: Verify current behavior**

Run: `flutter analyze --no-fatal-infos`

**Step 3: Write minimal implementation**

- 课表切换时先清掉当前 live activity key
- 停止旧通知 / 清理旧快照
- 重新同步当前 profile 的课程与设置到原生层
- 所有快照构建都从当前 active profile 取值

**Step 4: Verify**

- 真机切换课表验证一次
- Run: `flutter analyze --no-fatal-infos`

**Step 5: Commit**

```bash
git add lib/providers/timetable_provider.dart lib/services/miui_live_activities_service.dart android/app/src/main/kotlin/com/example/university_timetable/LiveUpdateScheduler.kt android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt
git commit -m "fix: bind live notifications to active timetable profile"
```

### Task 5: 首页增加课表切换胶囊

**Files:**
- Modify: `lib/screens/timetable_screen.dart`
- Test: `test/widgets/timetable_switcher_test.dart`

**Step 1: Write the failing test**

- 覆盖首页显示当前课表名胶囊。
- 覆盖点击胶囊能弹出切换面板。
- 覆盖点击目标课表会触发 provider 切换。

**Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/timetable_switcher_test.dart`
Expected: FAIL because switcher UI does not exist

**Step 3: Write minimal implementation**

- 保持品牌标题 `轻屿课表` 不动
- 在标题右侧或 app bar actions 区新增当前课表胶囊
- 点击弹出底部面板：
  - 课表列表
  - 新建空白课表
  - 复制当前课表
- 课表名过长时截断显示

**Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/timetable_switcher_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/screens/timetable_screen.dart test/widgets/timetable_switcher_test.dart
git commit -m "feat: add quick timetable switcher on home screen"
```

### Task 6: 增加课表管理页

**Files:**
- Create: `lib/screens/timetable_profiles_screen.dart`
- Modify: `lib/screens/timetable_screen.dart`
- Modify: `lib/screens/timetable_settings_screen.dart`

**Step 1: Write verification checklist**

- 能重命名课表
- 能删除非唯一课表
- 能看到当前课表标识
- 删除当前课表时自动切到剩余课表

**Step 2: Write minimal implementation**

- 从首页右上角菜单进入“课表管理”
- 列表支持：
  - 重命名
  - 删除
  - 标识当前课表
- 第一版不做拖拽排序，避免范围膨胀

**Step 3: Verify**

Run: `flutter analyze --no-fatal-infos`

**Step 4: Commit**

```bash
git add lib/screens/timetable_profiles_screen.dart lib/screens/timetable_screen.dart lib/screens/timetable_settings_screen.dart
git commit -m "feat: add timetable profile management screen"
```

### Task 7: 适配导入导出与文案

**Files:**
- Modify: `lib/screens/data_transfer_screen.dart`
- Modify: `lib/services/data_transfer_service.dart`
- Modify: `README.md`
- Modify: `docs/PRODUCT.md`

**Step 1: Write minimal implementation**

- 导出页明确提示“导出当前课表”
- 导入时提供：
  - 覆盖当前课表
  - 导入为新课表
- README 补充多课表能力说明

**Step 2: Verify**

Run: `flutter analyze --no-fatal-infos`

**Step 3: Commit**

```bash
git add lib/screens/data_transfer_screen.dart lib/services/data_transfer_service.dart README.md docs/PRODUCT.md
git commit -m "docs: explain multi timetable import and export"
```
