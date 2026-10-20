import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' as date_local;
import 'package:intl/intl.dart';
import 'package:university_timetable/utils/locale_utils.dart';

/// `syncIntlDefaultLocale` 的映射与「跟随系统 = 清空全局值」语义。
///
/// 背景：`DateFormat` 不传 locale 时读 `Intl.defaultLocale`，而这个全局值
/// flutter_localizations 不会设置、也不跟 `MaterialApp.locale` 走。修复
/// （2026-10-20 体检 #34）在 `_localeFromSettings` 里同步它——本文件断言
/// 同步函数设置的字符串、空值语义，以及「固定语言 → 切回跟随系统」这条
/// 端到端回路（复位后日期必须回到系统语言）；「DateFormat 因此按该 locale
/// 输出」属于 intl 库行为，用内置符号表验证（`initializeDateFormatting()`
/// 不带参数会装载全部语言；真机上符号表由 GlobalMaterialLocalizations 装载）。
void main() {
  setUpAll(date_local.initializeDateFormatting);

  // Intl.defaultLocale 是进程级全局，先存后还，避免污染其他测试。
  String? savedDefaultLocale;
  setUp(() {
    savedDefaultLocale = Intl.defaultLocale;
  });
  tearDown(() {
    Intl.defaultLocale = savedDefaultLocale;
  });

  group('syncIntlDefaultLocale', () {
    test('带地区码的 locale 同步为下划线 tag', () {
      syncIntlDefaultLocale(const Locale('zh', 'CN'));
      expect(Intl.defaultLocale, 'zh_CN');
    });

    test('纯语言的 locale 同步为 languageCode', () {
      syncIntlDefaultLocale(const Locale('ja'));
      expect(Intl.defaultLocale, 'ja');
    });

    test('null（跟随系统）清空全局值，不再沿用上一个 App 语言', () {
      Intl.defaultLocale = 'ko';
      syncIntlDefaultLocale(null);
      // 「什么都不做」正是 bug（2026-10-20 复核补）：进程内切过固定语言后，
      // 全局值会一直留着，于是 UI 已回系统语言、日期却还是上一个语言。
      expect(Intl.defaultLocale, isNull);
    });

    test('机制前提：设置后无参 DateFormat 确实按该 locale 输出', () {
      syncIntlDefaultLocale(const Locale('en', 'US'));
      expect(Intl.defaultLocale, 'en_US');
      // 期望值来自 CLDR 的 en yMMM 模式（独立来源），不是从实现里抄的。
      expect(DateFormat.yMMM().format(DateTime(2026, 7, 8)), 'Jul 2026');
    });

    test('固定语言 → 跟随系统：日期回到系统语言', () {
      final sample = DateTime(2026, 7, 8);
      // 期望值由 Intl.systemLocale 推出（测试环境默认 en_US），不从实现抄。
      final systemOutput = DateFormat.yMMM(Intl.systemLocale).format(sample);
      // 前提：不传 locale 时等于 systemLocale 的输出（DateFormat 回落口径）。
      expect(DateFormat.yMMM().format(sample), systemOutput);
      // 注意：intl 的 getCurrentLocale() 会把 defaultLocale 自动写成
      // systemLocale，所以下面 `isNull` 必须紧跟在复位之后、任何
      // DateFormat 调用之前。

      syncIntlDefaultLocale(const Locale('ko'));
      final koreanOutput = DateFormat.yMMM().format(sample);
      if (!Intl.systemLocale.toLowerCase().startsWith('ko')) {
        // 宿主系统本身就是韩语时这一步观察不到差异，不当脆断言。
        expect(koreanOutput, isNot(systemOutput));
      }

      syncIntlDefaultLocale(null);
      expect(Intl.defaultLocale, isNull);
      expect(DateFormat.yMMM().format(sample), systemOutput);
    });
  });
}
