// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  final chunk = jsonDecode(
    File('tool/.gen_log_arb_zh.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final enChunk = jsonDecode(
    File('tool/.gen_log_arb_en.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final targets = {
    'zh': 'lib/l10n/app_zh.arb',
    'en': 'lib/l10n/app_en.arb',
    'zh_HK': 'lib/l10n/app_zh_HK.arb',
    'zh_TW': 'lib/l10n/app_zh_TW.arb',
    'ja': 'lib/l10n/app_ja.arb',
    'ko': 'lib/l10n/app_ko.arb',
  };

  for (final entry in targets.entries) {
    final path = entry.value;
    final data = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final source = switch (entry.key) {
      'en' => enChunk,
      'ja' || 'ko' => enChunk,
      _ => chunk,
    };
    source.forEach((key, value) {
      data[key] = value;
      final metaKey = '@$key';
      if (chunk.containsKey(metaKey)) {
        data[metaKey] = chunk[metaKey];
      }
    });
    File(path).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
    print('Merged ${source.length} keys into $path');
  }
}
