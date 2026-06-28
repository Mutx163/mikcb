/// Parses week expressions from AI import JSON and WakeUp spreadsheet columns.
class WeekExpressionParser {
  const WeekExpressionParser._();

  static List<int> parse(
    String raw, {
    required String itemName,
  }) {
    var normalized = raw.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    normalized = normalized
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'\[[^\]]*节\]'), '')
        .replaceAll(RegExp(r'【[^】]*节】'), '');

    final modeMatch =
        RegExp(r'[（(](全部|单|双)[）)]').firstMatch(normalized)?.group(1);
    normalized = normalized.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '');

    final result = <int>{};
    final parts = normalized.split(RegExp(r'[，,、]'));
    for (final part in parts) {
      var token = part.trim();
      if (token.isEmpty) {
        continue;
      }

      String? tokenParity;
      if (token.endsWith('单')) {
        tokenParity = '单';
        token = token.substring(0, token.length - 1);
      } else if (token.endsWith('双')) {
        tokenParity = '双';
        token = token.substring(0, token.length - 1);
      }

      final rangeMatch = RegExp(r'^(\d+)-(\d+)$').firstMatch(token);
      if (rangeMatch != null) {
        final start = int.parse(rangeMatch.group(1)!);
        final end = int.parse(rangeMatch.group(2)!);
        if (start > end) {
          throw FormatException('$itemName 周次范围不合法');
        }
        var weeks = <int>[];
        for (var week = start; week <= end; week++) {
          weeks.add(week);
        }
        result.addAll(_applyParity(weeks, tokenParity));
        continue;
      }

      final parsed = int.tryParse(token);
      if (parsed == null || parsed < 1) {
        throw FormatException('$itemName 含有无法识别的周次：$token');
      }
      result.addAll(_applyParity([parsed], tokenParity));
    }

    final weeks = result.toList()..sort();
    if (modeMatch == '单') {
      return weeks.where((week) => week.isOdd).toList();
    }
    if (modeMatch == '双') {
      return weeks.where((week) => week.isEven).toList();
    }
    return weeks;
  }

  static List<int> _applyParity(List<int> weeks, String? parity) {
    if (parity == '单') {
      return weeks.where((week) => week.isOdd).toList();
    }
    if (parity == '双') {
      return weeks.where((week) => week.isEven).toList();
    }
    return weeks;
  }
}
