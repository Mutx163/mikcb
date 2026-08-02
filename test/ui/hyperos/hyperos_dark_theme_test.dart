import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';
import 'package:university_timetable/ui/hyperos/widgets/layout.dart';
import 'package:university_timetable/ui/hyperos/widgets/tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dark settings cards stay distinguishable from the page', (
    tester,
  ) async {
    late Color pageColor;
    late Color cardColor;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            pageColor = HyperosColors.scaffoldBackground(context);
            cardColor = HyperosColors.card(context);
            return Scaffold(
              body: HyperosListGroup(
                children: [HyperosNavTile(title: '课表管理', onTap: () {})],
              ),
            );
          },
        ),
      ),
    );

    expect(pageColor, const Color(0xFF242424));
    expect(cardColor, const Color(0xFF2D2D2D));
    expect(cardColor, isNot(pageColor));
    expect(
      HyperosColors.primaryText(tester.element(find.byType(Scaffold))),
      const Color(0xE6FFFFFF),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Material && widget.color == cardColor,
      ),
      findsOneWidget,
    );
  });
}
