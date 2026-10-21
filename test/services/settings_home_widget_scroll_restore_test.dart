// 回归：设置 →「桌面小组件」页下滑再上滑后，预览卡片必须还在。
//
// 用户报的现象（2026-10-21）：「进入以后，下滑再上滑，预览的小组件直接消失了，
// 重新进页面才显示」。
//
// 为什么这条测试放在 test/services/ 而不是 test/widgets/：按 AGENTS.md 的
// TEST-POLICY，widget / screens / ui 三处不再新增测试文件，新测试只落在
// integration_test、services、domain、models、utils。这条钉的是「滚动状态
// 契约」，不是外观，放在这里不违背该策略。
//
// 根因有两条，它们各自都能单独造成「卡片消失」，所以分三条用例分别钉住，
// 避免「修了其中一条，另一条却悄悄退化」：
//
//   1. 保活判据写错（按**列表下标** 0 取预览）——2026-10-21 起「精确闹钟权限」
//      横幅已从页面顶部挪到预览区「添加到桌面」下面，不再是独立列表项，横幅
//      存在时预览仍是第 0 项。但判据若退回「列表下标」，将来任何在预览前面
//      插入分区的改动都会让保活套错对象、预览照旧被回收重建。本用例继续以
//      「横幅存在」形态跑，钉的是判据本身，不是当前布局。
//   2. 两个 Scrollable 共用一份 PageStorage 存档——预览的 PageView 没挂自己的
//      PageStorageKey，往上找到的正是纵向列表的 `hyperos-list-<路由名>`。
//      列表往里写滚动像素、轮播往里写页号，谁后写谁生效。重建时轮播把列表的
//      像素值（实测 1076）当成页号，算出远超内容宽度的位置，一页都构建不出来
//      → 预览整块空白，而下方卡片名与尺寸行照旧还在。
//
// 断言用「屏幕上真的有图」而不是「控件树里有 Image」：故障形态里 Image 可能
// 压根没构建，也可能构建在屏幕外。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/settings/settings_home_widget.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import '../helpers_test_app.dart';

/// 1×1 透明 PNG：够 Image.memory 解码即可，尺寸判断不依赖它。
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const MethodChannel _homeWidgetChannel = MethodChannel(
  'com.mutx163.qingyu/home_widget',
);

/// 预览分区的稳定 key（页面自己挂的，用来在树里认出它）。
const ValueKey<String> _previewSectionKey = ValueKey<String>(
  'homeWidgetPreviewSection',
);

/// 页面逻辑尺寸：窄屏 + 矮屏，让「预览区能被完整滚出视口」必然发生。
const Size _screenSize = Size(400, 780);

void _seedPrefs() {
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

void _mockChannel({required bool exactAlarmGranted}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_homeWidgetChannel, (call) async {
        switch (call.method) {
          case 'canRequestPinWidget':
            return false;
          case 'canScheduleExactAlarms':
            return exactAlarmGranted;
          case 'listTodayWidgetInstances':
            return <Object?>[];
          case 'renderWidgetPreview':
            // 原生侧真实出图要 inflate + 绘制 + PNG 编码，有几十到几百毫秒。
            // 这里留一点延迟，避免「同步返回」掩盖重建期间的时序问题。
            await Future<void>.delayed(const Duration(milliseconds: 150));
            return <String, Object?>{
              'png': _tinyPng,
              'widthDp': 155.0,
              'heightDp': 155.0,
            };
          default:
            return null;
        }
      });
}

/// 屏幕上真正可见（与屏幕矩形相交）的预览图数量。
int _visiblePreviewImages(WidgetTester tester) {
  final images = find.byType(Image).evaluate();
  var visible = 0;
  for (final element in images) {
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) {
      continue;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.overlaps(Offset.zero & _screenSize)) {
      visible++;
    }
  }
  return visible;
}

/// 轮播当前页号；PageView 不在了或 controller 未就绪时返回 null。
double? _currentPage(WidgetTester tester) {
  final pageViews = find.byType(PageView, skipOffstage: false).evaluate();
  if (pageViews.isEmpty) {
    return null;
  }
  final controller = (pageViews.first.widget as PageView).controller;
  if (controller == null || controller.positions.length != 1) {
    return null;
  }
  final position = controller.position;
  if (!position.hasContentDimensions || position.viewportDimension <= 0) {
    return null;
  }
  return position.pixels / position.viewportDimension;
}

/// 页面上所有 Scrollable 各自「往上能找到的 PageStorageKey」。
///
/// 同一个 PageStorage 下，键相同的两个 Scrollable 会互相覆盖存档，这是
/// 根因 2 的直接判据。
List<List<String>> _scrollableStorageKeys(WidgetTester tester) {
  final result = <List<String>>[];
  final elements = find.byType(Scrollable, skipOffstage: false).evaluate();
  for (final element in elements) {
    final keys = <String>[];
    final key = element.widget.key;
    if (key is PageStorageKey) {
      keys.add('${key.value}');
    }
    element.visitAncestorElements((ancestor) {
      final ancestorKey = ancestor.widget.key;
      if (ancestorKey is PageStorageKey) {
        keys.add('${ancestorKey.value}');
      }
      return true;
    });
    result.add(keys);
  }
  return result;
}

