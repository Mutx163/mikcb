/// 架构守卫：**界面文案风格**（超宽与死键）。
///
/// 判据、上限、宽度算法全部在 `tool/copy_style_rules.dart` —— 本文件只负责
/// 「把它们跟基线比一比，多了一条就红」。CLI 自查是
/// `dart run tool/copy_style_lint.dart`，两者共用同一份实现，口径不会漂。
///
/// ## 为什么需要它
///
/// 2026-10-20～21 那轮文案简洁化没有机器检查，后果是可数的：
/// `8d1dff31` 立下「灰字 17 字」，四小时后 `1eab2028` 自己写出 25 字；
/// 同批还留下 9 条没人引用的孤儿键。**没有守卫的规则等于没有规则** ——
/// 这一点仓库自己已经证明过一次。
///
/// ## 两种模式
///
/// - **增量模式（默认，CI 与日常提交走这条）**：只拦「基线里没有的新违规」。
///   存量逐批清理，清一条删一行基线；删掉的行不许加回来。
/// - **存量已够大，为什么不一次清完**：202 条里中文只有 5 条、外语 197 条。
///   「17 字」这个上限是 400dp 屏量中文得出的，外语本来就宽一倍，
///   从没按同一口径写过。一次清完外语 197 条是把翻译全部重写，
///   与「文案简洁化」不是同一件事，需要单独一批。
///
/// ## 纪律
///
/// 所有读文件都经 [GuardSource.resolve]：pre-commit 会把本次提交物化成快照，
/// 守卫必须判定「这次提交的内容」，而不是混着别人在途改动的工作区。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/copy_style_rules.dart';
import 'guard_source.dart';

const _baselinePath = 'tool/copy_style_baseline.txt';
const _deadBaselinePath = 'tool/copy_style_dead_keys_baseline.txt';

/// 复述基线：说明句在标题之外没有新信息的存量（只减不增）。
const _restatingBaselinePath = 'tool/copy_style_restating_baseline.txt';

/// 开发者专用页：技术字段本来就长，且只对调试构建可见。
///
/// 与 `bfc6b6bf` 的取舍一致。**不是豁免**：不进基线、也不拦，
/// 单独计数——以后要收也有个数字在。
const _devOnlySources = <String>{
  'lib/screens/memory_stats_screen.dart',
  'lib/screens/hyperos_showcase_screen.dart',
  'lib/screens/miuix_showcase_screen.dart',
  'lib/screens/import/warehouse/warehouse_custom_debug_screen.dart',
  'lib/screens/live_diagnostics_log_viewer_screen.dart',
};

