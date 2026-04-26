# 节假日/调休标记功能 — 开发方案

## 文档信息

| 项目 | 内容 |
|------|------|
| 功能名称 | 节假日/调休标记 |
| 创建日期 | 2026-04-25 |
| 状态 | 方案设计 |
| 优先级 | P1 |

---

## 一、背景与动机

### 1.1 现状问题

当前课表的时间系统仅包含：
- `semesterStartDate` — 学期起始日
- `semesterWeekCount` — 总周数（默认20）
- 周数计算公式：`(today - semesterStartDate).inDays ~/ 7 + 1`

**没有任何节假日概念**。导致：
- 国庆、清明、五一等法定假期内，课表照常显示课程
- 调休上班日（周末补课）不显示课程
- 用户在假期期间收到课前提醒，造成困惑
- 超级岛在假期期间仍显示"下一节课"

### 1.2 竞品参考

WakeUp 课表等竞品已实现：
- 自动标记法定节假日、调休日
- 课表上直接显示"国庆假期"横幅
- 假期期间课程卡片灰显或隐藏

### 1.3 目标

1. 在周视图/日视图中标注法定节假日和调休日
2. 假期期间暂停课前提醒和超级岛更新
3. 桌面小组件在假期显示"假期中"状态
4. 支持内置法定假日数据 + 远程更新

---

## 二、数据模型

### 2.1 HolidayEntry

新增文件：`lib/models/holiday_entry.dart`

```dart
import 'dart:convert';

/// 节假日类型
enum HolidayType {
  /// 法定假期（国庆、清明等），课表灰显/隐藏
  vacation,

  /// 调休上班日（周末但需要上课）
  adjustedWorkday,

  /// 调休休息日（工作日但放假）
  adjustedRestday,
}

extension HolidayTypeX on HolidayType {
  String get value => switch (this) {
    HolidayType.vacation => 'vacation',
    HolidayType.adjustedWorkday => 'adjusted_workday',
    HolidayType.adjustedRestday => 'adjusted_restday',
  };

  static HolidayType fromValue(String? value) {
    return HolidayType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HolidayType.vacation,
    );
  }
}

/// 单日节假日条目
class HolidayEntry {
  /// 日期（仅日期部分，时间归零）
  final DateTime date;

  /// 显示名称，如"国庆节"、"调休上班"
  final String name;

  /// 节假日类型
  final HolidayType type;

  /// 所属假期组 ID（如"national-day-2026"），用于合并显示横幅
  final String? groupId;

  const HolidayEntry({
    required this.date,
    required this.name,
    required this.type,
    this.groupId,
  });

  /// 该日期是否应该隐藏/灰显课程
  bool get shouldHideCourses =>
      type == HolidayType.vacation || type == HolidayType.adjustedRestday;

  /// 该日期是否为调休上班日（需要显示课程）
  bool get isAdjustedWorkday => type == HolidayType.adjustedWorkday;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'name': name,
    'type': type.value,
    'groupId': groupId,
  };

  factory HolidayEntry.fromJson(Map<String, dynamic> json) {
    return HolidayEntry(
      date: DateTime.parse(json['date'] as String),
      name: json['name'] as String,
      type: HolidayTypeX.fromValue(json['type'] as String?),
      groupId: json['groupId'] as String?,
    );
  }
}
```

### 2.2 HolidayData

```dart
/// 年度节假日数据集合
class HolidayData {
  /// 数据年份
  final int year;

  /// 数据版本（用于远程更新比对）
  final int version;

  /// 所有节假日条目
  final List<HolidayEntry> entries;

  const HolidayData({
    required this.year,
    required this.version,
    required this.entries,
  });

  /// 按日期索引查询
  HolidayEntry? entryForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    try {
      return entries.firstWhere(
        (e) => _isSameDate(e.date, dateOnly),
      );
    } catch (_) {
      return null;
    }
  }

  /// 某日期是否为假期（应隐藏课程）
  bool isHoliday(DateTime date) => entryForDate(date)?.shouldHideCourses ?? false;

  /// 某日期是否为调休上班日
  bool isAdjustedWorkday(DateTime date) =>
      entryForDate(date)?.isAdjustedWorkday ?? false;

  /// 获取连续假期组
  List<HolidayEntry> entriesForGroup(String groupId) {
    return entries.where((e) => e.groupId == groupId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Map<String, dynamic> toJson() => {
    'year': year,
    'version': version,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory HolidayData.fromJson(Map<String, dynamic> json) {
    return HolidayData(
      year: json['year'] as int,
      version: json['version'] as int? ?? 1,
      entries: (json['entries'] as List<dynamic>? ?? const [])
          .map((e) => HolidayEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
```

---

## 三、数据源

### 3.1 内置法定假日 JSON

新增文件：`assets/holidays/2026.json`

格式：
```json
{
  "year": 2026,
  "version": 1,
  "entries": [
    {
      "date": "2026-01-01",
      "name": "元旦",
      "type": "vacation",
      "groupId": "new-year-2026"
    },
    {
      "date": "2026-01-02",
      "name": "调休上班",
      "type": "adjusted_workday",
      "groupId": "new-year-2026"
    }
  ]
}
```

