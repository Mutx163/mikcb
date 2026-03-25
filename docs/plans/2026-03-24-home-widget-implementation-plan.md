# 今日课程桌面小组件 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Android 端实现首批今日课程桌面小组件，支持 2×2、2×4、4×4 三种尺寸，点击打开首页，按课程时间节点及时刷新，并提供独立的现代化外观样式。

**Architecture:** 使用 Android 原生 `AppWidgetProvider + RemoteViews` 实现桌面小组件，Flutter 侧继续负责课表和设置数据的持久化。通过共享存储快照与原生定时调度，把“今天课程列表 / 下一节课程 / 当前状态”同步给小组件，并在关键时间点主动刷新，避免显示上一节课残留。

**Tech Stack:** Flutter, Android AppWidget, Kotlin BroadcastReceiver/AlarmManager, SharedPreferences, RemoteViews, existing timetable provider/storage services

---

### Task 1: 定义小组件数据快照与设置模型

**Files:**
- Modify: `lib/models/timetable_settings.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/providers/timetable_provider.dart`
- Test: `test/models/timetable_settings_test.dart`

**Step 1: Write the failing test**

在 `test/models/timetable_settings_test.dart` 新增断言，覆盖：
- 小组件背景样式默认值
- 小组件是否显示地点/倒计时默认值
- 小组件设置 JSON 序列化与反序列化

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/timetable_settings_test.dart`
Expected: FAIL，提示新字段不存在

**Step 3: Write minimal implementation**

在 `lib/models/timetable_settings.dart` 新增：
- `WidgetBackgroundStyle { glass, solid, gradient }`
- `widgetShowLocation`
- `widgetShowCountdown`
- `widgetBackgroundStyle`

在 `copyWith / defaults / toJson / fromJson` 里补齐。

如有需要，在 `lib/services/storage_service.dart` 和 `lib/providers/timetable_provider.dart` 补默认迁移逻辑，确保老用户升级不丢设置。

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/timetable_settings_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/models/timetable_settings.dart lib/services/storage_service.dart lib/providers/timetable_provider.dart test/models/timetable_settings_test.dart
git commit -m "feat: add widget settings model"
```

### Task 2: 生成原生可消费的今日课表快照

**Files:**
- Modify: `lib/providers/timetable_provider.dart`
- Modify: `lib/models/course.dart` (only if helper methods are needed)
- Create: `lib/services/home_widget_snapshot_service.dart`
- Test: `test/providers/timetable_provider_profiles_test.dart`

**Step 1: Write the failing test**

在 `test/providers/timetable_provider_profiles_test.dart` 新增测试：
- 今天有课时能生成“下一节 + 今日课程列表”
- 正在上课时状态切换为当前课程
- 今日无课时返回无课快照

**Step 2: Run test to verify it fails**

Run: `flutter test test/providers/timetable_provider_profiles_test.dart`
Expected: FAIL，提示快照接口不存在

**Step 3: Write minimal implementation**

新增 `lib/services/home_widget_snapshot_service.dart`，负责：
- 计算今日课程列表
- 计算当前课程 / 下一节课程
- 生成原生友好的 JSON 快照

在 `lib/providers/timetable_provider.dart` 暴露：
- `buildHomeWidgetSnapshot()`
- 在课程、设置、周次变化后触发快照更新

**Step 4: Run test to verify it passes**

Run: `flutter test test/providers/timetable_provider_profiles_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/home_widget_snapshot_service.dart lib/providers/timetable_provider.dart test/providers/timetable_provider_profiles_test.dart
git commit -m "feat: add home widget snapshot builder"
```

### Task 3: 打通 Flutter 到 Android 的小组件同步桥

**Files:**
- Create: `lib/services/home_widget_service.dart`
- Modify: `lib/main.dart`
- Modify: `android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Write the failing test**

如果已有 channel/service 测试基建，补一个最小单元测试；如果没有，至少在计划中要求后续通过手工验证。

**Step 2: Run test to verify it fails**

Run: `flutter analyze --no-fatal-infos`
Expected: 可能出现新 channel 未使用或未定义的错误

**Step 3: Write minimal implementation**

新增 `lib/services/home_widget_service.dart`：
- `syncSnapshot(String json)`
- `scheduleRefresh(...)`
- `clearWidgets()`

在 `MainActivity.kt` 新增 method channel：
- `syncHomeWidgetSnapshot`
- `scheduleHomeWidgetRefresh`
- `clearHomeWidgets`

在 `AndroidManifest.xml` 预留 `AppWidgetProvider` 与刷新 receiver 注册位置。

在 `main.dart` 初始化完成后确保快照可同步。

**Step 4: Run test to verify it passes**

Run: `flutter analyze --no-fatal-infos`
Expected: PASS，最多仅保留仓库原有 info

**Step 5: Commit**

```bash
git add lib/services/home_widget_service.dart lib/main.dart android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt android/app/src/main/AndroidManifest.xml
git commit -m "feat: add home widget sync bridge"
```

### Task 4: 实现 Android 小组件 Provider 与 2×2 布局

**Files:**
- Create: `android/app/src/main/kotlin/com/example/university_timetable/TodayCompactWidgetProvider.kt`
- Create: `android/app/src/main/res/layout/widget_today_compact.xml`
- Create: `android/app/src/main/res/xml/widget_today_compact_info.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Write the failing test**

Android 小组件通常难做自动测试，这一步以静态资源校验和编译通过为目标。

**Step 2: Run test to verify it fails**

Run: `./gradlew :app:compileDebugKotlin`
Expected: FAIL，提示 provider/布局资源不存在

**Step 3: Write minimal implementation**

