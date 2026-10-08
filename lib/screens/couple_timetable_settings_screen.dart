import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:provider/provider.dart';

import '../models/partner_timetable_binding.dart';
import '../domain/couple_timetable_logic.dart';
import '../providers/timetable_provider.dart';
import '../services/couple_webdav_config.dart';
import '../services/couple_webdav_service.dart';
import '../services/partner_timetable_service.dart';
import '../services/unified_transfer_service.dart';
import '../utils/import_file_reader.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../utils/course_color_palette.dart';
import '../utils/hex_color.dart';
import '../widgets/couple_webdav_connect_sheet.dart';

class CoupleTimetableSettingsScreen extends StatefulWidget {
  const CoupleTimetableSettingsScreen({super.key});

  @override
  State<CoupleTimetableSettingsScreen> createState() =>
      _CoupleTimetableSettingsScreenState();
}

class _CoupleTimetableSettingsScreenState
    extends State<CoupleTimetableSettingsScreen> {
  // 双人课程色快选：沿用一族一色的快捷色（选中色不在列表时
  // _paletteIncluding 会自动补到行首）。
  static const _coupleColorChoices = kCourseColorQuickPickHexes;

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isUnlinking = false;
  bool _isPullingWebdav = false;
  bool _isUploadingWebdav = false;

  final CoupleWebdavService _coupleWebdavService = CoupleWebdavService();
  CoupleWebdavConfig _coupleWebdavConfig = const CoupleWebdavConfig();
  bool _hasCoupleWebdavPassword = false;

  @override
  void initState() {
    super.initState();
    _loadCoupleWebdavState();
  }

  Future<void> _loadCoupleWebdavState() async {
    final config = await _coupleWebdavService.loadConfig();
    final hasPassword = await _coupleWebdavService.hasStoredPassword();
    if (!mounted) {
      return;
    }
    setState(() {
      _coupleWebdavConfig = config;
      _hasCoupleWebdavPassword = hasPassword;
    });
  }

  bool get _isCoupleWebdavConnected =>
      _coupleWebdavConfig.username.trim().isNotEmpty &&
      _hasCoupleWebdavPassword;

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
          HyperosSectionLabel(
            text: binding == null
                ? l10n.coupleTimetableUnboundTitle
                : l10n.coupleTimetableBoundTitle,
          ),
          if (binding != null)
            HyperosControlCard(
              child: HyperosControlCardInset(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                ),
              ),
            ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.coupleWebdavTitle),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: _buildCoupleWebdavControl(context, l10n),
            ),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.coupleTimetableTitle),
          HyperosControlCard(
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
            HyperosSectionLabel(text: l10n.coupleTimetableWeekOffsetTitle),
            HyperosControlCard(
              child: HyperosControlCardInset(
                child: _buildWeekOffsetControl(
                  context,
                  provider,
                  binding.weekOffset,
                ),
              ),
            ),
            const HyperosSectionGap(),
            HyperosSectionLabel(text: l10n.coupleTimetableColorsTitle),
            HyperosControlCard(
              child: HyperosControlCardInset(
                child: _buildCoupleColorsControl(context, provider, binding),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoupleWebdavControl(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final connected = _isCoupleWebdavConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          connected
              ? l10n.coupleWebdavConnectedAs(_coupleWebdavConfig.username)
              : l10n.coupleWebdavNotConnected,
          style: HyperosTypography.listTitle(context),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.coupleWebdavRemotePathHint(
            _coupleWebdavConfig.partnerTimetableRemotePath,
          ),
          style: HyperosTypography.listDetail(context),
        ),
        if (_coupleWebdavConfig.lastPulledAt != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.coupleWebdavLastPulledAt(
              _formatDateTime(_coupleWebdavConfig.lastPulledAt!),
            ),
            style: HyperosTypography.listDetail(context),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!connected)
              HyperosButton(
                label: l10n.coupleWebdavConnect,
                onPressed: _connectCoupleWebdav,
              )
            else ...[
              HyperosButton(
                label: _isPullingWebdav
                    ? '${l10n.coupleWebdavPullNow}...'
                    : l10n.coupleWebdavPullNow,
                loading: _isPullingWebdav,
                onPressed: _isPullingWebdav ? null : _pullPartnerWebdav,
              ),
              HyperosButton(
                label: _isUploadingWebdav
                    ? '${l10n.coupleWebdavUploadForPartner}...'
                    : l10n.coupleWebdavUploadForPartner,
                variant: HyperosButtonVariant.secondary,
                loading: _isUploadingWebdav,
                onPressed: _isUploadingWebdav
                    ? null
                    : _uploadMyTimetableForPartner,
              ),
              HyperosButton(
                label: l10n.coupleWebdavDisconnect,
                variant: HyperosButtonVariant.secondary,
                onPressed: _disconnectCoupleWebdav,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _connectCoupleWebdav() async {
    final result = await showHyperosSheet<CoupleWebdavConnectResult>(
      context: context,
      builder: (ctx) => CoupleWebdavConnectSheet(
        service: _coupleWebdavService,
        config: _coupleWebdavConfig,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _isPullingWebdav = true);
    try {
      await _coupleWebdavService.connect(
        username: result.username,
        password: result.password,
        mySlot: result.mySlot,
      );
      await _loadCoupleWebdavState();
      await _pullPartnerWebdav(force: true, showProgress: false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.coupleWebdavTestFailed,
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isPullingWebdav = false);
      }
    }
  }

  Future<void> _disconnectCoupleWebdav() async {
    // 服务侧现在只剩"清配置"这一条会失败的路径（prefs 写失败），仍要接住并说出来：
    // 这个按钮是 `onPressed: _disconnectCoupleWebdav` 的 tear-off，抛出去就没人接。
    try {
      await _coupleWebdavService.disconnect();
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    await _loadCoupleWebdavState();
  }

  Future<void> _pullPartnerWebdav({
    bool force = false,
    bool showProgress = true,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (showProgress) {
      setState(() => _isPullingWebdav = true);
    }
    try {
      final result = await _coupleWebdavService.pullPartnerTimetable(
        provider: context.read<TimetableProvider>(),
        force: force,
      );
      await _loadCoupleWebdavState();
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case CoupleWebdavPullStatus.imported:
          showAppToast(
            context,
            message: l10n.coupleWebdavPullImported,
            kind: AppToastKind.success,
          );
        case CoupleWebdavPullStatus.updated:
          showAppToast(
            context,
            message: l10n.coupleWebdavPullUpdated,
            kind: AppToastKind.success,
          );
        case CoupleWebdavPullStatus.unchanged:
          showAppToast(context, message: l10n.coupleWebdavPullUnchanged);
        case CoupleWebdavPullStatus.failed:
          showAppToast(
            context,
            message: localizeServiceMessage(
              l10n,
              result.errorCode ?? 'couple_webdav_pull_failed',
            ),
            kind: AppToastKind.error,
          );
      }
    } finally {
      if (mounted && showProgress) {
        setState(() => _isPullingWebdav = false);
      }
    }
  }

  Future<void> _uploadMyTimetableForPartner() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isUploadingWebdav = true);
    try {
      final errorCode = await _coupleWebdavService.uploadMyTimetableForPartner(
        provider: context.read<TimetableProvider>(),
      );
      if (!mounted) {
        return;
      }
      if (errorCode != null) {
        showAppToast(
          context,
          message: localizeServiceMessage(l10n, errorCode),
          kind: AppToastKind.error,
        );
        return;
      }
      showAppToast(
        context,
        message: l10n.coupleWebdavUploadSuccess,
        kind: AppToastKind.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.coupleWebdavPullFailed,
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingWebdav = false);
      }
    }
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
              _applyCoupleColor(context, provider, mineColorHex: color),
        ),
        const SizedBox(height: 14),
        _buildCoupleColorRow(
          context,
          label: l10n.coupleTimetableLegendPartner,
          selectedHex: binding.partnerColorHex,
          onSelected: (color) =>
              _applyCoupleColor(context, provider, partnerColorHex: color),
        ),
        const SizedBox(height: 14),
        _buildCoupleColorRow(
          context,
          label: l10n.coupleTimetableLegendTogether,
          selectedHex: binding.togetherColorHex,
          onSelected: (color) =>
              _applyCoupleColor(context, provider, togetherColorHex: color),
        ),
      ],
    );
  }

  /// `updatePartnerCoupleColors`（timetable_provider.dart:4581-4601）是
  /// **先改内存 `_partnerBinding`、再 `await savePartnerTimetableBinding(...)` 且没有
  /// try/catch** → 落盘失败会 reject 且不回滚。原先三处 `onSelected` 直接把返回的
  /// Future 丢掉：颜色当场看到变了、重启回旧值、零提示 —— 与 `settings_weather.dart:31`
  /// 同一形状的谎报成功（那批在 9345fa80 修掉）。
  Future<void> _applyCoupleColor(
    BuildContext context,
    TimetableProvider provider, {
    String? mineColorHex,
    String? partnerColorHex,
    String? togetherColorHex,
  }) async {
    try {
      await provider.updatePartnerCoupleColors(
        mineColorHex: mineColorHex,
        partnerColorHex: partnerColorHex,
        togetherColorHex: togetherColorHex,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
    }
  }

  // +/- 按钮原本是 `() => provider.updatePartnerWeekOffset(...)`，返回的 Future
  // 直接丢弃：落盘失败 rethrow 出去没有任何人接，既没有提示也不会回滚显示。
  Future<void> _shiftPartnerWeekOffset(
    BuildContext context,
    TimetableProvider provider,
    int nextOffset,
  ) async {
    try {
      await provider.updatePartnerWeekOffset(nextOffset);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
    }
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
      parseHexColorOrFallback(hex, fallback: HyperosIconColors.blue);

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
                  ? () => _shiftPartnerWeekOffset(context, provider, weekOffset - 1)
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
                  ? () => _shiftPartnerWeekOffset(context, provider, weekOffset + 1)
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
        tasks: provider.tasks,
        scheduleItems: provider.scheduleItems,
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
        // withData: true would already have the whole file in memory; on
        // Android an OOM kills the process rather than raising something
        // catchable, so the ceiling must be enforced before the read.
        // (false is the default; stated here because the default is the trap.)
        allowedExtensions: const ['json', 'mikcb'],
      );
      final file = result?.files.single;
      if (file == null) {
        return;
      }
      final path = file.path;
      if (path == null || path.isEmpty) {
        throw FormatException(l10n.importFileReadFailed);
      }
      final Uint8List bytes;
      try {
        bytes = await readImportFileBytes(
          path,
          maxBytes: UnifiedTransferService.maxImportFileBytes,
        );
      } on ImportFileTooLarge {
        throw FormatException(
          l10n.importFileTooLarge(
            formatByteBudget(UnifiedTransferService.maxImportFileBytes),
          ),
        );
      }
      final content = utf8.decode(bytes);
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
      borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
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
