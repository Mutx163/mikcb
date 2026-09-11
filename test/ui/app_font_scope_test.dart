import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/app_fonts.dart';

void main() {
  Widget host({
    required int userWeight,
    required int systemDelta,
    required Widget child,
  }) {
    return AppFontScope(
      userFontWeight: userWeight,
      systemFontWeightDelta: systemDelta,
      fontSpec: const AppFontSpec(fontFamily: 'MiSans'),
      child: child,
    );
  }

  testWidgets('用户非默认字重绝对覆盖，不再反向扣减', (tester) async {
    late AppFontScope scope;
    await tester.pumpWidget(
      host(
        userWeight: 500,
        systemDelta: 0,
        child: Builder(
          builder: (context) {
            scope = AppFontScope.maybeOf(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // 大标题设计 w400 → 用户设 500 时应为 500，而不是 400-500=100。
    expect(scope.resolveWeight(400), 500);
    // 小标题设计 w500 同样绝对覆盖。
    expect(scope.resolveWeight(500), 500);
  });

  testWidgets('默认字重下仅做系统增量补偿', (tester) async {
    late AppFontScope scope;
    await tester.pumpWidget(
      host(
        userWeight: kAppFontWeightDefault,
        systemDelta: 100,
        child: Builder(
          builder: (context) {
            scope = AppFontScope.maybeOf(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(scope.resolveWeight(400), 300);
    expect(scope.resolveWeight(500), 400);
  });

  group('resolveShiftedWeight', () {
    Future<AppFontScope> scopeWith(
      WidgetTester tester, {
      required int userWeight,
      required int systemDelta,
    }) async {
      late AppFontScope scope;
      await tester.pumpWidget(
        host(
          userWeight: userWeight,
          systemDelta: systemDelta,
          child: Builder(
            builder: (context) {
              scope = AppFontScope.maybeOf(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return scope;
    }

    testWidgets('用户调粗时整体平移，标题与详情差值保留', (tester) async {
      final scope = await scopeWith(
        tester,
        userWeight: 500,
        systemDelta: 0,
      );

      // 差值 300 不变：700→800、400→500（绝对覆盖会双双变成 500）。
      expect(scope.resolveShiftedWeight(700), 800);
      expect(scope.resolveShiftedWeight(400), 500);
    });

    testWidgets('用户调细时整体平移，差值保留', (tester) async {
      final scope = await scopeWith(
        tester,
        userWeight: 300,
        systemDelta: 0,
      );

      expect(scope.resolveShiftedWeight(700), 600);
      expect(scope.resolveShiftedWeight(400), 300);
    });

    testWidgets('平移结果钳制在 w100–w900', (tester) async {
      final scope = await scopeWith(tester, userWeight: 900, systemDelta: 0);

      expect(scope.resolveShiftedWeight(700), 900);
      // 上钳制后差值收敛，是有意行为（不能超出字体可用字重）。
      expect(scope.resolveShiftedWeight(400), 900);
      // 低于钳制线的角色不受影响，仍按平移结果走。
      expect(scope.resolveShiftedWeight(100), 600);
    });

    testWidgets('未改字重时与 resolveWeight 同口径（系统增量补偿）', (tester) async {
      final scope = await scopeWith(
        tester,
        userWeight: kAppFontWeightDefault,
        systemDelta: 100,
      );

      expect(
        scope.resolveShiftedWeight(700),
        scope.resolveWeight(700),
      );
      expect(
        scope.resolveShiftedWeight(400),
        scope.resolveWeight(400),
      );
    });
  });

  testWidgets('无 scope 时 Hyperos 样式可回退（不崩溃）', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(AppFontScope.maybeOf(context), isNull);
          return const SizedBox.shrink();
        },
      ),
    );
  });
}
