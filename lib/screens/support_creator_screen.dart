import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/support_creator_service.dart';

enum _SupportMethod { wechat, alipay }

class SupportCreatorScreen extends StatefulWidget {
  const SupportCreatorScreen({super.key});

  @override
  State<SupportCreatorScreen> createState() => _SupportCreatorScreenState();
}

class _SupportCreatorScreenState extends State<SupportCreatorScreen> {
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportCreatorTitle),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 760;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeroCard(context, compact: compact),
              const SizedBox(height: 8),
              _buildPaymentCard(context, compact: compact),
              const SizedBox(height: 8),
              FutureBuilder<SupportDonorData>(
                future: _donorFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.donorListTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(minHeight: 3),
                          ],
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '鸣谢名单',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.donorListLoadFailed,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _reloadDonors,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(l10n.reloadAction),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final data = snapshot.data ??
                      const SupportDonorData(
                        donors: <SupportDonorEntry>[],
                      );
                  return _buildDonorCard(context, data);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, {required bool compact}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 46 : 54,
            height: compact ? 46 : 54,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.coffee_rounded,
              color: colorScheme.primary,
              size: compact ? 24 : 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.supportHeroTitle,
                  style: (compact
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.supportHeroSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _CompactSupportChip(label: l10n.supportChipFixes),
                    _CompactSupportChip(label: l10n.supportChipAdapters),
                    _CompactSupportChip(label: l10n.supportChipPolish),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, {required bool compact}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportMethodTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_SupportMethod>(
              segments: [
                ButtonSegment<_SupportMethod>(
                  value: _SupportMethod.wechat,
                  label: Text(l10n.wechatLabel),
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                ),
                ButtonSegment<_SupportMethod>(
                  value: _SupportMethod.alipay,
                  label: Text(l10n.alipayLabel),
                  icon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ],
              selected: {_selectedMethod},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedMethod = selection.first;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildQrCard(
              context,
              title: _selectedMethod == _SupportMethod.wechat
                  ? l10n.wechatLabel
                  : l10n.alipayLabel,
              assetPath: _selectedMethod == _SupportMethod.wechat
                  ? 'assets/donate/wechatpay.png'
                  : 'assets/donate/alipay.png',
              fileName: _selectedMethod == _SupportMethod.wechat
                  ? 'qingyu_kebiao_wechatpay.png'
                  : 'qingyu_kebiao_alipay.png',
              helperText: _selectedMethod == _SupportMethod.wechat
                  ? l10n.supportWeChatHint
                  : l10n.supportAlipayHint,
              compact: compact,
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.supportCompleteThanks)),
                  );
                },
                icon: const Icon(Icons.favorite_border_rounded),
                label: Text(l10n.supportConfirmed),
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
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.qr_code_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () =>
                _showQrPreview(context, title: title, assetPath: assetPath),
            child: Container(
              width: compact ? 146 : 170,
              height: compact ? 146 : 170,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: EdgeInsets.all(compact ? 12 : 14),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            helperText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _showQrPreview(
                  context,
                  title: title,
                  assetPath: assetPath,
                ),
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.viewLargeImage),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _saveQrToGallery(
                  assetPath: assetPath,
                  fileName: fileName,
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.saveToGallery),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonorCard(BuildContext context, SupportDonorData data) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final donors = data.donors;
    Widget buildHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title?.isNotEmpty == true
                          ? data.title!
                          : l10n.donorListTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (data.subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.reloadAction,
                onPressed: _reloadDonors,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (data.updatedAt?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              l10n.updatedAtLabel(data.updatedAt!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    Widget buildDonorList({required bool shrinkWrap}) {
      if (donors.isEmpty) {
        return Text(
          l10n.donorListEmpty,
          style: theme.textTheme.bodyMedium,
        );
      }
      return ListView.separated(
        shrinkWrap: shrinkWrap,
        physics:
            shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: donors.length,
        itemBuilder: (context, index) {
          final donor = donors[index];
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        donor.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if ((donor.amount ?? '').isNotEmpty)
                      Text(
                        donor.amount!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                if ((donor.date ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    donor.date!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if ((donor.message ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    donor.message!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(),
            const SizedBox(height: 12),
            buildDonorList(shrinkWrap: true),
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style:
                      Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
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

class _CompactSupportChip extends StatelessWidget {
  final String label;

  const _CompactSupportChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
