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
import '../widgets/support_donor_tile.dart';

enum _SupportMethod { wechat, alipay }

class SupportCreatorScreen extends StatefulWidget {
  const SupportCreatorScreen({super.key});

  @override
  State<SupportCreatorScreen> createState() => _SupportCreatorScreenState();
}

class _SupportCreatorScreenState extends State<SupportCreatorScreen> {
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

    return HyperosControlCard(
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

    return HyperosControlCard(
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
                            // 承托白色二维码的井底必须不透明：onSurface 半透明
                            // 水洗叠在液态玻璃半透明卡上会直接透出壁纸发黑。
                            color: HyperosColors.secondaryVariant(context),
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
                                          color: accent.withValues(alpha: 0.35),
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
    return HyperosControlCard(child: child);
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
      final updatedAt = data.updatedAt?.isNotEmpty == true
          ? l10n.updatedAtLabel(data.updatedAt!)
          : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _sectionTitleStyle(typo, colors),
                ),
              ),
              if (updatedAt != null) ...[
                const SizedBox(width: 8),
                // 非 flex 定宽子项：与 Expanded 并存时剩余空间会被对半
                // 分掉，时间+刷新钮会被顶到行中间、右端留空。
                Text(
                  updatedAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // xs2 弱化为元数据级，与正文段落拉开层级；紧贴刷新钮
                  // 把「数据新旧」和「刷新」归为一组。
                  style: typo.body.xs2.copyWith(
                    color: colors.mutedForeground,
                    height: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              // MiuixIconButton 有 40dp 最小边，直接进标题行会把行撑高，
              // 文字居中后整体下沉，观感即「标题离卡片顶部变远」；
              // OverflowBox 压成 24 高槽位：按钮仍是 40×40 可点，视觉
              // 中心与标题文字对齐。
              // 槽宽 30 + centerLeft：40 宽的按钮盒右探 10dp 进内边距，
              // 20dp 图标右缘正好落在 16dp 内容右界上，与下方金额对齐。
              SizedBox(
                width: 30,
                height: 24,
                child: OverflowBox(
                  maxWidth: 40,
                  maxHeight: 40,
                  alignment: Alignment.centerLeft,
                  child: HyperosIconButton(
                    icon: Icons.refresh_rounded,
                    iconSize: 20,
                    tooltip: l10n.reloadAction,
                    onPressed: _reloadDonors,
                  ),
                ),
              ),
            ],
          ),
          if (data.subtitle?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              data.subtitle!,
              style: typo.body.xs.copyWith(
                color: colors.mutedForeground,
                height: 1.5,
              ),
            ),
          ],
          if (data.subtitleNote?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              // 提示条用页面二维码井同款主题化不透明底：玻璃卡上半透明
              // 水洗会透出壁纸发黑；井上灰墨会发灰，墨色用前景色。
              decoration: BoxDecoration(
                color: HyperosColors.secondaryVariant(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.subtitleNote!,
                      style: typo.body.xs.copyWith(
                        color: colors.foreground,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    Widget buildDonorList() {
      if (donors.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(l10n.donorListEmpty, style: _mutedStyle(typo, colors)),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < donors.length; i++) ...[
            if (i > 0)
              HyperosInsetDivider(indent: SupportDonorTile.dividerIndent),
            SupportDonorTile(
              donor: donors[i],
              isFirst: i == 0,
              isLast: i == donors.length - 1,
            ),
          ],
        ],
      );
    }

    return HyperosControlCard(
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: buildHeader(),
          ),
          const SizedBox(height: 12),
          buildDonorList(),
        ],
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
            // 同主页二维码井：不透明底，防止玻璃弹窗上透出壁纸发黑。
            decoration: BoxDecoration(
              color: HyperosColors.secondaryVariant(context),
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
