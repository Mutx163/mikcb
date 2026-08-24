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
    'home action menu keeps nine Miuix list rows without per-row blur',
    (tester) async {
      final anchorKey = GlobalKey();

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

      // Nine Miuix menu rows, one per action; the update row carries the
      // trailing dot badge. The anchored popup owns exactly one glass
      // surface — no row adds its own blur while the list moves.
      expect(find.byType(HyperosPressableRow), findsNWidgets(9));
      expect(find.byType(MiuixBadge), findsOneWidget);
      expect(find.byType(HyperosSelectPopupGlass), findsOneWidget);

      for (final title in const [
        '软件更新',
        '课程总览',
        '课程统计',
        '添加课程',
        '考试安排',
        '导入课程',
        '任务清单',
        '课表设置',
        '请喝咖啡',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
    },
  );

  testWidgets('home action menu rows remain tappable', (tester) async {
    final anchorKey = GlobalKey();
    late Future<HomeTopMenuAction?> menuResult;

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

    expect(await menuResult, HomeTopMenuAction.update);
  });

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
      // 与弹窗/选择 sheet 统一：液态玻璃带内容可读性衬底（暗背景下保持
      // 白色面板观感），不再是无衬底的「透亮」材质。
      expect(outerGlass.contentLegibilityFill, isTrue);
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
