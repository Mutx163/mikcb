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
