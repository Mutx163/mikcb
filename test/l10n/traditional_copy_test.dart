import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防回归测试：繁体文案的两个历史问题
///
/// 1. 繁体文件里残留简体字（zh_TW 曾有 479 条、zh_HK 曾有 105 条未繁化）
/// 2. 机器简繁转换把「一简对多繁」的字转坏
///    （輕誘/蠅響/壯態/步晝/偵斷/無漲礙/運櫻/原養）
///
/// 判据用固定字表，不依赖 OpenCC，纯 Dart 跑得动。
void main() {
  // 简体里出现、繁体必须是另一个字的字。繁简同形字（课表/更新/功能）不在此列。
  const simplifiedOnly = {
    '骤', '独', '义', '饱', '阈', '冲', '压', '缩', '铺', '层',
    '叠', '选', '学', '对', '应', '给', '后', '无', '门', '间',
    '电', '见', '语', '说', '让', '认', '记', '试', '该', '处',
    '备', '结', '续', '线', '级', '统', '复', '网', '录', '页',
    '顺', '项', '开', '关', '时', '闭', '为', '与', '从', '体',
    '点', '数', '据', '证', '过', '这', '么', '样', '东', '问',
    '题', '图', '协', '业', '乌', '价', '优', '会', '众', '传',
    '伤', '侠', '俩', '俭', '债', '倾', '偿', '储', '儿', '兑',
    '兰', '兴', '兹', '养', '兽', '内', '冈', '写', '军', '农',
    '决', '况', '冻', '净', '准', '凤', '凭', '击', '刘', '则',
    '刚', '创', '删', '荐', '轿', '较', '辑', '输', '辆', '辈',
    '辞', '辩', '边', '达', '迁', '迈', '运', '进', '远', '违',
    '连', '迟', '适', '逊', '递', '逻', '遗', '邮', '邻', '酬',
    '释', '针', '钉', '钓', '钝', '钟', '钢', '钥', '钦', '钩',
    '银', '铁', '铃', '铅', '铜', '铝', '铭', '铸', '链', '销',
    '锁', '锅', '错', '锡', '锦', '键', '闪', '闲', '闷', '闹',
    '闻', '阀', '阁', '阅', '阔', '队', '阴', '阵', '阶', '际',
    '陆', '陈', '险', '随', '隐', '难', '雏', '雾', '韩', '顶',
    '顷', '顽', '顾', '顿', '颁', '颂', '预', '领', '颇', '频',
    '颗', '颜', '额', '风', '飞', '饥', '饭', '饮', '饲', '饶',
    '饿', '馆', '马', '驰', '驱', '驳', '驶', '驻', '驼', '驾',
    '验', '骗', '鲁', '鲜', '鸟', '鸡', '鸣', '鸦', '鸿', '鹤',
    '麦', '黄', '齐', '齿', '龄', '龙', '龟',
};

  // 机器转换曾把这几个繁体字转错的（简 -> 繁体 -> 错字）
  const knownBad = ['輕誘', '蠅響', '壯態', '步晝', '偵斷', '無漲礙', '運櫻', '原養'];

  // 繁简同形、且繁体里本就合法的字，不算残留
  // 繁体里本来就合法的写法：台（计数用「台」）、只、么、几、
// 以及「区/群」这类在台港都保留的词
  const tradValid = {...simplifiedOnly, '台', '只', '几'};

  Map<String, dynamic> loadArb(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      fail('$path 不存在');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  // 简体字表里补上本次实际清掉、但不在上面字表里的字
  const extra = {'谢', '栏', '声', '尽', '许', '别', '继', '请', '总', '实', '没', '经',
    '欢', '补', '条', '够', '弹', '责', '运', '联', '监', '赖', '盖', '败', '环',
    '拦', '占', '机', '将', '启', '构', '击', '显', '称', '库', '须', '标', '仅',
    '却', '换', '历', '档', '签', '谱', '递', '缴', '罢', '紧', '竞', '赠', '赢',
    '赶', '跃', '驳', '骤', '鸣', '鸦', '鸿', '鹤', '麦', '齐', '齿', '龄', '龟'};

  group('Traditional Chinese copy', () {
    for (final locale in ['zh_TW', 'zh_HK']) {
      test('$locale has no simplified characters left in user-facing copy', () {
        final arb = loadArb('lib/l10n/app_$locale.arb');
        final offenders = <String>[];

        for (final entry in arb.entries) {
          final key = entry.key;
          if (key == '@@locale' || key.startsWith('@')) continue;
          final value = entry.value;
          if (value is! String || value.isEmpty) continue;

          final bad = value
              .split('')
              .where((c) => simplifiedOnly.contains(c) || extra.contains(c))
              .where((c) => !tradValid.contains(c))
              .toSet();
          if (bad.isNotEmpty) offenders.add('$key: ${bad.join()} | $value');
        }

        expect(
          offenders,
          isEmpty,
          reason: '$locale 仍有简体字残留（${offenders.length} 条）。\n'
              '${offenders.take(15).join('\n')}',
        );
      });

      test('$locale has no known machine-conversion typos', () {
        final arb = loadArb('lib/l10n/app_$locale.arb');
        for (final bad in knownBad) {
          for (final entry in arb.entries) {
            final value = entry.value;
            if (value is String && value.contains(bad)) {
              fail('${entry.key} 里出现转坏的「$bad」：$value');
            }
          }
        }
      });
    }

    test('traditional locales keep the same key set as simplified', () {
      final zh = loadArb('lib/l10n/app_zh.arb');
      final zhKeys = zh.keys
          .where((k) => k != '@@locale' && !k.startsWith('@'))
          .toSet();

      for (final locale in ['zh_TW', 'zh_HK']) {
        final arb = loadArb('lib/l10n/app_$locale.arb');
        final keys = arb.keys
            .where((k) => k != '@@locale' && !k.startsWith('@'))
            .toSet();
        final missing = zhKeys.difference(keys).toList();
        final extraKeys = keys.difference(zhKeys).toList();
        expect(missing, isEmpty, reason: '$locale 缺少键: ${missing.take(10)}');
        expect(extraKeys, isEmpty, reason: '$locale 多出键: ${extraKeys.take(10)}');
      }
    });

    test('traditional locales preserve every placeholder', () {
      final zh = loadArb('lib/l10n/app_zh.arb');
      final re = RegExp(r'\{[^}]*\}');

      for (final locale in ['zh_TW', 'zh_HK']) {
        final arb = loadArb('lib/l10n/app_$locale.arb');
        for (final key in zh.keys) {
          if (key == '@@locale' || key.startsWith('@')) continue;
          final src = zh[key];
          final dst = arb[key];
          if (src is! String || dst is! String) continue;

          final a = re.allMatches(src).map((m) => m.group(0)).toList()..sort();
          final b = re.allMatches(dst).map((m) => m.group(0)).toList()..sort();
          if (a.join(',') != b.join(',')) {
            fail('$locale / $key 占位符不一致：简 ${a.join()} vs 繁 ${b.join()}');
          }
        }
      }
    });
  });
}
