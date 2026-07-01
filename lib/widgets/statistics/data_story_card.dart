import 'package:flutter/material.dart';

import '../../models/statistics_models.dart';

/// 数据故事卡片
class DataStoryCard extends StatelessWidget {
  final DataStory story;

  const DataStoryCard({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  story.icon,
                  size: 22,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildRichContent(
                    context,
                    story.content,
                    colorScheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建富文本内容（加粗关键数据）
  Widget _buildRichContent(
    BuildContext context,
    String content,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];

    // 使用正则匹配 **text** 格式
    final pattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in pattern.allMatches(content)) {
      // 添加匹配前的普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
        ));
      }

      // 添加加粗文本
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ));

      lastEnd = match.end;
    }

    // 添加剩余的普通文本
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }
}

/// 数据故事列表
class DataStoryList extends StatelessWidget {
  final List<DataStory> stories;

  const DataStoryList({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: stories
          .map((story) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DataStoryCard(story: story),
              ))
          .toList(),
    );
  }
}
