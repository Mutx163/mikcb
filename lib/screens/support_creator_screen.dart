import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/bundled_assets.dart';
import '../services/support_creator_service.dart';
import '../utils/app_toast.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/bundled_asset_image.dart';

enum _SupportMethod { wechat, alipay }

class SupportCreatorScreen extends StatefulWidget {
  const SupportCreatorScreen({super.key});

  @override
  State<SupportCreatorScreen> createState() => _SupportCreatorScreenState();
}

class _SupportCreatorScreenState extends State<SupportCreatorScreen> {
  static const _sectionPadding = EdgeInsets.fromLTRB(14, 14, 14, 12);
  static const _donorSectionPadding = EdgeInsets.fromLTRB(14, 14, 14, 12);
  static const _paymentColumnGap = 10.0;

  final SupportCreatorService _service = SupportCreatorService();

  late Future<SupportDonorData> _donorFuture;
  _SupportMethod _selectedMethod = _SupportMethod.wechat;

  @override
  void initState() {
    super.initState();
    _donorFuture = _loadDonors();
  }

  TextStyle _sectionTitleStyle(FTypography typo, FColors colors) {
    return typo.body.sm.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.foreground,
      height: 1.4,
    );
  }

  TextStyle _bodyStyle(FTypography typo, FColors colors) {
    return typo.body.sm.copyWith(color: colors.foreground, height: 1.4);
  }

  TextStyle _mutedStyle(FTypography typo, FColors colors) {
    return typo.body.xs.copyWith(color: colors.mutedForeground, height: 1.4);
  }

  TextStyle _emphasisBodyStyle(FTypography typo, FColors colors) {
    return _bodyStyle(typo, colors).copyWith(fontWeight: FontWeight.w600);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.supportHeroTitle),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: HyperosListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildCompactHero(context, colors: colors, typo: typo),
            const SizedBox(height: 10),
            _buildPaymentCard(context, colors: colors, typo: typo),
            const SizedBox(height: 10),
            FutureBuilder<SupportDonorData>(
              future: _donorFuture,
              builder: (context, snapshot) =>
                  _buildDonorSection(context, snapshot, colors, typo),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodPicker(
    BuildContext context, {
    required bool isWechat,
    required FColors colors,
    required FTypography typo,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.supportMethodTitle, style: _emphasisBodyStyle(typo, colors)),
        const SizedBox(height: 8),
        HyperosSegmentedControl(
          tabs: [l10n.wechatLabel, l10n.alipayLabel],
          selectedIndex: isWechat ? 0 : 1,
          onChanged: (index) {
            setState(() {
              _selectedMethod = index == 0
                  ? _SupportMethod.wechat
                  : _SupportMethod.alipay;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCompactHero(
    BuildContext context, {
    required FColors colors,
    required FTypography typo,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.foreground.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BundledAssetImage(
                    assetPath: BundledAssets.launcherIcon,
                    fit: BoxFit.cover,
                    cacheWidth: 96,
                    cacheHeight: 96,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                    ),
                    border: Border.all(color: colors.background, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 9,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.supportHeroTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sectionTitleStyle(typo, colors),
                      ),
                    ),
                    const SizedBox(width: 6),
                    HyperosTag(
                      label: l10n.supportRunningBadge,
                      backgroundColor: const Color(0xFFD1FAE5),
                      textStyle: _mutedStyle(typo, colors).copyWith(
                        color: const Color(0xFF047857),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.supportHeroSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle(typo, colors),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _FeatureCapsule(
                      label: l10n.supportChipFixes,
                      labelStyle: _mutedStyle(typo, colors).copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4338CA),
                      ),
                      background: const Color(0xFFEEF2FF),
                    ),
                    _FeatureCapsule(
                      label: l10n.supportChipAdapters,
                      labelStyle: _mutedStyle(typo, colors).copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0369A1),
                      ),
                      background: const Color(0xFFE0F2FE),
                    ),
                    _FeatureCapsule(
                      label: l10n.supportChipPolish,
                      labelStyle: _mutedStyle(typo, colors).copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF047857),
                      ),
                      background: const Color(0xFFD1FAE5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context, {
    required FColors colors,
    required FTypography typo,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isWechat = _selectedMethod == _SupportMethod.wechat;
    final assetPath = isWechat
        ? BundledAssets.wechatPayQr
        : BundledAssets.alipayQr;
    final fileName = isWechat
        ? 'qingyu_kebiao_wechatpay.png'
        : 'qingyu_kebiao_alipay.png';
    final helperText = isWechat
        ? l10n.supportWeChatHint
        : l10n.supportAlipayHint;
    final accent = isWechat ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);

    return HyperosCard(
      child: Padding(
        padding: _sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPaymentMethodPicker(
              context,
              isWechat: isWechat,
              colors: colors,
              typo: typo,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showQrPreview(
                            context,
                            assetPath: assetPath,
                            fileName: fileName,
                            isWechat: isWechat,
                          ),
                          child: Ink(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.muted.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.border.withValues(alpha: 0.55),
                              ),
                            ),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colors.border.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: BundledAssetImage(
                                        assetPath: assetPath,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        isWechat
                                            ? Icons.chat_bubble_rounded
                                            : Icons
                                                  .account_balance_wallet_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.open_in_full_rounded,
                            size: 14,
                            color: colors.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.supportTapQrHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _mutedStyle(typo, colors),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _paymentColumnGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HyperosButton(
                        label: l10n.supportSaveShort,
                        variant: HyperosButtonVariant.secondary,
                        expand: true,
                        onPressed: () => _saveQrToGallery(
                          assetPath: assetPath,
                          fileName: fileName,
                        ),
                      ),
                      const SizedBox(height: 8),
                      HyperosButton(
                        label: l10n.supportConfirmedShort,
                        variant: HyperosButtonVariant.secondary,
                        expand: true,
                        onPressed: () {
                          showAppToast(
                            context,
                            message: l10n.supportCompleteThanks,
                            kind: AppToastKind.success,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(helperText, style: _mutedStyle(typo, colors)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorSection(
    BuildContext context,
    AsyncSnapshot<SupportDonorData> snapshot,
    FColors colors,
    FTypography typo,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildDonorShell(
        context,
        colors: colors,
        typo: typo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.donorListTitle, style: _sectionTitleStyle(typo, colors)),
            const SizedBox(height: 16),
            const Center(child: HyperosCircularProgress()),
          ],
        ),
      );
    }

    if (snapshot.hasError) {
      return _buildDonorShell(
        context,
        colors: colors,
        typo: typo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.donorListTitle, style: _sectionTitleStyle(typo, colors)),
            const SizedBox(height: 8),
            Text(l10n.donorListLoadFailed, style: _mutedStyle(typo, colors)),
            const SizedBox(height: 16),
            HyperosButton(
              label: l10n.reloadAction,
              variant: HyperosButtonVariant.secondary,
              onPressed: _reloadDonors,
            ),
          ],
        ),
      );
    }

    final data =
        snapshot.data ?? const SupportDonorData(donors: <SupportDonorEntry>[]);
    return _buildDonorCard(context, data, colors: colors, typo: typo);
  }

  Widget _buildDonorShell(
    BuildContext context, {
    required FColors colors,
    required FTypography typo,
    required Widget child,
  }) {
    return HyperosCard(padding: _donorSectionPadding, child: child);
  }

  Widget _buildDonorCard(
    BuildContext context,
    SupportDonorData data, {
    required FColors colors,
    required FTypography typo,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final donors = data.donors;
    final title = data.title?.isNotEmpty == true
        ? data.title!
        : l10n.donorListTitle;

    Widget buildHeader() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _sectionTitleStyle(typo, colors)),
                if (data.subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(data.subtitle!, style: _mutedStyle(typo, colors)),
                ],
                if (data.updatedAt?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.updatedAtLabel(data.updatedAt!),
                    style: _mutedStyle(typo, colors),
                  ),
                ],
              ],
            ),
          ),
          HyperosIconButton(
            icon: Icons.refresh_rounded,
            iconSize: 20,
            tooltip: l10n.reloadAction,
            onPressed: _reloadDonors,
          ),
        ],
      );
    }

    Widget buildDonorList() {
      if (donors.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(l10n.donorListEmpty, style: _mutedStyle(typo, colors)),
        );
      }

      return HyperosChoiceGroup(
        children: [
          for (final donor in donors)
            HyperosChoiceTile(
              prefix: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 16,
                  color: colors.primary,
                ),
              ),
              title: donor.name,
              subtitle: Text(
                [
                  if ((donor.date ?? '').isNotEmpty) donor.date!,
                  if ((donor.message ?? '').isNotEmpty) donor.message!,
                ].join('\n'),
                style: _mutedStyle(typo, colors),
              ),
              trailing: (donor.amount ?? '').isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        donor.amount!,
                        style: _emphasisBodyStyle(typo, colors),
                      ),
                    )
                  : null,
              onTap: null,
            ),
        ],
      );
    }

    return HyperosCard(
      padding: _donorSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [buildHeader(), const SizedBox(height: 12), buildDonorList()],
      ),
    );
  }

  Future<void> _saveQrToGallery({
    required String assetPath,
    required String fileName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final saved = await _service.saveAssetImageToGallery(
        assetPath: assetPath,
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: saved ? l10n.savedToGallery : l10n.saveToGalleryFailed,
        kind: saved ? AppToastKind.success : AppToastKind.error,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.saveFailedWithError('$error'),
        kind: AppToastKind.error,
      );
    }
  }

  void _showQrPreview(
    BuildContext context, {
    required String assetPath,
    required String fileName,
    required bool isWechat,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final dialogTitle = isWechat
        ? l10n.scanQrWechatTitle
        : l10n.scanQrAlipayTitle;

    final colors = context.theme.colors;
    showHyperosDialog<void>(
      context: context,
      title: dialogTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.muted.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: BundledAssetImage(
                    assetPath: assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.scanQrSubtitle,
            textAlign: TextAlign.center,
            style: context.theme.typography.body.xs.copyWith(
              color: colors.mutedForeground,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.saveToGallery,
          onPressed: () {
            Navigator.pop(context);
            _saveQrToGallery(assetPath: assetPath, fileName: fileName);
          },
        ),
        HyperosDialogAction(
          label: MaterialLocalizations.of(context).closeButtonLabel,
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _reloadDonors() {
    setState(() {
      _donorFuture = _loadDonors();
    });
  }

  Future<SupportDonorData> _loadDonors() {
    final settings = context.read<TimetableProvider>().settings;
    final mirrorUrlPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: AppUpdateMirrorPresetX.fromValue(settings.appUpdateMirrorPreset),
      customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
    );
    return _service.fetchDonors(mirrorUrlPrefix: mirrorUrlPrefix);
  }
}

class _FeatureCapsule extends StatelessWidget {
  const _FeatureCapsule({
    required this.label,
    required this.labelStyle,
    required this.background,
  });

  final String label;
  final TextStyle labelStyle;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: labelStyle),
    );
  }
}
