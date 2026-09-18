import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/weather_logic.dart';
import 'package:university_timetable/models/weather_forecast.dart';

const int _day = 18;

HourlyWeatherPoint _point({
  required int hour,
  int minute = 0,
  double? temperature,
  int? probability,
  double? precipitation,
  double? snowfall,
  int? code,
  int day = _day,
}) {
  return HourlyWeatherPoint(
    time: DateTime(2026, 9, day, hour, minute),
    temperatureC: temperature,
    precipitationProbability: probability,
    precipitationMm: precipitation,
    snowfallCm: snowfall,
    weatherCode: code,
  );
}

/// 2026-09-18 全天 24 小时逐小时序列，取值由回调按小时生成。
List<HourlyWeatherPoint> _fullDay({
  double Function(int hour)? temperatureFor,
  int Function(int hour)? codeFor,
  int Function(int hour)? probabilityFor,
  double Function(int hour)? precipitationFor,
  double Function(int hour)? snowfallFor,
}) {
  return [
    for (var hour = 0; hour < 24; hour++)
      _point(
        hour: hour,
        temperature: temperatureFor?.call(hour) ?? 20,
        code: codeFor?.call(hour),
        probability: probabilityFor?.call(hour),
        precipitation: precipitationFor?.call(hour),
        snowfall: snowfallFor?.call(hour),
      ),
  ];
}

CourseWeatherSummary? _summarizeOnDay(
  List<HourlyWeatherPoint> points, {
  required int startHour,
  int startMinute = 0,
  required int endHour,
  int endMinute = 0,
  int probabilityThreshold = defaultProbabilityVisibilityThreshold,
}) {
  return summarizeCourseWeather(
    forecast: WeatherForecast(
      latitude: 30.29365,
      longitude: 120.16142,
      fetchedAt: DateTime(2026, 9, 18, 6),
      hourly: points,
    ),
    start: DateTime(2026, 9, _day, startHour, startMinute),
    end: DateTime(2026, 9, _day, endHour, endMinute),
    probabilityVisibilityThreshold: probabilityThreshold,
  );
}

