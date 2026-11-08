// ignore_for_file: avoid_print
//
// 从 `lib/logging/app_log_messages.dart` 的中文源常量生成日志本地化配套文件。
//
// 用法：
//     dart run tool/gen_app_log_l10n.dart                # 只检查，不写盘（默认）
//     dart run tool/gen_app_log_l10n.dart --write        # 真写盘（写盘前强制校验）
//     dart run tool/gen_app_log_l10n.dart --root DIR     # 换一个项目根（自测用）
//
// ## 为什么重写成这样（2026-10-27）
//
// 上一版直接 `writeAsStringSync` 把两个手写文件**整份覆盖**成「生成结果」，
// 而生成器的正则只认 `static const X = '...'` 一种写法、只认单行映射条目，
// 于是把大量手写/格式化过的内容判成「不存在」并抹掉。实测（在副本上跑）：
//
// * `app_log_messages.dart`：337 行 → 186 行；
// * `app_log_message_localizer.dart`：402 行 → 194 行，
//   235 个 `'log_xxx' => l10n.xxx` 分支只剩 144 个，**丢了 96 个**；
// * `AppLogMessages.*` 在 `lib/` 里被广泛引用 → 直接编译不过。
//
// 因此本版不再「生成后覆盖」，改成**合并 + 硬校验**：
//
// 1. 从原文解析出已有关键结构（常量名→值、两个映射表、三个 switch 的每个分支，
//    以及分支的右值究竟是什么 —— 有些分支故意映射到别的文案键，比如
//    `log_home_widget_preview_render_failed => l10n.homeWidgetPreviewUnavailable`，
//    生成器不该把它「修正」成按公式推出来的名字）。
// 2. 合并规则只有一条：**只增不改、只删死分支**。要写入的值优先用原文已有的，
//    原文没有才按公式推。任何「已有条目会被改掉」都直接判红。
// 3. 写盘前跑一组结构性断言，任一不过 → 整份放弃、原文件一个字节不动、非 0 退出：
//    行数不得少于原文 90%、`AppLogMessages.<名字>` 一个都不许少、映射表条目不许少、
//    每个 switch 的分支数不许少、每个分支的右值必须能在 ARB 里找到 getter。
// 4. 默认**只检查不写盘**，要 `--write` 才落盘；先写临时文件再 rename。
//
// 配套咬合探针：`tool/selftest_destructive_scripts.py`（只在临时目录跑）。

import 'dart:convert';
import 'dart:io';

/// 写盘前允许的最大缩水比例：生成结果行数不得低于原文的 90%。
const double minLineRatio = 0.9;

