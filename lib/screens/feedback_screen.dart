import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/settings_section_widgets.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  static const String _issuesUrl = 'https://github.com/Mutx163/mikcb/issues';
  static const String _xiaohongshuId = '4976443029';
  static const String _coolapkId = 'Mutx666';
  static const String _qqGroupId = '1077077989';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            SettingsSectionCard(
              subtitle: l10n.feedbackIntro,
              child: Text(
                l10n.feedbackIssueHint,
                style: context.theme.typography.body.xs2,
              ),
            ),
            const SizedBox(height: 12),
            FTileGroup(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                FTile(
                  prefix: const Icon(Icons.bug_report_outlined),
                  title: Text(l10n.githubIssueTitle),
                  subtitle: Text(l10n.githubIssueSubtitle),
                  suffix: FButton.icon(
                    variant: FButtonVariant.ghost,
                    onPress: () => _copyText(
                      context,
                      _issuesUrl,
                      successMessage: l10n.copiedIssueAddress,
                    ),
                    child: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  onPress: () => _openUrl(_issuesUrl),
                ),
                FTile(
                  prefix: const Icon(Icons.forum_outlined),
                  title: Text(l10n.feedbackXiaohongshuTitle),
                  subtitle: Text(
                    l10n.feedbackXiaohongshuSubtitle(_xiaohongshuId),
                  ),
                  suffix: FButton.icon(
                    variant: FButtonVariant.ghost,
                    onPress: () => _copyText(
                      context,
                      _xiaohongshuId,
                      successMessage: l10n.copiedXiaohongshuId,
                    ),
                    child: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  onPress: () => _copyText(
                    context,
                    _xiaohongshuId,
                    successMessage: l10n.copiedXiaohongshuId,
                  ),
                ),
                FTile(
                  prefix: const Icon(Icons.verified_user_outlined),
                  title: Text(l10n.feedbackCoolapkTitle),
                  subtitle: Text(l10n.feedbackCoolapkSubtitle(_coolapkId)),
                  suffix: FButton.icon(
                    variant: FButtonVariant.ghost,
                    onPress: () => _copyText(
                      context,
                      _coolapkId,
                      successMessage: l10n.copiedCoolapkId,
                    ),
                    child: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  onPress: () => _copyText(
                    context,
                    _coolapkId,
                    successMessage: l10n.copiedCoolapkId,
                  ),
                ),
                FTile(
                  prefix: const Icon(Icons.groups_outlined),
                  title: Text(l10n.feedbackQqGroupTitle),
                  subtitle: Text(l10n.feedbackQqGroupSubtitle(_qqGroupId)),
                  suffix: FButton.icon(
                    variant: FButtonVariant.ghost,
                    onPress: () => _copyText(
                      context,
                      _qqGroupId,
                      successMessage: l10n.copiedQqGroupId,
                    ),
                    child: const Icon(Icons.copy_rounded, size: 18),
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
