import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/weather_location_failure_localizer.dart';
import 'package:university_timetable/services/device_location_service.dart';

const _locales = <String, Locale>{
  'zh': Locale('zh'),
  'zh_HK': Locale('zh', 'HK'),
  'zh_TW': Locale('zh', 'TW'),
  'en': Locale('en'),
  'ja': Locale('ja'),
  'ko': Locale('ko'),
};

void main() {
  test('每种失败原因在每种语言下都有非空文案', () {
    for (final entry in _locales.entries) {
      final l10n = lookupAppLocalizations(entry.value);
      for (final failure in DeviceLocationFailure.values) {
        final message = WeatherLocationFailureLocalizer.message(l10n, failure);
        expect(message.trim(), isNotEmpty, reason: '${entry.key} / $failure');
      }
    }
  });

  test('各种失败原因的中文文案互不相同（防拷贝粘贴错行）', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final messages = {
      for (final failure in DeviceLocationFailure.values)
        WeatherLocationFailureLocalizer.message(l10n, failure),
    };
    expect(messages.length, DeviceLocationFailure.values.length);
  });

  test('永久拒绝那条明确指路系统设置', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(
      WeatherLocationFailureLocalizer.message(
        zh,
        DeviceLocationFailure.permissionDeniedForever,
      ),
      contains('系统设置'),
    );
  });

  test('地名解析失败与其它定位失败是两句不同的话', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    final address = WeatherLocationFailureLocalizer.message(
      zh,
      DeviceLocationFailure.addressUnavailable,
    );
    final generic = WeatherLocationFailureLocalizer.message(
      zh,
      DeviceLocationFailure.failed,
    );
    expect(address, isNot(generic));
    // 已经定到位置了，只是名字没解析出来——这句要引导手动搜索。
    expect(address, contains('搜索'));
  });
}
