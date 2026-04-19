import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  static const String _issuesUrl = 'https://github.com/Mutx163/mikcb/issues';
  static const String _xiaohongshuId = '4976443029';
  static const String _coolapkId = 'Mutx666';
  static const String _qqGroupId = '1077077989';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feedbackTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.feedbackIntro,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.feedbackIssueHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FeedbackCard(
            icon: Icons.bug_report_outlined,
            title: l10n.githubIssueTitle,
            subtitle: l10n.githubIssueSubtitle,
            primaryLabel: l10n.openIssuePage,
            onPrimaryTap: () => _openUrl(_issuesUrl),
            secondaryLabel: l10n.copyAddress,
            onSecondaryTap: () => _copyText(
              context,
              _issuesUrl,
              successMessage: l10n.copiedIssueAddress,
            ),
          ),
          const SizedBox(height: 12),
          _FeedbackCard(
            icon: Icons.forum_outlined,
            title: l10n.feedbackXiaohongshuTitle,
            subtitle: l10n.feedbackXiaohongshuSubtitle(_xiaohongshuId),
            primaryLabel: l10n.copyXiaohongshuId,
            onPrimaryTap: () => _copyText(
              context,
              _xiaohongshuId,
              successMessage: l10n.copiedXiaohongshuId,
            ),
          ),
          const SizedBox(height: 12),
          _FeedbackCard(
            icon: Icons.verified_user_outlined,
            title: l10n.feedbackCoolapkTitle,
            subtitle: l10n.feedbackCoolapkSubtitle(_coolapkId),
            primaryLabel: l10n.copyCoolapkId,
            onPrimaryTap: () => _copyText(
              context,
              _coolapkId,
              successMessage: l10n.copiedCoolapkId,
            ),
          ),
          const SizedBox(height: 12),
          _FeedbackCard(
            icon: Icons.groups_outlined,
            title: l10n.feedbackQqGroupTitle,
            subtitle: l10n.feedbackQqGroupSubtitle(_qqGroupId),
            primaryLabel: l10n.copyQqGroupId,
            onPrimaryTap: () => _copyText(
              context,
              _qqGroupId,
              successMessage: l10n.copiedQqGroupId,
            ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final Future<void> Function() onPrimaryTap;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondaryTap;

  const _FeedbackCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: onPrimaryTap,
                  child: Text(primaryLabel),
                ),
                if (secondaryLabel != null && onSecondaryTap != null)
                  FilledButton.tonal(
                    onPressed: onSecondaryTap,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