Set<String> _loadIds(String path) {
  final file = File(GuardSource.resolve(path));
  if (!file.existsSync()) {
    fail('文案风格基线不存在：${file.path}');
  }
  return file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

void main() {
  final arbByLocale = loadArbs(GuardSource.resolve);
  final sources = loadSources(GuardSource.resolve);

  test('行内文案不得新增超宽（存量已冻结在基线里）', () {
    final violations = findViolations(
      sources: sources,
      arbByLocale: arbByLocale,
    );
    final baseline = _loadIds(_baselinePath);

    final live = violations
        .where((v) => !_devOnlySources.contains(v.source))
        .toList();
    final added = live
        .where((v) => !baseline.contains(violationId(v)))
        .toList();

    expect(
      added,
      isEmpty,
      reason:
          '这 ${added.length} 处行内文案超宽：\n'
          '${added.map((v) => '  $v').join('\n')}\n\n'
          '判据（tool/copy_style_rules.dart）：右侧有开关/取值/箭头的行，'
          '标题 ≤ ${titleMaxWidth.toStringAsFixed(0)}、说明句 ≤ '
          '${subtitleMaxWidth.toStringAsFixed(0)}（按渲染宽度，汉字算 1）。\n'
          '超宽不是「写得不够简洁」，是**真的折行**：400dp 屏上这行会变成两行，'
          '一屏看着繁杂——这正是这轮简洁化要修的东西。\n'
          '改法：删掉复述标题/导航说明/过程描述，或把「为什么」留在句子里、'
          '把「怎么做」交给界面本身。\n'
          '整宽段落（HyperosSectionDescription / 对话框正文）不在本规则内，'
          '它们本来就该多行。',
    );
  });

  test('说明句不得新增「复述标题」（存量已冻结在基线里）', () {
    final restating = findRestatingSubtitles(
      sources: sources,
      arbByLocale: arbByLocale,
    );
    final baseline = _loadIds(_restatingBaselinePath);

    final live = restating
        .where((v) => !_devOnlySources.contains(v.source))
        .toList();
    final added = live.where((v) => !baseline.contains(restatingId(v))).toList();

    expect(
      added,
      isEmpty,
      reason:
          '这 ${added.length} 处说明句只是在复述标题（去掉标题已有的词之后，'
          '没剩下什么新信息）：\n'
          '${added.map((v) => '  $v').join('\n')}\n\n'
          '判据（tool/copy_style_rules.dart 的 restatingResidue）：'
          '把说明句切词、剥掉行首操作动词，再看去掉「标题里已有的词」和'
          '「纯连接词」之后还剩几个词。剩 ≤ $restatingResidueMaxTokens 个，'
          '说明它没告诉用户标题之外的东西。\n'
          '改法：删掉说明句（布局已经说清了）；真要保留，就让它说清'
          '「关掉会怎样 / 什么前提下才生效」这种标题给不出的信息。\n'
          '确需放过（旧版本兼容等）就在 $_restatingBaselinePath 里'
          '裸写 `语言/说明键名` 并注明原因，但那是待办不是豁免。',
    );
  });

  test('死键只减不增（删了渲染就顺手删键）', () {
    final template = arbByLocale['zh']!;
    final dead = findDeadKeys(
      template: template,
      codeCorpus: sources.values.join('\n'),
    );
    final frozen = _loadIds(_deadBaselinePath);
    final added = dead.difference(frozen).toList()..sort();

    expect(
      added,
      isEmpty,
      reason:
          '这 ${added.length} 个键成了死键（ARB 里有、代码从不引用）：\n'
          '${added.map((k) => '  $k = ${template[k]}').join('\n')}\n\n'
          '删掉一处渲染时请把键一起删（六份 ARB 同步）——留着它的唯一效果是'
          '让下一次文案扫描把「已经不上屏的字」当成待办，并且误导后来者以为它还在用。\n'
          '真要保留（比如给旧版本兼容），在 tool/copy_style_baseline.txt 里'
          '裸写键名并注明原因。',
    );
  });

  test('基线文件自身合法（有序、无重复、无过期项）', () {
    for (final path in [_baselinePath, _deadBaselinePath]) {
      final raw = File(
        GuardSource.resolve(path),
      ).readAsLinesSync().map((line) => line.trim()).where(
        (line) => line.isNotEmpty && !line.startsWith('#'),
      ).toList();

      expect(
        raw.length,
        raw.toSet().length,
        reason: '$path 有重复行，会让「新增」判断失真',
      );
      expect(
        raw,
        equals([...raw]..sort()),
        reason: '$path 必须按字典序，diff 才干净',
      );
    }

    // 过期项 = 基线里写着、但现在已经不违规了。不清掉的话基线会越来越长，
    // 变成一个「说什么都豁免」的垃圾场——那正是它失去意义的方式。
    final violations = findViolations(
      sources: sources,
      arbByLocale: arbByLocale,
    );
    final current = violations.map(violationId).toSet();
    final template = arbByLocale['zh']!;
    final dead = findDeadKeys(
      template: template,
      codeCorpus: sources.values.join('\n'),
    );

    final staleWidths =
        (_loadIds(_baselinePath).difference(current).toList()..sort());
    final staleDead =
        (_loadIds(_deadBaselinePath).difference(dead).toList()..sort());

    expect(
      staleWidths,
      isEmpty,
      reason:
          '$_baselinePath 里这 ${staleWidths.length} 条已经不再超宽了，'
          '请删掉这些行：\n'
          '${staleWidths.map((id) => '  - $id').join('\n')}\n'
          '基线是待办清单，不是豁免记录。留着过期项会让它失去「只减不增」的意义。',
    );
    expect(
      staleDead,
      isEmpty,
      reason:
          '$_deadBaselinePath 里这 ${staleDead.length} 个键已经被引用或已删除，'
          '请删掉这些行：\n'
          '${staleDead.map((id) => '  - $id').join('\n')}',
    );
  });
}
