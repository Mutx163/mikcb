import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/utils/bing_wallpaper_date_label.dart';

/// 钉住日期文案的三档退化路径。
///
/// 重点是最后一条：**月/日越界必须当解析失败**。`DateTime(2026, 13, 45)` 会自动进位
/// 成 2027-02-14，于是接口哪天给了脏值，用户看到的是一个**不存在的日期**还不报错 ——
/// 那种 bug 极难从界面上联想到是解析问题。
void main() {
  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  // 固定"今天"，让断言不受测试运行时刻影响。
  final now = DateTime(2026, 10, 5, 21, 30);

  test('今天 / 昨天 走口语说法', () {
    expect(bingWallpaperDateLabel(l10n, '20261005', now: now), '今天');
    expect(bingWallpaperDateLabel(l10n, '20261004', now: now), '昨天');
  });

  test('更早的走月日，且不带年（列表最多 8 天，不会跨年）', () {
    expect(bingWallpaperDateLabel(l10n, '20261003', now: now), '10 月 3 日');
    expect(bingWallpaperDateLabel(l10n, '20260928', now: now), '9 月 28 日');
  });

  test('未来的日期也走月日，不给负数的「N 天前」', () {
    // Bing 的 enddate 偶尔跨到明天。
    expect(bingWallpaperDateLabel(l10n, '20261006', now: now), '10 月 6 日');
  });

  test('今天那条跨时刻也对（同一天的后半段不会忽然变成昨天）', () {
    expect(
      bingWallpaperDateLabel(l10n, '20261005', now: DateTime(2026, 10, 5, 0, 5)),
      '今天',
    );
    expect(
      bingWallpaperDateLabel(l10n, '20261005', now: DateTime(2026, 10, 5, 23, 55)),
      '今天',
    );
  });

  test('解析不出来就原样退回那串数字，绝不显示空白', () {
    expect(bingWallpaperDateLabel(l10n, 'abc', now: now), 'abc');
    expect(bingWallpaperDateLabel(l10n, '', now: now), '');
  });

  group('parseBingWallpaperDateKey', () {
    test('合法 YYYYMMDD', () {
      expect(parseBingWallpaperDateKey('20261005'), DateTime(2026, 10, 5));
    });

    test('长度不对 / 非数字一律失败', () {
      for (final bad in <String>[
        '',
        '2026',
        '202610051', // 9 位
        '2026100', // 7 位
        '2026ABCD',
        '  261005',
      ]) {
        expect(
          parseBingWallpaperDateKey(bad),
          isNull,
          reason: '「$bad」必须当坏值丢掉而不是被截断/进位',
        );
      }
    });

    test('月/日越界必须失败（否则 DateTime 会自动进位成别的日期）', () {
      expect(parseBingWallpaperDateKey('20261345'), isNull);
      expect(parseBingWallpaperDateKey('20260010'), isNull);
      expect(parseBingWallpaperDateKey('20261032'), isNull);
      expect(parseBingWallpaperDateKey('20261000'), isNull);
    });
  });
}