import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/user_guide_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/services/storage_service.dart';
import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async {
          switch (call.method) {
            case 'checkPromotedSupport':
              return {
                'androidVersion': 15,
                'hasNotificationPermission': true,
                'hasPromotedPermission': true,
                'canPostPromoted': true,
              };
            case 'checkNotificationPermission':
            case 'isIgnoringBatteryOptimizations':
            case 'isKeepAliveAccessibilityEnabled':
            case 'isAutoStartEnabled':
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
  });

  Finder nextButton() => find.text('下一步').last;
  Finder agreeButton() => find.text('同意并开始使用').last;

  testWidgets('non-consent guide shows 4 pages, no checkbox', (tester) async {
    await tester.pumpWidget(const TestApp(home: UserGuideScreen()));
    await tester.pumpAndSettle();

    // Welcome page. Assert the REAL consent tile type — the screen wraps a
    // MiuixCheckbox, so a Material Checkbox finder here was always vacuous.
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('轻屿课表'), findsOneWidget);
    expect(find.byType(HyperosCheckboxTile), findsNothing);

    // Navigate to privacy page
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
  });

  testWidgets('consent-required guide blocks forward on privacy page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(home: UserGuideScreen(requirePrivacyConsent: true)),
    );
    await tester.pumpAndSettle();

    // Welcome page → privacy page via Next button
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);

    // Try to go forward without checking checkbox — should stay on page 2.
    // Pages 3-4 stay unmounted before consent, so a forward swipe dies at a
    // real scroll boundary instead of overshooting and snapping back.
    expect(find.text('同意并开始使用'), findsNothing);
    expect(find.text('3 / 5'), findsNothing);
    expect(find.text('系统权限设置'), findsNothing);

    // Icon badges read the HyperOS palette, not the default Material scheme
    // (regression: M3 seed purple rendered as near-black fills).
    const hyperosPrimary = Color(0xFF3482FF);
    final badge = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.school_rounded),
        matching: find.byType(Container),
      ).first,
    );
    final badgeColor = (badge.decoration! as BoxDecoration).color;
    expect(badgeColor, hyperosPrimary);
  });

  testWidgets('real drag gestures: blocked pre-consent, unlocked after', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(home: UserGuideScreen(requirePrivacyConsent: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);

    // A real horizontal drag toward page 3 stays pinned on the privacy page.
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('3 / 5'), findsNothing);

    // Checking consent unlocks forward dragging. The consent tile sits at
    // the BOTTOM of the privacy page list — scroll it into view first
    // (offscreen sliver children are not built). HyperosCheckboxTile wraps
    // a MiuixCheckbox; there is no Material Checkbox in this screen.
    await tester.dragUntilVisible(
      find.byType(HyperosCheckboxTile),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HyperosCheckboxTile));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 / 5'), findsOneWidget);

    // Returning to the privacy page and unchecking shrinks the pages again
    // while resting exactly on the new boundary — must stay stable.
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    // Page remount reset the inner list offset — scroll down again.
    await tester.dragUntilVisible(
      find.byType(HyperosCheckboxTile),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HyperosCheckboxTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('2 / 5'), findsOneWidget);
  });

  testWidgets('auto-start status shows on permissions page', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: UserGuideScreen(
          requirePrivacyConsent: true,
          initialPrivacyChecked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate: welcome → privacy → permissions
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('系统权限设置'), findsOneWidget);
    expect(find.text('自启动'), findsOneWidget);
    expect(find.textContaining('已就绪'), findsOneWidget);
    expect(find.text('已开启'), findsNWidgets(2));
    expect(find.text('系统已允许'), findsOneWidget);
    expect(find.text('无限制'), findsOneWidget);
    expect(find.text('未开启'), findsOneWidget);
  });

  testWidgets('agree and start returns GuideAction.startUsing', (tester) async {
    GuideAction? action;

    await tester.pumpWidget(
      TestApp(
        home: _AutoOpenGuide(
          onCompleted: (value) {
            action = value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Page 1: Welcome → Next
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // Page 2: Privacy (initialPrivacyChecked) → Next
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // Page 3: Permissions → Next
    expect(find.text('3 / 5'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // Page 4: Personalize → Next（无 Provider 时页面为空但可翻页）
    expect(find.text('4 / 5'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // Page 5: Tips → Agree
    expect(find.text('5 / 5'), findsOneWidget);
    await tester.tap(agreeButton());
    await tester.pumpAndSettle();

    expect(action, GuideAction.startUsing);
    expect(find.text('guide closed'), findsOneWidget);
  });

  testWidgets('page navigation works forward and backward', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: UserGuideScreen(
          requirePrivacyConsent: true,
          initialPrivacyChecked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Page 1: Welcome
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('上一步'), findsNothing);

    // Navigate to page 2: Privacy
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);

    // Navigate to page 3: Permissions (consent checked via initial flag)
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    // Navigate to page 4: Personalize
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('4 / 5'), findsOneWidget);

    // Navigate to page 5: Tips
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('同意并开始使用'), findsOneWidget);

    // Navigate back to page 4, then to page 3
    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 5'), findsOneWidget);
  });

  testWidgets('collapsible header keeps guide content gap aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        home: UserGuideScreen(
          requirePrivacyConsent: true,
          initialPrivacyChecked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    RenderBox headerBox() =>
        tester
                .element(find.byType(HyperosCollapsibleTopAppBar))
                .findRenderObject()
            as RenderBox;
    RenderBox firstGroupBox() =>
        tester.element(find.byType(HyperosListGroup).first).findRenderObject()
            as RenderBox;
    double gap() {
      final header = headerBox();
      final group = firstGroupBox();
      return group.localToGlobal(Offset.zero).dy -
          (header.localToGlobal(Offset.zero).dy + header.size.height);
    }

    expect(gap(), closeTo(8, 0.5));
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -38));
    await tester.pumpAndSettle();
    expect(gap(), closeTo(8, 0.5));

    await tester.drag(list, const Offset(0, 38));
    await tester.pumpAndSettle();
    expect(gap(), closeTo(8, 0.5));

    await tester.drag(list, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(gap(), closeTo(8, 0.5));
  });

  testWidgets('language selector on welcome page with provider', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final provider = await createInitializedTestProvider(tester);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const TestApp(home: UserGuideScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('应用语言'), findsOneWidget);
    expect(find.text('语言选择'), findsOneWidget);
  });

  testWidgets('personalize page renders options and persists choices', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(autoInitialize: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const TestApp(home: UserGuideScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate: welcome → privacy → permissions → personalize
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    expect(find.text('4 / 5'), findsOneWidget);
    // 菜单样式卡随「列表/八宫格」双形态恢复而回归引导页。
    expect(find.text('菜单样式'), findsOneWidget);
    expect(find.text('视觉效果'), findsOneWidget);
    expect(find.text('高斯模糊'), findsOneWidget);
    expect(find.text('液态玻璃'), findsOneWidget);
    expect(find.text('实体卡片'), findsOneWidget);

    // 按目标当前位置精确补偿，把它挪到屏幕竖直 45% 处：既脱离底边
    // 裁剪区，也避开顶部悬浮折叠栏的遮挡区（行高变化时不再依赖
    // 写死的像素偏移）。
    Future<void> tapEffect(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final rect = tester.getRect(find.text(label));
      final shift = screenHeight * 0.45 - rect.center.dy;
      if (shift.abs() > 1) {
        await tester.drag(find.byType(ListView), Offset(0, shift));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    // 菜单样式双形态写入。
    await tester.tap(find.text('八宫格菜单'));
    await tester.pumpAndSettle();
    expect(provider.settings.homeMenuStyle, HomeMenuStyle.grid);
    await tester.tap(find.text('列表菜单'));
    await tester.pumpAndSettle();
    expect(provider.settings.homeMenuStyle, HomeMenuStyle.list);

    // 视觉效果三档映射。统一走 tapEffect（按目标位置精确居中），
    // 避免目标落入悬浮折叠顶栏遮挡区导致点击丢失。
    await tapEffect('高斯模糊');
    expect(provider.settings.frostedBlurEnabled, isTrue);
    expect(provider.settings.frostedGlassMode, FrostedGlassMode.gaussian);

    await tapEffect('液态玻璃');
    expect(provider.settings.frostedBlurEnabled, isTrue);
    expect(provider.settings.frostedGlassMode, FrostedGlassMode.liquidGlass);

    await tapEffect('实体卡片');
    expect(provider.settings.frostedBlurEnabled, isFalse);
  });

  testWidgets('personalize theme mode and seed color persist', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(autoInitialize: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const TestApp(home: UserGuideScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // 深浅色分段控件（懒加载列表：先拖到构建出来，再对齐点击）
    await tester.dragUntilVisible(
      find.text('浅色模式'),
      find.byType(ListView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -90));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色模式'));
    await tester.pumpAndSettle();
    expect(provider.settings.appThemeMode, AppThemeMode.light);

    // 主题色色板：选一个非默认主题（默认 blue）。
    // 色板为 HyperosColorChip，按 ForuiTheme.values 顺序排列。
    final target = ForuiTheme.values
        .where((t) => t != ForuiTheme.blue)
        .first;
    final dotFinder = find.byType(HyperosColorChip);
    await tester.dragUntilVisible(
      dotFinder.last,
      find.byType(ListView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(dotFinder, findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -90));
    await tester.pumpAndSettle();

    // 逐个点色板直到目标主题生效（色板按 ForuiTheme.values 顺序排列）
    for (final theme in ForuiTheme.values) {
      if (provider.settings.foruiTheme == target) break;
      await tester.tap(dotFinder.at(ForuiTheme.values.indexOf(theme)));
      await tester.pumpAndSettle();
    }
    expect(provider.settings.foruiTheme, target);
    expect(
      provider.settings.themeSeedColor,
      target.seedHex,
    );
  });

  testWidgets('welcome page shows import and restore when callbacks provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: UserGuideScreen(
          onImportCourses: () async => false,
          onRestoreBackup: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('轻屿课表'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
    expect(find.text('导入课表'), findsOneWidget);
    expect(find.text('从备份恢复'), findsOneWidget);
  });
}

class _AutoOpenGuide extends StatefulWidget {
  final ValueChanged<GuideAction?> onCompleted;

  const _AutoOpenGuide({required this.onCompleted});

  @override
  State<_AutoOpenGuide> createState() => _AutoOpenGuideState();
}

class _AutoOpenGuideState extends State<_AutoOpenGuide> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final action = await Navigator.of(context).push<GuideAction>(
        MaterialPageRoute(
          builder: (_) => const UserGuideScreen(
            requirePrivacyConsent: true,
            initialPrivacyChecked: true,
          ),
        ),
      );
      widget.onCompleted(action);
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('guide closed')));
  }
}
