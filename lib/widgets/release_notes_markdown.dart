import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 发布说明正文的 Markdown 渲染（2026-10-20 自 `screens/about_screen.dart` 抽出）。
///
/// ## 为什么住 widgets 层
///
/// 这段渲染被两处使用：关于页的「更新说明」区、更新日志页的条目正文。原先
/// 它定义在 `about_screen.dart` 里，于是 `changelog_screen.dart` 为了拿这一个
/// 类去 import 整个关于页；而关于页本身又要推更新日志页 —— 两边互相 import，
/// 构成 `screens/about_screen ↔ screens/changelog_screen` 的环。
///
/// 抽到 widgets 层后两边都从下往上依赖它，环就断了。这不是「把 import 搬进
/// 免检目录」：`lib/widgets/` 在层表里，dep_graph 照常判定；而且这里的依赖
/// 方向本来就是对的——一段纯渲染组件本来就该住 widgets，不该住某个具体页面。
///
/// ## 行为
///
/// 逐字搬自原实现，未改一个像素：同样的 `MarkdownBody` 参数、
/// 同样的样式表构建、同样的版本标题剥离规则。原文件保留 re-export 以免
/// 既有调用点（`about_screen.dart:1155`、`changelog_screen.dart:327`）受影响。
class ReleaseNotesMarkdown extends StatelessWidget {
  final String data;
  final ValueChanged<String?>? onTapLink;
  final bool plainTypography;
  final bool usePrimaryTextColor;

  static final RegExp _versionHeadingPattern = RegExp(
    r'^#\s+v[\d.\-a-zA-Z]+',
    caseSensitive: false,
  );

  const ReleaseNotesMarkdown({
    super.key,
    required this.data,
    this.onTapLink,
    this.plainTypography = false,
    this.usePrimaryTextColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = plainTypography ? _stripVersionHeading(data) : data;
    final styleSheet = _buildReleaseNotesStyleSheet(
      context,
      plainTypography: plainTypography,
      usePrimaryTextColor: usePrimaryTextColor,
    );
    final bulletStyle = styleSheet.listBullet;
    return MarkdownBody(
      data: normalized,
      styleSheet: styleSheet,
      listItemCrossAxisAlignment: plainTypography
          ? MarkdownListItemCrossAxisAlignment.start
          : MarkdownListItemCrossAxisAlignment.baseline,
      bulletBuilder: plainTypography
          ? (_) => Text('·', style: bulletStyle?.copyWith(height: 1.35))
          : null,
      onTapLink: (text, href, title) => onTapLink?.call(href),
    );
  }

  static String _stripVersionHeading(String data) {
    final lines = data.split('\n');
    var start = 0;
    if (lines.isNotEmpty &&
        _versionHeadingPattern.hasMatch(lines.first.trim())) {
      start = 1;
      while (start < lines.length && lines[start].trim().isEmpty) {
        start++;
      }
    }
    return lines.sublist(start).join('\n').trim();
  }

  static MarkdownStyleSheet _buildReleaseNotesStyleSheet(
    BuildContext context, {
    required bool plainTypography,
    required bool usePrimaryTextColor,
  }) {
    final theme = Theme.of(context);
    if (!plainTypography) {
      return MarkdownStyleSheet.fromTheme(theme);
    }
    final onSurface = theme.colorScheme.onSurface;
    final body = usePrimaryTextColor
        ? HyperosTypography.sectionDescription(
            context,
          ).copyWith(color: onSurface)
        : HyperosTypography.sectionDescription(context);
    final sectionHeader = body.copyWith(fontWeight: FontWeight.w600);
    final linkColor = usePrimaryTextColor
        ? onSurface
        : theme.colorScheme.primary;
    return MarkdownStyleSheet(
      p: body,
      pPadding: EdgeInsets.zero,
      listBullet: body,
      listIndent: 12,
      listBulletPadding: const EdgeInsets.only(right: 4),
      blockSpacing: 6,
      h1: sectionHeader,
      h1Padding: EdgeInsets.zero,
      h2: sectionHeader,
      h2Padding: const EdgeInsets.only(top: 8, bottom: 2),
      h3: sectionHeader,
      h3Padding: EdgeInsets.zero,
      h4: body,
      h5: body,
      h6: body,
      strong: body.copyWith(fontWeight: FontWeight.w500),
      em: body.copyWith(fontStyle: FontStyle.italic),
      a: body.copyWith(color: linkColor, decoration: TextDecoration.underline),
      blockquote: body,
      blockquotePadding: const EdgeInsets.only(left: 12),
      code: body.copyWith(
        fontFamily: 'monospace',
        fontSize: (body.fontSize ?? 14) - 1,
      ),
      // markdown `---`（GitCode 正文里更新日志与 SHA-256 之间的分隔）默认按
      // flutter_markdown 内建值渲染成 5px 粗线，视觉上像一条大黑杠。统一换成
      // MIUI 规范的 0.75px 发丝线，与卡内其他分隔线一致。
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            width: HyperosMiuixDivider.thickness,
            color: HyperosColors.dividerLine(context),
          ),
        ),
      ),
    );
  }
}
