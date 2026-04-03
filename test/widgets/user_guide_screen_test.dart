import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/user_guide_screen.dart';

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
    await tester.pumpWidget(
      const MaterialApp(
        home: UserGuideScreen(),
      ),
    );
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
  });

  testWidgets('first-run guide keeps consent checkbox visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserGuideScreen(requirePrivacyConsent: true),
      ),
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
}
