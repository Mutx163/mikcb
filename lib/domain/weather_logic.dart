import '../models/weather_forecast.dart';

/// 天气现象分类（由 WMO 码归并而来）。
///
/// 粒度取「图标能区分 + 用户需要知道差别」为准：小雨/中雨/大雨分开（要不要带伞
/// 的决策强度不同），毛毛雨与阵雨单列（阵雨是"下一阵就停"）。
/// 纯 Dart，不含任何展示层依赖——中文文案在 l10n，图标在 widget 层。
enum WeatherCategory {
  clear,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  freezingDrizzle,
  lightRain,
  rain,
  heavyRain,
  freezingRain,
  rainShowers,
  heavyRainShowers,
  lightSnow,
  snow,
  heavySnow,
  snowGrains,
  snowShowers,
  thunderstorm,
  thunderstormHail,
}

/// 天气现象严重度序（数值越大越恶劣）。
///
/// 一个时间区间内常有多个现象码（例如 08:00 阴、09:00 小雨），必须选一个代表；
/// 取"最恶劣"最符合用户对这一小时的预期。同一个序表既用于筛选候选，也用于
/// 在候选内定最终值，避免两处排序口径不一致。
int weatherCategorySeverity(WeatherCategory category) => switch (category) {
  WeatherCategory.clear => 0,
  WeatherCategory.mainlyClear => 1,
  WeatherCategory.partlyCloudy => 2,
  WeatherCategory.overcast => 3,
  WeatherCategory.fog => 4,
  WeatherCategory.drizzle => 5,
  WeatherCategory.freezingDrizzle => 6,
  WeatherCategory.lightRain => 7,
  WeatherCategory.rain => 8,
  WeatherCategory.heavyRain => 9,
  WeatherCategory.freezingRain => 10,
  WeatherCategory.rainShowers => 11,
  WeatherCategory.heavyRainShowers => 12,
  WeatherCategory.lightSnow => 13,
  WeatherCategory.snow => 14,
  WeatherCategory.heavySnow => 15,
  WeatherCategory.snowGrains => 16,
  WeatherCategory.snowShowers => 17,
  WeatherCategory.thunderstorm => 18,
  WeatherCategory.thunderstormHail => 19,
};

/// WMO 天气现象码 → 分类。
///
/// 未知码归到 [WeatherCategory.clear]：这是 API 未来新增码时的兜底，宁可少报
/// 一个不认识的恶劣天气，也不要凭猜测显示"暴雨"。
WeatherCategory weatherCategoryFromWmo(int code) => switch (code) {
  0 => WeatherCategory.clear,
  1 => WeatherCategory.mainlyClear,
  2 => WeatherCategory.partlyCloudy,
  3 => WeatherCategory.overcast,
  45 || 48 => WeatherCategory.fog,
  51 || 53 || 55 => WeatherCategory.drizzle,
  56 || 57 => WeatherCategory.freezingDrizzle,
  61 => WeatherCategory.lightRain,
  63 => WeatherCategory.rain,
  65 => WeatherCategory.heavyRain,
  66 || 67 => WeatherCategory.freezingRain,
  80 || 81 => WeatherCategory.rainShowers,
  82 => WeatherCategory.heavyRainShowers,
  71 => WeatherCategory.lightSnow,
  73 => WeatherCategory.snow,
  75 => WeatherCategory.heavySnow,
  77 => WeatherCategory.snowGrains,
  85 || 86 => WeatherCategory.snowShowers,
  95 => WeatherCategory.thunderstorm,
  96 || 99 => WeatherCategory.thunderstormHail,
  _ => WeatherCategory.clear,
};

/// 是否属于雪家族。
///
/// 冻雨（[WeatherCategory.freezingRain] / [WeatherCategory.freezingDrizzle]）
/// **不算**雪：它是雨落地结冰，用户要防的是滑，不是积雪。
bool weatherCategoryIsSnow(WeatherCategory category) => switch (category) {
  WeatherCategory.lightSnow ||
  WeatherCategory.snow ||
  WeatherCategory.heavySnow ||
  WeatherCategory.snowGrains ||
  WeatherCategory.snowShowers => true,
  _ => false,
};

/// 是否属于雨家族（含冻雨、毛毛雨、阵雨）。
bool weatherCategoryIsRain(WeatherCategory category) => switch (category) {
  WeatherCategory.drizzle ||
  WeatherCategory.freezingDrizzle ||
  WeatherCategory.lightRain ||
  WeatherCategory.rain ||
  WeatherCategory.heavyRain ||
  WeatherCategory.freezingRain ||
  WeatherCategory.rainShowers ||
  WeatherCategory.heavyRainShowers => true,
  _ => false,
};

/// 默认的降水概率显示阈值（百分比）。
///
/// 低于该值在业务上等于"基本不下"，印出来是噪音——「晴 · 23° · 0%」尤其蠢。
const int defaultProbabilityVisibilityThreshold = 30;

