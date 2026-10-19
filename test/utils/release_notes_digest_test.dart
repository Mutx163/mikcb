import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/release_notes_digest.dart';

/// 更新弹窗的「本次更新重点」（2026-10-18）。
///
/// 背景：发布说明是扁平一长串条目（v2.1.3.2 有 46 条），弹窗原来只是去掉标题后
/// 取前 4 行当作摘要 —— 用户看到的永远是「一大串更新内容的顶部」，而且一条 60 字的
/// 说明会在第二行中途被截断。这里钉住三件事：
///
/// 1. **分类**：`docs/release.md` 规定条目以「新增 / 优化 / 修复 / 移除」开头，
///    分类与计数都该认这四种词（英文正文的 New / Fixed 也要认）；
/// 2. **短标题**：重点行只放第一个「：」之前的半句，完整句子留给展开列表；
/// 3. **重点怎么挑**：作者显式声明的优先（`> 本次重点：A、B`），没声明时按
///    `新增 > 优化 > 移除 > 修复` 取前几条。
void main() {
  group('分类与短标题', () {
    test('真实片段：四条中文条目分类正确，重点取前三条新增且只留半句', () {
      const body = '# v2.1.3.3\n'
          '\n'
          '- 新增 壁纸图库的 Wallhaven 竖版图源：直接取原生竖图，并按手机实际分辨率下载，'
          '不再先拉一张超大图再由 App 放大；图库清单拉不到时先用上次的缓存。\n'
          '- 新增 超级岛「速览」：显示设置页加悬浮按钮，不用先选课就能让岛按当前阶段直接弹出。\n'
          '- 新增 课前快捷操作的勿扰选项：需要哪些权限提前可见、下课恢复不会越权改回别的设置。\n'
          '- 优化 每日壁纸开关的说明写清归属：开关是所有课表共用的，但每天换的图只应用到当前这份课表。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.total, 4, reason: '四条条目都要被数出来，弹窗的「查看全部 N 项」靠它');
      expect(digest.countOf(ReleaseChangeKind.added), 3);
      expect(digest.countOf(ReleaseChangeKind.improved), 1);
      expect(digest.countOf(ReleaseChangeKind.fixed), 0);
      expect(digest.highlightsDeclared, isFalse, reason: '没有声明重点时按分类优先级推断');
      expect(
        digest.highlights.map((entry) => entry.headline).toList(),
        <String>[
          '壁纸图库的 Wallhaven 竖版图源',
          '超级岛「速览」',
          '课前快捷操作的勿扰选项',
        ],
        reason: '重点行必须是「：」之前的半句；整句塞进弹窗还是原来那个看不完的长文本',
      );
      expect(
        digest.highlights.first.text,
        startsWith('壁纸图库的 Wallhaven 竖版图源：'),
        reason: '展开列表要能读到完整句子，不能只剩短标题',
      );
      expect(digest.highlights.first.label, '新增');
    });

    test('英文正文也认分类；大写写法原样保留成标签', () {
      const body = '- New: Bing daily wallpaper library\n'
          '- Fixed: startup crash when restoring a killed process\n'
          '- Improved: settings page layout\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.total, 3);
      expect(digest.countOf(ReleaseChangeKind.added), 1);
      expect(digest.countOf(ReleaseChangeKind.fixed), 1);
      expect(digest.countOf(ReleaseChangeKind.improved), 1);
      expect(digest.highlights.first.label, 'New');
      expect(digest.highlights.first.headline, 'Bing daily wallpaper library');
    });

    test('历史写法 `-新增`（没有空格）照样能分类', () {
      final digest = buildReleaseNotesDigest('-新增任务：添加与编辑任务页支持设置完成状态\n');

      expect(digest.total, 1);
      expect(digest.countOf(ReleaseChangeKind.added), 1);
      expect(digest.highlights.single.headline, '任务');
    });

    test('没有冒号的长句按两行尺度截断，避免重点行自己变成一段话', () {
      const body =
          '- 修复 桌面小组件色条颜色不跟着刷新（表现为「字是绿的、色条是红的」，重启桌面也没用，'
          '只有改一次主题色才会重新取色）\n';

      final digest = buildReleaseNotesDigest(body);

      final headline = digest.highlights.single.headline;
      expect(headline.runes.length, lessThanOrEqualTo(41), reason: '40 字 + 省略号');
      expect(headline, endsWith('…'));
    });
  });

  group('正文里的非条目行', () {
    test('版本标题、分隔线、SHA-256 行、表格、图片、缩进子项都不算条目', () {
      const body = '\uFEFF# v2.1.3.3\r\n'
          '\r\n'
          '- 修复 启动崩溃：被系统杀掉后重开不再闪一帧\r\n'
          '  - 这是上一条的细节说明，不该单独计数\r\n'
          '\r\n'
          '---\r\n'
          '\r\n'
          'SHA-256: 9f2c1b\r\n'
          'SHA-256-File: mikcb-2.1.3.3-arm64-v8a.apk\r\n'
          '\r\n'
          '| 平台 | 状态 |\r\n'
          '| --- | --- |\r\n'
          '\r\n'
          '![截图](https://example.com/a.png)\r\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.total, 1, reason: '只有那条修复是真条目');
      expect(digest.highlights.single.headline, '启动崩溃');
      expect(
        digest.entries.single.text,
        isNot(contains('SHA-256')),
        reason: 'CI 追加在正文末尾的摘要行不能被当成更新内容',
      );
    });

    test('只有标题没有条目的正文返回空摘要，弹窗回落到原来的提示', () {
      final digest = buildReleaseNotesDigest('# v1.0.0\n\n本次更新优化了稳定性。\n');

      expect(digest.isEmpty, isTrue);
      expect(digest.highlights, isEmpty);
    });

    test('markdown 加粗、行内代码、链接都从展示文本里去掉', () {
      const body = '- **新增** 支持 [GitCode](https://gitcode.com/x) 镜像与 `extra` 源\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.entries.single.text, '支持 GitCode 镜像与 extra 源');
      expect(digest.entries.single.label, '新增');
    });
  });

  group('作者声明的重点', () {
    test('顶部引用行的重点是权威来源，作者用的简写要能对上条目（模糊匹配）', () {
      const body = '# v2.1.3.2\n'
          '\n'
          '> 本次重点：Bing 每日壁纸库、十档玻璃滑杆\n'
          '\n'
          '- 新增 Bing 每日壁纸库：设置里能直接拉取 Bing 最近 8 天的每日壁纸自己挑。\n'
          '- 新增 首页顶栏玻璃带：会随整机默认材质自动切换为实体卡片或液态玻璃。\n'
          '- 优化 液态玻璃的档位改成一根 10 格节点滑杆：从「清澈」到「浓密」共 10 格。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.highlightsDeclared, isTrue);
      expect(
        digest.highlights.map((entry) => entry.headline).toList(),
        <String>['Bing 每日壁纸库', '十档玻璃滑杆'],
        reason: '声明的简写就是要显示的那一句，不该被换成正文里的长句',
      );
      expect(
        digest.highlights.map((entry) => entry.kind).toList(),
        <ReleaseChangeKind>[
          ReleaseChangeKind.added,
          ReleaseChangeKind.improved,
        ],
        reason: '简写「十档玻璃滑杆」和正文「10 格节点滑杆」字面不同，要靠相似度认回优化类',
      );
    });

    test('「## 本次重点」小节里的条目也算声明，且不挤占条目列表', () {
      const body = '# v2.0.0\n'
          '\n'
          '## 本次重点\n'
          '\n'
          '- 新增 情侣课表桌面卡片\n'
          '- 优化 玻璃模式收敛为三档\n'
          '\n'
          '## 全部更新\n'
          '\n'
          '- 新增 情侣课表桌面卡片：导入 TA 课表后合并显示。\n'
          '- 优化 玻璃模式：由四档收敛为三档。\n'
          '- 修复 实体卡片模式下菜单文字看不清。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.highlightsDeclared, isTrue);
      expect(
        digest.highlights.map((entry) => entry.headline).toList(),
        <String>['情侣课表桌面卡片', '玻璃模式收敛为三档'],
      );
      expect(digest.total, 5, reason: '声明小节里的两条本身就是变更，也要计入总数');
    });

    test('声明的简写对不上任何条目时，也照样把它显示出来（kind 记 other）', () {
      const body = '> 本次重点：某个正文里没写的改动\n\n- 修复 别的问题：细节\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.highlightsDeclared, isTrue);
      expect(digest.highlights.single.headline, '某个正文里没写的改动');
      expect(digest.highlights.single.kind, ReleaseChangeKind.other);
    });

    test('没有声明时按 新增 > 优化 > 移除 > 修复 的既有优先级挑重点', () {
      const body = '- 修复 甲：细节\n'
          '- 移除 乙：细节\n'
          '- 优化 丙：细节\n'
          '- 新增 丁：细节\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.highlightsDeclared, isFalse);
      expect(
        digest.highlights.map((entry) => entry.headline).toList(),
        <String>['丁', '丙', '乙'],
        reason: '修复属于「细节」，排在最后；这正是 docs/RELEASE.md 的优先级',
      );
    });

    test('全是修复的版本也要挑得出重点', () {
      const body = '- 修复 启动崩溃：细节\n- 修复 保存失败：细节\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.highlights.length, 2);
      expect(digest.highlights.first.kind, ReleaseChangeKind.fixed);
    });
  });

  group('条数上限与计数', () {
    test('默认最多 3 条重点，超出由参数控制', () {
      final body = List.generate(
        8,
        (index) => '- 新增 功能$index：细节',
      ).join('\n');

      expect(buildReleaseNotesDigest(body).highlights.length, 3);
      expect(
        buildReleaseNotesDigest(body, maxHighlights: 5).highlights.length,
        5,
      );
      expect(buildReleaseNotesDigest(body, maxHighlights: 0).highlights, isEmpty);
    });

    test('计数行按 新增 · 优化 · 修复 · 移除 的固定顺序，0 条不出现', () {
      const body = '- 修复 甲：细节\n- 新增 乙：细节\n- 移除 丙：细节\n- 新增 丁：细节\n';

      final counts = releaseChangeCounts(buildReleaseNotesDigest(body));

      expect(counts, <(String, int)>[('新增', 2), ('修复', 1), ('移除', 1)]);
    });

    test('无法识别的条目照样计入总数，只是没有分类标签', () {
      const body = '- 顺手改了一处措辞\n- 新增 真功能：细节\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.total, 2);
      expect(digest.countOf(ReleaseChangeKind.other), 1);
      expect(releaseChangeCounts(digest), <(String, int)>[('新增', 1)]);
    });
  });

  group('按分类分组的新版格式', () {
    test('分组标题定分类、标题带条数；条目本身不带前缀', () {
      const body = '# v2.1.4\n'
          '\n'
          '> 本次重点：桌面小组件效果预览、周末文案\n'
          '\n'
          '## 新增 · 2\n'
          '\n'
          '- 设置页的「桌面小组件效果预览」：十种卡片按真实渲染就地出图。\n'
          '- 桌面小组件的周末文案：周末没课显示「周末愉快」。\n'
          '\n'
          '## 优化 · 1\n'
          '\n'
          '- 启动：换入首页加一次交叉淡入。\n'
          '\n'
          '## 修复 · 2\n'
          '\n'
          '- 顶栏标题：四字标题不再被挤成省略号。\n'
          '- 壁纸：切回时位置不再错。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.total, 5);
      expect(digest.countOf(ReleaseChangeKind.added), 2);
      expect(digest.countOf(ReleaseChangeKind.improved), 1);
      expect(digest.countOf(ReleaseChangeKind.fixed), 2);
      expect(
        digest.entries.map((entry) => entry.label).toSet(),
        <String>{'新增', '优化', '修复'},
        reason: '计数行的分类词应沿用分组标题里的写法',
      );
      expect(
        digest.entries.first.text,
        '设置页的「桌面小组件效果预览」：十种卡片按真实渲染就地出图。',
        reason: '新格式条目不带前缀，正文不该被再剥一次',
      );
      expect(digest.highlightsDeclared, isTrue);
      expect(
        digest.highlights.map((entry) => entry.headline),
        <String>['桌面小组件效果预览', '周末文案'],
      );
      expect(digest.highlights.first.kind, ReleaseChangeKind.added);
    });

    test('emoji 装饰标题、英文分组标题都能认', () {
      const body = '# v3.0.0\n'
          '\n'
          '### ✨ 修复\n'
          '\n'
          '- 启动崩溃：重开不再闪一帧。\n'
          '\n'
          '### Removed\n'
          '\n'
          '- 旧版导入入口：统一走新流程。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.countOf(ReleaseChangeKind.fixed), 1);
      expect(digest.countOf(ReleaseChangeKind.removed), 1);
      expect(digest.entries.map((entry) => entry.label).toList(), <String>[
        '修复',
        'Removed',
      ]);
    });

    test('认不出分类的标题会清掉继承，不把后面的条目算进上一组', () {
      const body = '# v3.0.0\n'
          '\n'
          '## 修复\n'
          '- 甲：细节。\n'
          '\n'
          '## 其它说明\n'
          '- 这一条本来就不属于任何分类。\n'
          '\n'
          '## 新增\n'
          '- 乙：细节。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.countOf(ReleaseChangeKind.fixed), 1);
      expect(digest.countOf(ReleaseChangeKind.other), 1);
      expect(digest.countOf(ReleaseChangeKind.added), 1);
      expect(
        digest.entries[1].kind,
        ReleaseChangeKind.other,
        reason: '认不出的标题之后不能沿用上一组的「修复」',
      );
    });

    test('加粗的「本次重点」引用行也认', () {
      const body = '> **本次重点**：A 功能、B 修复\n\n## 新增\n- A 功能：说明。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.highlightsDeclared, isTrue);
      expect(digest.highlights.map((entry) => entry.headline), <String>[
        'A 功能',
        'B 修复',
      ]);
    });
  });

  group('导语', () {
    test('第一条条目之前的概括句会成为导语，冒号引导句不算', () {
      const body = '# 轻屿课表 1.1.0\n'
          '\n'
          '首个推荐版本。\n'
          '\n'
          '本次更新：\n'
          '\n'
          '- 应用正式更名为「轻屿课表」。\n';

      final digest = buildReleaseNotesDigest(body);

      expect(digest.intro, '首个推荐版本。');
      expect(digest.total, 1);
    });

    test('条目之后再出现的文字不会被当成导语', () {
      const body = '# v2.0.0\n\n- 新增 甲：细节。\n\n后来补充的一句话。\n';

      expect(buildReleaseNotesDigest(body).intro, isEmpty);
    });
  });

  // 2026-10-19：发 v2.1.4.1 时把重点写成「转场掉帧」（条目里写的是「转场更顺」），
  // 解析器认不回来仍会保留这条简写，只是降级成 kind=other、label 为空——
  // 界面上是一条没有分类标签的灰色重点，而当时的门禁察觉不到。
  group('声明的重点认不回来时能被指出来', () {
    test('重点里写了条目中没有的说法 → 进 unresolvedHighlights', () {
      const body = '# v2.1.4.1\n'
          '\n'
          '> 本次重点：软件更新页重做、转场掉帧\n'
          '\n'
          '## 优化 · 2\n'
          '\n'
          '- 软件更新页重做：一个状态只给一个动作。\n'
          '- 转场更顺：把悬浮钮冻结成预糊位图。\n';

      final digest = buildReleaseNotesDigest(body);
      expect(digest.highlightsDeclared, isTrue);
      expect(digest.highlights.length, 2);
      // 第一条认回「软件更新页重做」
      expect(digest.highlights.first.kind, ReleaseChangeKind.improved);
      expect(digest.highlights.first.label, '优化');
      // 第二条认不回来：kind=other、无标签，且能被 getter 点出来
      expect(digest.unresolvedHighlights.map((e) => e.headline), ['转场掉帧']);
    });

    test('重点抄条目里的原话 → unresolvedHighlights 为空', () {
      const body = '# v2.1.4.1\n'
          '\n'
          '> 本次重点：软件更新页重做、转场更顺\n'
          '\n'
          '## 优化 · 2\n'
          '\n'
          '- 软件更新页重做：一个状态只给一个动作。\n'
          '- 转场更顺：把悬浮钮冻结成预糊位图。\n';

      final digest = buildReleaseNotesDigest(body);
      expect(digest.unresolvedHighlights, isEmpty);
      expect(digest.highlights.map((e) => e.label), ['优化', '优化']);
    });
  });
}
