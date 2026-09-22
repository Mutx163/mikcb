// 「外观与配色」页里的「外观编辑」固定入口（2026-09-22 用户要求）。
//
// 这条入口存在的理由是**不依赖用户的自定义菜单排列**：首页右上角那条目属于
// 用户自己配的八宫格，把它挪掉或换掉就再也找不回来（同一理由下「课表页面」页
// 早就有一条同名入口）。所以这里钉两件事：
// ① 进这一页**首屏**就能看到这行（不用往下滚）；
// ② 点它真的进得去编辑页 —— 编辑页的类是本库私有的，构造或接线写错会静默失败。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

/// 用给定设置起一个「已初始化」的 profile，供设置页读取。
void _seedPrefs(TimetableSettings settings) {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    // 设置库 / 首页里的平台通道在 VM 下没有实现，不 mock 会抛 MissingPluginException。
    for (final channel in const [
      homeWidgetChannel,
      analyticsChannel,
      liveChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  tearDown(() {
    for (final channel in const [
      homeWidgetChannel,
      analyticsChannel,
      liveChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('外观与配色页首屏就有「外观编辑」入口，点它进得去编辑页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _seedPrefs(TimetableSettings.defaults());

    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 设置首页 → 「外观与配色」子页。
    final homeList = find.byType(HyperosListView).first;
    await tester.scrollUntilVisible(
      find.text('外观与配色'),
      200,
      scrollable: find
          .descendant(of: homeList, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(find.text('外观与配色'));
    await tester.pumpAndSettle();

    // 首屏即入口（位置紧跟「预览」组，不用往下滚）。
    expect(find.text('外观编辑'), findsOneWidget);
    // 行尾那句灰字描述已按用户要求去掉（2026-09-22：「灰字描述，不符合软件
    // 标准，去掉」）—— 断言它**不在**，防有人顺手加回来。
    expect(
      find.text('整页微缩预览，改壁纸与材质'),
      findsNothing,
      reason: '入口行只留标题，不挂行尾灰字描述',
    );

    await tester.tap(find.text('外观编辑'));
    await tester.pumpAndSettle();

    // 编辑页的 chrome：顶部「完成」，底部两颗圆钮。
    expect(find.text('完成'), findsOneWidget, reason: '没进到编辑页（或顶栏胶囊没出来）');
    expect(find.text('调整壁纸'), findsOneWidget);
    expect(find.text('材质'), findsOneWidget);
  });
}
