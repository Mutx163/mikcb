import '../l10n/service_message_localizer.dart';

/// Parses week expressions from AI import JSON and WakeUp spreadsheet columns.
class WeekExpressionParser {
  const WeekExpressionParser._();

  static final RegExp _bracketSectionSuffixPattern = RegExp(
    r'\[[^\]]*\u8282\]',
  );
  static final RegExp _fullWidthBracketSectionSuffixPattern = RegExp(
    r'\u3010[^\u3011]*\u8282\u3011',
  );
  static final RegExp _parityModePattern = RegExp(
    r'[\uff08(](\u5168\u90e8|\u5355|\u53cc)[\uff09)]',
  );
  static final RegExp _parentheticalPattern = RegExp(
    r'[\uff08(][^\uff09)]*[\uff09)]',
  );
  static final RegExp _tokenSeparatorPattern = RegExp(r'[\uff0c,\u3001]');

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
        .replaceAll(_bracketSectionSuffixPattern, '')
        .replaceAll(_fullWidthBracketSectionSuffixPattern, '');

    final modeMatch = _parityModePattern.firstMatch(normalized)?.group(1);
    normalized = normalized.replaceAll(_parentheticalPattern, '');

    final result = <int>{};
    final parts = normalized.split(_tokenSeparatorPattern);
    var nonEmptyTokenCount = 0;
    var anyTokenParity = false;
    for (final part in parts) {
      var token = part.trim();
      if (token.isEmpty) {
        continue;
      }
      nonEmptyTokenCount += 1;

      String? tokenParity;
      if (token.endsWith('\u5355')) {
        tokenParity = '\u5355';
        token = token.substring(0, token.length - 1);
        anyTokenParity = true;
      } else if (token.endsWith('\u53cc')) {
        tokenParity = '\u53cc';
        token = token.substring(0, token.length - 1);
        anyTokenParity = true;
      }

      final rangeMatch = RegExp(r'^(\d+)-(\d+)$').firstMatch(token);
      if (rangeMatch != null) {
        final start = int.parse(rangeMatch.group(1)!);
        final end = int.parse(rangeMatch.group(2)!);
        if (start < 1) {
          throw FormatException(
            encodeServiceMessage('week_start_invalid', {'itemName': itemName}),
          );
        }
        if (start > end) {
          throw FormatException(
            encodeServiceMessage('week_range_invalid', {'itemName': itemName}),
          );
        }
        if (end > 30) {
          throw FormatException(
            encodeServiceMessage('week_range_too_large', {
              'itemName': itemName,
            }),
          );
        }
        final weeks = <int>[];
        for (var week = start; week <= end; week++) {
          weeks.add(week);
        }
        result.addAll(_applyParity(weeks, tokenParity));
        continue;
      }

      final parsed = int.tryParse(token);
      if (parsed == null || parsed < 1) {
        throw FormatException(
          encodeServiceMessage('week_token_unrecognized', {
            'itemName': itemName,
            'token': token,
          }),
        );
      }
      result.addAll(_applyParity([parsed], tokenParity));
    }

    var weeks = result.toList()..sort();
    // Global (单)/(双) only applies to a single token expression, so multi-range
    // strings like "1-5、7-11(单)" are not incorrectly filtered as a whole.
    final applyGlobalParity =
        modeMatch != null && !anyTokenParity && nonEmptyTokenCount <= 1;
    if (applyGlobalParity && modeMatch == '\u5355') {
      weeks = weeks.where((week) => week.isOdd).toList();
    } else if (applyGlobalParity && modeMatch == '\u53cc') {
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
      encodeServiceMessage('weeks_exceed_semester_clamped', {
        'itemName': itemName,
        'semesterWeekCount': semesterWeekCount,
        'weeks': over.join('\u3001'),
      }),
    );
    return weeks.where((week) => week <= semesterWeekCount).toList();
  }

  static List<int> _applyParity(List<int> weeks, String? parity) {
    if (parity == '\u5355') {
      return weeks.where((week) => week.isOdd).toList();
    }
    if (parity == '\u53cc') {
      return weeks.where((week) => week.isEven).toList();
    }
    return weeks;
  }
}
