import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixBadge;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';
import 'package:university_timetable/widgets/home_top_menu.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'home action menu renders resolved entries as Miuix list rows '
    'without per-row blur',
    (tester) async {
      final anchorKey = GlobalKey();
      final entries = resolveHomeGridMenuEntries(
        TimetableSettings.defaults(),
      );

      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  key: anchorKey,
                  onPressed: () {
                    showHomeTopMenuSheet(
                      context,
                      hasAvailableUpdate: true,
                      entries: entries,
                      anchorKey: anchorKey,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 与八宫格共享同一份自定义排列（默认 8 项，任务清单不在其中）。
      // The anchored popup owns exactly one glass surface — no row adds its
      // own blur while the list moves.
      expect(find.byType(HyperosPressableRow), findsNWidgets(8));
      expect(find.byType(MiuixBadge), findsOneWidget);
      expect(find.byType(HyperosSelectPopupGlass), findsOneWidget);

      for (final title in const [
        '软件更新',
        '课程总览',
        '课程统计',
        '添加课程',
        '考试安排',
        '导入课程',
        '课表设置',
        '请喝咖啡',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('任务清单'), findsNothing);
    },
  );

  testWidgets('home action menu rows remain tappable', (tester) async {
    final anchorKey = GlobalKey();
    late Future<String?> menuResult;
    final entries = resolveHomeGridMenuEntries(
      TimetableSettings.defaults(),
    );

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  menuResult = showHomeTopMenuSheet(
                    context,
                    hasAvailableUpdate: false,
                    entries: entries,
                    anchorKey: anchorKey,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('软件更新'));
    await tester.pumpAndSettle();

    expect(await menuResult, 'update');
  });

  testWidgets(
    'home action menu honors custom order and groups rows by category',
    (tester) async {
      final anchorKey = GlobalKey();
      late Future<String?> menuResult;
      final entries = resolveHomeGridMenuEntries(
        TimetableSettings.defaults().copyWith(
          // copyWith 会钉住 settings，这里断言的是自定义排列顺序本身；
          // tasks(features) → support(about) → settings(preferences)
          // 的分类交界处应各插一个分组间隔。
          homeGridMenuActions: ['tasks', 'support', 'settings'],
        ),
      );

      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  key: anchorKey,
                  onPressed: () {
                    menuResult = showHomeTopMenuSheet(
                      context,
                      hasAvailableUpdate: false,
                      entries: entries,
                      anchorKey: anchorKey,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 只渲染用户选择的入口，顺序与持久化一致。
      expect(find.text('任务清单'), findsOneWidget);
      expect(find.text('请喝咖啡'), findsOneWidget);
      expect(find.text('课表设置'), findsOneWidget);
      expect(find.text('软件更新'), findsNothing);

      await tester.tap(find.text('任务清单'));
      await tester.pumpAndSettle();

      expect(await menuResult, 'tasks');
    },
  );

  testWidgets(
    'liquid menu anchors its single popup with legibility fill',
    (tester) async {
      final anchorKey = GlobalKey();
      const liquidAppearance = FrostedAppearance(
        sheetBlurSigma: 15,
        sheetTintAlpha: 0.7,
        sheetBarrierAlpha: 0.2,
        glassMode: FrostedGlassMode.liquidGlass,
      );

      await tester.pumpWidget(
        TestApp(
          home: FrostedAppearanceScope(
            appearance: liquidAppearance,
            // Keep the appearance scope above this nested navigator so the
            // dialog route can resolve the same liquid-glass settings as the
            // page chrome. The outer TestApp navigator would otherwise place
            // the dialog above this scope.
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: anchorKey,
                    onPressed: () {
                      showHomeTopMenuSheet(
                        context,
                        hasAvailableUpdate: false,
                        entries: resolveHomeGridMenuEntries(
                          TimetableSettings.defaults(),
                        ),
                        anchorKey: anchorKey,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final outerGlass = tester.widget<HyperosLiquidGlassSurface>(
        find.byType(HyperosLiquidGlassSurface),
      );
      expect(outerGlass.role, HyperosLiquidGlassRole.modal);
      // 152cd9b4 起弹窗与 Sheet 的液态玻璃不再叠加可读性衬底，保持通透材质
      // 与首页标题/星期栏统一（选择弹窗同为 contentLegibilityFill=false）。
      expect(outerGlass.contentLegibilityFill, isFalse);
      expect(find.byType(HyperosLiquidGlassSurface), findsOneWidget);
    },
  );

  testWidgets('grid menu renders default eight tiles without tasks entry', (
    tester,
  ) async {
    final anchorKey = GlobalKey();
    late Future<String?> menuResult;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  menuResult = showHomeTopGridMenuSheet(
                    context,
                    hasAvailableUpdate: false,
                    entries: resolveHomeGridMenuEntries(
                      TimetableSettings.defaults(),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // v2.0.5.5 默认排列：8 个瓷贴，任务清单不在其中（列表菜单独有）。
    for (final title in const [
      '软件更新',
      '课程总览',
      '课程统计',
      '添加课程',
      '考试安排',
      '导入课程',
      '课表设置',
      '请喝咖啡',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('任务清单'), findsNothing);
    expect(find.byIcon(Icons.system_update_alt_rounded), findsOneWidget);

    await tester.tap(find.text('课程总览'));
    await tester.pumpAndSettle();

    expect(await menuResult, 'overview');
  });

  testWidgets('grid menu honors custom order and update badge', (tester) async {
    final anchorKey = GlobalKey();
    late Future<String?> menuResult;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  menuResult = showHomeTopGridMenuSheet(
                    context,
                    hasAvailableUpdate: true,
                    entries: resolveHomeGridMenuEntries(
                      TimetableSettings.defaults().copyWith(
                        homeMenuStyle: HomeMenuStyle.grid,
                        // copyWith 会钉住 settings，这里断言的是自定义
                        // 排列顺序本身，settings 在尾部不影响本例。
                        homeGridMenuActions: ['tasks', 'support'],
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // 自定义排列只渲染用户选择的入口，顺序与持久化一致。
    expect(find.text('任务清单'), findsOneWidget);
    expect(find.text('请喝咖啡'), findsOneWidget);
    expect(find.text('软件更新'), findsNothing);

    // 更新角标跟随 hasAvailableUpdate（本例没有更新瓷贴，因此无角标文本）。
    expect(find.text('更新'), findsNothing);

    await tester.tap(find.text('任务清单'));
    await tester.pumpAndSettle();

    expect(await menuResult, 'tasks');
  });
}
