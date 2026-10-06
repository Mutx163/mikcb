import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/screens/course_import_screen.dart';

/// 导入预览的周次摘要必须是本地化的（第 34 轮）。
///
/// `_buildCoursePreviewLine` 里超过 6 周那一支原先写死
/// `'$first-$last（共 $n 周）'`，而同一个函数上两行还在用 `l10n.weekListSeparator`，
/// 六语里也早就有正好对应这句话的键 `availableWeeksCount`
/// （zh「共 {count} 周」/ en "{count} weeks" / ko「총 {count}주」）。
/// 后果：en/ja/ko 用户在整页英文里看到全角括号 + 简体「共 N 周」，
/// zh_TW / zh_HK 也混进简体字形。
void main() {
  final tenWeeks = List<int>.generate(10, (index) => index + 1);

  Future<String> summary(String localeId, {List<int> weeks = const []}) async {
    final l10n = await AppLocalizations.delegate.load(Locale(localeId));
    return importPreviewWeekSummary(
      weeks: weeks,
      weekListSeparator: l10n.weekListSeparator,
      weekNotProvidedLabel: l10n.courseImportWeekNotProvided,
      weeksCountLabel: l10n.availableWeeksCount,
    );
  }

  test('英文环境下不出现中日韩字形', () async {
    final text = await summary('en', weeks: tenWeeks);

    expect(
      RegExp('[\\u4e00-\\u9fff\\u3040-\\u30ff\\uac00-\\ud7af]').hasMatch(text),
      isFalse,
      reason: 'en 摘要里混进了汉字：$text',
    );
    expect(text, contains('1-10'));
    expect(text, contains('10 weeks'));
  });

  test('韩文环境下用本地化的"共 N 周"', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
    final text = await summary('ko', weeks: tenWeeks);

    expect(text, contains(l10n.availableWeeksCount(10)));
    expect(
      RegExp('[\\u4e00-\\u9fff]').hasMatch(text),
      isFalse,
      reason: 'ko 摘要里混进了汉字：$text',
    );
  });

  test('中文环境仍然写"共 N 周"', () async {
    final text = await summary('zh', weeks: tenWeeks);

    expect(text, '1-10 · 共 10 周');
  });

  test('不超 6 周照旧逐个列出，空列表走既有文案', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(
      importPreviewWeekSummary(
        weeks: [1, 3, 5],
        weekListSeparator: l10n.weekListSeparator,
        weekNotProvidedLabel: l10n.courseImportWeekNotProvided,
        weeksCountLabel: l10n.availableWeeksCount,
      ),
      [1, 3, 5].join(l10n.weekListSeparator),
    );
    expect(
      importPreviewWeekSummary(
        weeks: const [],
        weekListSeparator: l10n.weekListSeparator,
        weekNotProvidedLabel: l10n.courseImportWeekNotProvided,
        weeksCountLabel: l10n.availableWeeksCount,
      ),
      l10n.courseImportWeekNotProvided,
    );
  });

  test('接线棘：写死的"（共 N 周）"不得回来', () {
    final source = File(
      'lib/screens/course_import_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains('（共 \${weeks.length} 周）')),
      reason: '又写回了硬编码中文的全角括号摘要',
    );
    expect(
      RegExp('importPreviewWeekSummary\\(').hasMatch(source),
      isTrue,
      reason: 'helper 写了但没接线，等于没修',
    );
  });
}
