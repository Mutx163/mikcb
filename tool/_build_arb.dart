import 'dart:convert';
import 'dart:io';

/// 用法: dart run tool/_build_arb.dart <target_locale> <chunk_dir>
/// 读取 zh.arb 结构，合并 chunk_dir 下的翻译片段，输出完整 ARB
void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart run tool/_build_arb.dart <locale> <chunk_dir>');
    exit(1);
  }
  final locale = args[0];
  final chunkDir = args[1];

  final source = jsonDecode(
    File('lib/l10n/app_zh.arb').readAsStringSync(),
  ) as Map<String, dynamic>;

  // 读取所有 chunk 文件
  final translations = <String, String>{};

  // 先读取现有的 ARB 文件（如果有）
  final existingPath = 'lib/l10n/app_$locale.arb';
  if (File(existingPath).existsSync()) {
    final existing = jsonDecode(File(existingPath).readAsStringSync()) as Map<String, dynamic>;
    for (final e in existing.entries) {
      if (!e.key.startsWith('@') && e.key != '@@locale' && e.value is String) {
        // 只保留不是中文占位符的翻译
        final zhVal = source[e.key];
        if (zhVal is String && e.value != zhVal) {
          translations[e.key] = e.value as String;
        }
      }
    }
  }

  final dir = Directory(chunkDir);
  if (dir.existsSync()) {
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      if (file.path.endsWith('.json') && file.path.contains('${locale}_')) {
        final chunk = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final e in chunk.entries) {
          if (e.value is String) translations[e.key] = e.value as String;
        }
      }
    }
  }

  // 合并：source 提供结构和 @metadata，translations 提供翻译
  final merged = <String, dynamic>{};
  var translated = 0;
  var fallback = 0;

  for (final entry in source.entries) {
    final key = entry.key;
    if (key == '@@locale') {
      merged[key] = locale;
    } else if (translations.containsKey(key)) {
      merged[key] = translations[key];
      if (!key.startsWith('@')) translated++;
    } else {
      merged[key] = entry.value; // 未翻译的保留中文
      if (!key.startsWith('@')) fallback++;
    }
  }

  final outPath = 'lib/l10n/app_$locale.arb';
  File(outPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(merged) + '\n',
  );
  print('✅ $outPath: $translated translated, $fallback fallback (zh)');
}
