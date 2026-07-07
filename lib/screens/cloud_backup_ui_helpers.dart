import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../services/cloud_backup_index_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/course_field_picker_sheet.dart';

enum CloudBackupDetailAction { restore, delete }

class CloudBackupUiHelpers {
  const CloudBackupUiHelpers._();

  static String formatBackupDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String resolveBackupDeviceLabel(
    BuildContext context,
    String deviceLabel,
  ) {
    final trimmed = deviceLabel.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return AppLocalizations.of(context)!.cloudBackupDefaultDeviceLabel;
  }

  static String buildBackupSubtitle(
    BuildContext context,
    CloudBackupEntry entry,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final device = resolveBackupDeviceLabel(context, entry.deviceLabel);
    final summary = entry.profileCount != null && entry.courseCount != null
        ? l10n.cloudBackupSummary(entry.profileCount!, entry.courseCount!)
        : null;
    return summary == null ? device : '$device · $summary';
  }
}

Future<CloudBackupDetailAction?> showCloudBackupDetailSheet({
  required BuildContext context,
  required CloudBackupEntry entry,
  required String deviceLabel,
  required String formattedTime,
}) {
  final l10n = AppLocalizations.of(context)!;
  final summary = entry.profileCount != null && entry.courseCount != null
      ? l10n.cloudBackupSummary(entry.profileCount!, entry.courseCount!)
      : null;

  return showHyperosSheet<CloudBackupDetailAction>(
    context: context,
    builder: (ctx) {
      return PickerSheetScaffold(
        actions: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HyperosButton(
              label: l10n.cloudBackupRestoreAction,
              onPressed: () =>
                  Navigator.pop(ctx, CloudBackupDetailAction.restore),
            ),
            if (!entry.isCurrent) ...[
              const SizedBox(height: 12),
              HyperosButton(
                label: l10n.deleteAction,
                variant: HyperosButtonVariant.destructive,
                onPressed: () =>
                    Navigator.pop(ctx, CloudBackupDetailAction.delete),
              ),
            ],
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.isCurrent
                  ? l10n.cloudBackupCurrentLabel
                  : formattedTime,
              style: HyperosTypography.sheetTitle(context),
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.cloudBackupDetailDevice}: $deviceLabel',
              style: HyperosTypography.listDetail(context),
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.cloudBackupDetailSummary}: $summary',
                style: HyperosTypography.listDetail(context),
              ),
            ],
          ],
        ),
      );
    },
  );
}
