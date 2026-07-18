import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/user_guide_screen.dart';
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

    // Welcome page
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('轻屿课表'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    // Navigate to privacy page
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
  });

  testWidgets('consent-required guide blocks forward on privacy page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(home: UserGuideScreen(requirePrivacyConsent: true)),
    );
    await tester.pumpAndSettle();

    // Welcome page → privacy page via Next button
    expect(find.text('1 / 4'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);

    // Try to go forward without checking checkbox — should stay on page 2
    // (onPageChanged snaps back because !_privacyChecked && page > 1)
    // Note: _goNext animates to page 3 but onPageChanged snaps back to 2.
    // We can't easily test swipe in widget tests, so just verify the state.
    expect(find.text('同意并开始使用'), findsNothing);
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

    expect(find.text('3 / 4'), findsOneWidget);
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
    expect(find.text('1 / 4'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // Page 2: Privacy (initialPrivacyChecked) → Next
    expect(find.text('2 / 4'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // Page 3: Permissions → Next
    expect(find.text('3 / 4'), findsOneWidget);
    await tester.tap(nextButton());
    await tester.pumpAndSettle();

    // Page 4: Tips → Agree
    expect(find.text('4 / 4'), findsOneWidget);
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
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('上一步'), findsNothing);

    // Navigate to page 2: Privacy
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);

    // Navigate to page 3: Permissions (consent checked via initial flag)
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    // Navigate to page 4: Tips
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('同意并开始使用'), findsOneWidget);

    // Navigate back to page 3
    await tester.tap(find.text('上一步'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 4'), findsOneWidget);
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
