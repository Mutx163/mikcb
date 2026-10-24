// 主路径 6：新建日程 → 点一个快捷模板 → 保存 → 磁盘里那一条就是模板填的
//
// ## 这条路径要证明什么
//
// 用户视角一句话：**打开新建日程，点「组会」，标题和时长自己填好了，点保存能存下去。**
//
// 所以要两头都钉（缺一不可）：
//   1. **界面层**：点模板卡之后，标题输入框里真的是「组会」、结束时刻真的按 60 分钟算好；
//   2. **数据层**：点保存之后，`provider.scheduleItems` 里那一条的 title / 起止时刻
//      **就是模板给的**，不是表单默认值。
//
// 只钉数据层 → 抓不到「模板点了没反应、但用户自己又打了字」；
// 只钉界面层 → 抓不到「界面对了但保存链路把字段吞了」（`_save` 里从 controller
// 重新读 title、从 `_startTime/_endTime` 重新格式化，任一环接错都会丢）。
//
// ## 为什么必须断言「不是默认值」
//
// 表单新建时的默认是「此刻 → 一小时后」，标题为空。如果只断言标题是「组会」，
// 那么「模板压根没接上、但测试自己 enterText 了」也会通过。这里刻意
// **不输入任何标题**：标题只能由模板给，才有资格证明模板真的接线了。
//
// ## 为什么点「组会」而不点别的
//
// 组会 = 60 分钟，与表单默认的「一小时后」**恰好相同**——那样就验不出时长有没有
// 被模板改过。所以选 **聚餐（120 分钟）**：它和默认值不同，套用后结束时刻必须
// 比开始晚 120 分钟。这是「拿一个默认值不会撞上的对照」。
//
// ## 破坏性提醒
//
// 写**真实磁盘**，用的是专用 flavor `itest`（包名 `com.mutx163.qingyu.itest`，
// 与 prod/profile/dev 完全隔离）。纪律与理由见 `README.md` 与
// `add_course_to_home_test.dart` 文件头。
//
// ## 怎么跑
//
//   flutter test integration_test/schedule_quick_preset_test.dart \
//     -d <device-id> --flavor itest
//
// **`-d` 不能省**：不指定时 flutter_tools 会自己挑设备——那是在控制用户的实体设备。
//
// ## 当前状态
//
// 已写、**未在真机上跑**（本次会话没有用户授权的设备）。代码路径与断言都按源码
// 核对过；跑通后请把结果补进 `README.md` 的路径表并删掉这一段。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/domain/schedule_quick_presets.dart';
import 'package:university_timetable/l10n/schedule_preset_localizer.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/add_schedule_item_screen.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/schedule_quick_preset_rail.dart';

/// 套用的模板：聚餐 = 120 分钟。
///
/// 选它是因为 120 ≠ 表单默认的 60，套用之后时长一定发生了变化，「模板真的
/// 改过时长」才有得验。见文件头。
const String _presetId = 'dining';

