import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' as date_local;
import 'package:intl/intl.dart';
import 'package:university_timetable/utils/locale_utils.dart';

/// `syncIntlDefaultLocale` 的映射与「跟随系统不动」语义。
///
/// 背景：`DateFormat` 不传 locale 时读 `Intl.defaultLocale`，而这个全局值
/// flutter_localizations 不会设置、也不跟 `MaterialApp.locale` 走。修复
/// （2026-10-20 体检 #34）在 `_localeFromSettings` 里同步它——本文件只断言
/// 同步函数设置的字符串与空值语义；「DateFormat 因此按该 locale 输出」属于
/// intl 库行为，用内置 en_US 符号表验证一次机制前提即可（真机上符号表由
/// GlobalMaterialLocalizations 装载，纯 flutter_test 环境没有，须手动初始化）。
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

    test('null（跟随系统）不动全局值', () {
      Intl.defaultLocale = 'ko';
      syncIntlDefaultLocale(null);
      expect(Intl.defaultLocale, 'ko');
    });

    test('机制前提：设置后无参 DateFormat 确实按该 locale 输出', () {
      syncIntlDefaultLocale(const Locale('en', 'US'));
      expect(Intl.defaultLocale, 'en_US');
      // 期望值来自 CLDR 的 en yMMM 模式（独立来源），不是从实现里抄的。
      expect(DateFormat.yMMM().format(DateTime(2026, 7, 8)), 'Jul 2026');
    });
  });
}
