import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/utils/coordinate_precision.dart';

/// 坐标精度与「是不是同一个城市」的判定（2026-10-20 回归钉）。
///
/// ## 背景：一个真的踩到的 bug
///
/// 隐私要求「坐标只以约 1 公里精度（2 位小数）出网与落盘」，于是预报请求
/// 与缓存都按取整坐标走。但**内存里的位置**当时没统一：升级用户从旧版本
/// 读回的是 5 位小数（`30.29365`），而缓存的预报是取整坐标（`30.29`）。
///
/// `samePlaceTolerance` 是 `1e-4`，取整误差最大 `0.005` —— **差 50 倍**。
/// 结果：`matchesLocation` 永远判否 →
///
/// - 冷启动每次都把缓存预报当「别的城市」丢掉，用户白等一次网络；
/// - 日视图每张卡重建都会 `_shouldRefresh()` 判真，触发重复拉取。
///
/// 修法是**在比较处统一精度**（而不是改存储）：两边都取整后再比，于是
/// 「全精度 vs 全精度」「全精度 vs 取整」「取整 vs 取整」三种组合都成立。
///
/// 下面的用例就是那个 bug 的钉子：把比较改回裸值（不取整），前两条会红。
void main() {
  const fullPrecision = WeatherLocation(
    name: '杭州',
    admin1: '浙江',
    latitude: 30.29365,
    longitude: 120.16142,
    timezone: 'Asia/Shanghai',
  );

  const coarsened = WeatherLocation(
    name: '杭州',
    admin1: '浙江',
    latitude: 30.29,
    longitude: 120.16,
    timezone: 'Asia/Shanghai',
  );

  const anotherCity = WeatherLocation(
    name: '成都',
    admin1: '四川',
    latitude: 30.5728,
    longitude: 104.0668,
    timezone: 'Asia/Shanghai',
  );

  group('同一地点的判定要跨精度成立', () {
    test('全精度 vs 取整（升级用户的旧位置 vs 新缓存）算同一地点', () {
      expect(
        fullPrecision.isSamePlaceAs(coarsened),
        isTrue,
        reason: '取整误差 0.00365 远大于 1e-4 容差；不取整就会判异地',
      );
      expect(
        coarsened.isSamePlaceAs(fullPrecision),
        isTrue,
        reason: '方向也要成立，谁在左谁在右不该影响结论',
      );
    });

    test('全精度 vs 全精度（两侧都未取整）仍算同一地点', () {
      expect(fullPrecision.isSamePlaceAs(fullPrecision), isTrue);
    });

    test('真的换城市仍判异地——修复不能把不同城市误判成同城', () {
      expect(fullPrecision.isSamePlaceAs(anotherCity), isFalse);
      expect(coarsened.isSamePlaceAs(anotherCity), isFalse);
    });

    test('预报归属判定同样跨精度', () {
      final forecast = WeatherForecast(
        latitude: coarsenCoordinate(fullPrecision.latitude),
        longitude: coarsenCoordinate(fullPrecision.longitude),
        fetchedAt: DateTime(2026, 10, 20, 8),
        hourly: const [],
      );
      expect(
        forecast.matchesLocation(fullPrecision),
        isTrue,
        reason: '缓存按取整坐标存、内存位置全精度时，必须仍认作同城',
      );
      expect(forecast.matchesLocation(anotherCity), isFalse);
    });
  });

  group('coarsened() 的语义', () {
    test('取整到 2 位小数，其余字段原样保留', () {
      final result = fullPrecision.coarsened();
      expect(result.latitude, 30.29);
      expect(result.longitude, 120.16);
      expect(result.name, fullPrecision.name);
      expect(result.admin1, fullPrecision.admin1);
      expect(result.timezone, fullPrecision.timezone);
    });

    test('幂等：已经取整过的再取整不变', () {
      final once = fullPrecision.coarsened();
      final twice = once.coarsened();
      expect(twice.latitude, once.latitude);
      expect(twice.longitude, once.longitude);
    });
  });
}
