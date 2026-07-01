/// Parses week expressions from AI import JSON and WakeUp spreadsheet columns.
class WeekExpressionParser {
  const WeekExpressionParser._();

  static List<int> parse(
    String raw, {
    required String itemName,
    int? semesterWeekCount,
    List<String>? warnings,
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
        if (start < 1) {
          throw FormatException('$itemName 周次起始值不合法');
        }
        if (start > end) {
          throw FormatException('$itemName 周次范围不合法');
        }
        if (end > 30) {
          throw FormatException('$itemName 周次范围过大，请检查');
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

    var weeks = result.toList()..sort();
    if (modeMatch == '单') {
      weeks = weeks.where((week) => week.isOdd).toList();
    } else if (modeMatch == '双') {
      weeks = weeks.where((week) => week.isEven).toList();
    }

    return _clampToSemesterWeekCount(
      weeks,
      semesterWeekCount: semesterWeekCount,
      itemName: itemName,
      warnings: warnings,
    );
  }

  static List<int> _clampToSemesterWeekCount(
    List<int> weeks, {
    required String itemName,
    int? semesterWeekCount,
    List<String>? warnings,
  }) {
    if (semesterWeekCount == null || semesterWeekCount < 1 || weeks.isEmpty) {
      return weeks;
    }
    final over = weeks.where((week) => week > semesterWeekCount).toList();
    if (over.isEmpty) {
      return weeks;
    }
    warnings?.add(
      '$itemName 含有超过学期周数 $semesterWeekCount 的周次（'
      '${over.join('、')}），已忽略超出部分',
    );
    return weeks.where((week) => week <= semesterWeekCount).toList();
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
