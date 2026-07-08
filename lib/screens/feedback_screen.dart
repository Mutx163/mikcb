import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  static const String _issuesUrl = 'https://github.com/Mutx163/mikcb/issues';
  static const String _xiaohongshuId = '4976443029';
  static const String _coolapkId = 'Mutx666';
  static const String _qqGroupId = '1077077989';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.feedbackTitle),
      child: HyperosListView(
        children: [
          HyperosListGroup(
            children: [
              _FeedbackChannelTile(
                brandBadge: const _FeedbackBrandBadge.svg(
                  assetPath: 'assets/branding/github.svg',
                  color: Color(0xFF181717),
                ),
                title: l10n.githubIssueTitle,
                subtitle: l10n.githubIssueSubtitle,
                onTap: () => _openUrl(_issuesUrl),
                onCopy: () => _copyText(
                  context,
                  _issuesUrl,
                  successMessage: l10n.copiedIssueAddress,
                ),
              ),
              _FeedbackChannelTile(
                brandBadge: const _FeedbackBrandBadge.svg(
                  assetPath: 'assets/branding/xiaohongshu.svg',
                  color: Colors.white,
                  backgroundColor: Color(0xFFFF2442),
                ),
                title: l10n.feedbackXiaohongshuTitle,
                subtitle: l10n.feedbackXiaohongshuSubtitle(_xiaohongshuId),
                onTap: () => _copyText(
                  context,
                  _xiaohongshuId,
                  successMessage: l10n.copiedXiaohongshuId,
                ),
                onCopy: () => _copyText(
                  context,
                  _xiaohongshuId,
                  successMessage: l10n.copiedXiaohongshuId,
                ),
              ),
              _FeedbackChannelTile(
                brandBadge: const _FeedbackBrandBadge.png(
                  assetPath: 'assets/branding/coolapk.png',
                  backgroundColor: Color(0xFF4CAF50),
                ),
                title: l10n.feedbackCoolapkTitle,
                subtitle: l10n.feedbackCoolapkSubtitle(_coolapkId),
                onTap: () => _copyText(
                  context,
                  _coolapkId,
                  successMessage: l10n.copiedCoolapkId,
                ),
                onCopy: () => _copyText(
                  context,
                  _coolapkId,
                  successMessage: l10n.copiedCoolapkId,
                ),
              ),
              _FeedbackChannelTile(
                brandBadge: const _FeedbackBrandBadge.svg(
                  assetPath: 'assets/branding/qq.svg',
                  color: Color(0xFF12B7F5),
                ),
                title: l10n.feedbackQqGroupTitle,
                subtitle: l10n.feedbackQqGroupSubtitle(_qqGroupId),
                onTap: () => _copyText(
                  context,
                  _qqGroupId,
                  successMessage: l10n.copiedQqGroupId,
                ),
                onCopy: () => _copyText(
                  context,
                  _qqGroupId,
                  successMessage: l10n.copiedQqGroupId,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyText(
    BuildContext context,
    String value, {
    required String successMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    showAppToast(context, message: successMessage, kind: AppToastKind.success);
  }
}

EdgeInsets _feedbackRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.rowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
}

class _FeedbackChannelTile extends StatelessWidget {
  const _FeedbackChannelTile({
    required this.brandBadge,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onCopy,
  });

  final Widget brandBadge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: _feedbackRowPadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            brandBadge,
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: HyperosTypography.listTitle(context)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: HyperosTypography.listDetail(context)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              color: HyperosColors.actionIcon(context),
              tooltip: MaterialLocalizations.of(context).copyButtonLabel,
              onPressed: onCopy,
            ),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

class _FeedbackBrandBadge extends StatelessWidget {
  const _FeedbackBrandBadge.svg({
    required this.assetPath,
    required this.color,
    this.backgroundColor,
  }) : _isSvg = true;

  const _FeedbackBrandBadge.png({required this.assetPath, this.backgroundColor})
    : _isSvg = false,
      color = null;

  final String assetPath;
  final Color? color;
  final Color? backgroundColor;
  final bool _isSvg;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBackgroundColor =
        backgroundColor ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final iconSize = _isSvg
        ? HyperosTokens.iconGlyphSize
        : HyperosTokens.iconBadgeSize - 8;
    final iconWidget = _isSvg
        ? SvgPicture.asset(
            assetPath,
            width: iconSize,
            height: iconSize,
            colorFilter: color == null
                ? null
                : ColorFilter.mode(color!, BlendMode.srcIn),
          )
        : Image.asset(
            assetPath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.broken_image_outlined,
              size: HyperosTokens.iconGlyphSize,
              color: HyperosColors.actionIcon(context),
            ),
          );

    return Container(
      width: HyperosTokens.iconBadgeSize,
      height: HyperosTokens.iconBadgeSize,
      decoration: BoxDecoration(
        color: resolvedBackgroundColor,
        borderRadius: BorderRadius.circular(HyperosTokens.iconBadgeRadius),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: iconWidget,
    );
  }
}
