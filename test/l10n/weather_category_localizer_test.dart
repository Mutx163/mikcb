import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/weather_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/weather_category_localizer.dart';

/// 全部 6 个语言的 locale（zh 的三个变体靠 countryCode 区分）。
const _locales = <String, Locale>{
  'zh': Locale('zh'),
  'zh_HK': Locale('zh', 'HK'),
  'zh_TW': Locale('zh', 'TW'),
  'en': Locale('en'),
  'ja': Locale('ja'),
  'ko': Locale('ko'),
};

CourseWeatherSummary _summary({
  WeatherCategory category = WeatherCategory.lightRain,
  int temperatureC = 23,
  int? probability = 60,
  bool showProbability = true,
}) {
  return CourseWeatherSummary(
    category: category,
    temperatureC: temperatureC,
    hourCount: 2,
    precipitationProbability: probability,
    showPrecipitationProbability: showProbability,
    representativeWmoCode: null,
  );
}

void main() {
  test('每个分类在每种语言下都有非空文案', () {
    for (final entry in _locales.entries) {
      final l10n = lookupAppLocalizations(entry.value);
      for (final category in WeatherCategory.values) {
        final label = WeatherCategoryLocalizer.label(l10n, category);
        expect(label.trim(), isNotEmpty, reason: '${entry.key} / $category');
      }
    }
  });

  test('中文下 20 个分类文案互不相同（防拷贝粘贴错行）', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final labels = {
      for (final category in WeatherCategory.values)
        WeatherCategoryLocalizer.label(l10n, category),
    };
    expect(labels.length, WeatherCategory.values.length);
  });

  test('各语言的关键现象翻译抽查', () {
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh')),
        WeatherCategory.lightRain,
      ),
      '小雨',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh')),
        WeatherCategory.snow,
      ),
      '中雪',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('en')),
        WeatherCategory.lightRain,
      ),
      'Light rain',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('ja')),
        WeatherCategory.thunderstorm,
      ),
      '雷雨',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('ko')),
        WeatherCategory.clear,
      ),
      '맑음',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh', 'HK')),
        WeatherCategory.rainShowers,
      ),
      '陣雨',
    );
    expect(
      WeatherCategoryLocalizer.label(
        lookupAppLocalizations(const Locale('zh', 'TW')),
        WeatherCategory.rainShowers,
      ),
      '陣雨',
    );
  });

  test('摘要行：现象 · 温度 · 概率', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(
      WeatherCategoryLocalizer.summary(l10n, _summary()),
      '小雨 · 23° · 60%',
    );
  });

  test('概率不该显示时用短句', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(
      WeatherCategoryLocalizer.summary(
        l10n,
        _summary(category: WeatherCategory.clear, temperatureC: 26, showProbability: false),
      ),
      '晴 · 26°',
    );
  });

  test('概率为 null 时不渲染百分号', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final line = WeatherCategoryLocalizer.summary(
      l10n,
      _summary(probability: null, showProbability: false),
    );
    expect(line, '小雨 · 23°');
    expect(line, isNot(contains('%')));
  });

  test('每种语言的摘要行都替换掉了占位符', () {
    for (final entry in _locales.entries) {
      final l10n = lookupAppLocalizations(entry.value);
      final withProbability = WeatherCategoryLocalizer.summary(
        l10n,
        _summary(temperatureC: -7, probability: 80),
      );
      final withoutProbability = WeatherCategoryLocalizer.summary(
        l10n,
        _summary(temperatureC: -7, showProbability: false),
      );
      for (final line in [withProbability, withoutProbability]) {
        expect(line, contains('-7'), reason: entry.key);
        expect(line, isNot(contains('{')), reason: entry.key);
        expect(line.trim(), isNotEmpty, reason: entry.key);
      }
      expect(withProbability, contains('80%'), reason: entry.key);
      expect(withoutProbability, isNot(contains('80')), reason: entry.key);
    }
  });

  test('负温度与零度都正常渲染', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(
      WeatherCategoryLocalizer.summary(l10n, _summary(temperatureC: 0)),
      '小雨 · 0° · 60%',
    );
    expect(
      WeatherCategoryLocalizer.summary(l10n, _summary(temperatureC: -12)),
      '小雨 · -12° · 60%',
    );
  });
}