void main(List<String> args) {
  final write = args.contains('--write');
  final rootArg = _valueOf(args, '--root');
  final root = rootArg == null ? Directory.current : Directory(rootArg);

  final messagesFile = File('${root.path}/lib/logging/app_log_messages.dart');
  final localizerFile = File('${root.path}/lib/logging/app_log_message_localizer.dart');
  final arbFile = File('${root.path}/i18n/app_en.arb');

  for (final file in [messagesFile, localizerFile, arbFile]) {
    if (!file.existsSync()) {
      _fail('找不到 ${file.path}，什么都不做');
    }
  }

  final messagesSource = messagesFile.readAsStringSync();
  final localizerSource = localizerFile.readAsStringSync();
  final arbGetterNames = _arbGetterNames(arbFile.readAsStringSync());

  // ---------- 解析现有 messages.dart ----------
  final consts = _parseConsts(messagesSource);
  final messages = <String, String>{};
  final literals = <String, String>{};
  for (final entry in consts.entries) {
    if (entry.value.startsWith('log_')) {
      messages[entry.key] = entry.value;
    } else {
      literals[entry.key] = entry.value;
    }
  }
  final fieldMap = _parseStringMap(messagesSource, 'appLogFieldLabels');
  final categoryMap = _parseStringMap(messagesSource, 'appLogCategoryLabels');

  // ---------- 解析现有 localizer ----------
  final msgBranches = _parseSwitch(localizerSource, 'localizeMessage');
  final fieldBranches = _parseSwitch(localizerSource, 'localizeField');
  final catBranches = _parseSwitch(localizerSource, 'localizeCategory');

  _say('原文：常量 ${consts.length} 个（log_ ${messages.length} / 直出中文 ${literals.length}）'
      '，字段映射 ${fieldMap.length} 条，分类映射 ${categoryMap.length} 条');
  _say('localizer：消息分支 ${msgBranches.length} 个，字段分支 ${fieldBranches.length} 个，'
      '分类分支 ${catBranches.length} 个');

  // ---------- 合并：只增不改 ----------
  final problems = <String>[];

  // 1) 常量：已有的一个不许丢、一个不许改；缺的按公式补。
  final newMessages = <String, String>{};
  for (final entry in arbGetterNames.messageStrings.entries) {
    final name = entry.key;
    final logKey = entry.value;
    if (messages.containsKey(name)) {
      // 原文里已有同名的，沿用原文那一条（值和键都照抄）。
      newMessages[name] = messages[name]!;
      if (messages[name] != logKey) {
        // 同名但代码串不同：只报告，不擅自改（改代码串会改日志落盘的键，
      // 历史日志就对不上了）。
        _say('  [注意] $name 原文是 ${messages[name]}，ARB 建议 $logKey，沿用原文');
      }
    } else {
      newMessages[name] = logKey;
      _say('  [补常量] $name = $logKey');
    }
  }
  // 原文里有、ARB 里没有的常量也必须保留（直接引用的地方还在）。
  for (final entry in messages.entries) {
    newMessages.putIfAbsent(entry.key, () => entry.value);
  }

  // 2) 字段映射：原条目原样保留，按 ARB 的 logField* 补缺。
  final newFieldMap = <String, String>{...fieldMap};
  for (final entry in arbGetterNames.fieldEntries.entries) {
    newFieldMap.putIfAbsent(entry.key, () => entry.value);
  }

  // 3) 分类映射：原条目原样保留，按 ARB 的 logCat* 补缺。
  final newCategoryMap = <String, String>{...categoryMap};
  for (final entry in arbGetterNames.categoryEntries.entries) {
    newCategoryMap.putIfAbsent(entry.key, () => entry.value);
  }

  // 4) switch 分支：原文有的（连同它原本的右值）原样保留；只补真正缺的。
  //
  // 注意 `liveUpdateSettingsSynced` 不参与：它是带参数的消息，走的是上面那段
  // `startsWith(...)` 特判，不在 switch 里，不该为它造分支。
  final newMsgBranches = <String, String>{...msgBranches};
  for (final key in newMessages.values) {
    if (newMsgBranches.containsKey(key)) continue;
    final getter = _getterForMessageKey(key);
    if (!arbGetterNames.getters.contains(getter)) {
      // 没有对应 getter 说明这条日志只能原样显示（比如 `fairMemoryXxx` 那几条
      // 本来就直出中文，没进 ARB）。这是现状而不是错误：记一条说明就跳过，
      // switch 的 `_ => message` 会兜住它。
      _say('  [跳过分支] $key 在 ARB 里没有 $getter，保留原文原样显示');
      continue;
    }
    newMsgBranches[key] = 'l10n.$getter';
  }

  final newFieldBranches = <String, String>{...fieldBranches};
  for (final value in newFieldMap.values) {
    if (newFieldBranches.containsKey(value)) continue;
    final getter = _getterForFieldKey(value);
    if (!arbGetterNames.getters.contains(getter)) {
      _say('  [跳过分支] $value 在 ARB 里没有 $getter，保留原文原样显示');
      continue;
    }
    newFieldBranches[value] = 'l10n.$getter';
  }

  final newCatBranches = <String, String>{...catBranches};
  for (final value in newCategoryMap.values) {
    if (newCatBranches.containsKey(value)) continue;
    final getter = _getterForCategoryKey(value);
    if (!arbGetterNames.getters.contains(getter)) {
      problems.add('分类键 $value 推出的 $getter 在 ARB 里不存在');
      continue;
    }
    newCatBranches[value] = 'l10n.$getter';
  }

  // 5) 每个分支的右值必须真的存在（原文里那两个「故意映射到别的文案」的白名单）。
  for (final MapEntry(key: key, value: rhs) in newMsgBranches.entries) {
    final target = rhs.replaceFirst('l10n.', '');
    if (!arbGetterNames.getters.contains(target)) {
      problems.add('消息分支 $key => $rhs 的目标 getter 在 ARB 里不存在');
    }
  }
  for (final MapEntry(key: key, value: rhs) in newFieldBranches.entries) {
    final target = rhs.replaceFirst('l10n.', '');
    if (!arbGetterNames.getters.contains(target)) {
      problems.add('字段分支 $key => $rhs 的目标 getter 在 ARB 里不存在');
    }
  }
  for (final MapEntry(key: key, value: rhs) in newCatBranches.entries) {
    final target = rhs.replaceFirst('l10n.', '');
    if (!arbGetterNames.getters.contains(target)) {
      problems.add('分类分支 $key => $rhs 的目标 getter 在 ARB 里不存在');
    }
  }

  // ---------- 渲染 ----------
  final messagesOut = _renderMessages(newMessages, literals, newFieldMap, newCategoryMap);
  final localizerOut = _renderLocalizer(newMsgBranches, newFieldBranches, newCatBranches);

  // ---------- 结构断言 ----------
  problems.addAll(_structuralChecks(
    original: messagesSource,
    rendered: messagesOut,
    kind: 'app_log_messages.dart',
    mustKeep: consts.keys.toList(),
    mustKeepPattern: 'static const',
  ));
  problems.addAll(_structuralChecks(
    original: localizerSource,
    rendered: localizerOut,
    kind: 'app_log_message_localizer.dart',
    mustKeep: [
      ...msgBranches.keys,
      ...fieldBranches.keys,
      ...catBranches.keys,
    ],
    mustKeepPattern: null,
  ));

  // 分支数一条都不许少（覆盖上面的 mustKeep，额外钉一层）。
  problems.addAll(_noShrink('消息分支', msgBranches.length, _countBranches(localizerOut, 'localizeMessage')));
  problems.addAll(_noShrink('字段分支', fieldBranches.length, _countBranches(localizerOut, 'localizeField')));
  problems.addAll(_noShrink('分类分支', catBranches.length, _countBranches(localizerOut, 'localizeCategory')));
  problems.addAll(_noShrink('字段映射', fieldMap.length, newFieldMap.length));
  problems.addAll(_noShrink('分类映射', categoryMap.length, newCategoryMap.length));

  final messagesChanged = messagesOut != messagesSource;
  final localizerChanged = localizerOut != localizerSource;

  if (problems.isNotEmpty) {
    for (final problem in problems) {
      _warn('ERROR $problem');
    }
    _warn('共 ${problems.length} 条问题，已放弃写盘，原文件一个字节都没动。');
    exitCode = 1;
    return;
  }

  if (!messagesChanged && !localizerChanged) {
    _say('两个文件都与生成结果一致，无需改动。');
    return;
  }

  if (!write) {
    _say('');
    if (messagesChanged) _say('app_log_messages.dart 会被更新（只增不改）。');
    if (localizerChanged) _say('app_log_message_localizer.dart 会被更新（只增不改）。');
    _say('加 --write 才落盘。');
    return;
  }

  if (messagesChanged) {
    _atomicWrite(messagesFile, messagesOut);
    _say('已写回 ${messagesFile.path}');
  }
  if (localizerChanged) {
    _atomicWrite(localizerFile, localizerOut);
    _say('已写回 ${localizerFile.path}');
  }
  _say('生成完成：消息 ${newMessages.length} 条、字段 ${newFieldMap.length} 条、'
      '分类 ${newCategoryMap.length} 条，全部通过结构校验。');
  _say('（ARB 里的 log* 键未改动；如需新增文案请直接改 ARB 后重跑本脚本）');
}

