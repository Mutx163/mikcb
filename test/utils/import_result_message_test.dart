import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/import_result_message.dart';
import 'package:university_timetable/l10n/app_localizations_zh.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';

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

  test('rollback incomplete reports recovery failure', () {
    final l10n = AppLocalizationsZh();
    final message = localizeServiceMessage(
      l10n,
      'import_rollback_incomplete',
    );

    expect(message, l10n.serviceMsgImportRollbackIncomplete);
    expect(message, isNot(contains('文件有效')));
  });

  test('row warnings keep the field name of the inner code', () {
    // Regression: encodeServiceRowWarning nests the inner payload inside the
    // outer one, and both levels use the same `|` separator, so parseServiceMessage
    // flattened the inner args into the outer map. The recursion did not pass
    // them down, so every field_must_be_integer / field_cannot_be_empty row
    // warning rendered with an empty field name.
    final l10n = AppLocalizationsZh();
    final message = localizeServiceMessage(
      l10n,
      encodeServiceRowWarning(7, 'field_must_be_integer', args: {
        'field': 'start_section',
      }),
    );

    expect(message, contains('7'));
    expect(
      message,
      contains(l10n.serviceMsgFieldStartSection),
      reason: '内层的 {field} 必须显示出来，而不是空字符串',
    );
    expect(message, isNot(contains('：，')));
  });
}
