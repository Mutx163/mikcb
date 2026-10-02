import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/logging/app_log_message_localizer.dart';
import 'package:university_timetable/logging/app_log_messages.dart';

import '../helpers_test_app.dart';

/// 回归钉（2026-10-02 审查第 8 轮，应用日志的本地化覆盖）：
///
/// `AppLogMessageLocalizer.localizeMessage` 的兜底是 `_ => message`
/// （app_log_message_localizer.dart:103），所以**没有分支的键会被原样显示**：
/// 用户在「设置 → 应用日志」里看到的是 `log_wallpaper_history_import_merge_failed`
/// 这样的英文蛇形键，导出发给维护者的 txt 里也是这一串（这份日志正是给用户
/// 截图/导出用的）。
///
/// 机械对照全仓 `AppLogMessages.*` 的 229 个键与 localizer 的分支，缺 5 条，
/// 且这 5 条全都是**失败/异常**类事件（迁移失败、合并失败、预设跳过），
/// 恰恰是最需要读得懂的那几条。假日日志侧 19 个键全有分支，无缺口。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const unmappedKeys = <String>[
    AppLogMessages.wallpaperHistoryGlobalMigrationFailed,
    AppLogMessages.wallpaperHistoryImportMergeFailed,
    AppLogMessages.appGlobalSettingsMigrationFailed,
    AppLogMessages.liveUpdateTestPresetArmed,
    AppLogMessages.liveUpdateTestPresetSkipped,
  ];

  testWidgets('失败类日志键必须翻成可读文案，不再显示原始键', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    for (final key in unmappedKeys) {
      final text = AppLogMessageLocalizer.localizeMessage(l10n, key);
      expect(text, isNot(key), reason: '$key 仍以原始键显示');
      expect(text, isNot(contains('log_')), reason: '$key 未被本地化');
      expect(text.trim(), isNotEmpty);
    }
  });

  testWidgets('其它语言也不能回落到原始键', (tester) async {
    for (final locale in const [
      Locale('en'),
      Locale('ja'),
      Locale('ko'),
      Locale('zh', 'HK'),
      Locale('zh', 'TW'),
    ]) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      for (final key in unmappedKeys) {
        final text = AppLogMessageLocalizer.localizeMessage(l10n, key);
        expect(
          text,
          isNot(key),
          reason: '${locale.toLanguageTag()} 下 $key 仍以原始键显示',
        );
      }
    }
  });
}
