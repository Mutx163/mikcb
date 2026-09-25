import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防回归：占位符在 6 个语言之间必须一致，且不能被多余引号包住。
///
/// 真实踩过的两个坑：
/// 1. 批量替换时值被 JSON.stringify 两次，落盘成 "key": "\"值\""，
///    解析后值两端各多一个引号，台湾版一次中招 120 条。
/// 2. 同一个键在不同语言里占位符集合不同，句子会缺信息
///    （locationTimeMatchApplyOverflowResult 的 {matched} 只有部分语言用了）。
void main() {
  const locales = ['zh', 'zh_TW', 'zh_HK', 'en', 'ja', 'ko'];
  final arbs = <String, String>{
    for (final l in locales) l: 'lib/l10n/app_$l.arb',
  };

  Map<String, dynamic> load(String locale) {
    final f = File(arbs[locale]!);
    if (!f.existsSync()) fail('${arbs[locale]} 不存在');
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  final data = {for (final l in locales) l: load(l)};

  Iterable<MapEntry<String, dynamic>> values(String l) =>
      data[l]!.entries.where((e) =>
          e.key != '@@locale' &&
          !e.key.startsWith('@') &&
          e.value is String &&
          (e.value as String).trim().isNotEmpty);

  final placeholderRe = RegExp(r'\{[^}]*\}');
  String placeholders(Object? v) =>
      (placeholderRe.allMatches(v.toString()).map((m) => m.group(0)!).toList()..sort()).join(',');

  group('ARB cross-locale integrity', () {
    test('no value is wrapped in stray double quotes', () {
      for (final l in locales) {
        final bad = values(l)
            .where((e) => (e.value as String).startsWith('"') &&
                (e.value as String).endsWith('"'))
            .map((e) => '${e.key} = ${e.value}')
            .toList();
        expect(bad, isEmpty,
            reason: '$l 有 ${bad.length} 条值被多余引号包住：\n${bad.take(10).join('\n')}');
      }
    });

    test('every key has the same placeholders in all locales', () {
      final problems = <String>[];
      for (final entry in values('zh')) {
        final key = entry.key;
        final base = placeholders(entry.value);
        for (final l in locales) {
          if (l == 'zh') continue;
          final other = data[l]![key];
          if (other is! String) continue;
          final p = placeholders(other);
          // 英文复数语法（{count, plural, ...}）单独放行
          if (p.contains('plural')) continue;
          if (p != base) {
            problems.add('$key [$l] 期望 {$base} 实际 {$p}');
          }
        }
      }
      expect(problems, isEmpty,
          reason: '占位符不一致 ${problems.length} 处：\n${problems.take(15).join('\n')}');
    });

    test('all locales expose the same message keys', () {
      final base = values('zh').map((e) => e.key).toSet();
      for (final l in locales) {
        if (l == 'zh') continue;
        final keys = values(l).map((e) => e.key).toSet();
        expect(base.difference(keys).toList(), isEmpty,
            reason: '$l 缺少键：${base.difference(keys).take(10)}');
        expect(keys.difference(base).toList(), isEmpty,
            reason: '$l 多出键：${keys.difference(base).take(10)}');
      }
    });

    test('no message contains a replacement character', () {
      for (final l in locales) {
        final bad = values(l)
            .where((e) => (e.value as String).contains('\uFFFD'))
            .map((e) => '${e.key} = ${e.value}')
            .toList();
        expect(bad, isEmpty, reason: '$l 有乱码：${bad.take(5)}');
      }
    });
  });
}
