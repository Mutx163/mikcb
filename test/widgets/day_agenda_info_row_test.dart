import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/day_agenda_info_row.dart';

import '../helpers_test_app.dart';

void main() {
  testWidgets('图标 14px、颜色为 ink 的 0.82 透明', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: DayAgendaInfoRow(
          icon: Icons.person_outline_rounded,
          text: '教师：张三',
          ink: Colors.white,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 14);
    expect(icon.color, Colors.white.withValues(alpha: 0.82));
  });

  testWidgets('图标与文字间距 6', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: DayAgendaInfoRow(
          icon: Icons.location_on_outlined,
          text: 'A 教学楼',
          ink: Colors.white,
        ),
      ),
    );

    // 不能用 find.byType(SizedBox)：Icon 内部也会把自己包进一个 SizedBox。
    // 这里按「宽度 6、高度不约束」精确定位到图标与文字之间那一个。
    final spacer = find.descendant(
      of: find.byType(DayAgendaInfoRow),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 6 && widget.height == null,
      ),
    );
    expect(spacer, findsOneWidget);
  });

  testWidgets('文字 11.5px、ink 的 0.92 透明、单行省略', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: DayAgendaInfoRow(
          icon: Icons.schedule_rounded,
          text: '08:00 - 09:35',
          ink: Colors.black,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('08:00 - 09:35'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.style?.fontSize, 11.5);
    expect(text.style?.fontWeight, FontWeight.w400);
    expect(text.style?.height, 1.15);
    expect(text.style?.color, Colors.black.withValues(alpha: 0.92));
  });

  testWidgets('浮点宽度文字被省略号截断而不是换行', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: SizedBox(
          width: 80,
          child: DayAgendaInfoRow(
            icon: Icons.person_outline_rounded,
            text: '很长的教师名字与节次说明' * 3,
            ink: Colors.white,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('很长的教师名字'), findsOneWidget);
  });
}