// ---------------------------------------------------------------------------
// 解析
// ---------------------------------------------------------------------------

/// 解析 `static const name = 'value';`（允许等号后换行）。
Map<String, String> _parseConsts(String source) {
  final result = <String, String>{};
  final pattern = RegExp(
    r"static const (\w+) =\s*'((?:[^'\\]|\\.)*)'\s*;",
  );
  for (final match in pattern.allMatches(source)) {
    result[match.group(1)!] = _unescapeDart(match.group(2)!);
  }
  return result;
}

/// 解析 `const Map<String, String> name = { 'k': 'v', ... };`（允许换行与缩进）。
Map<String, String> _parseStringMap(String source, String name) {
  final result = <String, String>{};
  final block = RegExp(
    'const Map<String, String> $name = \\{([\\s\\S]*?)\\n\\};',
  ).firstMatch(source);
  if (block == null) return result;
  final entry = RegExp(r"'([^']+)':\s*'([^']+)'");
  for (final match in entry.allMatches(block.group(1)!)) {
    result[match.group(1)!] = match.group(2)!;
  }
  return result;
}

/// 解析某个 `static String xxx(...) { ... return switch (x) { 'key' => l10n.y, ... } }`
/// 里的全部分支，返回 键 → 右值（右值可能跨行，归并成 `l10n.xxx`）。
Map<String, String> _parseSwitch(String source, String method) {
  final result = <String, String>{};
  final start = source.indexOf('static String $method(');
  if (start < 0) return result;
  final end = source.indexOf('static String localize', start + 10);
  final body = end < 0 ? source.substring(start) : source.substring(start, end);
  final branch = RegExp(r"'([^']+)' =>\s*(l10n\.\w+),");
  for (final match in branch.allMatches(body)) {
    result[match.group(1)!] = match.group(2)!;
  }
  return result;
}