**需要收录的节假日（2026年）**：
- 元旦（1.1）
- 春节（1.26-2.1，调休 1.24、2.7 上班）
- 清明节（4.4-4.6）
- 劳动节（5.1-5.5，调休 4.26 上班）
- 端午节（5.31-6.2）
- 中秋节（9.25-9.27）
- 国庆节（10.1-10.7，调休 9.27、10.10 上班）

> 注意：调休日期以国务院办公厅正式通知为准，每年年底公布次年安排。
> 数据来源参考：https://www.gov.cn/

### 3.2 远程更新服务

新增文件：`lib/services/holiday_service.dart`

```dart
class HolidayService {
  static const _remoteUrl = 'https://api.example.com/holidays/';
  static const _cacheKeyPrefix = 'holiday_data_';

  final StorageService _storage;

  HolidayService(this._storage);

  /// 获取指定年份的节假日数据
  /// 优先级：内存缓存 > 本地存储 > 内置资源 > 远程拉取
  Future<HolidayData> getDataForYear(int year) async {
    // 1. 检查本地缓存
    final cached = _loadFromCache(year);
    if (cached != null) return cached;

    // 2. 加载内置资源
    final builtin = await _loadBuiltin(year);

    // 3. 异步拉取远程更新（不阻塞返回）
    _fetchRemoteUpdate(year).then((remote) {
      if (remote != null && remote.version > builtin.version) {
        _saveToCache(year, remote);
      }
    });

    return builtin;
  }

  Future<HolidayData> _loadBuiltin(int year) async {
    final json = await rootBundle.loadString('assets/holidays/$year.json');
    return HolidayData.fromJson(jsonDecode(json));
  }

  Future<HolidayData?> _fetchRemoteUpdate(int year) async {
    try {
      final response = await http.get(Uri.parse('$_remoteUrl$year.json'));
      if (response.statusCode == 200) {
        return HolidayData.fromJson(jsonDecode(response.body));
      }
    } catch (_) {}
    return null;
  }
}
```

### 3.3 pubspec.yaml 变更

```yaml
flutter:
  assets:
    - assets/holidays/     # 新增：内置节假日数据
```

---

## 四、Provider 层集成

### 4.1 TimetableProvider 新增方法

在 `lib/providers/timetable_provider.dart` 中新增：

```dart
// === 节假日相关 ===

HolidayData? _holidayData;

/// 初始化节假日数据
Future<void> _loadHolidayData() async {
  final now = DateTime.now();
  _holidayData = await _holidayService.getDataForYear(now.year);
  notifyListeners();
}

/// 获取指定日期的节假日条目
HolidayEntry? getHolidayForDate(DateTime date) {
  return _holidayData?.entryForDate(date);
}

/// 指定日期是否为假期（应隐藏课程）
bool isHoliday(DateTime date) {
  return _holidayData?.isHoliday(date) ?? false;
}

/// 指定日期是否为调休上班日
bool isAdjustedWorkday(DateTime date) {
  return _holidayData?.isAdjustedWorkday(date) ?? false;
}

/// 获取指定周的假期横幅信息
/// 返回该周内所有连续假期组
List<HolidayBannerInfo> getHolidayBannersForWeek(int week) {
  if (_holidayData == null || _settings.semesterStartDate == null) return [];

  final weekStart = _dateForWeek(week);
  final banners = <HolidayBannerInfo>[];

  for (int i = 0; i < 7; i++) {
    final date = weekStart.add(Duration(days: i));
    final entry = _holidayData!.entryForDate(date);
    if (entry != null && entry.groupId != null) {
      // 合并同组假期为横幅
      if (banners.every((b) => b.groupId != entry.groupId)) {
        final groupEntries = _holidayData!.entriesForGroup(entry.groupId!);
        banners.add(HolidayBannerInfo(
          groupId: entry.groupId!,
          name: entry.name,
          startDate: groupEntries.first.date,
          endDate: groupEntries.last.date,
          type: entry.type,
        ));
      }
    }
  }

  return banners;
}

/// 计算日期对应的周次（第几周）
DateTime _dateForWeek(int week) {
  final start = _settings.semesterStartDate!;
  return _startOfWeek(start).add(Duration(days: (week - 1) * 7));
}
```

### 4.2 LiveUpdate 集成

在超级岛更新逻辑中增加假期判断：

```dart
void _updateLiveActivity() {
  final now = DateTime.now();

  // 假期期间暂停超级岛更新
  if (isHoliday(now)) {
    _clearLiveActivity();
    return;
  }

  // ... 原有逻辑
}
```

### 4.3 桌面小组件集成

在 `HomeWidgetSnapshotService` 中：

```dart
Map<String, dynamic> buildSnapshot() {
  final now = DateTime.now();

  if (_provider.isHoliday(now)) {
    return {
      'type': 'holiday',
      'name': _provider.getHolidayForDate(now)?.name ?? '假期中',
      'date': now.toIso8601String(),
    };
  }

  // ... 原有逻辑
}
```

