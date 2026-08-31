import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/support_creator_service.dart';
import 'package:university_timetable/widgets/support_donor_tile.dart';

void main() {
  // docs/donors.json 实际数据形态，回归锚点基于它构造。
  SupportDonorEntry entry({
    String name = 'XIAOXIKGB',
    String? amount = '¥8.88',
    String? date = '2026-08-30 14:42:22',
    String? message = '用了半年超级好！',
  }) {
    return SupportDonorEntry(
      name: name,
      amount: amount,
      date: date,
      message: message,
    );
  }

  Future<void> pumpTile(
    WidgetTester tester,
    SupportDonorEntry donor, {
    ThemeData? theme,
    bool first = false,
    bool last = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? ThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: Center(
            child: SupportDonorTile(
              donor: donor,
              isFirst: first,
              isLast: last,
            ),
          ),
        ),
      ),
    );
  }

  Container avatarContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find
          .descendant(of: find.byType(SupportDonorTile), matching: find.byType(Container))
          .first,
    );
  }

  Color avatarBg(WidgetTester tester) {
    final decoration = avatarContainer(tester).decoration! as BoxDecoration;
    return decoration.color!;
  }

  testWidgets('头像取昵称首字符：拉丁转大写、中文取首字、空名回落爱心', (tester) async {
    await pumpTile(tester, entry(name: 'xiaoxi'));
    expect(
      find.descendant(of: find.byType(SupportDonorTile), matching: find.text('X')),
      findsOneWidget,
    );

    await pumpTile(tester, entry(name: '做人要像清水'));
    expect(
      find.descendant(of: find.byType(SupportDonorTile), matching: find.text('做')),
      findsOneWidget,
    );

    await pumpTile(tester, entry(name: ''));
    expect(
      find.descendant(of: find.byType(SupportDonorTile), matching: find.text('♥')),
      findsOneWidget,
    );
  });

  testWidgets('右栏日期截到 yyyy-MM-dd，不渲染时间部分', (tester) async {
    await pumpTile(tester, entry());
    expect(find.text('2026-08-30'), findsOneWidget);
    expect(find.textContaining('14:42'), findsNothing);

    await pumpTile(tester, entry(date: '2026-08-30'));
    expect(find.text('2026-08-30'), findsOneWidget);
  });

  testWidgets('留言独立一行；无留言时不留占位', (tester) async {
    await pumpTile(tester, entry());
    expect(find.text('用了半年超级好！'), findsOneWidget);
    expect(find.text('XIAOXIKGB'), findsOneWidget);

    await pumpTile(tester, entry(message: null));
    expect(find.text('用了半年超级好！'), findsNothing);
    expect(find.text('XIAOXIKGB'), findsOneWidget);
  });

  testWidgets('金额与日期皆缺时右栏整体不占位，仅剩昵称与留言', (tester) async {
    await pumpTile(tester, entry(amount: null, date: null, message: '加油！'));
    expect(find.text('加油！'), findsOneWidget);
    // 右栏由金额或日期驱动，两者皆空时行内只剩左栏一个文字 Column。
    expect(
      find.descendant(of: find.byType(SupportDonorTile), matching: find.byType(Column)),
      findsNWidgets(1),
    );
  });

  testWidgets('头像底色不透明：液态玻璃卡上半透明水洗会透出壁纸发黑（亮/暗双态锚点）', (tester) async {
    await pumpTile(tester, entry());
    expect(avatarBg(tester).a, 1.0);

    await pumpTile(tester, entry(), theme: ThemeData(brightness: Brightness.dark));
    expect(avatarBg(tester).a, 1.0);
  });

  testWidgets('金额用主题 primary 色，昵称用前景色，留言/日期用次级色', (tester) async {
    final theme = ThemeData(brightness: Brightness.light);
    await pumpTile(tester, entry(), theme: theme);

    expect(
      tester.widget<Text>(find.text('¥8.88')).style?.color,
      theme.colorScheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('XIAOXIKGB')).style?.color,
      theme.colorScheme.onSurface,
    );
    expect(
      tester.widget<Text>(find.text('用了半年超级好！')).style?.color,
      theme.colorScheme.onSurfaceVariant,
    );
    expect(
      tester.widget<Text>(find.text('2026-08-30')).style?.color,
      theme.colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('同一昵称头像色确定，不同昵称铺开多种色相（不许全体同色退化）', (tester) async {
    await pumpTile(tester, entry(name: 'Alice'));
    final first = avatarBg(tester);
    await pumpTile(tester, entry(name: 'Alice'));
    expect(avatarBg(tester), first);

    const names = ['Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < names.length; i++)
                SupportDonorTile(
                  donor: SupportDonorEntry(name: names[i]),
                  isFirst: i == 0,
                  isLast: i == names.length - 1,
                ),
            ],
          ),
        ),
      ),
    );

    final distinctColors = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(SupportDonorTile),
            matching: find.byType(Container),
          ),
        )
        .map((container) => (container.decoration! as BoxDecoration).color)
        .toSet();
    expect(distinctColors.length, greaterThanOrEqualTo(3));
  });

  testWidgets('首末行 padding 传入行位标记（列表分隔线由屏幕侧按缩进补齐）', (tester) async {
    await pumpTile(tester, entry(), first: true, last: true);
    expect(find.byType(SupportDonorTile), findsOneWidget);

    // 分隔线缩进契约：16(行内边距) + 38(头像) + 12(间距) 对齐正文左缘。
    expect(SupportDonorTile.dividerIndent, 66.0);
  });
}