Future<void> _pumpSettled(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    _seedPrefs();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_homeWidgetChannel, null);
  });

  /// 两种顶部形态都要覆盖：
  /// - `exactAlarmGranted: true` —— 没有引导横幅，预览在列表第 0 项；
  /// - `false` —— Android 12+ 未授权，横幅占第 0 项，预览被挤到第 1 项。
  ///   真机默认就是这个形态，也正是保活判据写错时失效的那条路。
  for (final granted in [true, false]) {
    final label = granted ? '无精确闹钟横幅' : '有精确闹钟横幅';

    testWidgets('$label：下滑再上滑，预览卡片仍在屏幕上', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(_screenSize);
      _mockChannel(exactAlarmGranted: granted);

      final provider = await createInitializedTestProvider(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const TestApp(home: HomeWidgetSettingsScreen()),
        ),
      );
      await _pumpSettled(tester);

      expect(
        _visiblePreviewImages(tester),
        1,
        reason: '进页后应能看到一张预览卡片',
      );

      final listScrollable = find
          .descendant(
            of: find.byType(HyperosListView).first,
            matching: find.byType(Scrollable),
          )
          .first;

      // 往下滑，把预览区整块滚出视口。
      await tester.drag(listScrollable, const Offset(0, -1200));
      await _pumpSettled(tester, frames: 6);
      expect(
        _visiblePreviewImages(tester),
        0,
        reason: '预览区此时应已滚出屏幕',
      );

      // 再滑回顶部。
      for (var i = 0; i < 8; i++) {
        await tester.drag(listScrollable, const Offset(0, 250));
        await _pumpSettled(tester, frames: 3);
      }

      expect(
        _visiblePreviewImages(tester),
        1,
        reason:
            '滑回顶部后预览卡片必须还在屏幕上。'
            '为 0 说明重建后轮播落到了内容之外（存档被纵向列表的像素值污染）。',
      );
      final page = _currentPage(tester);
      // 先断言非空（重建后 controller 必须已就绪），后面才能把它当数值比较。
      expect(page, isNotNull, reason: '重建后 PageView 应已就绪');
      expect(
        page,
        inInclusiveRange(0.0, 9.0),
        reason: '页号必须落在 10 张卡片的范围内；远超上限说明存档被纵向列表的像素值污染',
      );
      // 不能停在「转圈」或「暂不可用」上。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('预览暂不可用'), findsNothing);
    });
  }

  testWidgets('滚出视口时预览分区必须被保活，而不是丢掉整棵子树', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_screenSize);
    // 用「有横幅」形态：这正是保活判据按列表下标写时会失效的那条路。
    _mockChannel(exactAlarmGranted: false);

    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: HomeWidgetSettingsScreen()),
      ),
    );
    await _pumpSettled(tester);

    // 横幅确实在（2026-10-21 起挂在预览区「添加到桌面」下方，不再是独立列表项）。
    expect(find.textContaining('精确闹钟'), findsWidgets);
    // 横幅必须落在预览分区内（预览区有稳定 ValueKey），而不是列表最前面。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('homeWidgetPreviewSection')),
        matching: find.textContaining('精确闹钟'),
      ),
      findsWidgets,
      reason: '精确闹钟引导应挂在预览分区内（「添加到桌面」之下），不再占列表首项',
    );

    final listScrollable = find
        .descendant(
          of: find.byType(HyperosListView).first,
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.drag(listScrollable, const Offset(0, -1200));
    await _pumpSettled(tester, frames: 6);

    // 保活生效的标志：预览分区已滚出屏幕（onstage 为 0），但**仍在树里**。
    expect(
      find.byKey(_previewSectionKey).evaluate().length,
      0,
      reason: '预览区此时应已滚出屏幕',
    );
    expect(
      find.byKey(_previewSectionKey, skipOffstage: false).evaluate().length,
      1,
      reason:
          '预览分区滚出视口后应被保活留在树上。为 0 说明保活没套到预览上'
          '（顶部横幅占了列表第 0 项时，按列表下标判断会套错对象）。',
    );
  });

  testWidgets('预览轮播必须有自己的滚动存档键，不与纵向列表共用', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(_screenSize);
    _mockChannel(exactAlarmGranted: true);

    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: HomeWidgetSettingsScreen()),
      ),
    );
    await _pumpSettled(tester);

    final keysByScrollable = _scrollableStorageKeys(tester);
    expect(
      keysByScrollable.length,
      greaterThanOrEqualTo(2),
      reason: '这一页至少有纵向列表与横向轮播两个 Scrollable',
    );
    for (final keys in keysByScrollable) {
      expect(
        keys,
        isNotEmpty,
        reason: '每个 Scrollable 都必须落在某个 PageStorageKey 下，否则存档没有归属',
      );
    }
    // 根因 2 的直接判据：任何一个 Scrollable 的键路径都不许与另一个完全相同，
    // 否则它们会往 PageStorage 的同一格里互相覆盖（列表写像素、轮播写页号）。
    final identifiers = keysByScrollable.map((keys) => keys.join('/')).toSet();
    expect(
      identifiers.length,
      keysByScrollable.length,
      reason:
          '两个 Scrollable 的 PageStorage 键路径重复了：它们会互相覆盖滚动存档，'
          '重建时轮播会把纵向列表的像素值当成页号，预览整块空白。',
    );
  });
}
