import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations_zh.dart';
import 'package:university_timetable/l10n/app_localizations_en.dart';
import 'package:university_timetable/l10n/app_localizations_ja.dart';
import 'package:university_timetable/l10n/app_localizations_ko.dart';

void main() {
  group('Localization completeness', () {
    test('cloudSyncBaseUrlSecurityNote exists in all supported locales', () {
      // 测试中文
      final zh = AppLocalizationsZh();
      expect(
        zh.cloudSyncBaseUrlSecurityNote,
        isNotEmpty,
        reason: 'zh: cloudSyncBaseUrlSecurityNote should not be empty',
      );

      // 测试英文
      final en = AppLocalizationsEn();
      expect(
        en.cloudSyncBaseUrlSecurityNote,
        isNotEmpty,
        reason: 'en: cloudSyncBaseUrlSecurityNote should not be empty',
      );

      // 测试日语
      final ja = AppLocalizationsJa();
      expect(
        ja.cloudSyncBaseUrlSecurityNote,
        isNotEmpty,
        reason: 'ja: cloudSyncBaseUrlSecurityNote should not be empty',
      );

      // 测试韩语
      final ko = AppLocalizationsKo();
      expect(
        ko.cloudSyncBaseUrlSecurityNote,
        isNotEmpty,
        reason: 'ko: cloudSyncBaseUrlSecurityNote should not be empty',
      );
    });

    test('cloudSyncBaseUrlSecurityNote is not Chinese in non-Chinese locales',
        () {
      final en = AppLocalizationsEn();
      final ja = AppLocalizationsJa();
      final ko = AppLocalizationsKo();

      // 英文不应该包含中文字符
      expect(
        en.cloudSyncBaseUrlSecurityNote,
        isNot(contains('正式版')),
        reason: 'en: should not contain Chinese characters',
      );

      // 日语应该包含日语字符（至少是假名）
      expect(
        ja.cloudSyncBaseUrlSecurityNote,
        anyOf(contains('リリース'), contains('HTTPS')),
        reason: 'ja: should contain Japanese text',
      );

      // 韩语应该包含韩语字符
      expect(
        ko.cloudSyncBaseUrlSecurityNote,
        anyOf(contains('출시'), contains('HTTPS')),
        reason: 'ko: should contain Korean text',
      );
    });

    test('ARB files contain cloudSyncBaseUrlSecurityNote key', () {
      final arbFiles = [
        'lib/l10n/app_zh.arb',
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ja.arb',
        'lib/l10n/app_ko.arb',
        'lib/l10n/app_zh_TW.arb',
        'lib/l10n/app_zh_HK.arb',
      ];

      for (final arbFile in arbFiles) {
        final file = File(arbFile);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final json = jsonDecode(content) as Map<String, dynamic>;
          expect(
            json.containsKey('cloudSyncBaseUrlSecurityNote'),
            isTrue,
            reason: '$arbFile should contain cloudSyncBaseUrlSecurityNote',
          );
          expect(
            json['cloudSyncBaseUrlSecurityNote'],
            isNotEmpty,
            reason:
                '$arbFile: cloudSyncBaseUrlSecurityNote should not be empty',
          );
        }
      }
    });
  });
}