---

## 五、UI 层

### 5.1 周视图假期横幅

在 `_buildWeekPage` 方法中，当该周存在假期时，在课程网格上方显示横幅：

```dart
Widget _buildHolidayBanner(HolidayBannerInfo banner) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.celebration, size: 16, color: Colors.orange.shade700),
        const SizedBox(width: 8),
        Text(
          '${banner.name}  ${_formatDateRange(banner.startDate, banner.endDate)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
```

### 5.2 课程卡片灰显

在 `_buildDayCourseDisplayItems` 中，当该日期为假期时，课程卡片增加灰显效果：

```dart
// 在 course_card.dart 中新增参数
Widget buildCourseCard({
  required Course course,
  required TimetableSettings settings,
  required int week,
  bool isHoliday = false,      // 新增
  bool isAdjustedWorkday = false, // 新增
}) {
  return Opacity(
    opacity: isHoliday ? 0.3 : 1.0,
    child: Stack(
      children: [
        // 原有卡片内容
        if (isHoliday)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('假期', style: TextStyle(fontSize: 8)),
            ),
          ),
        if (isAdjustedWorkday)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('补班', style: TextStyle(fontSize: 8)),
            ),
          ),
      ],
    ),
  );
}
```

### 5.3 日视图集成

在日视图的日期列表项中，假期日期显示特殊标记：

```dart
// 在日期选择器中
Widget _buildDayChip(DateTime date) {
  final holiday = provider.getHolidayForDate(date);
  return Column(
    children: [
      // 原有日期数字
      if (holiday != null)
        Text(
          holiday.name,
          style: TextStyle(fontSize: 8, color: Colors.orange),
        ),
    ],
  );
}
```

### 5.4 设置页

在 `timetable_settings_screen.dart` 中新增设置项：

```
节假日设置
├── 显示节假日标记 [开关，默认开]
├── 假期期间灰显课程 [开关，默认开]
├── 假期期间暂停提醒 [开关，默认开]
└── 节假日数据版本: 2026 v1 (内置)
    └── 检查更新 [按钮]
```

---

## 六、文件变更清单

| 操作 | 文件路径 | 说明 |
|------|----------|------|
| **新增** | `lib/models/holiday_entry.dart` | HolidayEntry + HolidayData 模型 |
| **新增** | `lib/services/holiday_service.dart` | 节假日数据加载/缓存/远程更新 |
| **新增** | `assets/holidays/2026.json` | 2026年内置法定假日数据 |
| **修改** | `lib/providers/timetable_provider.dart` | 新增节假日查询方法、LiveUpdate 假期判断 |
| **修改** | `lib/screens/timetable_screen.dart` | 周视图横幅、日视图标记 |
| **修改** | `lib/widgets/course_card.dart` | 假期灰显、调休标记 |
| **修改** | `lib/services/home_widget_snapshot_service.dart` | 小组件假期状态 |
| **修改** | `lib/screens/timetable_settings_screen.dart` | 节假日设置项 |
| **修改** | `lib/l10n/app_zh.arb` | 中文翻译 |
| **修改** | `lib/l10n/app_en.arb` | 英文翻译 |
| **修改** | `pubspec.yaml` | assets 声明 |

---

## 七、实现步骤

### Phase 1：数据层（1-2天）
1. 创建 `holiday_entry.dart` 模型
2. 创建 `holiday_service.dart` 服务
3. 整理 2026 年法定假日数据 → `assets/holidays/2026.json`
4. 编写单元测试

### Phase 2：Provider 集成（1天）
5. `TimetableProvider` 新增节假日方法
6. LiveUpdate 假期暂停逻辑
7. 桌面小组件假期状态

### Phase 3：UI 集成（2-3天）
8. 周视图假期横幅
9. 课程卡片灰显效果
10. 日视图日期标记
11. 设置页节假日选项

### Phase 4：收尾（1天）
12. 国际化翻译
13. 边界情况测试（跨年、学期末）
14. 文档更新

---

## 八、风险与注意事项

| 风险 | 应对 |
|------|------|
| 调休日期每年变化 | 内置数据需年度更新；远程拉取兜底 |
| 内置数据有误 | 支持用户手动编辑（未来可做） |
| 跨年学期（秋季学期跨到次年1月） | `HolidayService` 需加载两个年份的数据 |
| 清华等学校有自己的校历 | 预留 `customHolidays` 扩展字段 |
| 性能 | 数据量小（一年约30条），无性能压力 |

---

## 九、测试用例

1. **假期灰显**：设置学期起始日在国庆前，查看第N周是否显示"国庆假期"横幅且课程灰显
2. **调休上班**：设置学期包含调休周末，确认该日显示课程且有"补班"标记
3. **超级岛暂停**：假期日期内，确认不触发 LiveUpdate
4. **小组件状态**：假期日期内，小组件显示"假期中"
5. **跨年加载**：学期跨年时，确认同时加载两年数据
6. **无网络降级**：断网状态下，使用内置数据正常工作
7. **远程更新**：模拟远程版本高于本地，确认自动更新缓存
