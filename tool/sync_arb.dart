#!/usr/bin/env dart
// sync_arb.dart — 检测 zh.arb 与其他语言的差异
//
// 用法：
//   dart run tool/sync_arb.dart                # 输出差异报告
//   dart run tool/sync_arb.dart --json         # 输出 JSON（交给 AI 翻译）
//   dart run tool/sync_arb.dart --apply <file> # 将翻译结果写入 ARB
//
// 工作流：
//   1. 编辑 zh.arb（唯一手动维护的文件）
//   2. 运行本脚本查看差异
//   3. 将 --json 输出交给 AI 翻译
//   4. AI 返回翻译后，用 --apply 写入

import 'dart:convert';
import 'dart:io';

const _arbDir = 'lib/l10n';
const _sourceFile = '$_arbDir/app_zh.arb';
const _targetFiles = {
  'en': '$_arbDir/app_en.arb',
  'zh_HK': '$_arbDir/app_zh_HK.arb',
  'zh_TW': '$_arbDir/app_zh_TW.arb',
  'ja': '$_arbDir/app_ja.arb',
  'ko': '$_arbDir/app_ko.arb',
};

Map<String, dynamic> _readArb(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void _writeArb(String path, Map<String, dynamic> data) {
  final sorted = Map.fromEntries(
    data.entries.toList()
      ..sort((a, b) {
        final aIsMeta = a.key.startsWith('@');
        final bIsMeta = b.key.startsWith('@');
        if (aIsMeta && !bIsMeta) return -1;
        if (!aIsMeta && bIsMeta) return 1;
        return a.key.compareTo(b.key);
      }),
  );
  File(path).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(sorted) + '\n',
  );
}

void main(List<String> args) {
  final jsonMode = args.contains('--json');
  final applyIdx = args.indexOf('--apply');

  // --apply: 从文件读取翻译结果并写入 ARB
  if (applyIdx >= 0) {
    _applyTranslations(args);
    return;
  }

  final source = _readArb(_sourceFile);
  final sourceKeys = source.keys.where((k) => !k.startsWith('@')).toList();

  if (jsonMode) {
    // 输出 JSON 格式，交给 AI 翻译
    final request = <String, dynamic>{'_meta': '翻译请求，目标语言: en, zh_HK, zh_TW'};
    for (final locale in _targetFiles.keys) {
      final target = _readArb(_targetFiles[locale]!);
      final missing = <String, String>{};
      for (final key in sourceKeys) {
        if (!target.containsKey(key)) {
          missing[key] = source[key] as String;
        }
      }
      if (missing.isNotEmpty) request[locale] = missing;
    }
    if (request.length <= 1) {
      print(jsonEncode({'status': 'all_synced'}));
    } else {
      print(const JsonEncoder.withIndent('  ').convert(request));
    }
    return;
  }

  // 默认：输出差异报告
  print('📖 基准: $_sourceFile (${sourceKeys.length} 个 key)\n');
  var allSynced = true;
  for (final entry in _targetFiles.entries) {
    final target = _readArb(entry.value);
    final missing = <String>[];
    for (final key in sourceKeys) {
      if (!target.containsKey(key)) missing.add(key);
    }
    if (missing.isEmpty) {
      print('✅ ${entry.key}: 已同步');
    } else {
      allSynced = false;
      print('📝 ${entry.key}: 缺失 ${missing.length} 个 key');
      for (final key in missing.take(5)) {
        print('   $key: ${source[key]}');
      }
      if (missing.length > 5) print('   ... 还有 ${missing.length - 5} 个');
    }
  }
  print(allSynced
      ? '\n✨ 全部同步'
      : '\n💡 运行 dart run tool/sync_arb.dart --json 输出待翻译内容');
}

void _applyTranslations(List<String> args) {
  final applyIdx = args.indexOf('--apply');
  if (applyIdx + 1 >= args.length) {
    print('❌ 用法: dart run tool/sync_arb.dart --apply <translation.json>');
    exit(1);
  }
  final filePath = args[applyIdx + 1];
  final file = File(filePath);
  if (!file.existsSync()) {
    print('❌ 文件不存在: $filePath');
    exit(1);
  }

  final translations = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final source = _readArb(_sourceFile);
  var totalApplied = 0;

  for (final locale in _targetFiles.keys) {
    final localeTranslations = translations[locale];
    if (localeTranslations is! Map) continue;

    final targetPath = _targetFiles[locale]!;
    final target = _readArb(targetPath);
    var applied = 0;

    for (final entry in localeTranslations.entries) {
      final key = entry.key;
      if (key.startsWith('@') || key == '_meta') continue;
      target[key] = entry.value;
      // 同步 @metadata
      final metaKey = '@$key';
      if (source.containsKey(metaKey) && !target.containsKey(metaKey)) {
        target[metaKey] = source[metaKey];
      }
      applied++;
    }

    if (applied > 0) {
      _writeArb(targetPath, target);
      print('✅ $locale: 写入 $applied 个 key → $targetPath');
      totalApplied += applied;
    }
  }

  print('\n✨ 共写入 $totalApplied 个翻译');
}