int _countBranches(String source, String method) => _parseSwitch(source, method).length;

/// 从 app_en.arb 推出所有 getter 名，以及 log* 消息/字段/分类三组键。
class ArbNames {
  ArbNames(this.getters, this.messageStrings, this.fieldEntries, this.categoryEntries);

  /// 所有可以 `l10n.xxx` 的 getter（camelCase）。
  final Set<String> getters;

  /// `log_xxx` → 建议的常量名（与原文一致就沿用原文的键名）。
  final Map<String, String> messageStrings;

  final Map<String, String> fieldEntries;
  final Map<String, String> categoryEntries;
}

ArbNames _arbGetterNames(String arbSource) {
  final data = jsonDecode(arbSource) as Map<String, dynamic>;
  final getters = <String>{for (final key in data.keys) _camel(key)};

  final messageStrings = <String, String>{};
  final fieldEntries = <String, String>{};
  final categoryEntries = <String, String>{};
  for (final key in data.keys) {
    if (key.startsWith('logField') && !key.startsWith('logField@')) {
      final raw = key.substring('logField'.length);
      final fieldKey = 'log_field_${_snake(raw)}';
      fieldEntries[_lowerFirst(raw)] = fieldKey;
    } else if (key.startsWith('logCat') && !key.startsWith('logCat@')) {
      final raw = key.substring('logCat'.length);
      categoryEntries[_snake(raw)] = 'log_cat_${_snake(raw)}';
    } else if (RegExp(r'^log[A-Z]').hasMatch(key) && key != 'logExportTitle') {
      final raw = key.substring(3);
      messageStrings[_lowerFirst(raw)] = 'log_${_snake(raw)}';
    }
  }
  return ArbNames(getters, messageStrings, fieldEntries, categoryEntries);
}

String _getterForMessageKey(String logKey) {
  // log_xxx_yyy → logXxxYyy
  return 'log${_pascal(logKey.substring(4))}';
}

String _getterForFieldKey(String logKey) {
  // log_field_xxx_yyy → logFieldXxxYyy
  return 'logField${_pascal(logKey.substring('log_field_'.length))}';
}

String _getterForCategoryKey(String logKey) {
  // log_cat_xxx_yyy → logCatXxxYyy
  return 'logCat${_pascal(logKey.substring('log_cat_'.length))}';
}

// ---------------------------------------------------------------------------
// 渲染
// ---------------------------------------------------------------------------

