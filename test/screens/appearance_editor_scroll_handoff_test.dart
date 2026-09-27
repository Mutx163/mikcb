// 外观编辑页的「滚动位置交接」：在首页（周视图 / 日视图）滑下去再进编辑页，
// 卡片里那份缩尺首页必须停在**同一个位置**，而不是落定后跳回置顶。
//
// 用户 2026-09-27 反馈：「如果把周视图或者日视图下滑点进去，预览的状态会变成
// 置顶到顶部」。根因：缩尺预览那份首页是**另一条路由里的另一个实例**，它的滚动
// 位置走自己的 `PageStorage` 桶（`ModalRoute` 每条路由一份），与真实首页那份
// 毫无关系 —— 卡片先显示首页快照（滑下去的样子），落定后换成预览自己烤的图
// （停在 0），于是读成「一进编辑页就置顶」。
//
// 修法见 `TimetableHomePreviewScope.scrollOffsets`：真实首页把滚动位置报上来
// （`publishHomeScrollOffset`），编辑页在进页那一刻原样递给预览那份，预览按同一
// 套 key 建自己的滚动控制器。
//
// 这份测试只钉**交接**（位置有没有传过去、传的是不是同一个值）；时序与落定门
// 见 `appearance_editor_layout_test.dart`。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/app_global_settings_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/preview_bake_boundary.dart';
import 'package:university_timetable/widgets/timetable_home_preview_scope.dart';

import '../helpers_test_app.dart';

DateTime _startOfCurrentWeek(DateTime now) {
  final normalized = DateTime(now.year, now.month, now.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

String _clock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

void _seedInitializedPrefs(TimetableSettings settings) {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: settings,
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
  });
}

