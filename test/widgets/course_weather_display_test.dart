import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/weather_logic.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/widgets/course_weather_display.dart';

/// 全部 6 个语言的 locale（zh 的三个变体靠 countryCode 区分）。
const _locales = <String, Locale>{
  'zh': Locale('zh'),
  'zh_HK': Locale('zh', 'HK'),
  'zh_TW': Locale('zh', 'TW'),
  'en': Locale('en'),
  'ja': Locale('ja'),
  'ko': Locale('ko'),
};

AppLocalizations _zh() => lookupAppLocalizations(const Locale('zh'));

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

/// 默认内容组合 = 设置页的默认值：现象开、温度开、概率关。
CourseWeatherDisplay? _display(
  CourseWeatherSummary? summary, {
  bool phenomenon = true,
  bool temperature = true,
  bool probability = false,
}) {
  return courseWeatherDisplayFor(
    l10n: _zh(),
    summary: summary,
    showPhenomenon: phenomenon,
    showTemperature: temperature,
    showProbability: probability,
  );
}

void main() {
  group('内容开关组合', () {
    test('默认组合（现象 + 温度）拼成「小雨 · 23°」', () {
      expect(_display(_summary())?.text, '小雨 · 23°');
    });

    test('三项全开带上概率', () {
      expect(
        _display(_summary(), probability: true)?.text,
        '小雨 · 23° · 60%',
      );
    });

    test('只要温度时只剩数字', () {
      expect(
        _display(_summary(), phenomenon: false)?.text,
        '23°',
      );
    });

    test('只要现象时不带温度', () {
      expect(
        _display(_summary(), temperature: false)?.text,
        '小雨',
      );
    });

    test('温度 + 概率（关掉现象）', () {
      expect(
        _display(_summary(), phenomenon: false, probability: true)?.text,
        '23° · 60%',
      );
    });

    test('三项全关返回 null，整行不渲染', () {
      expect(
        _display(
          _summary(),
          phenomenon: false,
          temperature: false,
        ),
        isNull,
      );
    });

    test('没有摘要时无论开关怎么配都返回 null', () {
      expect(_display(null), isNull);
      expect(_display(null, probability: true), isNull);
      expect(
        _display(null, phenomenon: false, temperature: false),
        isNull,
      );
    });
  });

  group('降水概率的可用性', () {
    test('摘要判定不该显示时，即使勾了概率也不出现', () {
      final display = _display(
        _summary(probability: 10, showProbability: false),
        probability: true,
      );
      expect(display?.text, '小雨 · 23°');
      expect(display?.text, isNot(contains('%')));
    });

    test('概率为 null 时不渲染百分号', () {
      final display = _display(
        _summary(probability: null, showProbability: false),
        probability: true,
      );
      expect(display?.text, '小雨 · 23°');
      expect(display?.text, isNot(contains('%')));
    });

    test('只勾了概率但没有可用概率 → 整行消失（不留一个光秃秃的图标）', () {
      expect(
        _display(
          _summary(probability: null, showProbability: false),
          phenomenon: false,
          temperature: false,
          probability: true,
        ),
        isNull,
      );
    });
  });

  group('图标', () {
    test('现象开着时图标跟随现象分类', () {
      expect(
        _display(_summary())?.icon,
        weatherIconFor(WeatherCategory.lightRain),
      );
      expect(
        _display(_summary(category: WeatherCategory.snow))?.icon,
        weatherIconFor(WeatherCategory.snow),
      );
    });

    test('现象开着时，温度也开着也不会抢走图标', () {
      // 优先级 = 现象 > 温度 > 概率：由第一个勾上的项目认领。
      expect(
        _display(_summary(), probability: true)?.icon,
        weatherIconFor(WeatherCategory.lightRain),
      );
    });

    test('关掉现象、只留温度 → 图标换成温度计', () {
      final display = _display(_summary(), phenomenon: false);
      expect(display?.icon, Icons.thermostat);
      expect(display?.text, '23°');
      // 不能还是「小雨」那一族的雨滴——用户刚把现象关掉，再画雨滴等于把现象从
      // 后门放回来。
      expect(display?.icon, isNot(weatherIconFor(WeatherCategory.lightRain)));
    });

    test('关掉现象、只留概率 → 图标换成百分号', () {
      final display = _display(
        _summary(),
        phenomenon: false,
        temperature: false,
        probability: true,
      );
      expect(display?.icon, Icons.percent);
      expect(display?.text, '60%');
    });

    test('关掉现象、温度与概率都在 → 图标由温度认领', () {
      final display = _display(_summary(), phenomenon: false, probability: true);
      expect(display?.icon, Icons.thermostat);
      expect(display?.text, '23° · 60%');
    });

    test('只要这一行会画，图标就一定是三种可认领形状之一', () {
      // 「认领」原则的兜底断言：图标只可能来自某个勾上的项目（现象→天气图标、
      // 温度→温度计、概率→百分号），不会冒出第四种说不出所以然的图形。
      final claimable = {
        weatherIconFor(WeatherCategory.lightRain),
        Icons.thermostat,
        Icons.percent,
      };
      for (final phenomenon in [true, false]) {
        for (final temperature in [true, false]) {
          for (final probability in [true, false]) {
            if (!phenomenon && !temperature && !probability) {
              continue; // 三项全关：整行不画，本来就没有图标
            }
            final display = _display(
              _summary(),
              phenomenon: phenomenon,
              temperature: temperature,
              probability: probability,
            );
            expect(
              display,
              isNotNull,
              reason: 'p=$phenomenon t=$temperature r=$probability',
            );
            expect(
              claimable,
              contains(display!.icon),
              reason: 'p=$phenomenon t=$temperature r=$probability',
            );
          }
        }
      }
    });

    test('20 个分类都有图标且不是同一个', () {
      final icons = {
        for (final category in WeatherCategory.values)
          weatherIconFor(category),
      };
      // 图标按「家族」复用（小雨/中雨/大雨同一个水滴），所以只要求收敛到少数几个
      // 不同图形，而不是 20 个全不同——但绝不能退化成一个。
      expect(icons.length, greaterThan(5));
    });
  });

  group('跨语言', () {
    test('每种语言都替换掉占位符，且现象名随语言变', () {
      for (final entry in _locales.entries) {
        final l10n = lookupAppLocalizations(entry.value);
        final full = courseWeatherDisplayFor(
          l10n: l10n,
          summary: _summary(temperatureC: -7, probability: 80),
          showPhenomenon: true,
          showTemperature: true,
          showProbability: true,
        )!;
        expect(full.text, contains('-7'), reason: entry.key);
        expect(full.text, contains('80%'), reason: entry.key);
        expect(full.text, isNot(contains('{')), reason: entry.key);
        expect(full.text.trim(), isNotEmpty, reason: entry.key);
      }
      // 同一个现象在不同语言下的现象名不该是同一串（否则就是漏翻译）。
      String phenomenonName(Locale locale) => courseWeatherDisplayFor(
        l10n: lookupAppLocalizations(locale),
        summary: _summary(),
        showPhenomenon: true,
        showTemperature: false,
        showProbability: false,
      )!.text;
      expect(
        phenomenonName(_locales['zh']!),
        isNot(phenomenonName(_locales['en']!)),
      );
    });

    test('负温度与零度都正常渲染', () {
      expect(_display(_summary(temperatureC: 0))?.text, '小雨 · 0°');
      expect(_display(_summary(temperatureC: -12))?.text, '小雨 · -12°');
    });
  });
}