String _renderMessages(
  Map<String, String> messages,
  Map<String, String> literals,
  Map<String, String> fieldMap,
  Map<String, String> categoryMap,
) {
  final buffer = StringBuffer()
    ..writeln('/// Centralized English log message keys for persisted app diagnostics.')
    ..writeln('/// Categories remain English snake_case for level inference and grep.')
    ..writeln('/// UI display is localized via [AppLogMessageLocalizer].')
    ..writeln('abstract final class AppLogMessages {');
  for (final entry in messages.entries) {
    final line = "  static const ${entry.key} = '${entry.value}';";
    buffer.writeln(line.length <= 80 ? line : _wrapAssign('  static const ${entry.key} =', "'${entry.value}';"));
  }

  buffer
    ..writeln()
    ..writeln('  /// 直出中文，未进 ARB（localizer 找不到映射时原样显示）');
  for (final entry in literals.entries) {
    buffer.writeln("  static const ${entry.key} = '${entry.value}';");
  }

  buffer
    ..writeln()
    ..writeln("  static const liveUpdateSettingsSyncedKey = 'log_live_update_settings_synced';")
    ..writeln()
    ..writeln('''  static String liveUpdateSettingsSynced({
    required bool beforeClass,
    required bool duringClass,
    required bool beforeEnd,
    required bool promote,
    required bool notification,
    required bool countdown,
    required bool courseName,
    required bool location,
  }) =>
      '\$liveUpdateSettingsSyncedKey|'
      'beforeClass=\$beforeClass|'
      'duringClass=\$duringClass|'
      'beforeEnd=\$beforeEnd|'
      'promote=\$promote|'
      'notification=\$notification|'
      'countdown=\$countdown|'
      'courseName=\$courseName|'
      'location=\$location';
}''')
    ..writeln()
    ..writeln('/// English field keys for structured log viewer display.')
    ..writeln('const Map<String, String> appLogFieldLabels = {');
  for (final entry in fieldMap.entries) {
    final line = "  '${entry.key}': '${entry.value}',";
    buffer.writeln(line.length <= 80 ? line : _wrapAssign("  '${entry.key}':", "'${entry.value}',"));
  }
  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('String categoryDisplayLabel(String category, AppLocalizations l10n) =>')
    ..writeln('    AppLogMessageLocalizer.localizeCategory(l10n, category);')
    ..writeln()
    ..writeln('String fieldDisplayLabel(String key, AppLocalizations l10n) =>')
    ..writeln('    AppLogMessageLocalizer.localizeField(l10n, key);')
    ..writeln()
    ..writeln('/// English category keys for structured log viewer display.')
    ..writeln('const Map<String, String> appLogCategoryLabels = {');
  for (final entry in categoryMap.entries) {
    final line = "  '${entry.key}': '${entry.value}',";
    buffer.writeln(line.length <= 80 ? line : _wrapAssign("  '${entry.key}':", "'${entry.value}',"));
  }
  buffer.writeln('};');
  return buffer.toString();
}

