import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  static const String _issuesUrl =
      'https://github.com/Mutx163/mikcb/issues';
  static const String _xiaohongshuId = '4976443029';
  static const String _coolapkId = 'Mutx666';
  static const String _qqGroupId = '1077077989';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('问题反馈'),
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
                    '如果你遇到崩溃、课程显示异常、导入问题，或者想提交功能建议，可以通过下面这些渠道反馈。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '涉及复现步骤、截图、版本号和日志的问题，建议优先走 GitHub Issue。',
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
            title: 'GitHub Issue',
            subtitle: '打开仓库 Issue 页面，可提交问题、建议或查看已有反馈记录。',
            primaryLabel: '打开 Issue 页面',
            onPrimaryTap: () => _openUrl(_issuesUrl),
            secondaryLabel: '复制地址',
            onSecondaryTap: () => _copyText(
              context,
              _issuesUrl,
              successMessage: '已复制 Issue 地址',
            ),
          ),
          const SizedBox(height: 12),
          _FeedbackCard(
            icon: Icons.forum_outlined,
            title: '小红书',
            subtitle: '作者小红书号：$_xiaohongshuId',
            primaryLabel: '复制小红书号',
            onPrimaryTap: () => _copyText(
              context,
              _xiaohongshuId,
              successMessage: '已复制小红书号',
            ),
          ),
          const SizedBox(height: 12),
          _FeedbackCard(
            icon: Icons.verified_user_outlined,
            title: '酷安',
            subtitle: '作者酷安号：$_coolapkId',
            primaryLabel: '复制酷安号',
            onPrimaryTap: () => _copyText(
              context,
              _coolapkId,
              successMessage: '已复制酷安号',
            ),
          ),
          const SizedBox(height: 12),
          _FeedbackCard(
            icon: Icons.groups_outlined,
            title: 'QQ群',
            subtitle: 'QQ群号：$_qqGroupId',
            primaryLabel: '复制群号',
            onPrimaryTap: () => _copyText(
              context,
              _qqGroupId,
              successMessage: '已复制 QQ 群号',
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
