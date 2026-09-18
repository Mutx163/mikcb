import 'dart:convert';

/// 一个地点（天气数据的地理坐标载体）。
///
/// 只保留「选城市」需要的字段：显示名、行政区、国家、经纬度、时区。
/// [admin1] 是区分同名地点的唯一依据——搜「杭州」会同时返回浙江杭州与
/// 四川甘孜一个同名村，列表必须把行政区显示出来。
///
/// 两个来源共用本模型：手动搜索（Open-Meteo 地理编码，无 [district]）与
/// 定位反查（BigDataCloud，有 [district]）。
class WeatherLocation {
  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
    this.district,
    this.timezone,
  });

  final String name;

  /// 一级行政区（省 / 州）。
  final String? admin1;

  final String? country;

  /// 区 / 县一级。只有定位反查会填；手动搜索来的地点为 null。
  final String? district;

  final double latitude;
  final double longitude;

  /// IANA 时区名，如 `Asia/Shanghai`；缺失时按设备时区处理。
  final String? timezone;

  /// 经纬度差小于该值即视为同一地点（换城市判定用）。
  static const double samePlaceTolerance = 1e-4;

  /// 结果列表的副标题：行政区 + 国家，跳过空值与与主标题重复的值。
  String get regionLabel {
    final parts = <String>[];
    for (final value in [admin1, country]) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty || trimmed == name || parts.contains(trimmed)) {
        continue;
      }
      parts.add(trimmed);
    }
    return parts.join(' · ');
  }

  /// 设置页那一行尾随显示的紧凑地名。
  ///
  /// 有 [district] 时给出「市 · 区」（例如「杭州市 · 拱墅区」）——定位场景下用户
  /// 要的就是这个精度；尾随区域窄，省市区全串会被截断。手动搜索来的地点没有
  /// district，就只显示市名，不会出现空段或多余的间隔点。
  String get displayName {
    final trimmedDistrict = district?.trim() ?? '';
    if (trimmedDistrict.isEmpty || trimmedDistrict == name) {
      return name;
    }
    return '$name · $trimmedDistrict';
  }

  /// 是否与 [other] 指向同一地点。
  ///
  /// 只比经纬度，不比名字：同一地点在不同语言下的名字不同。
  bool isSamePlaceAs(WeatherLocation other) {
    return (latitude - other.latitude).abs() < samePlaceTolerance &&
        (longitude - other.longitude).abs() < samePlaceTolerance;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'admin1': admin1,
    'country': country,
    'district': district,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
  };

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('weather location: missing name');
    }
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('weather location: missing coordinates');
    }
    final admin1 = json['admin1'];
    final country = json['country'];
    // district 是后加的字段：老数据里没有这个键，读到 null 即可，不需要迁移。
    final district = json['district'];
    final timezone = json['timezone'];
    return WeatherLocation(
      name: name,
      admin1: admin1 is String ? admin1 : null,
      country: country is String ? country : null,
      district: district is String ? district : null,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone is String ? timezone : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  /// 解析持久化的地点；数据损坏时返回 null（不抛，调用方按「未设置城市」处理）。
  static WeatherLocation? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return WeatherLocation.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

/// 预报序列里的一个逐小时点。
///
/// 字段语义（Open-Meteo 口径，聚合算法依赖它，勿改）：
/// - [time] 为 `T` 时，[temperatureC] 与 [weatherCode] 是 **T 时刻的瞬时值**；
/// - [precipitationMm]、[snowfallCm]、[precipitationProbability] 是
///   **`(T-1h, T]` 区间的累计量 / 概率**。
///
/// 任何字段都可能为 null：某个变量在某个时刻缺报是正常的，聚合时逐字段跳过。
class HourlyWeatherPoint {
  const HourlyWeatherPoint({
    required this.time,
    this.temperatureC,
    this.precipitationProbability,
    this.precipitationMm,
    this.snowfallCm,
    this.weatherCode,
  });

  /// 墙钟时刻（不带时区偏移）。与课程时间同为墙钟语义，直接比较。
  final DateTime time;

  final double? temperatureC;

  /// 降水概率，0~100。
  final int? precipitationProbability;

  /// 降水量（雨 + 阵雨 + 雪的水当量），mm。
  final double? precipitationMm;

  /// 降雪量，cm。
  final double? snowfallCm;

  /// WMO 天气现象码。
  final int? weatherCode;
}

/// 一个地点的多日逐小时预报。
///
/// [hourly] 保证按 [HourlyWeatherPoint.time] 升序——聚合算法依赖有序性做二分。
class WeatherForecast {
  WeatherForecast({
    required this.latitude,
    required this.longitude,
    required this.fetchedAt,
    required List<HourlyWeatherPoint> hourly,
  }) : hourly = _sortedCopy(hourly);

  /// 拷贝并按时间升序排序。
  ///
  /// 刻意不写成 `[...hourly]..sort(...)`：级联调用会让列表字面量推断不出元素
  /// 类型，比较闭包的参数退化成 dynamic，`--fatal-infos` 下直接判错。
  static List<HourlyWeatherPoint> _sortedCopy(
    List<HourlyWeatherPoint> points,
  ) {
    final copy = List<HourlyWeatherPoint>.of(points);
    copy.sort((a, b) => a.time.compareTo(b.time));
    return List<HourlyWeatherPoint>.unmodifiable(copy);
  }

  final double latitude;
  final double longitude;

  /// 抓取时刻（本地墙钟）。
  final DateTime fetchedAt;

  final List<HourlyWeatherPoint> hourly;

  /// 窗口起始小时。
  DateTime? get windowStart => hourly.isEmpty ? null : hourly.first.time;

  /// 窗口结束小时。
  DateTime? get windowEnd => hourly.isEmpty ? null : hourly.last.time;

  /// 预报是否覆盖 [time]（含端点）。
  bool covers(DateTime time) {
    if (hourly.isEmpty) {
      return false;
    }
    return !time.isBefore(hourly.first.time) && !time.isAfter(hourly.last.time);
  }

  /// 到 [now] 为止，这份预报的窗口是否已经走完（跨天后需要重拉）。
  bool hasLapsedAt(DateTime now) {
    final end = windowEnd;
    return end == null || now.isAfter(end);
  }

  /// 是否是 [location] 的预报。
  bool matchesLocation(WeatherLocation location) {
    return (latitude - location.latitude).abs() <
            WeatherLocation.samePlaceTolerance &&
        (longitude - location.longitude).abs() <
            WeatherLocation.samePlaceTolerance;
  }

  /// 列式序列化：逐小时字段拆成 6 个平行数组，体积约为逐点对象的 1/3。
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'fetchedAt': fetchedAt.millisecondsSinceEpoch,
    'time': [for (final point in hourly) _wallClockIso(point.time)],
    'temperature_2m': [for (final point in hourly) point.temperatureC],
    'precipitation_probability': [
      for (final point in hourly) point.precipitationProbability,
    ],
    'precipitation': [for (final point in hourly) point.precipitationMm],
    'snowfall': [for (final point in hourly) point.snowfallCm],
    'weather_code': [for (final point in hourly) point.weatherCode],
  };

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final fetchedAtMs = (json['fetchedAt'] as num?)?.toInt();
    if (latitude == null || longitude == null || fetchedAtMs == null) {
      throw const FormatException('weather forecast: missing header');
    }
    return _fromColumns(
      latitude: latitude,
      longitude: longitude,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
      columns: json,
    );
  }

  /// 解析 Open-Meteo `/v1/forecast` 的原始响应。
  ///
  /// 厂商把 6 个平行数组放在 `hourly` 子对象里，且不返回 `fetchedAt`（由调用方
  /// 在请求成功那一刻传入）。放在模型里而不是服务里，是为了让「列式数组怎么读」
  /// 只有一份实现——服务只管发请求与取字段。
  factory WeatherForecast.fromOpenMeteoResponse(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
  }) {
    final hourly = json['hourly'];
    if (hourly is! Map) {
      throw const FormatException('weather forecast: missing hourly block');
    }
    // 经纬度用响应里回填的格点中心，而不是请求坐标——后续判断「缓存是不是这个
    // 城市的」时才不会因为格点偏移误判为换城。
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('weather forecast: missing coordinates');
    }
    return _fromColumns(
      latitude: latitude,
      longitude: longitude,
      fetchedAt: fetchedAt,
      columns: Map<String, dynamic>.from(hourly),
    );
  }

  static WeatherForecast _fromColumns({
    required double latitude,
    required double longitude,
    required DateTime fetchedAt,
    required Map<String, dynamic> columns,
  }) {
    final times = _column(columns['time']);
    final temperatures = _column(columns['temperature_2m']);
    final probabilities = _column(columns['precipitation_probability']);
    final precipitation = _column(columns['precipitation']);
    final snowfall = _column(columns['snowfall']);
    final codes = _column(columns['weather_code']);

    final hourly = <HourlyWeatherPoint>[];
    for (var i = 0; i < times.length; i++) {
      final rawTime = times[i];
      if (rawTime is! String) {
        continue;
      }
      final time = DateTime.tryParse(rawTime);
      if (time == null) {
        continue;
      }
      hourly.add(
        HourlyWeatherPoint(
          time: time,
          temperatureC: _doubleAt(temperatures, i),
          precipitationProbability: _intAt(probabilities, i),
          precipitationMm: _doubleAt(precipitation, i),
          snowfallCm: _doubleAt(snowfall, i),
          weatherCode: _intAt(codes, i),
        ),
      );
    }

    return WeatherForecast(
      latitude: latitude,
      longitude: longitude,
      fetchedAt: fetchedAt,
      hourly: hourly,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  /// 解析缓存的预报；数据损坏或没有任何小时点时返回 null。
  static WeatherForecast? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final forecast = WeatherForecast.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return forecast.hourly.isEmpty ? null : forecast;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _column(Object? raw) =>
      raw is List ? raw : const <dynamic>[];

  static double? _doubleAt(List<dynamic> column, int index) {
    if (index >= column.length) {
      return null;
    }
    final value = column[index];
    return value is num ? value.toDouble() : null;
  }

  static int? _intAt(List<dynamic> column, int index) {
    if (index >= column.length) {
      return null;
    }
    final value = column[index];
    return value is num ? value.round() : null;
  }

  /// 不带偏移量的墙钟 ISO 串。
  ///
  /// 不能用 `toIso8601String()`：本地时间会带上 `.000` 尾巴，UTC 时间还会加
  /// `Z`；显式拼装能保证「存进去什么墙钟，读出来就是什么墙钟」。
  static String _wallClockIso(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}'
        'T${two(time.hour)}:${two(time.minute)}';
  }
}
