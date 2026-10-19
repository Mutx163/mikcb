import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/app_update_service.dart';
import 'package:university_timetable/utils/release_notes_digest.dart';

/// 真实样本：2026-10-19 从
/// `https://github.com/Mutx163/mikcb/releases/tag/v2.1.3.4` 抓到的
/// `div[data-test-selector="body-content"]` 内层 HTML（292 字符，原样）。
const String _realReleasePageBodyHtml = '''
<h1>v2.1.3.4</h1>
<blockquote>
<p>本次重点：桌面小组件「效果预览」、小组件周末文案</p>
</blockquote>
<ul>
<li>新增 设置页的「桌面小组件效果预览」：十种卡片按真实渲染 1:1 出图，左右滑动切换；背景样式、卡片圆角、课程色、界面语言、深浅色一改，预览当场跟着变，不用先加一块到桌面才知道长什么样；下方「添加到桌面」跟随当前那一张。</li>
<li>新增 桌面小组件的周末文案：周六、周日一节课都没排时显示「周末愉快」，周五没课了显示「周末要开始了」；调休上班的周末不算周末，周末有课时也不会误显示。</li>
</ul>''';

void main() {
  test('Release 页面 HTML 能还原出摘要解析器认得的 Markdown', () {
    final markdown = htmlBodyToMarkdown(_realReleasePageBodyHtml);

    expect(markdown, contains('# v2.1.3.4'));
    expect(markdown, contains('> 本次重点：桌面小组件「效果预览」、小组件周末文案'));
    expect(markdown, contains('- 新增 设置页的「桌面小组件效果预览」'));
    expect(markdown, contains('- 新增 桌面小组件的周末文案'));
    // 引用块不能只剩一个孤零零的「>」——那会让「> 本次重点」永远匹配不上。
    expect(markdown.split('\n').where((l) => l.trim() == '>'), isEmpty);
  });

  test('还原后的文本能出摘要：2 条重点，不是退回整段正文', () {
    final digest = buildReleaseNotesDigest(
      htmlBodyToMarkdown(_realReleasePageBodyHtml),
    );

    expect(digest.entries.length, 2);
    expect(digest.highlights.length, 2);
    expect(digest.total, 2);
    expect(digest.highlights.first.label, '新增');
    expect(digest.highlights.first.headline, contains('桌面小组件「效果预览」'));
  });

  test('行内标签与实体只留文字，二级标题保住分组', () {
    final markdown = htmlBodyToMarkdown(
      '<h2>新增 · 2</h2>\n'
      '<ul>\n'
      '<li><strong>粗体</strong>与<code>代码</code>与<a href="/x">链接</a></li>\n'
      '<li>A &amp; B&nbsp;&nbsp;C</li>\n'
      '</ul>',
    );

    expect(markdown, contains('## 新增 · 2'));
    expect(markdown, contains('- 粗体与代码与链接'));
    expect(markdown, contains('A & B'));
    // 行内标签不该把 Markdown 的列表符号带坏
    expect(markdown, isNot(contains('<strong>')));
    expect(markdown, isNot(contains('<a ')));
  });

  test('纯段落正文不会被强行改结构', () {
    final markdown = htmlBodyToMarkdown(
      '<p>第一段</p>\n<p>第二段</p>',
    );
    expect(markdown, '第一段\n\n第二段');
  });
}