const Duration _homeRevealTimeout = Duration(seconds: 30);
const Duration _pollStep = Duration(milliseconds: 100);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    StorageService().resetForTesting();
    await StorageService().init();
    // 日程随 profile 落盘，没有独立的 `saveScheduleItems`。这里只清课表，
    // 日程的有无由下面用例里的「保存前没有这条标题」来保证 —— 不要求整个
    // 日程列表为空，因为设备上可能留着上一次跑剩的条目。
    await StorageService().setAcceptedPrivacyPolicy(true);
    await StorageService().setHasSeenUserGuide(true);
    StorageService().resetForTesting();
  });

  testWidgets('点「聚餐」模板 → 标题与两小时时长自动填好 → 保存后磁盘里就是它', (
    tester,
  ) async {
    final preset = scheduleQuickPresetById(_presetId);
    expect(preset, isNotNull, reason: '快捷模板表里没有 $_presetId');
    final expectedDuration = preset!.durationMinutes;

    unawaited(app.main());

    // ---- 1. 冷启动到首页（与既有两条路径同一套等待逻辑） ----
    // 等首页真正换入而不是只等 provider：provider 在 MaterialApp 之上、
    // 启动瞬间就在树上，等它等于没等，下面 `Navigator` 可能还是启动画面的。
    await _pumpUntil(
      tester,
      () => find.byType(TimetableScreen).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '冷启动 ${_homeRevealTimeout.inSeconds}s 内首页未换入',
    );
    final provider = _anyProvider(tester)!;

    // ---- 2. 直接进新建日程页 ----
    //
    // 不走首页菜单：那条要开玻璃弹层、滚到「添加日程」，动画链长且依赖
    // 菜单项顺序。本路径要验的是「模板 → 表单 → 保存」，不是导航。
    // 但页面必须由**真实的 MaterialApp 上下文**承载（主题 / l10n 都要在），
    // 所以用 navigator 推而不是单独 pump 一个 MaterialApp。
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/schedule/add'),
          builder: (_) => const AddScheduleItemScreen(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byType(AddScheduleItemScreen).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      reason: '新建日程页没有打开',
    );
    // 等转场走完（模板卡要真的在屏幕内才点得到）。
    await _pumpUntil(
      tester,
      () {
        final rail = find.byType(ScheduleQuickPresetRail);
        if (rail.evaluate().isEmpty) {
          return false;
        }
        final rect = tester.getRect(rail.first);
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        return rect.top > 0 && rect.top < screen.height;
      },
      timeout: const Duration(seconds: 15),
      reason: '快捷模板轨没进入可视区域（页面转场没走完或模板区没渲染）',
    );

    // ---- 3. 断言前置：模板轨在，且当前没有任何一张卡是选中态 ----
    final railWidget = tester.widget<ScheduleQuickPresetRail>(
      find.byType(ScheduleQuickPresetRail),
    );
    expect(
      railWidget.selectedPresetId,
      isNull,
      reason: '新建时就已有模板处于选中态：初始状态不该预选任何模板',
    );

    // 标题此刻是空的 —— 这是下面「标题只能来自模板」这个断言的前提。
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final expectedTitle = scheduleQuickPresetTitle(l10n, _presetId);
    expect(expectedTitle, isNotEmpty, reason: '模板 $_presetId 没有标题文案');
    expect(
      provider.scheduleItems.any((i) => i.title == expectedTitle),
      isFalse,
      reason:
          '磁盘里已经有标题「$expectedTitle」的日程，本用例的「保存后多出来一条」'
          '会假通过。先清掉上一次跑剩的数据',
    );

    final titleFieldBefore = _titleFieldText(tester);
    expect(
      titleFieldBefore,
      isEmpty,
      reason: '新建日程的标题初始应为空，否则「模板填了标题」验不出来',
    );

    // ---- 4. 点「聚餐」那张卡 ----
    final presetCard = find.byKey(
      const ValueKey('schedule-quick-preset-$_presetId'),
    );
    expect(
      presetCard,
      findsOneWidget,
      reason: '找不到「$_presetId」那张模板卡：卡片 key 变了或该模板没渲染',
    );
    await tester.tap(presetCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // ---- 5. 界面层断言：标题真的被填上了 ----
    await _pumpUntil(
      tester,
      () => _titleFieldText(tester) == expectedTitle,
      timeout: const Duration(seconds: 5),
      reason:
          '点了「$_presetId」模板卡，标题框里却是「${_titleFieldText(tester)}」，'
          '期望「$expectedTitle」：模板没有把标题写进输入框',
    );

    // ---- 6. 界面层断言：选中态落在这张卡上（且只有它） ----
    final railAfter = tester.widget<ScheduleQuickPresetRail>(
      find.byType(ScheduleQuickPresetRail),
    );
    expect(
      railAfter.selectedPresetId,
      _presetId,
      reason: '套用之后模板轨的 selectedPresetId 不是 $_presetId：选中态没跟上',
    );

    // ---- 7. 数据层断言 A：点保存之后 provider 里那一条是模板填的 ----
    //
    // 保存走顶栏 semantics label「保存」（FHeaderAction 里包的 Semantics）。
    final semanticsHandle = tester.ensureSemantics();
    await _pumpUntil(
      tester,
      () {
        final save = find.bySemanticsLabel('保存');
        if (save.evaluate().isEmpty) {
          return false;
        }
        final rect = tester.getRect(save.first);
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        // 顶栏在转场中会停在屏幕外，此时 tap 命中落空且只有一条警告日志。
        return rect.center.dx > 0 &&
            rect.center.dx < screen.width &&
            rect.center.dy > 0 &&
            rect.center.dy < screen.height;
      },
      timeout: const Duration(seconds: 15),
      reason: '保存按钮一直没滑进屏幕（转场没走完或顶栏溢出）',
    );
    await tester.tap(find.bySemanticsLabel('保存'));
    semanticsHandle.dispose();
    await tester.pump();

    await _pumpUntil(
      tester,
      () => provider.scheduleItems.any((i) => i.title == expectedTitle),
      timeout: const Duration(seconds: 15),
      reason:
          '点了保存但 provider.scheduleItems 里没有标题「$expectedTitle」：'
          '保存没落库（校验没过 / 落盘失败 / 保存键没点到）',
    );

    final saved = provider.scheduleItems.firstWhere(
      (i) => i.title == expectedTitle,
    );

    // ---- 8. 数据层断言 B：时长就是模板给的 120 分钟 ----
    //
    // 这一条是整套断言里最要紧的：它同时抓住两件事——
    //   「模板没接上时长」（差值会退回默认的 60 分钟）；
    //   「保存时把算好的结束时刻丢了」（差值会是 0 或别的值）。
    final startMinutes = _asMinutes(saved.startTime);
    final endMinutes = _asMinutes(saved.endTime);
    expect(
      endMinutes - startMinutes,
      expectedDuration,
      reason:
          '存下来的日程时长是 ${endMinutes - startMinutes} 分钟，'
          '期望模板给的 $expectedDuration 分钟（开始 ${saved.startTime}、'
          '结束 ${saved.endTime}）：时长没跟着模板走',
    );

    // ---- 9. 数据层断言 C：颜色也是模板给的 ----
    expect(
      saved.color,
      preset.colorHex,
      reason: '存下来的日程颜色是 ${saved.color}，期望模板色 ${preset.colorHex}',
    );

    // ---- 10. 页面关掉了（保存成功才有 pop） ----
    await _pumpUntil(
      tester,
      () => find.byType(AddScheduleItemScreen).evaluate().isEmpty,
      timeout: const Duration(seconds: 15),
      reason: '保存成功后新建日程页没有关闭',
    );
  });
}

