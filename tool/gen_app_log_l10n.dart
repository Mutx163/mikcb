// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Generates log ARB entries and localizer from app_log_messages.dart Chinese source.
void main() {
  final messagesFile = File('lib/logging/app_log_messages.dart');
  final content = messagesFile.readAsStringSync();

  final messageEntries = <String, String>{};
  final fieldEntries = <String, String>{};
  final categoryEntries = <String, String>{};

  final constPattern = RegExp(
    r"static const (\w+) = '([^']+)';",
  );
  for (final match in constPattern.allMatches(content)) {
    final name = match.group(1)!;
    final value = match.group(2)!;
    if (value.contains(RegExp(r'[\u4e00-\u9fff]'))) {
      messageEntries[name] = value;
    }
  }

  final fieldMapPattern = RegExp(
    r"const Map<String, String> appLogFieldLabels = \{([\s\S]*?)\};",
  );
  final fieldMapMatch = fieldMapPattern.firstMatch(content);
  if (fieldMapMatch != null) {
    final fieldPattern = RegExp(r"'([^']+)': '([^']+)'");
    for (final match in fieldPattern.allMatches(fieldMapMatch.group(1)!)) {
      fieldEntries[match.group(1)!] = match.group(2)!;
    }
  }

  final categoryMapPattern = RegExp(
    r"const Map<String, String> appLogCategoryLabels = \{([\s\S]*?)\};",
  );
  final categoryMapMatch = categoryMapPattern.firstMatch(content);
  if (categoryMapMatch != null) {
    final categoryPattern = RegExp(r"'([^']+)': '([^']+)'");
    for (final match
        in categoryPattern.allMatches(categoryMapMatch.group(1)!)) {
      categoryEntries[match.group(1)!] = match.group(2)!;
    }
  }

  String snake(String name) {
    return name
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .toLowerCase();
  }

  String arbKey(String prefix, String id) => '$prefix${id[0].toUpperCase()}${id.substring(1)}';

  final arb = <String, dynamic>{};
  final keyToArb = <String, String>{};

  for (final entry in messageEntries.entries) {
    final logKey = 'log_${snake(entry.key)}';
    final arbKeyName = arbKey('log', entry.key);
    arb[arbKeyName] = entry.value;
    keyToArb[logKey] = arbKeyName;
  }

  // liveUpdateSettingsSynced is special - parameterized
  arb['logLiveUpdateSettingsSynced'] =
      'Flutter 超级岛设置已同步：课前={beforeClass}，课中={duringClass}，下课前={beforeEnd}，提升={promote}，通知={notification}，倒计时={countdown}，课程名={courseName}，地点={location}';
  arb['@logLiveUpdateSettingsSynced'] = {
    'placeholders': {
      'beforeClass': {'type': 'String'},
      'duringClass': {'type': 'String'},
      'beforeEnd': {'type': 'String'},
      'promote': {'type': 'String'},
      'notification': {'type': 'String'},
      'countdown': {'type': 'String'},
      'courseName': {'type': 'String'},
      'location': {'type': 'String'},
    },
  };
  keyToArb['log_live_update_settings_synced'] = 'logLiveUpdateSettingsSynced';

  for (final entry in fieldEntries.entries) {
    final logKey = 'log_field_${entry.key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m[1]!.toLowerCase()}')}';
    final normalizedKey = entry.key[0].toLowerCase() + entry.key.substring(1);
    final arbKeyName = 'logField${entry.key[0].toUpperCase()}${entry.key.substring(1)}';
    arb[arbKeyName] = entry.value;
    keyToArb[logKey] = arbKeyName;
    keyToArb['log_field_${entry.key}'] = arbKeyName;
  }

  for (final entry in categoryEntries.entries) {
    final arbKeyName = 'logCat${_pascalize(entry.key)}';
    arb[arbKeyName] = entry.value;
    keyToArb[entry.key] = arbKeyName;
    keyToArb['log_cat_${entry.key}'] = arbKeyName;
  }

  arb['logExportTitle'] = '轻屿课表 - 应用日志';

  File('tool/.gen_log_arb_zh.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(arb),
  );

  // Rewrite app_log_messages.dart
  final buffer = StringBuffer('''
/// Centralized English log message keys for persisted app diagnostics.
/// Categories remain English snake_case for level inference and grep.
/// UI display is localized via [AppLogMessageLocalizer].
abstract final class AppLogMessages {
''');

  for (final entry in messageEntries.entries) {
    buffer.writeln("  static const ${entry.key} = 'log_${snake(entry.key)}';");
  }

  buffer.writeln('''
  static const liveUpdateSettingsSyncedKey = 'log_live_update_settings_synced';

  static String liveUpdateSettingsSynced({
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
}

/// English field keys for structured log viewer display.
const Map<String, String> appLogFieldLabels = {
''');

  for (final key in fieldEntries.keys) {
    final fieldKey = 'log_field_${key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m[1]!.toLowerCase()}')}';
    buffer.writeln("  '$key': '$fieldKey',");
  }

  buffer.writeln('''};

String categoryDisplayLabel(String category, AppLocalizations l10n) =>
    AppLogMessageLocalizer.localizeCategory(l10n, category);

String fieldDisplayLabel(String key, AppLocalizations l10n) =>
    AppLogMessageLocalizer.localizeField(l10n, key);

/// English category keys for structured log viewer display.
const Map<String, String> appLogCategoryLabels = {
''');

  for (final key in categoryEntries.keys) {
    buffer.writeln("  '$key': 'log_cat_$key',");
  }

  buffer.writeln('};');
  messagesFile.writeAsStringSync(buffer.toString());

  // Generate localizer switch cases
  final loc = StringBuffer('''
import '../l10n/app_localizations.dart';

/// Maps persisted log message / field / category keys to localized strings.
abstract final class AppLogMessageLocalizer {
  static String localizeMessage(AppLocalizations l10n, String message) {
    if (message.startsWith('\${AppLogMessages.liveUpdateSettingsSyncedKey}|')) {
      final params = <String, String>{};
      for (final part in message.split('|').skip(1)) {
        final idx = part.indexOf('=');
        if (idx > 0) {
          params[part.substring(0, idx)] = part.substring(idx + 1);
        }
      }
      return l10n.logLiveUpdateSettingsSynced(
        params['beforeClass'] ?? '',
        params['duringClass'] ?? '',
        params['beforeEnd'] ?? '',
        params['promote'] ?? '',
        params['notification'] ?? '',
        params['countdown'] ?? '',
        params['courseName'] ?? '',
        params['location'] ?? '',
      );
    }
    return switch (message) {
''');

  for (final entry in messageEntries.entries) {
    final logKey = 'log_${snake(entry.key)}';
    final arbKeyName = arbKey('log', entry.key);
    loc.writeln("      '$logKey' => l10n.$arbKeyName,");
  }
  loc.writeln("      _ => message,");
  loc.writeln('''    };
  }

  static String localizeField(AppLocalizations l10n, String key) {
    final mapped = appLogFieldLabels[key];
    if (mapped == null) return key;
    return switch (mapped) {
''');

  for (final entry in fieldEntries.entries) {
    final arbKeyName = 'logField${entry.key[0].toUpperCase()}${entry.key.substring(1)}';
    final fieldKey = 'log_field_${entry.key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m[1]!.toLowerCase()}')}';
    loc.writeln("      '$fieldKey' => l10n.$arbKeyName,");
  }
  loc.writeln("      _ => key,");
  loc.writeln('''    };
  }

  static String localizeCategory(AppLocalizations l10n, String category) {
    final mapped = appLogCategoryLabels[category];
    if (mapped == null) return category;
    return switch (mapped) {
''');

  for (final entry in categoryEntries.entries) {
    final arbKeyName = 'logCat${_pascalize(entry.key)}';
    loc.writeln("      'log_cat_${entry.key}' => l10n.$arbKeyName,");
  }
  loc.writeln("      _ => category,");
  loc.writeln('''    };
  }

  static String localizeExportTitle(AppLocalizations l10n) => l10n.logExportTitle;
}
''');

  File('lib/logging/app_log_message_localizer.dart').writeAsStringSync(loc.toString());

  print('Generated ${messageEntries.length} messages, ${fieldEntries.length} fields, ${categoryEntries.length} categories');
  print('ARB chunk: tool/.gen_log_arb_zh.json');
}

String _pascalize(String snake) {
  return snake
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join();
}
