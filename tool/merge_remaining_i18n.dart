// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  final zh = jsonDecode(
    File('tool/.gen_remaining_i18n_zh.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  const enPath = 'tool/.gen_remaining_i18n_en.json';
  if (!File(enPath).existsSync()) {
    print('Missing $enPath — copy zh as fallback');
    File(enPath).writeAsStringSync(jsonEncode(zh));
  }
  final en = jsonDecode(File(enPath).readAsStringSync()) as Map<String, dynamic>;

  final targets = {
    'zh': ('lib/l10n/app_zh.arb', zh),
    'en': ('lib/l10n/app_en.arb', en),
    'zh_HK': ('lib/l10n/app_zh_HK.arb', zh),
    'zh_TW': ('lib/l10n/app_zh_TW.arb', zh),
    'ja': ('lib/l10n/app_ja.arb', en),
    'ko': ('lib/l10n/app_ko.arb', en),
  };

  for (final entry in targets.entries) {
    final path = entry.value.$1;
    final source = entry.value.$2;
    final data = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    source.forEach((key, value) {
      data[key] = value;
      final metaKey = '@$key';
      if (zh.containsKey(metaKey)) {
        data[metaKey] = zh[metaKey];
      }
    });
    File(path).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
    print('Merged into $path');
  }
}