Future<void> _pumpUntilSettled(
  WidgetTester tester, {
  int maxFrames = 90,
  Duration step = const Duration(milliseconds: 40),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(step);
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
}

/// 某块纵向滚动体的当前位置（无论它用的是内部兜底控制器还是宿主给的）。
double _scrollPixels(WidgetTester tester, Finder scroll) => tester
    .state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)),
    )
    .position
    .pixels;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    AppGlobalSettingsService.resetCacheForTest();
    _seedInitializedPrefs(TimetableSettings.defaults());
    homeScrollOffsets.value = const HomeScrollOffsets.empty();
    for (final channel in const [
      'com.mutx163.qingyu/home_widget',
      'com.mutx163.qingyu/umeng_analytics',
      'com.mutx163.qingyu/miui_live',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(channel),
            (call) async => null,
          );
    }
  });

  tearDown(() {
    for (final channel in const [
      'com.mutx163.qingyu/home_widget',
      'com.mutx163.qingyu/umeng_analytics',
      'com.mutx163.qingyu/miui_live',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  /// 泵起真实首页（第 1 周），外面照 `main.dart` 的真实结构套一层缩放转场壳。
  ///
  /// [courseDay] 非空时给那天排 8 门课（日视图那条列表才有得滚）。
  Future<TimetableProvider> pumpHome(
    WidgetTester tester, {
    int? courseDay,
  }) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();
    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
          // 玻璃坞 + 自适应节高：网格下方补一段药丸占用的余量 → 周课表可滚。
          homeNavigationForm: HomeNavigationForm.glassDock,
          timetableAutoFitSectionHeight: true,
        ),
      );
      await provider.setCurrentWeek(1);
      if (courseDay != null) {
        for (var section = 1; section <= 8; section++) {
          await provider.addCourse(
            Course(
              id: 'c$section',
              name: '课程$section',
              teacher: '老师',
              location: 'A10$section',
              dayOfWeek: courseDay,
              startSection: section,
              endSection: section,
              startTime: _clock(6 + section, 0),
              endTime: _clock(6 + section, 45),
            ),
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    final editor = settingsSubpageById('appearanceEditor');
    expect(editor, isNotNull, reason: '注册表里必须有 appearanceEditor 子页');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance.defaults,
            child: HyperosZoomShrinkScope(
              child: RepaintBoundary(
                child: TimetableScreen(
                  enableUpdateCheck: false,
                  enableProgressTimer: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    return provider;
  }

  /// 走首页菜单那条路把编辑页推上来（缩放转场），并等落定。
  Future<void> pushEditor(WidgetTester tester) async {
    // ignore: unawaited_futures
    Navigator.of(tester.element(find.byType(TimetableScreen))).push<void>(
      HyperosZoomPageRoute<void>(
        builder: (_) => settingsSubpageById('appearanceEditor')!,
      ),
    );
    await tester.pump();
    await _pumpUntilSettled(tester);
    expect(tester.takeException(), isNull);
  }

  /// 预览那份首页（烤图边界底下那棵）里的某块纵向滚动体。
  Finder previewScroll(PageStorageKey<String> key) => find.descendant(
    of: find.byType(PreviewBakeBoundary),
    matching: find.byKey(key),
  );

  testWidgets('周视图：滑下去再进编辑页，预览那份停在同一个位置', (tester) async {
    await pumpHome(tester);
    final homeWeekScroll = find.byKey(
      const PageStorageKey<String>('week-scroll-1'),
    );
    expect(homeWeekScroll, findsOneWidget);

    await tester.drag(homeWeekScroll, const Offset(0, -200));
    await _pumpUntilSettled(tester);
    final homeOffset = _scrollPixels(tester, homeWeekScroll);
    expect(homeOffset, greaterThan(0), reason: '前提：首页确实滑下去了');

    await pushEditor(tester);

    // 编辑页把「进页那一刻」的滚动位置原样递给预览那份。
    final scope = tester.widget<TimetableHomePreviewScope>(
      find.byType(TimetableHomePreviewScope),
    );
    expect(
      scope.scrollOffsets['week-scroll-1'],
      closeTo(homeOffset, 0.5),
      reason: '宿主必须把真实首页的滚动位置递进预览 scope',
    );

    // 预览那份首页的网格滚到同一个位置（修复前是 0 = 置顶）。
    final previewWeekScroll = previewScroll(
      const PageStorageKey<String>('week-scroll-1'),
    );
    expect(previewWeekScroll, findsOneWidget, reason: '预览那份首页也要有周课表');
    expect(
      _scrollPixels(tester, previewWeekScroll),
      closeTo(homeOffset, 0.5),
      reason: '预览必须是同一屏，不能落定后跳回置顶',
    );
  });

  testWidgets('日视图：滑下去再进编辑页，预览那份停在同一个位置', (tester) async {
    final today = DateTime.now();
    final otherDay = today.weekday == 1 ? 2 : today.weekday - 1;
    await pumpHome(tester, courseDay: otherDay);

    // 进那天（相邻一天）的日视图。
    await tester.tap(find.byKey(ValueKey('weekday-header-1-$otherDay')));
    await tester.pump();
    await _pumpUntilSettled(tester);
    final homeDayScroll = find.byKey(
      PageStorageKey<String>('day-agenda-1-$otherDay'),
    );
    expect(homeDayScroll, findsOneWidget, reason: '应已进日视图且那天有课');

    await tester.drag(homeDayScroll, const Offset(0, -600));
    await _pumpUntilSettled(tester);
    final homeOffset = _scrollPixels(tester, homeDayScroll);
    expect(homeOffset, greaterThan(0), reason: '前提：日课表确实滑下去了');

    await pushEditor(tester);

    final scope = tester.widget<TimetableHomePreviewScope>(
      find.byType(TimetableHomePreviewScope),
    );
    expect(
      scope.scrollOffsets['day-agenda-1-$otherDay'],
      closeTo(homeOffset, 0.5),
      reason: '宿主必须把真实首页的滚动位置递进预览 scope',
    );

    final previewDayScroll = previewScroll(
      PageStorageKey<String>('day-agenda-1-$otherDay'),
    );
    expect(previewDayScroll, findsOneWidget, reason: '预览那份也要停在同一天');
    expect(
      _scrollPixels(tester, previewDayScroll),
      closeTo(homeOffset, 0.5),
      reason: '预览必须是同一屏，不能落定后跳回置顶',
    );
  });

  testWidgets('没滑过就进编辑页：预览停在顶部（别把位置搞串）', (tester) async {
    await pumpHome(tester);
    final homeWeekScroll = find.byKey(
      const PageStorageKey<String>('week-scroll-1'),
    );
    expect(_scrollPixels(tester, homeWeekScroll), 0);

    await pushEditor(tester);

    final previewWeekScroll = previewScroll(
      const PageStorageKey<String>('week-scroll-1'),
    );
    expect(_scrollPixels(tester, previewWeekScroll), 0);
  });

  testWidgets('预览自己那份不回灌：预览的滚动不进全局快照', (tester) async {
    // 保护真实首页的位置不被预览覆盖（预览那份也走同一套 key）。
    await pumpHome(tester);
    final homeWeekScroll = find.byKey(
      const PageStorageKey<String>('week-scroll-1'),
    );
    await tester.drag(homeWeekScroll, const Offset(0, -200));
    await _pumpUntilSettled(tester);
    final homeOffset = _scrollPixels(tester, homeWeekScroll);
    expect(homeOffset, greaterThan(0));

    await pushEditor(tester);
    // 预览那份若回灌，全局会被改写成它的位置（此处两者本就相同，所以要再
    // 制造一次差异：把预览那份手动滚走）。
    final previewWeekScroll = previewScroll(
      const PageStorageKey<String>('week-scroll-1'),
    );
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: previewWeekScroll,
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    position.jumpTo(0);
    await tester.pump();
    expect(
      homeScrollOffsets.value['week-scroll-1'],
      closeTo(homeOffset, 0.5),
      reason: '预览那份的滚动不许回灌（否则真实首页的位置会被换成预览的）',
    );
  });
}
