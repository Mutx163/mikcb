// Bing 每日壁纸的两条日志键必须有中文文案。
//
// `AppLogMessageLocalizer.localizeMessage` 的兜底分支是 `_ => message`
// （app_log_message_localizer.dart:204）——没有分支的键**原样显示**，而这份文本正是
// 「设置 → 应用日志」页与导出 txt（发给维护者的那份）的内容。所以声明了键却忘了
// 接文案，用户在日志页看到的就是 `log_bing_wallpaper_request_failed` 这种蛇形串。
//
// 回归钉在**六种语言**上：这批键一次要动 6 份 arb + localizer 分支，漏一份就有一个
// 语言界面露馅，而中文界面自己看着是好的。

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/logging/app_log_message_localizer.dart';
import 'package:university_timetable/logging/app_log_messages.dart';

const List<Locale> _locales = <Locale>[
  Locale('zh'),
  Locale('zh', 'HK'),
  Locale('zh', 'TW'),
  Locale('en'),
  Locale('ja'),
  Locale('ko'),
];

const List<String> _bingKeys = <String>[
  AppLogMessages.bingWallpaperRequestFailed,
  AppLogMessages.bingWallpaperAutoApplyFailed,
];

Future<AppLocalizations> _localizations(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  test('Bing 壁纸的两条失败日志在六种语言下都不再露出蛇形键', () async {
    for (final locale in _locales) {
      final l10n = await _localizations(locale);
      for (final key in _bingKeys) {
        final text = AppLogMessageLocalizer.localizeMessage(l10n, key);
        expect(
          text,
          isNot(key),
          reason: '$locale 下 $key 没有接上文案，日志页会显示原始键',
        );
        expect(
          text.trim(),
          isNotEmpty,
          reason: '$locale 下 $key 的文案是空的',
        );
      }
    }
  });

  test('兜底分支确实会原样返回——上面那条断言才有意义', () async {
    // 防「测试自己写错了断言」：随便一个没接文案的键必须原样返回。
    final l10n = await _localizations(const Locale('zh'));
    expect(
      AppLogMessageLocalizer.localizeMessage(l10n, 'log_definitely_not_a_key'),
      'log_definitely_not_a_key',
    );
  });
}