实现 `2×2` 小组件：
- 显示下一节课主卡
- 点击打开首页
- 无课时显示完整无课卡片
- 使用独立现代化卡片样式，不复用 App 页面布局

在 `RemoteViews` 中使用：
- 课程名
- 时间
- 可选地点或状态文案

**Step 4: Run test to verify it passes**

Run: `./gradlew :app:compileDebugKotlin`
Expected: PASS（若当前环境仍被 Flutter plugin loader 阻塞，则记录为环境问题，改用真机安装验证）

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/example/university_timetable/TodayCompactWidgetProvider.kt android/app/src/main/res/layout/widget_today_compact.xml android/app/src/main/res/xml/widget_today_compact_info.xml android/app/src/main/AndroidManifest.xml
git commit -m "feat: add 2x2 today widget"
```

### Task 5: 实现 2×4 与 4×4 布局

**Files:**
- Create: `android/app/src/main/kotlin/com/example/university_timetable/TodayMediumWidgetProvider.kt`
- Create: `android/app/src/main/kotlin/com/example/university_timetable/TodayLargeWidgetProvider.kt`
- Create: `android/app/src/main/res/layout/widget_today_medium.xml`
- Create: `android/app/src/main/res/layout/widget_today_large.xml`
- Create: `android/app/src/main/res/xml/widget_today_medium_info.xml`
- Create: `android/app/src/main/res/xml/widget_today_large_info.xml`
- Modify: shared widget render helper file if extracted

**Step 1: Write the failing test**

以编译和手工安装验证为主。

**Step 2: Run test to verify it fails**

Run: `./gradlew :app:compileDebugKotlin`
Expected: FAIL，提示新增 provider/资源未实现

**Step 3: Write minimal implementation**

实现：
- `2×4`：主卡 + 后续课程列表
- `4×4`：完整今日课程列表
- 今日无课时显示统一无课视觉
- 课程进行中时主卡切换为当前状态，不继续显示上一节

可以抽出共享 renderer/helper，避免三套 provider 复制逻辑。

**Step 4: Run test to verify it passes**

Run: `./gradlew :app:compileDebugKotlin`
Expected: PASS 或仅受现有环境问题阻塞

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/example/university_timetable/TodayMediumWidgetProvider.kt android/app/src/main/kotlin/com/example/university_timetable/TodayLargeWidgetProvider.kt android/app/src/main/res/layout/widget_today_medium.xml android/app/src/main/res/layout/widget_today_large.xml android/app/src/main/res/xml/widget_today_medium_info.xml android/app/src/main/res/xml/widget_today_large_info.xml
git commit -m "feat: add medium and large today widgets"
```

### Task 6: 实现按时间节点主动刷新

**Files:**
- Create: `android/app/src/main/kotlin/com/example/university_timetable/HomeWidgetRefreshReceiver.kt`
- Modify: `android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/providers/timetable_provider.dart`

**Step 1: Write the failing test**

在 Provider 层补最小测试，验证课程变化时会重新同步快照；原生定时部分以手工验证为主。

**Step 2: Run test to verify it fails**

Run: `flutter test test/providers/timetable_provider_profiles_test.dart`
Expected: FAIL，刷新调度尚未接入

**Step 3: Write minimal implementation**

实现按关键时间点刷新：
- 当前课开始
- 当前课结束
- 下一节课开始
- 今日最后一节课结束

使用 `AlarmManager` 或现有调度逻辑在这些节点触发小组件刷新，而不只依赖系统周期更新。

**Step 4: Run test to verify it passes**

Run: `flutter test test/providers/timetable_provider_profiles_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/example/university_timetable/HomeWidgetRefreshReceiver.kt android/app/src/main/kotlin/com/example/university_timetable/MainActivity.kt android/app/src/main/AndroidManifest.xml lib/providers/timetable_provider.dart
git commit -m "feat: add scheduled home widget refresh"
```

### Task 7: 新增小组件设置页

**Files:**
- Modify: `lib/screens/timetable_settings_screen.dart`
- Modify: `lib/models/timetable_settings.dart`
- Test: `test/models/timetable_settings_test.dart`

**Step 1: Write the failing test**

为小组件设置新增序列化测试：
- 背景样式
- 是否显示地点
- 是否显示倒计时

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/timetable_settings_test.dart`
Expected: FAIL

**Step 3: Write minimal implementation**

在设置页新增“小组件”入口或区块，提供：
- 背景样式：玻璃 / 纯色 / 渐变
- 是否显示地点
- 是否显示倒计时
- 说明点击后打开首页

保存后立即同步小组件快照并触发刷新。

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/timetable_settings_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/screens/timetable_settings_screen.dart lib/models/timetable_settings.dart test/models/timetable_settings_test.dart
git commit -m "feat: add home widget settings"
```

### Task 8: 手工联调与发布前验证

**Files:**
- No code changes required unless issues are found

**Step 1: Verify widget install and render**

Manual:
- 安装 debug 包到真机
- 添加 2×2 / 2×4 / 4×4 三个组件
- 确认点击均可打开首页

**Step 2: Verify refresh timing**

Manual:
- 构造“即将上课 / 正在上课 / 刚下课 / 今日无课”四种场景
- 观察组件是否及时切换，不残留上一节课

**Step 3: Verify style settings**

Manual:
- 切换玻璃 / 纯色 / 渐变
- 切换地点/倒计时显示开关
- 检查三种尺寸是否都更新

**Step 4: Run final checks**

Run:
- `flutter analyze --no-fatal-infos`
- `flutter test test/models/timetable_settings_test.dart`
- `flutter test test/providers/timetable_provider_profiles_test.dart`

Expected:
- 通过，最多仅保留仓库原有 info

**Step 5: Commit**

```bash
git add .
git commit -m "feat: add today home widgets"
```