/// 把 `HH:mm` 拼到 [date] 的日期上；格式非法返回 null。
DateTime? combineDateAndTime(DateTime date, String time) {
  final parts = time.trim().split(':');
  if (parts.length < 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// 一节课时段内的天气摘要。
class CourseWeatherSummary {
  const CourseWeatherSummary({
    required this.category,
    required this.temperatureC,
    required this.hourCount,
    required this.precipitationProbability,
    required this.showPrecipitationProbability,
    required this.representativeWmoCode,
  });

  /// 时段内的代表天气现象。
  final WeatherCategory category;

  /// 时段内的代表温度（摄氏度，四舍五入到整数）。
  final int temperatureC;

  /// 参与聚合的小时数（诊断与测试用，UI 不用）。
  final int hourCount;

  /// 时段内最高的降水概率；全缺报时为 null。
  final int? precipitationProbability;

  /// 是否值得把 [precipitationProbability] 显示给用户。
  final bool showPrecipitationProbability;

  /// 选出 [category] 时命中的 WMO 码（诊断与测试用，UI 不用）。
  final int? representativeWmoCode;
}

/// 把一节课的时间区间聚合成一条天气摘要。
///
/// 覆盖规则：取所有**与 `[start, end]` 有交集的小时桶**，即
/// `t > start && t < end + 1h`。
///
/// - 左开 `t > start`：08:00 开始的课，`t = 08:00` 那条桶覆盖的是 07:00~08:00，
///   完全在课前，必须排除。
/// - 右开 `t < end + 1h`：09:35 结束的课，09:00~09:35 这段落在 `t = 10:00` 的
///   桶里（降水是前 1 小时累计），必须带上。
///
/// 由此得到一个很有用的性质：只要该日有预报数据，命中集合必非空（任意正长度
/// 区间必落入某个小时桶）。所以返回 null 只意味着"这一天不在预报窗口内"，
/// 不是算法边界问题。
///
/// 无可用数据时返回 null，调用方据此不渲染。
CourseWeatherSummary? summarizeCourseWeather({
  required WeatherForecast forecast,
  required DateTime start,
  required DateTime end,
  int probabilityVisibilityThreshold = defaultProbabilityVisibilityThreshold,
}) {
  if (!end.isAfter(start)) {
    return null;
  }

  final windowEnd = end.add(const Duration(hours: 1));
  final firstIndex = _firstIndexAfter(forecast.hourly, start);
  final selected = <HourlyWeatherPoint>[];
  for (var i = firstIndex; i < forecast.hourly.length; i++) {
    final point = forecast.hourly[i];
    if (!point.time.isBefore(windowEnd)) {
      break;
    }
    selected.add(point);
  }
  if (selected.isEmpty) {
    return null;
  }

  var temperatureSum = 0.0;
  var temperatureCount = 0;
  for (final point in selected) {
    final value = point.temperatureC;
    if (value == null || !value.isFinite) {
      continue;
    }
    temperatureSum += value;
    temperatureCount++;
  }
  if (temperatureCount == 0) {
    // 温度是这一行的主语；没有温度就不显示整行。
    return null;
  }

  int? probability;
  var precipitationMm = 0.0;
  var snowfallCm = 0.0;
  final observed = <({WeatherCategory category, int code})>[];
  for (final point in selected) {
    final pointProbability = point.precipitationProbability;
    if (pointProbability != null) {
      probability = probability == null
          ? pointProbability
          : (pointProbability > probability ? pointProbability : probability);
    }
    final pointPrecipitation = point.precipitationMm;
    if (pointPrecipitation != null &&
        pointPrecipitation.isFinite &&
        pointPrecipitation > precipitationMm) {
      precipitationMm = pointPrecipitation;
    }
    final pointSnowfall = point.snowfallCm;
    if (pointSnowfall != null &&
        pointSnowfall.isFinite &&
        pointSnowfall > snowfallCm) {
      snowfallCm = pointSnowfall;
    }
    final code = point.weatherCode;
    if (code != null) {
      observed.add((category: weatherCategoryFromWmo(code), code: code));
    }
  }
  if (probability != null) {
    probability = probability.clamp(0, 100).toInt();
  }

  final snowiest = _mostSevere(observed, weatherCategoryIsSnow);
  final rainiest = _mostSevere(observed, weatherCategoryIsRain);

  // 雪优先于雨：区间内任一小时下雪就报雪，哪怕同时也下雨。
  final WeatherCategory category;
  if (snowfallCm > 0 || snowiest != null) {
    // 有降雪量但现象码全是雨（数据自相矛盾）时兜底到最轻的雪。
    category = snowiest?.category ?? WeatherCategory.lightSnow;
  } else if (precipitationMm > 0.1 || rainiest != null) {
    category = rainiest?.category ?? WeatherCategory.lightRain;
  } else {
    category = _mostSevere(observed, (_) => true)?.category ??
        WeatherCategory.clear;
  }

  int? representativeCode;
  for (final item in observed) {
    if (item.category == category) {
      representativeCode = item.code;
      break;
    }
  }

  return CourseWeatherSummary(
    category: category,
    temperatureC: (temperatureSum / temperatureCount).round(),
    hourCount: selected.length,
    precipitationProbability: probability,
    showPrecipitationProbability:
        probability != null && probability >= probabilityVisibilityThreshold,
    representativeWmoCode: representativeCode,
  );
}

/// 第一个 `time > [threshold]` 的下标；全部不满足时返回 `length`。
///
/// 线性扫描在 16 天窗口（384 点）下也不算慢，但这个函数每帧每张卡都会被调用，
/// 二分让代价与预报长度无关。
int _firstIndexAfter(List<HourlyWeatherPoint> points, DateTime threshold) {
  var low = 0;
  var high = points.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (points[mid].time.isAfter(threshold)) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }
  return low;
}

/// 在 [items] 中挑出满足 [predicate] 且严重度最高的一个。
({WeatherCategory category, int code})? _mostSevere(
  List<({WeatherCategory category, int code})> items,
  bool Function(WeatherCategory category) predicate,
) {
  ({WeatherCategory category, int code})? best;
  var bestSeverity = -1;
  for (final item in items) {
    if (!predicate(item.category)) {
      continue;
    }
    final severity = weatherCategorySeverity(item.category);
    if (severity > bestSeverity) {
      best = item;
      bestSeverity = severity;
    }
  }
  return best;
}