/// 从当前树里取 provider：主页面挂上之后任意一层的 context 都能拿到。
TimetableProvider? _anyProvider(WidgetTester tester) {
  final elements = find.byType(MaterialApp).evaluate();
  if (elements.isEmpty) {
    return null;
  }
  try {
    return Provider.of<TimetableProvider>(elements.first, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

/// 标题输入框当前文本。
///
/// 用「第一个 EditableText」而不是按 key 找：表单里字段顺序是固定的
/// （标题 → 地点 → 备注），标题就是第一个。按 key 需要给生产代码加测试专用
/// Key，那是为测试改产品结构。
String _titleFieldText(WidgetTester tester) {
  final finder = find.byType(EditableText);
  if (finder.evaluate().isEmpty) {
    return '';
  }
  return tester.widget<EditableText>(finder.first).controller.text;
}

/// `"HH:mm"` → 当天分钟数。数据损坏时直接失败（而不是静默当成 0）。
int _asMinutes(String value) {
  final parts = value.split(':');
  expect(parts.length, 2, reason: '时刻「$value」不是 HH:mm 形状');
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  expect(hour, isNotNull, reason: '时刻「$value」的小时部分解析失败');
  expect(minute, isNotNull, reason: '时刻「$value」的分钟部分解析失败');
  return hour! * 60 + minute!;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String reason,
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (condition()) {
      return;
    }
    await tester.pump(_pollStep);
  }
  if (condition()) {
    return;
  }
  fail('$reason（已等待 ${stopwatch.elapsed.inMilliseconds}ms）');
}
