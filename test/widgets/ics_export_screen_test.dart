import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/data_transfer_screen.dart';
import 'package:university_timetable/screens/ics_export_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 点导出按钮并在弹出的去向菜单里选一项。
  ///
  /// 弹窗锚定在导出按钮旁（showHyperosListPopup），选项文本即菜单行文本。
  /// 注意：按钮在弹窗打开期间一直处于 loading 转圈（repeating 动画），
  /// 弹窗打开阶段只能 pump 定长帧，不能用 pumpAndSettle。
  Future<void> tapExportAndPick(WidgetTester tester, String optionLabel) async {
    final button = find.byKey(const Key('ics-export-share'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(optionLabel).last);
    await tester.pumpAndSettle();
  }

  testWidgets('renders profile, date range, and event type controls', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: IcsExportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课表'), findsWidgets);
    expect(find.text('日期范围'), findsOneWidget);
    expect(find.text('日历内容'), findsOneWidget);
    expect(find.text('课程'), findsOneWidget);
    expect(find.text('考试'), findsOneWidget);
    expect(find.text('日程'), findsOneWidget);
    expect(find.byKey(const Key('ics-export-share')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the HyperOS Miuix date picker for the export range', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: IcsExportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始日期'));
    await tester.pumpAndSettle();

    expect(find.byType(MiuixDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('empty event selection is reported without sharing', (
    tester,
  ) async {
    final provider = _testProvider();
    var shareCalls = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: IcsExportScreen(
            shareCallback: (_) async {
              shareCalls++;
              return const ShareResult('shared', ShareResultStatus.success);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['课程', '考试', '日程']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    final button = find.byKey(const Key('ics-export-share'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(shareCalls, 0);
    expect(find.text('至少选择一种日历内容'), findsOneWidget);
  });

  testWidgets('passes generated ICS data to the share callback', (
    tester,
  ) async {
    final provider = _testProvider();

    ShareParams? sharedParams;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: IcsExportScreen(
            shareCallback: (params) async {
              sharedParams = params;
              return const ShareResult('shared', ShareResultStatus.success);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapExportAndPick(tester, '分享给别人');

    expect(sharedParams, isNotNull);
    expect(sharedParams!.files, hasLength(1));
    final sharedContent = utf8.decode(
      await sharedParams!.files!.single.readAsBytes(),
    );
    expect(sharedContent, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(sharedContent, contains('BEGIN:VEVENT'));
    expect(find.text('已导出并分享 1 个日历事件'), findsOneWidget);
  });

  testWidgets('export button offers the share / save chooser', (tester) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: IcsExportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('ics-export-share'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    // 按钮 loading 转圈是 repeating 动画，弹窗打开阶段不能 pumpAndSettle。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('分享给别人'), findsOneWidget);
    expect(find.text('保存到手机目录'), findsOneWidget);
  });

  testWidgets('save option writes generated ICS without sharing', (
    tester,
  ) async {
    final provider = _testProvider();
    var shareCalls = 0;
    var saveCalls = 0;
    String? savedFileName;
    Uint8List? savedBytes;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: IcsExportScreen(
            shareCallback: (_) async {
              shareCalls++;
              return const ShareResult('shared', ShareResultStatus.success);
            },
            saveCallback: (fileName, bytes) async {
              saveCalls++;
              savedFileName = fileName;
              savedBytes = bytes;
              return '/fake/dir/$fileName';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapExportAndPick(tester, '保存到手机目录');

    expect(shareCalls, 0, reason: '选了保存就不应再调起分享');
    expect(saveCalls, 1);
    expect(savedFileName, endsWith('.ics'));
    expect(utf8.decode(savedBytes!), startsWith('BEGIN:VCALENDAR\r\n'));
    expect(find.text('日历已保存，共 1 个事件'), findsOneWidget);
  });

  testWidgets('cancelling the system save dialog reports cancellation', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: IcsExportScreen(
            saveCallback: (_, _) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapExportAndPick(tester, '保存到手机目录');

    expect(find.text('已取消保存日历'), findsOneWidget);
  });

  testWidgets('exposes calendar export from Backup & Migration', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: DataTransferScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('导出日历'), findsNWidgets(2));
    expect(find.text('选择课程、考试和日程，生成 ICS 日历并分享'), findsOneWidget);
    expect(find.byIcon(Icons.event_outlined), findsNothing);
  });

  testWidgets('Backup & Migration exports the time template when schemes exist', (
    tester,
  ) async {
    final TimetableProvider provider = _FakeTimetableProviderWithSchemes(
      _testProfile(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: DataTransferScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(HyperosButton, '导出时间模板');
    expect(button, findsOneWidget);
    final widget = tester.widget<HyperosButton>(button);
    expect(widget.onPressed, isNotNull);
  });

  testWidgets('Backup & Migration disables the time export without schemes', (
    tester,
  ) async {
    final provider = _testProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: DataTransferScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(HyperosButton, '导出时间模板');
    expect(button, findsOneWidget);
    final widget = tester.widget<HyperosButton>(button);
    expect(widget.onPressed, isNull);
  });

  group('跳过节假日课程开关', () {
    const toggleKey = Key('ics-export-skip-holiday-courses');

    Future<void> pumpScreen(
      WidgetTester tester, {
      required TimetableProvider provider,
    }) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: IcsExportScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('默认关闭，且勾选课程时可见', (tester) async {
      await pumpScreen(tester, provider: _testProvider());

      expect(find.byKey(toggleKey), findsOneWidget);
      expect(find.text('跳过节假日课程'), findsOneWidget);
      final tile = tester.widget<HyperosSwitchTile>(
        find.byKey(toggleKey),
      );
      expect(tile.value, isFalse, reason: '默认不改变导出结果');
    });

    testWidgets('取消勾选「课程」后该开关隐藏（改了不生效的选项不保留）', (
      tester,
    ) async {
      await pumpScreen(tester, provider: _testProvider());
      expect(find.byKey(toggleKey), findsOneWidget);

      await tester.tap(find.text('课程'));
      await tester.pumpAndSettle();

      expect(find.byKey(toggleKey), findsNothing);
    });

    testWidgets('打开开关后摘要出现「已跳过节假日课程」', (tester) async {
      await pumpScreen(tester, provider: _testProvider());
      expect(find.text('已跳过节假日课程'), findsNothing);

      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();

      final tile = tester.widget<HyperosSwitchTile>(
        find.byKey(toggleKey),
      );
      expect(tile.value, isTrue);
      expect(find.text('已跳过节假日课程'), findsOneWidget);
    });

    /// 2026-03-02（周一，第 1 周）设为法定假期；该课表只有这一节课。
    /// 返回类型必须声明为 TimetableProvider：ChangeNotifierProvider.value
    /// 按声明类型注册，子类声明会让屏幕里的 context.read<TimetableProvider>
    /// 抛 ProviderNotFoundException（与 _testProvider() 同理）。
    TimetableProvider holidayProvider() => _HolidayTimetableProvider(
      _testProfile(),
      HolidayData(
        year: 2026,
        version: 1,
        entries: [
          HolidayEntry(
            date: DateTime(2026, 3, 2),
            name: '国庆节',
            type: HolidayType.vacation,
          ),
        ],
      ),
    );

    testWidgets('关闭时照常导出假期当天的课程', (tester) async {
      var shareCalls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: holidayProvider(),
          child: TestApp(
            home: IcsExportScreen(
              shareCallback: (_) async {
                shareCalls++;
                return const ShareResult('shared', ShareResultStatus.success);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapExportAndPick(tester, '分享给别人');

      expect(shareCalls, 1, reason: '默认不过滤，假期当天的课程照常导出');
    });

    testWidgets('开启后假期当天无事件可导出，不会调起分享', (tester) async {
      var shareCalls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: holidayProvider(),
          child: TestApp(
            home: IcsExportScreen(
              shareCallback: (_) async {
                shareCalls++;
                return const ShareResult('shared', ShareResultStatus.success);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 开关在视口外，先 ensureVisible 再 tap（同上）。
      final toggle = find.byKey(toggleKey);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      // 无事件时提示直接弹出，不会进入去向菜单。
      final shareButton = find.byKey(const Key('ics-export-share'));
      await tester.ensureVisible(shareButton);
      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      expect(find.text('分享给别人'), findsNothing);
      expect(shareCalls, 0, reason: '全部课程都被假期过滤掉后不应分享空日历');
      expect(find.text('所选日期范围内没有日历事件'), findsOneWidget);
    });

    testWidgets('测试用「假期状态覆盖」开关开启时不得清空导出（导出忽略该调试开关）', (
      tester,
    ) async {
      // 「诊断 → 实时 → 假期状态覆盖」是**测试**开关：HolidayResolver 在它
      // 开启时把除调休上班日外的每一天都判为假期。若导出继承它，用户测试后
      // 忘了关就会导出一份空日历，且摘要只说「已跳过节假日课程」。
      // 声明类型必须是 TimetableProvider：ChangeNotifierProvider.value 按
      // **声明类型**注册，写成子类会让屏幕里的 read<TimetableProvider>() 抛
      // ProviderNotFoundException（与 holidayProvider() 同款，见其注释）。
      final TimetableProvider overrideProvider = _HolidayTimetableProvider(
        _testProfile(),
        const HolidayData(year: 2026, version: 1, entries: []),
        settingsOverride: TimetableSettings.defaults().copyWith(
          holidayOverrideEnabled: true,
        ),
      );
      var shareCalls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: overrideProvider,
          child: TestApp(
            home: IcsExportScreen(
              shareCallback: (_) async {
                shareCalls++;
                return const ShareResult('shared', ShareResultStatus.success);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = find.byKey(toggleKey);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tapExportAndPick(tester, '分享给别人');

      expect(
        shareCalls,
        1,
        reason: '覆盖开关是调试模拟，导出必须忽略它——否则日历会一节课都不剩',
      );
    });
  });
}

TimeScheme _testScheme() {
  return TimeScheme(
    id: 'widget-share-scheme',
    name: '测试作息',
    sections: const [
      SectionTime(startTime: '08:00', endTime: '08:45'),
    ],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeTimetableProviderWithSchemes extends _FakeTimetableProvider {
  _FakeTimetableProviderWithSchemes(super.profile);

  @override
  List<TimeScheme> get timeSchemes => [_testScheme()];
}

/// 带节假日数据的假 provider，供“跳过节假日课程”用例使用。
class _HolidayTimetableProvider extends _FakeTimetableProvider {
  _HolidayTimetableProvider(super.profile, this._data, {this.settingsOverride});

  final HolidayData _data;

  /// 覆盖 [TimetableProvider.settings] 用。注意：基类的 `settings` 是它自己的
  /// 私有 `_settings` 字段，**不是** `activeProfile.settings`，所以想在一个假
  /// provider 上打开「假期状态覆盖」这类设置，只能覆盖这个 getter——只改
  /// profile 里的 settings 是无效的（用例会静默变成空断言）。
  final TimetableSettings? settingsOverride;

  @override
  HolidayData? get holidayData => _data;

  @override
  TimetableSettings get settings => settingsOverride ?? super.settings;
}

TimetableProfile _testProfile() {
  final now = DateTime(2026, 2);
  return TimetableProfile(
    id: 'ics-widget-profile',
    name: '测试课表',
    courses: [
      Course(
        id: 'ics-widget-course',
        name: 'ICS 测试课程',
        teacher: '测试老师',
        location: 'A101',
        dayOfWeek: DateTime.monday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        endWeek: 1,
      ),
    ],
    settings: TimetableSettings.defaults().copyWith(
      semesterStartDate: DateTime(2026, 3, 2),
      semesterWeekCount: 1,
    ),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
}

TimetableProvider _testProvider() {
  return _FakeTimetableProvider(_testProfile());
}

class _FakeTimetableProvider extends TimetableProvider {
  _FakeTimetableProvider(this._profile)
    : super(autoInitialize: false, enableLiveActivitySync: false);

  final TimetableProfile _profile;

  @override
  List<TimetableProfile> get profiles => [_profile];

  @override
  TimetableProfile? get activeProfile => _profile;

  /// 节假日数据：默认空（无假期）；子类可覆盖。
  @override
  HolidayData? get holidayData => null;
}
