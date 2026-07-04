import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.feedbackTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.feedbackIntro, style: theme.textTheme.bodyMedium),
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
            FTileGroup(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                FTile(
                  prefix: Icon(Icons.bug_report_outlined),
                  title: Text(l10n.githubIssueTitle),
                  subtitle: Text(l10n.githubIssueSubtitle),
                  suffix: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copyText(
                      context,
                      _issuesUrl,
                      successMessage: l10n.copiedIssueAddress,
                    ),
                  ),
                  onPress: () => _openUrl(_issuesUrl),
                ),
                FTile(
                  prefix: Icon(Icons.forum_outlined),
                  title: Text(l10n.feedbackXiaohongshuTitle),
                  subtitle: Text(
                    l10n.feedbackXiaohongshuSubtitle(_xiaohongshuId),
                  ),
                  suffix: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copyText(
                      context,
                      _xiaohongshuId,
                      successMessage: l10n.copiedXiaohongshuId,
                    ),
                  ),
                  onPress: () => _copyText(
                    context,
                    _xiaohongshuId,
                    successMessage: l10n.copiedXiaohongshuId,
                  ),
                ),
                FTile(
                  prefix: Icon(Icons.verified_user_outlined),
                  title: Text(l10n.feedbackCoolapkTitle),
                  subtitle: Text(l10n.feedbackCoolapkSubtitle(_coolapkId)),
                  suffix: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copyText(
                      context,
                      _coolapkId,
                      successMessage: l10n.copiedCoolapkId,
                    ),
                  ),
                  onPress: () => _copyText(
                    context,
                    _coolapkId,
                    successMessage: l10n.copiedCoolapkId,
                  ),
                ),
                FTile(
                  prefix: Icon(Icons.groups_outlined),
                  title: Text(l10n.feedbackQqGroupTitle),
                  subtitle: Text(l10n.feedbackQqGroupSubtitle(_qqGroupId)),
                  suffix: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copyText(
                      context,
                      _qqGroupId,
                      successMessage: l10n.copiedQqGroupId,
                    ),
                  ),
                  onPress: () => _copyText(
                    context,
                    _qqGroupId,
                    successMessage: l10n.copiedQqGroupId,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }
}
