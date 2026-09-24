import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/widgets/home_menu_route_catalog.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 首页下拉快捷导入的「位置门控」回归。
///
/// 背景：玻璃坞形态会给自适应周课表注入底部滚动余量（药丸占用 62px），
/// 网格由此变成可滚动的 SingleChildScrollView。若此时仍叠加原始竖向
/// 拖拽探测器（_HomePullVerticalDragDetector），任何「向下」手势都会
/// 不计滚动位置地直接把下拉进度累计进快捷导入——用户从页面中部向下
/// 滑、还没把课表滚回顶部，快捷导入（更新）就被触发。
///
/// 修复：有余量（存在可滚动课表）时不再上探测器，改由 Overscroll
/// 通知（自带 atTop 判定）驱动下拉。
///
/// 追加（2026-09-18）：atTop 只说明"这一帧在顶部"，一次**从半路滚回顶部**
/// 的手势滚到顶后 atTop 立刻为真，尾巴那点 overscroll 照样被计入下拉 →
/// 用户读到"我只是滚上去，怎么就刷新了"。现在再叠一层手势起点判定
/// （_homePullGestureStartedAtTop）：只有"按下时就已经在顶部"的那次拖拽
/// 才算下拉，滚回顶部的那一拖整段不计，到顶后要再拉一次。
void main() {
  // 拆分后设置页由库侧登记（生产在 main() 启动时完成）；测试环境直接
  // 调用一次，保证玻璃坞「课表设置」内嵌入口可解析。
  registerSettingsPages(
    settingsScreen: () => const TimetableSettingsScreen(),
    subpageById: settingsSubpageById,
  );

  Future<TimetableProvider> pumpHome({
    required WidgetTester tester,
    required HomeNavigationForm form,
    bool autoFit = true,
  }) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: form,
        glassDockActions: const ['week'],
        // 自适应节高：玻璃坞下网格 + 底部余量 = 可滚动的周课表。
        timetableAutoFitSectionHeight: autoFit,
        homePullQuickImportEnabled: true,
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: FrostedAppearanceScope(
            appearance: FrostedAppearance.defaults,
            child: TimetableScreen(
              enableUpdateCheck: false,
              enableProgressTimer: false,
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

  /// 当前周（第 1 周）的纵向周课表滚动视图。
  Finder weekScroll() =>
      find.byKey(const PageStorageKey<String>('week-scroll-1'));

  /// 周课表纵向滚动位置（测试里玻璃余量 62px，滚走一眼看得出）。
  double weekScrollPixels(WidgetTester tester) {
    return tester
        .state<ScrollableState>(
          find.descendant(of: weekScroll(), matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
  }

  testWidgets('玻璃坞+自适应：下拉开着时手指上移只收下拉，不把列表滚走', (tester) async {
    await pumpHome(tester: tester, form: HomeNavigationForm.glassDock);
    expect(weekScroll(), findsOneWidget);
    expect(weekScrollPixels(tester), 0);

    final gesture = await tester.startGesture(tester.getCenter(weekScroll()));
    // 先过 touch slop，再真正下拉：`DragStartBehavior.start` 会把 slop 那段
    // 吃掉，一次 moveBy 是拉不出药丸的（tester.drag 内部就是这么拆两步的）。
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsOneWidget,
      reason: '下拉已打开',
    );
    expect(weekScrollPixels(tester), 0, reason: '下拉期间列表本就不动');

    // 手指上移 = 想取消：应当只把下拉收回去。修复前这段位移会同时把列表
    // 滚走（读到 62），用户看到的是"我想取消，页面却被滚上去了"。
    await gesture.moveBy(const Offset(0, -150));
    await tester.pump();
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsNothing,
      reason: '上移应收起下拉药丸',
    );
    expect(weekScrollPixels(tester), 0, reason: '收起下拉时列表不能被滚走');

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃坞+自适应：没课的日视图也能下拉打开快捷导入药丸', (tester) async {
    await pumpHome(tester: tester, form: HomeNavigationForm.glassDock);
    final today = DateTime.now();

    // 进日视图：本例没有任何课程，进的是空态那天。
    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final column = find.byKey(ValueKey('day-column-1-${today.weekday}'));
    expect(column, findsOneWidget, reason: '应已进入日视图');

    // 空态下从顶部下拉：空态此前只是个 Padding（不是滚动体），下拉没有着力点，
    // 整条手势无处驱动 → 药丸永远出不来。
    final gesture = await tester.startGesture(tester.getCenter(column));
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsOneWidget,
      reason: '没课的那天也要能下拉导入',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃坞+自适应：网格未回顶部的小幅下拉不应触发快捷导入', (tester) async {
    await pumpHome(tester: tester, form: HomeNavigationForm.glassDock);
    expect(weekScroll(), findsOneWidget);

    // 先上滑把课表滑到底部（玻璃余量 62px 全部吃满）。
    await tester.drag(weekScroll(), const Offset(0, -200));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 此刻网格并不在顶部；向下小幅拖动 60px（不足以把课表滚回顶部，
    // 也就不会产生顶部 overscroll）。
    await tester.drag(weekScroll(), const Offset(0, 60));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 修复后：这次下拉只用于把滚动位置推回顶部，不应打开快捷导入药丸。
    // 修复前：原始探测器不计位置直接累计下拉，药丸当场弹出。
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsNothing,
      reason: '未滑动到顶部的下拉不应触发首页快捷导入（更新）',
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃坞+自适应：一次手势从半路滚回顶部不触发，到顶后再拉才触发', (tester) async {
    await pumpHome(tester: tester, form: HomeNavigationForm.glassDock);
    expect(weekScroll(), findsOneWidget);

    // 先上滑吃满玻璃余量（62px），此刻不在顶部。
    await tester.drag(weekScroll(), const Offset(0, -200));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 一次连续手势：先把课表滚回顶部（62），再继续下拉约 128。
    // 修复前：尾巴那点在顶部的 overscroll 被当成"下拉"，药丸当场弹出——
    // 用户读到的是"我只是滚上去，怎么就刷了"。
    await tester.drag(weekScroll(), const Offset(0, 190));
    await tester.pump();
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsNothing,
      reason: '滚回顶部的那一拖不算下拉，要再拉一下才触发',
    );

    // 到顶后重新拉一次（手势起点在顶部）→ 照常打开药丸。
    await tester.drag(weekScroll(), const Offset(0, 100));
    await tester.pump();
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsOneWidget,
      reason: '到顶部后再拉一次应正常触发',
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('经典形态：手势收尾丢掉时看门狗把药丸收回（不许一直挂着）', (tester) async {
    // 2026-09-22 真机：下拉那颗**进度圈**（本来就是"跟手填充、不旋转"）一直挂着，
    // 不转也不消失。
    //
    // 复现的是"收尾丢掉了"：经典形态（无玻璃坞余量 ⇒ 没有纵向滚动体）走原始拖拽
    // 探测器，而它只在**自己还在跟踪**的那次指针结束时收回。第二根手指落下会把它
    // 的跟踪状态清掉，此后指针被系统 cancel（拉出通知栏 / 边缘返回 / 切应用）就
    // 再没有任何人收回进度 —— 药丸停在半截，没有超时会救它。
    //
    // 看门狗判据不看驱动路：屏上手指清空而进度还没归零 ⇒ 这一轮收尾丢了 ⇒ 收回。
    await pumpHome(
      tester: tester,
      form: HomeNavigationForm.classic,
      autoFit: false,
    );

    final gesture = await tester.startGesture(tester.getCenter(weekScroll()));
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsOneWidget,
      reason: '前置条件：下拉已打开（进度圈挂着）',
    );

    // 第二根手指落下：探测器重置跟踪状态；随后两根指针都被系统取消。
    final second = await tester.startGesture(
      tester.getCenter(weekScroll()) + const Offset(60, 60),
    );
    await tester.pump();
    await gesture.cancel();
    await second.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsNothing,
      reason: '屏幕上一根手指都没有了，进度必须被收回（修复前它一直挂着）',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('经典形态：第二根手指按住时，第一根结束仍收回进度', (tester) async {
    await pumpHome(
      tester: tester,
      form: HomeNavigationForm.classic,
      autoFit: false,
    );

    final first = await tester.startGesture(tester.getCenter(weekScroll()));
    await first.moveBy(const Offset(0, 30));
    await first.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(find.byType(MiuixCircularProgressIndicator), findsOneWidget);

    final second = await tester.startGesture(
      tester.getCenter(weekScroll()) + const Offset(60, 60),
    );
    await tester.pump();
    await first.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsNothing,
      reason: '发起下拉的第一根手指结束，就不能继续等第二根手指',
    );

    await second.cancel();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('经典形态：拉到阈值抬手照常触发（看门狗不能把触发判定吃掉）', (tester) async {
    // 与上一条成对：看门狗管的是"收尾丢了就收回"，不是把功能取消掉。
    // 这条钉：拉到阈值上方抬手，那一刻"够阈值 ⇒ 拉课表"的判定仍要完整走完 ——
    // 药丸切到**不确定态**（progress == null，转圈），而不是被收回或停在进度态。
    await pumpHome(
      tester: tester,
      form: HomeNavigationForm.classic,
      autoFit: false,
    );

    await tester.drag(weekScroll(), const Offset(0, 200));
    await tester.pump();

    final indicator = tester.widget<MiuixCircularProgressIndicator>(
      find.byType(MiuixCircularProgressIndicator),
    );
    expect(indicator.progress, isNull, reason: '够阈值抬手必须真的进入"正在拉课表"的不确定态');

    await tester.pump(const Duration(seconds: 2));
    // ⚠️ 到这里不再断言"药丸消失"：测试环境里那次会话要读本地宏记录，
    // 收尾时机不由这条用例说了算（会话的收尾口径另有 finally 与整场看门狗两层）。
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃坞+自适应：快速带惯性抬手仍按阈值触发', (tester) async {
    // 快速 fling 会让 ScrollEndNotification 紧跟 PointerUp 到达，正好覆盖
    // 玻璃坞形态下最容易出现的“抬手收尾抢在触发判定前面”的时序。
    await pumpHome(
      tester: tester,
      form: HomeNavigationForm.glassDock,
    );
    expect(weekScroll(), findsOneWidget);

    await tester.fling(
      weekScroll(),
      const Offset(0, 300),
      1200,
    );
    await tester.pump();

    final indicator = tester.widget<MiuixCircularProgressIndicator>(
      find.byType(MiuixCircularProgressIndicator),
    );
    expect(
      indicator.progress,
      isNull,
      reason: '快速抬手只要越阈值，就必须进入“正在拉课表”的不确定态，不能被看门狗提前收回',
    );

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃坞+自适应：位于顶部时下拉仍能正常打开快捷导入药丸', (tester) async {
    await pumpHome(tester: tester, form: HomeNavigationForm.glassDock);
    expect(weekScroll(), findsOneWidget);

    // 从顶部直接下拉：回到顶部的 overscroll 应照常驱动下拉药丸。
    await tester.drag(weekScroll(), const Offset(0, 100));
    await tester.pump();

    expect(
      find.byType(MiuixCircularProgressIndicator),
      findsOneWidget,
      reason: '处于顶部时下拉仍应打开快捷导入药丸（修复不能破坏既有入口）',
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