void main() {
  group('WMO 码映射', () {
    const expected = <int, WeatherCategory>{
      0: WeatherCategory.clear,
      1: WeatherCategory.mainlyClear,
      2: WeatherCategory.partlyCloudy,
      3: WeatherCategory.overcast,
      45: WeatherCategory.fog,
      48: WeatherCategory.fog,
      51: WeatherCategory.drizzle,
      53: WeatherCategory.drizzle,
      55: WeatherCategory.drizzle,
      56: WeatherCategory.freezingDrizzle,
      57: WeatherCategory.freezingDrizzle,
      61: WeatherCategory.lightRain,
      63: WeatherCategory.rain,
      65: WeatherCategory.heavyRain,
      66: WeatherCategory.freezingRain,
      67: WeatherCategory.freezingRain,
      71: WeatherCategory.lightSnow,
      73: WeatherCategory.snow,
      75: WeatherCategory.heavySnow,
      77: WeatherCategory.snowGrains,
      80: WeatherCategory.rainShowers,
      81: WeatherCategory.rainShowers,
      82: WeatherCategory.heavyRainShowers,
      85: WeatherCategory.snowShowers,
      86: WeatherCategory.snowShowers,
      95: WeatherCategory.thunderstorm,
      96: WeatherCategory.thunderstormHail,
      99: WeatherCategory.thunderstormHail,
    };

    test('每个已知码都映射到期望分类', () {
      for (final entry in expected.entries) {
        expect(
          weatherCategoryFromWmo(entry.key),
          entry.value,
          reason: 'WMO ${entry.key}',
        );
      }
    });

    test('未知码兜底为 clear，不猜成恶劣天气', () {
      expect(weatherCategoryFromWmo(100), WeatherCategory.clear);
      expect(weatherCategoryFromWmo(-1), WeatherCategory.clear);
    });
  });

  group('严重度与雨雪家族', () {
    test('严重度序单调：晴 < 雨 < 雪 < 雷暴', () {
      expect(
        weatherCategorySeverity(WeatherCategory.clear),
        lessThan(weatherCategorySeverity(WeatherCategory.lightRain)),
      );
      expect(
        weatherCategorySeverity(WeatherCategory.heavyRain),
        lessThan(weatherCategorySeverity(WeatherCategory.lightSnow)),
      );
      expect(
        weatherCategorySeverity(WeatherCategory.heavySnow),
        lessThan(weatherCategorySeverity(WeatherCategory.thunderstormHail)),
      );
    });

    test('冻雨归雨家族不归雪家族', () {
      expect(weatherCategoryIsRain(WeatherCategory.freezingRain), isTrue);
      expect(weatherCategoryIsSnow(WeatherCategory.freezingRain), isFalse);
      expect(weatherCategoryIsRain(WeatherCategory.freezingDrizzle), isTrue);
      expect(weatherCategoryIsSnow(WeatherCategory.freezingDrizzle), isFalse);
    });

    test('阵雪归雪、阵雨归雨', () {
      expect(weatherCategoryIsSnow(WeatherCategory.snowShowers), isTrue);
      expect(weatherCategoryIsRain(WeatherCategory.snowShowers), isFalse);
      expect(weatherCategoryIsRain(WeatherCategory.rainShowers), isTrue);
      expect(weatherCategoryIsSnow(WeatherCategory.rainShowers), isFalse);
    });

    test('晴与阴不属于任何降水家族', () {
      for (final category in [
        WeatherCategory.clear,
        WeatherCategory.mainlyClear,
        WeatherCategory.partlyCloudy,
        WeatherCategory.overcast,
        WeatherCategory.fog,
      ]) {
        expect(weatherCategoryIsRain(category), isFalse);
        expect(weatherCategoryIsSnow(category), isFalse);
      }
    });
  });

  group('combineDateAndTime', () {
    final date = DateTime(2026, 9, 18);

    test('把 HH:mm 拼到日期上', () {
      expect(combineDateAndTime(date, '08:05'), DateTime(2026, 9, 18, 8, 5));
    });

    test('容忍不带前导零的写法', () {
      expect(combineDateAndTime(date, '8:5'), DateTime(2026, 9, 18, 8, 5));
      expect(combineDateAndTime(date, ' 08:05 '), DateTime(2026, 9, 18, 8, 5));
    });

    test('越界与畸形输入返回 null', () {
      for (final raw in ['24:00', '08:60', '-1:00', 'abc', '', '08', '08:']) {
        expect(combineDateAndTime(date, raw), isNull, reason: raw);
      }
    });
  });

  group('区间选取边界', () {
    test('08:00–09:35 命中 09:00 与 10:00 两桶', () {
      final summary = _summarizeOnDay(
        _fullDay(),
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.hourCount, 2);
    });

    test('13:00–14:35 命中 14:00 与 15:00 两桶', () {
      final summary = _summarizeOnDay(
        _fullDay(),
        startHour: 13,
        endHour: 14,
        endMinute: 35,
      );
      expect(summary!.hourCount, 2);
    });

    test('08:00–08:45 只命中 09:00 一桶', () {
      final summary = _summarizeOnDay(
        _fullDay(),
        startHour: 8,
        endHour: 8,
        endMinute: 45,
      );
      expect(summary!.hourCount, 1);
    });

    test('08:10–11:00 命中 09:00 / 10:00 / 11:00 三桶', () {
      final summary = _summarizeOnDay(
        _fullDay(),
        startHour: 8,
        startMinute: 10,
        endHour: 11,
      );
      expect(summary!.hourCount, 3);
    });

    test('起点所在整点桶被排除：08:00 的课不吃 07:00–08:00 那一桶', () {
      // 08:00 那一桶的温度给到 100，其余全是 5；只选 09:00 一桶 → 5 度。
      final points = _fullDay(
        temperatureFor: (hour) => hour == 8 ? 100 : 5,
      );
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 8,
        endMinute: 45,
      );
      expect(summary!.temperatureC, 5);
    });

    test('终点后一桶被带上：09:35 的课吃到 09:00–10:00 那一桶', () {
      // 11:00 那一桶给到 100，09:00 与 10:00 为 0；带上了就对，漏了会算出偏小的值。
      final points = _fullDay(
        temperatureFor: (hour) => hour == 11 ? 100 : 0,
      );
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.hourCount, 2);
      expect(summary.temperatureC, 0);
    });

    test('跨整点的长课（08:00–09:00）只吃到 09:00 一桶', () {
      final summary = _summarizeOnDay(
        _fullDay(),
        startHour: 8,
        endHour: 9,
      );
      expect(summary!.hourCount, 1);
    });
  });

  group('聚合', () {
    test('单行时温度与概率取该行原值', () {
      final points = [
        _point(hour: 9, temperature: 23.4, probability: 60, code: 61),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 8,
        endMinute: 45,
      );
      expect(summary!.temperatureC, 23);
      expect(summary.precipitationProbability, 60);
      expect(summary.hourCount, 1);
    });

    test('温度取多行均值并四舍五入，概率取最大值', () {
      final points = [
        _point(hour: 9, temperature: 20, probability: 10, code: 3),
        _point(hour: 10, temperature: 31, probability: 55, code: 3),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.temperatureC, 26); // (20 + 31) / 2 = 25.5 → 26
      expect(summary.precipitationProbability, 55);
    });

    test('缺失的温度被跳过，不按 0 参与均值', () {
      final points = [
        _point(hour: 9, code: 3),
        _point(hour: 10, temperature: 30, code: 3),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.temperatureC, 30);
    });

    test('概率 29 不显示、30 显示', () {
      CourseWeatherSummary summaryAt(int value) {
        return _summarizeOnDay(
          [_point(hour: 9, temperature: 20, probability: value, code: 61)],
          startHour: 8,
          endHour: 8,
          endMinute: 45,
        )!;
      }

      final below = summaryAt(29);
      expect(below.precipitationProbability, 29);
      expect(below.showPrecipitationProbability, isFalse);

      final at = summaryAt(30);
      expect(at.precipitationProbability, 30);
      expect(at.showPrecipitationProbability, isTrue);
    });

    test('降水概率显示阈值可调', () {
      final custom = _summarizeOnDay(
        [_point(hour: 9, temperature: 20, probability: 29, code: 61)],
        startHour: 8,
        endHour: 8,
        endMinute: 45,
        probabilityThreshold: 0,
      )!;
      expect(custom.showPrecipitationProbability, isTrue);
    });

    test('概率全缺报时现象与温度照常给出，只是不显示百分比', () {
      final points = [
        _point(hour: 9, temperature: 20, code: 61),
        _point(hour: 10, temperature: 22, code: 61),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.precipitationProbability, isNull);
      expect(summary.showPrecipitationProbability, isFalse);
      expect(summary.category, WeatherCategory.lightRain);
      expect(summary.temperatureC, 21);
    });
  });

  group('代表现象', () {
    test('雪雨同存时报雪', () {
      final points = [
        _point(hour: 9, temperature: 1, precipitation: 2, code: 63),
        _point(hour: 10, temperature: 0, snowfall: 1, code: 73),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.category, WeatherCategory.snow);
      expect(summary.representativeWmoCode, 73);
    });

    test('有降雪量但现象码全是雨时兜底报小雪', () {
      final points = [
        _point(hour: 9, temperature: 1, precipitation: 2, code: 63),
        _point(hour: 10, temperature: 0, snowfall: 0.5, code: 63),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.category, WeatherCategory.lightSnow);
      expect(summary.representativeWmoCode, isNull);
    });

    test('有降水量但现象码全是晴时兜底报小雨', () {
      final points = [
        _point(hour: 9, temperature: 20, precipitation: 0.5, code: 0),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 8,
        endMinute: 45,
      );
      expect(summary!.category, WeatherCategory.lightRain);
      expect(summary.representativeWmoCode, isNull);
    });

    test('干燥时取严重度最高的现象码', () {
      final points = [
        _point(hour: 9, temperature: 20, code: 0),
        _point(hour: 10, temperature: 20, code: 2),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.category, WeatherCategory.partlyCloudy);
      expect(summary.representativeWmoCode, 2);
    });

    test('雨家族内取最严重的一档', () {
      final points = [
        _point(hour: 9, temperature: 20, code: 61),
        _point(hour: 10, temperature: 20, code: 65),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 9,
        endMinute: 35,
      );
      expect(summary!.category, WeatherCategory.heavyRain);
      expect(summary.representativeWmoCode, 65);
    });

    test('冻雨不触发雪分支', () {
      final points = [
        _point(hour: 9, temperature: -2, precipitation: 1, code: 66),
      ];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 8,
        endMinute: 45,
      );
      expect(summary!.category, WeatherCategory.freezingRain);
    });

    test('现象码全缺报时兜底为晴', () {
      final points = [_point(hour: 9, temperature: 20)];
      final summary = _summarizeOnDay(
        points,
        startHour: 8,
        endHour: 8,
        endMinute: 45,
      );
      expect(summary!.category, WeatherCategory.clear);
      expect(summary.representativeWmoCode, isNull);
    });
  });

  group('空结果兜底', () {
    test('end 不晚于 start 时返回 null', () {
      expect(
        _summarizeOnDay(_fullDay(), startHour: 9, endHour: 9),
        isNull,
      );
      expect(
        _summarizeOnDay(_fullDay(), startHour: 10, endHour: 9),
        isNull,
      );
    });

    test('预报不覆盖该日时返回 null', () {
      final previousDay = [
        for (var hour = 0; hour < 24; hour++)
          _point(hour: hour, day: 17, temperature: 20, code: 0),
      ];
      expect(
        _summarizeOnDay(
          previousDay,
          startHour: 8,
          endHour: 9,
          endMinute: 35,
        ),
        isNull,
      );
    });

    test('预报为空时返回 null', () {
      expect(
        _summarizeOnDay(const [], startHour: 8, endHour: 9, endMinute: 35),
        isNull,
      );
    });

    test('时段内温度全缺报时返回 null，不显示半条信息', () {
      final points = [
        _point(hour: 9, probability: 60, code: 61),
        _point(hour: 10, probability: 60, code: 61),
      ];
      expect(
        _summarizeOnDay(points, startHour: 8, endHour: 9, endMinute: 35),
        isNull,
      );
    });
  });
}
