import 'package:flutter/material.dart';

import '../services/transfer_diff_service.dart';
import '../services/transfer_package.dart';
import '../ui/hyperos/hyperos.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

/// Shows the shared migration preview and requires an explicit merge or
/// overwrite choice before a transport adapter can apply a package.
Future<TransferApplyMode?> showTransferPreviewDialog({
  required BuildContext context,
  required TransferDiff preview,
  TransferDiff? alternatePreview,
  required TransferPackage incoming,
  String? title,
}) {
  final l10n = AppLocalizations.of(context)!;
  String formatSummary(TransferDiff value) => value.allSummaries
      .map(
        (item) =>
            '${item.kind.value}: +${item.addedCount} / ~${item.updatedCount} / -${item.removedCount}',
      )
      .join('\n');
  final message = [
    l10n.selectImportModeMessage,
    'channel=${incoming.channel.value}',
    'scope=${incoming.scope.value}',
    'transferId=${incoming.packageId}',
    if (alternatePreview != null) ...[
      'merge:\n${formatSummary(alternatePreview)}',
      'overwrite:\n${formatSummary(preview)}',
    ] else
      formatSummary(preview),
  ].join('\n\n');

  return showHyperosDialog<TransferApplyMode>(
    context: context,
    title: title ?? l10n.selectImportModeTitle,
    message: message,
    actions: [
      HyperosDialogAction(
        label: l10n.cancelAction,
        onPressed: () => Navigator.pop(context),
      ),
      HyperosDialogAction(
        label: l10n.selectImportModeMerge,
        onPressed: () => Navigator.pop(context, TransferApplyMode.merge),
      ),
      HyperosDialogAction(
        label: l10n.replaceCurrentTimetable,
        isPrimary: true,
        onPressed: () => Navigator.pop(context, TransferApplyMode.overwrite),
      ),
    ],
  );
}
