import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          HyperosSectionDescription(text: l10n.feedbackIntro),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              l10n.feedbackIssueHint,
              style: HyperosTypography.listDetail(context),
            ),
          ),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              _FeedbackChannelTile(
                icon: Icons.bug_report_outlined,
                iconAccent: HyperosIconColors.orange,
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
                icon: Icons.forum_outlined,
                iconAccent: HyperosIconColors.red,
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
                icon: Icons.verified_user_outlined,
                iconAccent: HyperosIconColors.green,
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
                icon: Icons.groups_outlined,
                iconAccent: HyperosIconColors.blue,
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onCopy,
    this.iconAccent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final Color? iconAccent;

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
            HyperosIconBadge(
              icon: icon,
              accent: iconAccent ?? HyperosIconColors.blue,
            ),
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
