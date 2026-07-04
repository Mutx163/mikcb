import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/support_creator_service.dart';
import '../services/bundled_assets.dart';
import '../widgets/bundled_asset_image.dart';

enum _SupportMethod { wechat, alipay }

class SupportCreatorScreen extends StatefulWidget {
  const SupportCreatorScreen({super.key});

  @override
  State<SupportCreatorScreen> createState() => _SupportCreatorScreenState();
}

class _SupportCreatorScreenState extends State<SupportCreatorScreen> {
  static const _sectionPadding = EdgeInsets.fromLTRB(12, 12, 12, 10);

  /// Section titles — matches [_SettingsSectionCard] in timetable settings.
  TextStyle _sectionTitleStyle(FTypography typo, FColors colors) {
    return typo.body.sm.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.foreground,
    );
  }

  /// Primary list / label text.
  TextStyle _bodyStyle(FTypography typo, FColors colors) {
    return typo.body.sm.copyWith(color: colors.foreground, height: 1.45);
  }

  /// Secondary hints, dates, subtitles — same size as body, muted color only.
  TextStyle _mutedStyle(FTypography typo, FColors colors) {
    return typo.body.sm.copyWith(color: colors.mutedForeground, height: 1.45);
  }

  TextStyle _emphasisBodyStyle(FTypography typo, FColors colors) {
    return _bodyStyle(typo, colors).copyWith(fontWeight: FontWeight.w600);
  }

  final SupportCreatorService _service = SupportCreatorService();
  late Future<SupportDonorData> _donorFuture;
  _SupportMethod _selectedMethod = _SupportMethod.wechat;

  @override
  void initState() {
    super.initState();
    _donorFuture = _loadDonors();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography;

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.supportHeroTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildHeroSection(
                  context,
                  compact: compact,
                  colors: colors,
                  typo: typo,
                ),
                const SizedBox(height: 12),
                _buildPaymentCard(
                  context,
                  compact: compact,
                  colors: colors,
                  typo: typo,
                ),
                const SizedBox(height: 12),
                FutureBuilder<SupportDonorData>(
                  future: _donorFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildDonorShell(
                        context,
                        colors: colors,
                        typo: typo,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.donorListTitle,
                              style: _sectionTitleStyle(typo, colors),
                            ),
                            const SizedBox(height: 16),
                            const Center(child: FProgress()),
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
                            Text(
                              l10n.donorListTitle,
                              style: _sectionTitleStyle(typo, colors),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.donorListLoadFailed,
                              style: _mutedStyle(typo, colors),
                            ),
                            const SizedBox(height: 16),
                            FButton(
                              variant: FButtonVariant.secondary,
                              onPress: _reloadDonors,
                              prefix: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                              ),
                              child: Text(l10n.reloadAction),
                            ),
                          ],
                        ),
                      );
                    }
                    final data =
                        snapshot.data ??
                        const SupportDonorData(donors: <SupportDonorEntry>[]);
                    return _buildDonorCard(
                      context,
                      data,
                      colors: colors,
                      typo: typo,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDonorShell(
    BuildContext context, {
    required FColors colors,
    required FTypography typo,
    required Widget child,
  }) {
    return FCard.raw(
      child: Padding(padding: _sectionPadding, child: child),
    );
  }

  Widget _buildHeroSection(
    BuildContext context, {
    required bool compact,
    required FColors colors,
    required FTypography typo,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.16),
                  colorScheme.primaryContainer.withValues(alpha: 0.5),
                  colors.background,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            right: -28,
            top: -28,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              compact ? 14 : 16,
              12,
              compact ? 12 : 14,
            ),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: compact ? 72 : 80,
                        height: compact ? 72 : 80,
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.55),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: 0.14,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BundledAssetImage(
                            assetPath: BundledAssets.launcherIcon,
                            fit: BoxFit.cover,
                            cacheWidth: 160,
                            cacheHeight: 160,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.background,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.local_cafe_rounded,
                            size: 15,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                Row(
                  children: [
                    Expanded(
                      child: _SupportHighlight(
                        icon: Icons.handyman_outlined,
                        label: l10n.supportChipFixes,
                        labelStyle: _emphasisBodyStyle(typo, colors),
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SupportHighlight(
                        icon: Icons.sync_alt_rounded,
                        label: l10n.supportChipAdapters,
                        labelStyle: _emphasisBodyStyle(typo, colors),
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SupportHighlight(
                        icon: Icons.auto_awesome_rounded,
                        label: l10n.supportChipPolish,
                        labelStyle: _emphasisBodyStyle(typo, colors),
                        colors: colors,
                      ),
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
    required bool compact,
    required FColors colors,
    required FTypography typo,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isWechat = _selectedMethod == _SupportMethod.wechat;
    final title = isWechat ? l10n.wechatLabel : l10n.alipayLabel;
    final assetPath = isWechat
        ? BundledAssets.wechatPayQr
        : BundledAssets.alipayQr;
    final fileName = isWechat
        ? 'qingyu_kebiao_wechatpay.png'
        : 'qingyu_kebiao_alipay.png';
    final helperText = isWechat
        ? l10n.supportWeChatHint
        : l10n.supportAlipayHint;

    return FCard.raw(
      child: Padding(
        padding: _sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportMethodTitle,
              style: _sectionTitleStyle(typo, colors),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FButton(
                    variant: isWechat
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: () =>
                        setState(() => _selectedMethod = _SupportMethod.wechat),
                    prefix: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                    ),
                    child: Text(l10n.wechatLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FButton(
                    variant: !isWechat
                        ? FButtonVariant.primary
                        : FButtonVariant.outline,
                    onPress: () =>
                        setState(() => _selectedMethod = _SupportMethod.alipay),
                    prefix: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                    ),
                    child: Text(l10n.alipayLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildQrCard(
              context,
              title: title,
              assetPath: assetPath,
              fileName: fileName,
              helperText: helperText,
              compact: compact,
              colors: colors,
              typo: typo,
            ),
            Center(
              child: FButton(
                variant: FButtonVariant.ghost,
                onPress: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.supportCompleteThanks)),
                  );
                },
                prefix: const Icon(Icons.favorite_border_rounded, size: 16),
                child: Text(l10n.supportConfirmed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(
    BuildContext context, {
    required String title,
    required String assetPath,
    required String fileName,
    required String helperText,
    required bool compact,
    required FColors colors,
    required FTypography typo,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final qrSize = compact ? 108.0 : 120.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () =>
                  _showQrPreview(context, title: title, assetPath: assetPath),
              child: Ink(
                width: qrSize,
                height: qrSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.foreground.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: BundledAssetImage(
                  assetPath: assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helperText,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _mutedStyle(typo, colors),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.secondary,
                onPress: () =>
                    _showQrPreview(context, title: title, assetPath: assetPath),
                prefix: const Icon(Icons.fullscreen_rounded, size: 16),
                child: Text(l10n.viewLargeImage),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FButton(
                variant: FButtonVariant.primary,
                onPress: () =>
                    _saveQrToGallery(assetPath: assetPath, fileName: fileName),
                prefix: const Icon(Icons.download_rounded, size: 16),
                child: Text(l10n.saveToGallery),
              ),
            ),
          ],
        ),
      ],
    );
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
          FButton(
            variant: FButtonVariant.ghost,
            onPress: _reloadDonors,
            child: const Icon(Icons.refresh_rounded, size: 20),
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

      return FTileGroup(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final donor in donors)
            FTile(
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
              title: Text(donor.name, style: _emphasisBodyStyle(typo, colors)),
              subtitle: Text(
                [
                  if ((donor.date ?? '').isNotEmpty) donor.date!,
                  if ((donor.message ?? '').isNotEmpty) donor.message!,
                ].join('\n'),
                style: _mutedStyle(typo, colors),
              ),
              suffix: (donor.amount ?? '').isNotEmpty
                  ? FBadge(
                      variant: FBadgeVariant.secondary,
                      child: Text(
                        donor.amount!,
                        style: _emphasisBodyStyle(typo, colors),
                      ),
                    )
                  : null,
            ),
        ],
      );
    }

    return FCard.raw(
      child: Padding(
        padding: _sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(),
            const SizedBox(height: 12),
            buildDonorList(),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQrToGallery({
    required String assetPath,
    required String fileName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await _service.saveAssetImageToGallery(
        assetPath: assetPath,
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved ? l10n.savedToGallery : l10n.saveToGalleryFailed),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.saveFailedWithError('$error'))),
      );
    }
  }

  void _showQrPreview(
    BuildContext context, {
    required String title,
    required String assetPath,
  }) {
    showFDialog<void>(
      context: context,
      builder: (dialogContext, style, animation) {
        final colors = dialogContext.theme.colors;
        return FDialog(
          title: Text(title),
          body: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: BundledAssetImage(assetPath: assetPath, fit: BoxFit.contain),
          ),
          actions: [
            FButton(
              variant: FButtonVariant.primary,
              onPress: () => Navigator.pop(dialogContext),
              child: Text(
                MaterialLocalizations.of(dialogContext).closeButtonLabel,
              ),
            ),
          ],
        );
      },
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

class _SupportHighlight extends StatelessWidget {
  const _SupportHighlight({
    required this.icon,
    required this.label,
    required this.labelStyle,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final TextStyle labelStyle;
  final FColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
        ],
      ),
    );
  }
}