String _renderLocalizer(
  Map<String, String> messageBranches,
  Map<String, String> fieldBranches,
  Map<String, String> categoryBranches,
) {
  final buffer = StringBuffer()
    ..writeln("import '../l10n/app_localizations.dart';")
    ..writeln("import 'app_log_messages.dart';")
    ..writeln()
    ..writeln('/// Maps persisted log message / field / category keys to localized strings.')
    ..writeln('abstract final class AppLogMessageLocalizer {')
    ..writeln('  static String localizeMessage(AppLocalizations l10n, String message) {')
    ..writeln("    if (message.startsWith('\${AppLogMessages.liveUpdateSettingsSyncedKey}|')) {")
    ..writeln('      final params = <String, String>{};')
    ..writeln('      for (final part in message.split(\'|\').skip(1)) {')
    ..writeln("        final idx = part.indexOf('=');")
    ..writeln('        if (idx > 0) {')
    ..writeln('          params[part.substring(0, idx)] = part.substring(idx + 1);')
    ..writeln('        }')
    ..writeln('      }')
    ..writeln('      return l10n.logLiveUpdateSettingsSynced(')
    ..writeln("        params['beforeClass'] ?? '',")
    ..writeln("        params['duringClass'] ?? '',")
    ..writeln("        params['beforeEnd'] ?? '',")
    ..writeln("        params['promote'] ?? '',")
    ..writeln("        params['notification'] ?? '',")
    ..writeln("        params['countdown'] ?? '',")
    ..writeln("        params['courseName'] ?? '',")
    ..writeln("        params['location'] ?? '',")
    ..writeln('      );')
    ..writeln('    }')
    ..writeln('    return switch (message) {');
  for (final entry in messageBranches.entries) {
    buffer.writeln(_branchLine("      '${entry.key}'", entry.value));
  }
  buffer
    ..writeln('      _ => message,')
    ..writeln('    };')
    ..writeln('  }')
    ..writeln()
    ..writeln('  static String localizeField(AppLocalizations l10n, String key) {')
    ..writeln('    final mapped = appLogFieldLabels[key];')
    ..writeln('    if (mapped == null) return key;')
    ..writeln('    return switch (mapped) {');
  for (final entry in fieldBranches.entries) {
    buffer.writeln(_branchLine("      '${entry.key}'", entry.value));
  }
  buffer
    ..writeln('      _ => key,')
    ..writeln('    };')
    ..writeln('  }')
    ..writeln()
    ..writeln('  static String localizeCategory(AppLocalizations l10n, String category) {')
    ..writeln('    final mapped = appLogCategoryLabels[category];')
    ..writeln('    if (mapped == null) return category;')
    ..writeln('    return switch (mapped) {');
  for (final entry in categoryBranches.entries) {
    buffer.writeln(_branchLine("      '${entry.key}'", entry.value));
  }
  buffer
    ..writeln('      _ => category,')
    ..writeln('    };')
    ..writeln('  }')
    ..writeln()
    ..writeln('  static String localizeExportTitle(AppLocalizations l10n) =>')
    ..writeln('      l10n.logExportTitle;')
    ..writeln('}')
    ..writeln()
    ..writeln('String categoryDisplayLabel(String category, AppLocalizations l10n) =>')
    ..writeln('    AppLogMessageLocalizer.localizeCategory(l10n, category);')
    ..writeln()
    ..writeln('String fieldDisplayLabel(String key, AppLocalizations l10n) =>')
    ..writeln('    AppLogMessageLocalizer.localizeField(l10n, key);');
  return buffer.toString();
}

String _branchLine(String pattern, String rhs) {
  final line = '$pattern => $rhs,';
  if (line.length <= 80) return line;
  return '$pattern =>\n        $rhs,';
}

String _wrapAssign(String head, String tail) => '$head\n      $tail';

// ---------------------------------------------------------------------------
// 校验
// ---------------------------------------------------------------------------

