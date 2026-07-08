import '../l10n/app_localizations.dart';

/// 构建课程导入完成后的 Toast 文案（含警告后缀）。
String buildImportResultMessage({
  required AppLocalizations l10n,
  required int importedCount,
  required bool replaceExisting,
  int warningCount = 0,
}) {
  final warningSuffix = warningCount == 0
      ? ''
      : l10n.aiWarningExtraSuffix(warningCount);
  if (importedCount > 0) {
    return replaceExisting
        ? l10n.importOverwriteCount(importedCount) + warningSuffix
        : l10n.importUpdatedCount(importedCount) + warningSuffix;
  }
  return warningCount > 0
      ? l10n.importNoCourseChanges + warningSuffix
      : l10n.importNoCourseChanges;
}
