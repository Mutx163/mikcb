import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/user_guide_screen.dart';
import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
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

  testWidgets(
    'settings guide still shows privacy and disclaimer without consent controls',
    (tester) async {
      await tester.pumpWidget(const TestApp(home: UserGuideScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('免责与风险提示'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('隐私、第三方 SDK 与免责说明'), findsOneWidget);
      expect(find.text('免责与风险提示'), findsOneWidget);
      expect(find.textContaining('当前页面不需要再次勾选同意'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('我已阅读并同意友盟相关隐私说明'), findsNothing);
    },
  );

  testWidgets('first-run guide keeps consent checkbox visible', (tester) async {
    await tester.pumpWidget(
      const TestApp(home: UserGuideScreen(requirePrivacyConsent: true)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('免责与风险提示'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('隐私、第三方 SDK 与免责说明'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('我已阅读并同意友盟相关隐私说明'), findsOneWidget);
  });

  testWidgets('auto-start status asks user to confirm in system settings', (
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

    // Navigate to permissions page
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(find.text('系统权限设置'), findsOneWidget);
    expect(find.text('自启动'), findsOneWidget);
    expect(find.text('建议开启'), findsNothing);
    // 自启动现在通过原生 AppOps 真实检测，测试环境非 Android 默认为 true
    expect(find.text('4 / 5 已完成'), findsOneWidget);
    // Verify each permission's status label
    expect(find.text('已开启'), findsNWidgets(2)); // notification + autostart
    expect(find.text('系统已允许'), findsOneWidget); // island
    expect(find.text('无限制'), findsOneWidget); // battery
    expect(find.text('未开启'), findsOneWidget); // keepAlive (test env)
  });

  testWidgets('agree and start returns consent result', (tester) async {
    bool? accepted;

    await tester.pumpWidget(
      TestApp(
        home: _AutoOpenGuide(
          onCompleted: (value) {
            accepted = value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsOneWidget);
    tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsOneWidget);
    tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('同意并开始使用'), findsOneWidget);
    tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed!();
    await tester.pumpAndSettle();

    expect(accepted, isTrue);
    expect(find.text('guide closed'), findsOneWidget);
  });

  testWidgets('page navigation works forward and backward', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: UserGuideScreen(requirePrivacyConsent: true),
      ),
    );
    await tester.pumpAndSettle();

    // Page 1: Privacy
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.text('上一步'), findsNothing); // No back button on first page

    // The checkbox is inside a ListView on the privacy page
    // Scroll within the second Scrollable (the ListView, not the PageView)
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      400,
      scrollable: find.byType(Scrollable).at(1),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Navigate to page 2: Permissions
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);

    // Navigate to page 3: Tips
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);
    expect(find.text('同意并开始使用'), findsOneWidget);

    // Navigate back to page 2
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('language selector appears on first page when provider is available', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const TestApp(home: UserGuideScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('应用语言'), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });

  testWidgets('non-consent guide shows all pages without checkbox', (tester) async {
    await tester.pumpWidget(
      const TestApp(home: UserGuideScreen()),
    );
    await tester.pumpAndSettle();

    // Should show 3 pages even without consent requirement
    expect(find.text('1 / 3'), findsOneWidget);

    // No checkbox on non-consent guide
    expect(find.byType(Checkbox), findsNothing);

    // Can navigate directly without checkbox
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });
}

class _AutoOpenGuide extends StatefulWidget {
  final ValueChanged<bool?> onCompleted;

  const _AutoOpenGuide({required this.onCompleted});

  @override
  State<_AutoOpenGuide> createState() => _AutoOpenGuideState();
}

class _AutoOpenGuideState extends State<_AutoOpenGuide> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const UserGuideScreen(
            requirePrivacyConsent: true,
            initialPrivacyChecked: true,
          ),
        ),
      );
      widget.onCompleted(accepted);
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
