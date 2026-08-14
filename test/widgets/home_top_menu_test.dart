import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixBadge;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';
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
    'liquid menu uses clear header glass for its single anchored popup',
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
      expect(outerGlass.contentLegibilityFill, isFalse);
      expect(find.byType(HyperosLiquidGlassSurface), findsOneWidget);
    },
  );
}