List<String> _structuralChecks({
  required String original,
  required String rendered,
  required String kind,
  required List<String> mustKeep,
  required String? mustKeepPattern,
}) {
  final problems = <String>[];

  // 闸 1：行数不许显著缩水（旧版就是在这里把 337 行写成 186 行）。
  final before = '\n'.allMatches(original).length;
  final after = '\n'.allMatches(rendered).length;
  if (after < (before * minLineRatio).floor()) {
    problems.add(
      '$kind 行数从 $before 缩到 $after（低于 ${(minLineRatio * 100).round()}%），拒绝写盘',
    );
  }

  // 闸 2：名字一个都不许丢（AppLogMessages.xxx / 各 switch 的 case 键）。
  final missing = [
    for (final name in mustKeep)
      if (!rendered.contains(name)) name,
  ];
  if (missing.isNotEmpty) {
    problems.add('$kind 丢了 ${missing.length} 个名字：${missing.take(8).toList()}');
  }

  // 闸 3：最简单的结构性断言 —— 括号配平、没有生成器事故留下的空行堆积。
  if (!_balanced(rendered, '{', '}')) {
    problems.add('$kind 花括号不配平');
  }
  // 首行（注释头）不许被改。**先归一化行尾**：仓库里这两个文件是 CRLF，而生成器
  // 用 `writeln` 产出 LF，直接 `startsWith(原文首行)` 会把「只是行尾不同」误判成
  // 「注释头被改」—— 2026-10-27 实测：两个文件都因此永远拒绝写盘，脚本成了
  // 「跑一次什么都不做」的摆设（安全但无用）。
  if (_firstLine(rendered) != _firstLine(original)) {
    problems.add('$kind 的首行与原文不同（注释头被改）');
  }

  // 闸 4：Dart 层面的粗校验 —— 不许出现控制字符、不许有连续的 3 个空行。
  if (rendered.contains('\u0000')) {
    problems.add('$kind 含有 NUL 字节');
  }
  if (rendered.contains('\n\n\n\n')) {
    problems.add('$kind 出现连续 3 个以上空行');
  }

  // 闸 5：**注释不许变少**。生成器按正则解析，抓不到挂在常量/分支上的说明注释，
  // 于是「只增不改」的承诺对代码成立、对注释不成立 —— 2026-10-27 在副本上实测：
  // messages 少 3 条说明、localizer 少一段「为什么有这 5 条兜底分支」的解释。
  //
  // 这条**只报警不阻断**：注释丢了不影响编译，也不影响用户看到什么，而阻断会让
  // 这个脚本彻底不能跑（等于没有）。报警的意义是让「本次会丢掉哪几条注释」出现在
  // 输出里，跑的人自己决定是接受还是先把注释搬进 ARB 侧。
  final lostComments = _commentLines(original) - _commentLines(rendered);
  if (lostComments > 0) {
    _warn(
      '$kind 的注释行会少 $lostComments 行（生成器不保留手写说明；'
      '不阻断，但请确认丢掉的不是关键解释）',
    );
  }

  return problems;
}

/// 数一数注释行（`///` 或 `//` 开头，去掉缩进）。
int _commentLines(String text) {
  var n = 0;
  for (final raw in text.split('\n')) {
    final line = raw.trimLeft();
    if (line.startsWith('///') || line.startsWith('//')) n++;
  }
  return n;
}

List<String> _noShrink(String what, int before, int after) => [
      if (after < before) '$what 从 $before 个降到 $after 个，拒绝写盘',
    ];

bool _balanced(String text, String open, String close) {
  var depth = 0;
  for (final rune in text.runes) {
    if (rune == open.codeUnitAt(0)) depth++;
    if (rune == close.codeUnitAt(0)) depth--;
    if (depth < 0) return false;
  }
  return depth == 0;
}

/// 取首行并**去掉行尾 `\r`**。
///
/// 存在的理由见 `_structuralChecks` 闸 3：仓库里被生成的文件是 CRLF，生成器产出
/// LF，不归一化就会把行尾差异误报成「注释头被改」。
String _firstLine(String text) {
  final end = text.indexOf('\n');
  final line = end < 0 ? text : text.substring(0, end);
  return line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
}

// ---------------------------------------------------------------------------
// 杂项
// ---------------------------------------------------------------------------

void _atomicWrite(File file, String text) {
  final tmp = File('${file.path}.gen-tmp');
  tmp.writeAsStringSync(text, flush: true);
  tmp.renameSync(file.path);
}

String? _valueOf(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String _snake(String name) => name
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .toLowerCase();

String _pascal(String snake) => snake
    .split('_')
    .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join();

String _camel(String key) {
  final parts = key.split(RegExp(r'[^A-Za-z0-9]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return key;
  return _lowerFirst(
    parts.first + parts.skip(1).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join(),
  );
}

String _lowerFirst(String value) =>
    value.isEmpty ? value : '${value[0].toLowerCase()}${value.substring(1)}';

String _unescapeDart(String raw) => raw
    .replaceAll(r"\'", "'")
    .replaceAll(r'\\', r'\');

void _say(String message) => stdout.writeln(message);

void _warn(String message) => stderr.writeln(message);

Never _fail(String message) {
  stderr.writeln('ERROR $message');
  exit(2);
}
