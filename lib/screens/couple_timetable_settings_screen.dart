import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:provider/provider.dart';

import '../models/partner_timetable_binding.dart';
import '../providers/timetable/couple_timetable_logic.dart';
import '../providers/timetable_provider.dart';
import '../services/partner_timetable_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';

class CoupleTimetableSettingsScreen extends StatefulWidget {
  const CoupleTimetableSettingsScreen({super.key});

  @override
  State<CoupleTimetableSettingsScreen> createState() =>
      _CoupleTimetableSettingsScreenState();
}

class _CoupleTimetableSettingsScreenState
    extends State<CoupleTimetableSettingsScreen> {
  static const _coupleColorChoices = [
    '#2196F3',
    '#2563EB',
    '#4CAF50',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF5722',
    '#795548',
    '#607D8B',
    '#F44336',
  ];

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isUnlinking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final binding = provider.partnerBinding;
    final partnerProfile = provider.partnerProfile;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.coupleTimetableTitle),
      child: HyperosListView(
        children: [
          HyperosControlCard(
            title: binding == null
                ? l10n.coupleTimetableUnboundTitle
                : l10n.coupleTimetableBoundTitle,
            subtitle: l10n.coupleTimetableIntro,
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (binding != null) ...[
                    _buildInfoRow(
                      context,
                      l10n.coupleTimetablePartnerNameLabel,
                      partnerProfile?.name ?? binding.partnerName,
                    ),
                    _buildInfoRow(
                      context,
                      l10n.courseCountBullet(
                        partnerProfile?.courses.length ?? 0,
                      ),
                      binding.lastImportedAt == null
                          ? '-'
                          : _formatDateTime(binding.lastImportedAt!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    l10n.coupleTimetablePrivacyHint,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            title: l10n.coupleTimetableTitle,
            child: HyperosControlCardInset(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  HyperosButton(
                    label: _isExporting
                        ? '${l10n.coupleTimetableExportForPartner}...'
                        : l10n.coupleTimetableExportForPartner,
                    loading: _isExporting,
                    onPressed: _isExporting ? null : _exportForPartner,
                  ),
                  HyperosButton(
                    label: _isImporting
                        ? '${l10n.coupleTimetableImportPartner}...'
                        : l10n.coupleTimetableImportPartner,
                    variant: HyperosButtonVariant.secondary,
                    loading: _isImporting,
                    onPressed: _isImporting ? null : _importPartner,
                  ),
                  if (binding != null)
                    HyperosButton(
                      label: _isUnlinking
                          ? '${l10n.coupleTimetableUnlink}...'
                          : l10n.coupleTimetableUnlink,
                      variant: HyperosButtonVariant.secondary,
                      loading: _isUnlinking,
                      onPressed: _isUnlinking ? null : _confirmUnlink,
                    ),
                ],
              ),
            ),
          ),
          if (binding != null) ...[
            const HyperosSectionGap(),
            HyperosControlCard(
              title: l10n.coupleTimetableWeekOffsetTitle,
              subtitle: l10n.coupleTimetableWeekOffsetSubtitle,
              child: HyperosControlCardInset(
                child: _buildWeekOffsetControl(context, provider, binding.weekOffset),
              ),
            ),
            const HyperosSectionGap(),
            HyperosControlCard(
              title: l10n.coupleTimetableColorsTitle,
              subtitle: l10n.coupleTimetableColorsSubtitle,
              child: HyperosControlCardInset(
                child: _buildCoupleColorsControl(context, provider, binding),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoupleColorsControl(
    BuildContext context,
    TimetableProvider provider,
    PartnerTimetableBinding binding,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCoupleColorRow(
          context,
          label: l10n.coupleTimetableLegendMine,
          selectedHex: binding.mineColorHex,
          onSelected: (color) =>
              provider.updatePartnerCoupleColors(mineColorHex: color),
        ),
        const SizedBox(height: 14),
        _buildCoupleColorRow(
          context,
          label: l10n.coupleTimetableLegendPartner,
          selectedHex: binding.partnerColorHex,
          onSelected: (color) =>
              provider.updatePartnerCoupleColors(partnerColorHex: color),
        ),
        const SizedBox(height: 14),
        _buildCoupleColorRow(
          context,
          label: l10n.coupleTimetableLegendTogether,
          selectedHex: binding.togetherColorHex,
          onSelected: (color) =>
              provider.updatePartnerCoupleColors(togetherColorHex: color),
        ),
      ],
    );
  }

  Widget _buildCoupleColorRow(
    BuildContext context, {
    required String label,
    required String selectedHex,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HyperosTypography.listTitle(context)),
        const SizedBox(height: 8),
        HyperosHexColorChipGroup(
          colorHexes: _paletteIncluding(selectedHex),
          selectedHex: selectedHex,
          colorParser: _colorFromHex,
          distributeHorizontally: false,
          onSelectedHex: onSelected,
        ),
      ],
    );
  }

  List<String> _paletteIncluding(String selectedHex) {
    final normalized = selectedHex.toUpperCase();
    if (_coupleColorChoices.any((hex) => hex.toUpperCase() == normalized)) {
      return _coupleColorChoices;
    }
    return [selectedHex, ..._coupleColorChoices];
  }

  Color _colorFromHex(String hex) =>
      parseHexColorOrFallback(hex, fallback: Colors.blue);

  Widget _buildWeekOffsetControl(
    BuildContext context,
    TimetableProvider provider,
    int weekOffset,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final previewWeek = provider.currentWeek;
    final partnerWeek = provider.partnerWeekFor(previewWeek);
    final canDecrement = weekOffset > CoupleTimetableLogic.minWeekOffset;
    final canIncrement = weekOffset < CoupleTimetableLogic.maxWeekOffset;
    final offsetLabel = weekOffset == 0
        ? l10n.coupleTimetableWeekOffsetZero
        : l10n.coupleTimetableWeekOffsetSigned(
            weekOffset > 0 ? '+$weekOffset' : '$weekOffset',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _WeekOffsetStepButton(
              icon: Icons.remove_rounded,
              enabled: canDecrement,
              onPressed: canDecrement
                  ? () => provider.updatePartnerWeekOffset(weekOffset - 1)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                offsetLabel,
                textAlign: TextAlign.center,
                style: HyperosTypography.listTitle(context),
              ),
            ),
            const SizedBox(width: 12),
            _WeekOffsetStepButton(
              icon: Icons.add_rounded,
              enabled: canIncrement,
              onPressed: canIncrement
                  ? () => provider.updatePartnerWeekOffset(weekOffset + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l10n.coupleTimetableWeekOffsetPreview(previewWeek, partnerWeek),
          style: HyperosTypography.listDetail(context),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: HyperosTypography.listTitle(context)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: HyperosTypography.listDetail(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportForPartner() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);
    try {
      await provider.dataTransferService.exportAndShare(
        profileName: provider.activeProfile?.name,
        courses: provider.courses,
        settings: provider.settings,
        currentWeek: provider.currentWeek,
        shareText: l10n.coupleTimetableShareText,
        shareSubject: l10n.coupleTimetableShareSubject,
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importPartner() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const ['json', 'mikcb'],
      );
      final file = result?.files.single;
      if (file == null) {
        return;
      }
      final bytes = file.bytes;
      final content = bytes == null ? '' : utf8.decode(bytes);
      if (!mounted || content.isEmpty) {
        if (mounted && content.isEmpty) {
          throw FormatException(l10n.importFileReadFailed);
        }
        return;
      }
      final importResult = await provider.importPartnerTimetable(content);
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: importResult.kind == PartnerImportResultKind.updated
            ? l10n.coupleTimetableImportUpdated
            : l10n.coupleTimetableImportSuccess,
        kind: AppToastKind.success,
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, error.message),
        kind: AppToastKind.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.importFailedInvalidFile,
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _confirmUnlink() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosDialog<bool>(
      context: context,
      title: l10n.coupleTimetableUnlinkConfirmTitle,
      message: l10n.coupleTimetableUnlinkConfirmMessage,
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context, false),
        ),
        HyperosDialogAction(
          label: l10n.coupleTimetableUnlink,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isUnlinking = true);
    try {
      await context.read<TimetableProvider>().unlinkPartner();
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.coupleTimetableUnlinkSuccess,
        kind: AppToastKind.success,
      );
    } finally {
      if (mounted) {
        setState(() => _isUnlinking = false);
      }
    }
  }
}

class _WeekOffsetStepButton extends StatelessWidget {
  const _WeekOffsetStepButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return HyperosFrostedSurface(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
