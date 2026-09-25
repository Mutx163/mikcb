// 日视图底部「回今日」浮钮：位置（底部居中）、文案、主题色跟随、以及
// 「不许遮住列表最后一张卡」的底部余量。
//
// 背景：这颗钮原先在顶部摘要卡里（浅色胶囊，`primaryContainer` 底色）。
// 现改为日视图底部居中的玻璃浮钮，图标/文字取**外观里选的主题色本身**
// （不是它的浅色调），并在日课表列表底部补一段滚动余量，让最后一项能滑到
// 钮的上方——和底部导航栏一样不遮内容。
//
// 与周视图右下角的「回本周」是两套独立体系：那颗在日视图一律不显示，这颗
// 只在日视图且当前不是今天时出现，也不受「回本周」的浮态透明度设置影响。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_popup_glass.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/utils/theme_seed_accent.dart';

import '../helpers_test_app.dart';

/// 刻意挑一个和默认蓝、和星期栏强调色都不同的绿，验证"跟随主题色"。
const String _themeSeedHex = '#4CAF50';
const Color _themeSeedColor = Color(0xFF4CAF50);

DateTime _startOfCurrentWeek(DateTime now) {
  final normalized = DateTime(now.year, now.month, now.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

String _clock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 浮钮的材质读的是 [FrostedAppearanceScope]，**不是** provider 里的设置
/// （真机上由 `main.dart` 用 `settings.frostedAppearance` 下发这一份）。
/// `TestApp` 不装这个 scope，缺了它 `of(context)` 会回落到 [FrostedAppearance.defaults]
/// 的基础档 —— 那时这颗钮走磨砂片、树里根本没有 [LiquidGlassSurface]。
FrostedAppearance _liquidGlassAppearance() => FrostedAppearance(
  sheetBlurSigma: FrostedAppearance.defaults.sheetBlurSigma,
  sheetTintAlpha: FrostedAppearance.defaults.sheetTintAlpha,
  sheetBarrierAlpha: FrostedAppearance.defaults.sheetBarrierAlpha,
  glassMode: FrostedGlassMode.liquidGlass,
);

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
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

Future<void> _pumpTimetableFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpUntilSettled(
  WidgetTester tester, {
  int maxFrames = 80,
  Duration step = const Duration(milliseconds: 80),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(step);
    if (!tester.binding.hasScheduledFrame) {
      break;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    _seedInitializedPrefs();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
  });

  testWidgets('回今日浮钮：底部居中、跟随主题色、不遮列表最后一项', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();
    final otherDay = today.weekday == 1 ? 2 : today.weekday - 1;

    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
          themeSeedColor: _themeSeedHex,
        ),
      );
      await provider.setCurrentWeek(1);
      // 给相邻那天排 8 门课：列表必然超出视口，才能验证"滑到底不被钮遮"。
      for (var section = 1; section <= 8; section++) {
        await provider.addCourse(
          Course(
            id: 'c$section',
            name: '课程$section',
            teacher: '老师',
            location: 'A10$section',
            dayOfWeek: otherDay,
            startSection: section,
            endSection: section,
            startTime: _clock(7 + section, 0),
            endTime: _clock(7 + section, 45),
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        // 主题色走 ThemeSeedScope（真机由 MaterialApp.builder 挂），这颗钮的
        // 配色就是从它读的，不挂就只能断言到回落色。
        child: const ThemeSeedScope(
          seedHex: _themeSeedHex,
          child: TestApp(
            home: TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);

    // 先停在今天：这颗钮不该出现（已经在今天，没有"回"的意义）。
    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);
    await _pumpUntilSettled(tester);
    expect(
      find.byKey(const ValueKey('back-to-today-button')),
      findsNothing,
      reason: '停在今天时不该有「回今日」',
    );

    // 切到相邻那天。
    await tester.tap(find.byKey(ValueKey('weekday-header-1-$otherDay')));
    await _pumpUntilSettled(tester);

    final buttonFinder = find.byKey(const ValueKey('back-to-today-button'));
    expect(buttonFinder, findsOneWidget, reason: '不是今天时应出现「回今日」');
    expect(find.text('回今日'), findsOneWidget);

    const sourceShadow = HyperosGlassShadow.compactShadow;
    final shadowFinder = find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
        return false;
      }
      return (widget.decoration as BoxDecoration).boxShadow?.contains(
            sourceShadow,
          ) ??
          false;
    });
    expect(shadowFinder, findsOneWidget);
    final shadowClipFinder = find.byKey(
      const ValueKey('back-to-today-shadow'),
    );
    expect(shadowClipFinder, findsOneWidget);
    final buttonSize = tester.getSize(buttonFinder);
    final shadowClip = tester
        .widget<ClipPath>(shadowClipFinder)
        .clipper!
        .getClip(buttonSize);
    expect(shadowClip.contains(buttonSize.center(Offset.zero)), isFalse);
    expect(shadowClip.contains(Offset(buttonSize.width / 2, -1)), isTrue);

    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final buttonRect = tester.getRect(buttonFinder);
    // 形状与底栏同族（胶囊，圆角 = 半高），但比底栏矮一档、窄一圈：
    // 高度约底栏 56 的 2/3，宽度只让文字 + 左右 16 内边距。
    expect(buttonRect.height, moreOrLessEquals(38, epsilon: 1));
    final decoration =
        tester.widget<DecoratedBox>(buttonFinder).decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(19));
    // 这条用例跑在默认档（≈磨砂）：描边**必须留着** —— `HyperosFrostedSurface`
    // 只是一层模糊 + 水洗，自己不画边，去掉这颗钮就没边界了。液态档不画描边，
    // 见「回今日浮钮：液态档不画描边、按窄件压折射」。
    expect(decoration.border, isNotNull);
    debugPrint('[back-to-today] size=${buttonRect.size}');
    expect(
      buttonRect.width,
      lessThan(96),
      reason: '宽度要克制，别让文字悬在大片留白里',
    );
    expect(
      find.descendant(of: buttonFinder, matching: find.byType(Icon)),
      findsNothing,
      reason: '按用户要求去掉箭头，只留文案',
    );
    // 底部居中：水平居中于屏幕，且贴屏幕底部（经典形态留 24 边距）。
    expect(
      (buttonRect.center.dx - screenSize.width / 2).abs(),
      lessThan(2),
      reason: '按钮应水平居中',
    );
    expect(
      buttonRect.bottom,
      greaterThan(screenSize.height - 90),
      reason: '按钮应在屏幕底部（导航栏上方）',
    );

    // 跟随主题色：图标与文字都取外观里选的 seed 本身。
    final labelStyle = tester
        .widget<Text>(find.descendant(of: buttonFinder, matching: find.text('回今日')))
        .style;
    expect(labelStyle?.color, _themeSeedColor);

    // 摘要卡里不再有第二个入口。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('day-view-summary')),
        matching: buttonFinder,
      ),
      findsNothing,
      reason: '顶部摘要卡不该再放「回今日」',
    );

    // 列表滑到底：最后一张卡必须停在按钮上方，不被遮住。
    final listFinder = find.byKey(
      PageStorageKey<String>('day-agenda-1-$otherDay'),
    );
    expect(listFinder, findsOneWidget);
    await tester.drag(listFinder, const Offset(0, -1200));
    await _pumpUntilSettled(tester);

    final lastCard = tester.getRect(
      find.byKey(const ValueKey('day-view-edit-card-c8')),
    );
    expect(
      lastCard.bottom,
      lessThanOrEqualTo(tester.getRect(buttonFinder).top),
      reason: '滑到底后最后一张卡应在「回今日」上方，不被遮挡',
    );

    // 点它回今天：选中天回到今天，钮随之消失。
    await tester.tap(buttonFinder);
    await _pumpUntilSettled(tester);
    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
      reason: '「回今日」应把选中天带回今天',
    );
    expect(
      find.byKey(const ValueKey('back-to-today-button')),
      findsNothing,
      reason: '回到今天后按钮应消失',
    );

    // 秒显示：再从今天滑出去，**手指还没松、刚过页中点**就该出现。
    // 绑的是星期栏同一份页中点预览做局部重建；若把可见性算在整屏 build 里，
    // 这里会读到 0 个（要等 ScrollEnd 落定后的整屏 setState）。
    final swipeRect = tester.getRect(
      find.byKey(const ValueKey('day-view-swipe-area')),
    );
    final swipeDx = swipeRect.width * 0.7 * (today.weekday <= 3 ? -1 : 1);
    final gesture = await tester.startGesture(swipeRect.center);
    // 分两步：先过 touch slop，再走真正的位移。必须拆——页面上有纵向滚动体时
    // 分页的横向识别器不再是竞技场唯一成员，它要到位移超过 slop 才 accept，
    // 而 DragStartBehavior.start 会把 accept 的那一次 move 当作起点吃掉，
    // 单次大 move 会被整段吞掉（真实手指一帧一帧移动，不受影响）。
    await gesture.moveBy(Offset(swipeDx.sign * 24, 0));
    await gesture.moveBy(Offset(swipeDx - swipeDx.sign * 24, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(const ValueKey('back-to-today-button')),
      findsOneWidget,
      reason: '滑过页中点、手指未松时就该出现（不能等落定）',
    );
    await gesture.up();
    await _pumpUntilSettled(tester);
  });

  // 采样源：这颗钮在 `homeStack` 的 `BackdropGroup` 里，但**不能**跟组采样。
  //
  // 组里那张快照是**壁纸**（`UndimmedBackdropCapture` 画在页面主体之前，见
  // `timetable_screen.dart` 的 `homeStack`），快照的屏幕位置固定 ⇒ 跟组采样时
  // 它的背景逐帧一模一样，下面课表怎么滚都不变（用户 2026-09-20 口径「背景永远
  // 都是不变的」）。底栏药丸看着会变，是因为坞层被 `_wrapHomeWithTopMenu` 摆在
  // 采样宿主**之外**、拿不到那个组 —— 它走的是实时采样。这颗钮按用户拍板
  // 「对齐药丸实时采样」，所以 `grouped` 必须是 false。
  testWidgets('回今日浮钮走实时采样：在组里但不跟组采样', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();
    final otherDay = today.weekday == 1 ? 2 : today.weekday - 1;

    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          // 这颗钮只有液态档才走 LiquidGlassSurface，其余档是磨砂片（没有
          // `grouped` 这回事），所以材质必须显式给液态。
          home: FrostedAppearanceScope(
            appearance: _liquidGlassAppearance(),
            child: const TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);
    await tester.tap(find.byKey(ValueKey('weekday-header-1-$otherDay')));
    await _pumpUntilSettled(tester);

    final buttonFinder = find.byKey(const ValueKey('back-to-today-button'));
    expect(buttonFinder, findsOneWidget, reason: '不是今天时应出现「回今日」');

    final surface = tester.widget<LiquidGlassSurface>(
      find.descendant(
        of: buttonFinder,
        matching: find.byType(LiquidGlassSurface),
      ),
    );
    expect(
      surface.grouped,
      isFalse,
      reason: '跟组采样 ⇒ 背景固定成一张壁纸切片，下面怎么滚都不变',
    );
    // 对照组：它**确实**在祖先组里 —— 所以上面那条不是空转断言，
    // 「改回 grouped: true」会真的把背景冻住。
    expect(
      find.ancestor(of: buttonFinder, matching: find.byType(BackdropGroup)),
      findsWidgets,
      reason: '这颗钮在 homeStack 的 BackdropGroup 里，正是"在组里但不跟组"的处境',
    );
  });

  // 「两层圈圈」回归（用户 2026-09-20 报，对着底栏药丸说「完全不一样」）。
  //
  // 两圈是两个不同的东西：**外圈**是这颗钮自己画的 1dp 描边，**内圈**是玻璃的
  // 折射/色散带（绝对 14.5dp，在这颗 38dp 高的钮上占 38%，上下两条几乎连起来）。
  // 同族的底栏药丸 / 坞内圆钮都不画描边、短边 56dp 也不被压折射 —— 所以这颗钮
  // 要同时改两样，只改一样就还差一圈（用户拍板「去描边 + 压折射」）。
  testWidgets('回今日浮钮：液态档不画描边、按窄件压折射', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();
    final otherDay = today.weekday == 1 ? 2 : today.weekday - 1;

    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: TestApp(
          home: FrostedAppearanceScope(
            appearance: _liquidGlassAppearance(),
            child: const TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
            ),
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);
    await tester.tap(find.byKey(ValueKey('weekday-header-1-$otherDay')));
    await _pumpUntilSettled(tester);

    final buttonFinder = find.byKey(const ValueKey('back-to-today-button'));
    expect(buttonFinder, findsOneWidget);

    final decoration =
        tester.widget<DecoratedBox>(buttonFinder).decoration as BoxDecoration;
    expect(
      decoration.border,
      isNull,
      reason: '描边叠在玻璃自己的边光上 ⇒ 外圈那一条硬线（药丸 / 圆钮都没有）',
    );
    expect(
      decoration.boxShadow,
      isNull,
      reason: '同族的药丸 / 圆钮都没有投影',
    );
    expect(
      decoration.borderRadius,
      BorderRadius.circular(19),
      reason: '这层外壳只去掉描边与投影，圆角与键位不变',
    );

    final surface = tester.widget<LiquidGlassSurface>(
      find.descendant(
        of: buttonFinder,
        matching: find.byType(LiquidGlassSurface),
      ),
    );
    expect(
      surface.maxRefraction,
      narrowSurfaceMaxRefraction(38),
      reason: '38dp 矮胶囊要压折射位移，否则内圈那条作用带占满整颗钮',
    );
    expect(surface.maxRefraction, closeTo(10.64, 1e-9));
  });

  // 回归：甩到别的天、惯性还没停就点「回今日」，必须真的有反应。
  // 首版会失败：此时"已落定的选择"还停在今天，_animateDayViewToWeek 的
  // 「已经在目标那天」判断看的是落定值，于是整调用直接 return，用户读到的
  // 就是"点了没反应"，随后惯性照旧把画面带到别的天。
  testWidgets('惯性未停时点回今日也要回到今天', (tester) async {
    final provider = await createInitializedTestProvider(tester);
    final today = DateTime.now();

    await tester.runAsync(() async {
      await provider.updateTimetableSettings(
        provider.settings.copyWith(
          semesterStartDate: _startOfCurrentWeek(today),
          semesterWeekCount: 20,
          timetableHideWeekends: false,
        ),
      );
      await provider.setCurrentWeek(1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(
          home: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    );
    await _pumpTimetableFrame(tester);
    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await _pumpTimetableFrame(tester);
    await _pumpUntilSettled(tester);

    final buttonFinder = find.byKey(const ValueKey('back-to-today-button'));
    expect(buttonFinder, findsNothing, reason: '起点是今天，先没有这颗钮');

    // 甩向同周内的相邻一天：往周中方向甩，避免跨周。
    final goForward = today.weekday <= 3;
    final otherDay = goForward ? today.weekday + 1 : today.weekday - 1;
    final swipeArea = find.byKey(const ValueKey('day-view-swipe-area'));
    await tester.fling(
      swipeArea,
      Offset(goForward ? -400 : 400, 0),
      1200,
    );
    // 只推进一点点：惯性还在跑，选择尚未落定。
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      buttonFinder,
      findsOneWidget,
      reason: '甩过页中点后、惯性未停时就该有「回今日」',
    );

    await tester.tap(buttonFinder);
    await _pumpUntilSettled(tester);

    expect(
      find.byKey(ValueKey('timetable-day-view-1-${today.weekday}')),
      findsOneWidget,
      reason: '惯性未停时点「回今日」也要回到今天（首版在这里无反应）',
    );
    expect(
      find.byKey(ValueKey('timetable-day-view-1-$otherDay')),
      findsNothing,
      reason: '不能停在甩过去的那天',
    );
  });
}
