import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/about_screen.dart';
import '../helpers_test_app.dart';

void main() {
  test('split release notes into lazy top-level blocks', () {
    final blocks = splitReleaseNotesIntoBlocks(
      '# v2.0.5.5\n\n'
      '### 新增\n\n'
      '- 第一项\n'
      '  继续说明\n'
      '- 第二项\n\n'
      '### 优化\n\n'
      '- 第三项',
    );

    expect(blocks, const [
      '### 新增',
      '- 第一项\n  继续说明',
      '- 第二项',
      '### 优化',
      '- 第三项',
    ]);
  });

  test(
    'split release notes keeps fenced code and nested list lines together',
    () {
      final blocks = splitReleaseNotesIntoBlocks(
        '### 变更\n\n'
        '- 示例\n'
        '  - 子项\n'
        '  ```dart\n'
        '  # not a heading\n'
        '  ```\n'
        '- 下一项',
      );

      expect(blocks, const [
        '### 变更',
        '- 示例\n  - 子项\n  ```dart\n  # not a heading\n  ```',
        '- 下一项',
      ]);
    },
  );

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

  testWidgets('plain release notes show section headers and indented lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        home: Scaffold(
          body: ReleaseNotesMarkdown(
            plainTypography: true,
            data: '# v1.2.1.1\n\n## 新增\n\n- 第一项\n\n## 优化\n\n- 第二项',
          ),
        ),
      ),
    );

    expect(find.text('v1.2.1.1'), findsNothing);
    expect(find.text('新增'), findsOneWidget);
    expect(find.text('优化'), findsOneWidget);
    expect(find.text('第一项'), findsOneWidget);
    expect(find.text('第二项'), findsOneWidget);
  });
}
