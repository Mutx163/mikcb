import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/import_result_message.dart';
import 'package:university_timetable/l10n/app_localizations_zh.dart';

void main() {
  test('buildImportResultMessage appends warnings when no courses imported', () {
    final l10n = AppLocalizationsZh();

    expect(
      buildImportResultMessage(
        l10n: l10n,
        importedCount: 0,
        replaceExisting: false,
        warningCount: 2,
      ),
      '${l10n.importNoCourseChanges}${l10n.aiWarningExtraSuffix(2)}',
    );
  });

  test('buildImportResultMessage reports merge count with warnings', () {
    final l10n = AppLocalizationsZh();

    expect(
      buildImportResultMessage(
        l10n: l10n,
        importedCount: 3,
        replaceExisting: false,
        warningCount: 1,
      ),
      '${l10n.importUpdatedCount(3)}${l10n.aiWarningExtraSuffix(1)}',
    );
  });
}
