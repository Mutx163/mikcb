import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/ui/hyperos/hyperos_overlay_header.dart';
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';

import '../../helpers_test_app.dart';

void main() {
  testWidgets('overlay header suffix action receives taps through title layer', (
    WidgetTester tester,
  ) async {
    var savePressed = false;

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: HyperosOverlayNestedHeader(
            title: const Text('添加课程'),
            prefixes: [
              FHeaderAction.back(onPress: () {}),
            ],
            suffixes: [
              FHeaderAction(
                icon: const Icon(Icons.check_rounded),
                semanticsLabel: '保存',
                onPress: () => savePressed = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(savePressed, isTrue);
  });
}
