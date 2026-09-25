import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_tab_bar.dart';
import 'package:university_timetable/widgets/home_menu_route_catalog.dart';

/// 玻璃坞拖到**推入路由**的页面入口后返回：底栏高亮必须回到真实所在页。
///
/// 用户 2026-09-20 报告（原话）：底栏可以滑动切换页面，把底栏滑到「外观编辑」
/// 那一格时，返回是回到切换前所在的页面（日/周视图），**但那个灰色的高亮还
/// 停在外观编辑上**，页面却不是那个了 —— 高亮与页面不一致。
///
/// 「外观编辑」不是常驻内嵌页（不在 `kInlineDockPages`），点它是 `Navigator.push`
/// 推一个新路由；所以父级的 `selectedIndex` 从头到尾都不会变成那一格，指示器
/// 却在拖动期间被直接写到了那一格上。修法见
/// `soft_glass_tab_bar.dart` 的 `_revertUnlessAdopted`。
void main() {
  registerSettingsPages(
    settingsScreen: () => const TimetableSettingsScreen(),
    subpageById: settingsSubpageById,
  );
  TestWidgetsFlutterBinding.ensureInitialized();

  const indicatorKey = ValueKey('soft-glass-tab-indicator');

  /// 连续多帧把弹簧推到静止（`pump(duration)` 单帧读数会停在动画中间）。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  /// 指示器当前的布局左边界；读 `Positioned.left` 而非渲染矩形，避免被
  /// 拖动/按压的 `Transform` 缩放污染。
  double indicatorLeft(WidgetTester tester) =>
      tester.widget<Positioned>(find.byKey(indicatorKey)).left!;

  Future<void> pumpDock(WidgetTester tester, List<String> dockActions) async {
    final provider = TimetableProvider(autoInitialize: false);
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        glassDockActions: dockActions,
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
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(SoftGlassTabBar), findsOneWidget);
  }

  testWidgets('拖到底栏的「外观编辑」槽再返回：高亮必须回到原来的课表槽', (tester) async {
    // 排列：日(0) / 周(1) / 外观编辑(2)。启动在周视图 → 高亮本来在槽 1。
    await pumpDock(tester, const ['day', 'week', 'appearanceEditor']);

    // 拖动前的落点 = 「周课表」槽（后面要比对回到这里）。
    final weekSlotLeft = indicatorLeft(tester);

    // 从「周课表」起拖（起手点必须落在当前选中格内），大幅右拖到最后一格。
    await tester.drag(find.text('周课表'), const Offset(400, 0));
    await tester.pump();
    await settle(tester);

    expect(
      find.byKey(const ValueKey('appearance-editor-preview-card')),
      findsOneWidget,
      reason: '拖到底栏该槽应推入「外观编辑」页',
    );
    // 页面已经推上来了 —— 底栏不该把自己标成停在这一格（它不是常驻页）。
    expect(
      indicatorLeft(tester),
      closeTo(weekSlotLeft, 0.5),
      reason: '推入新路由的入口不是常驻页，指示器不该停在那一格',
    );

    // 返回：回到切换前所在的周视图。
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await settle(tester);

    expect(
      find.byKey(const ValueKey('appearance-editor-preview-card')),
      findsNothing,
      reason: '返回后外观编辑页应已收起',
    );
    expect(
      find.byKey(const PageStorageKey<String>('week-scroll-1')),
      findsOneWidget,
      reason: '返回后应落回周视图',
    );
    // 用户报告的就是这一条：返回后页面是周视图，高亮却还停在外观编辑上。
    expect(
      indicatorLeft(tester),
      closeTo(weekSlotLeft, 0.5),
      reason: '返回后高亮必须与页面一致，停在原来的课表槽上',
    );
  });

  testWidgets('点底栏的「外观编辑」槽：推页必须晚一帧（先把按压光斑收掉）', (
    tester,
  ) async {
    // 用户 2026-09-25 口径：「点击底栏的时候会有亮光，但是亮光对应衔接这个
    // 缩小动画的时候，就会形成闪一下的样子」。那颗亮光是玻璃药丸的按压光斑
    // （`pressGlow`）：进光瞬时、抬手后 140ms 渐隐，所以抬手那刻最亮；而缩放
    // 转场第 0 帧就把整屏烤成快照，"最亮那一帧"被定格 → 光斑亮满 400ms 后突然
    // 消失。
    //
    // 修法是"归零 + 下一帧再推"，本条钉住**那半拍**：点击当帧绝不能已经推上去。
    // 少了它就等于没修——快照照样会拍到最亮的光斑。
    await pumpDock(tester, const ['day', 'week', 'appearanceEditor']);
    expect(find.byKey(const ValueKey('appearance-editor-preview-card')), findsNothing);

    // 真实地点那一格（走 Listener/GestureDetector 的完整路径，不用 tester.tap：
    // tap 是"按下-立刻抬起"，而光斑的瞬时进光要靠 Listener 真的收到 down）。
    final slot = find.text('外观编辑');
    final gesture = await tester.startGesture(tester.getCenter(slot));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('appearance-editor-preview-card')),
      findsNothing,
      reason: '点击当帧就推页 = 光斑归零的重绘还没落地，快照仍会拍到最亮那一帧',
    );

    // 下一帧才推。
    await tester.pump();
    await settle(tester);
    expect(
      find.byKey(const ValueKey('appearance-editor-preview-card')),
      findsOneWidget,
      reason: '晚一帧之后必须照常推入（这条不是"干脆不推了"）',
    );
  });
}
