import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/about_screen.dart';
import '../helpers_test_app.dart';

void main() {
  testWidgets('release notes render markdown content', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: Scaffold(
          body: ReleaseNotesMarkdown(
            data: '# 更新标题\n\n- 第一项\n- 第二项\n\n[查看详情](https://example.com)',
          ),
        ),
      ),
    );

    expect(find.text('更新标题'), findsOneWidget);
    expect(find.text('第一项'), findsOneWidget);
    expect(find.text('第二项'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
  });
}
