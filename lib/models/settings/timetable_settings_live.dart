// 从 timetable_settings.dart 拆出的直播展示与节次模型（2026-10-19，行为零变化）。
// 只依赖 timetable_settings_enums.dart，不反向依赖宿主。

import 'timetable_settings_enums.dart';

/// 超级岛/焦点通知展开态里可逐字段控制显示与顺序的详细信息字段。
///
/// 值的字符串（value）与原生 `LiveUpdateService` 构造展开文本时使用的 key
/// 一一对应：stage / shortName / progress / status / time / location /
/// teacher / next / note。
enum LiveExpandedDetailField {
  stage('stage'),
  shortName('shortName'),
  progress('progress'),
  status('status'),
  time('time'),
  location('location'),
  teacher('teacher'),
  nextCourse('next'),
  note('note');

  const LiveExpandedDetailField(this.value);

  final String value;
}

/// 反序列化展开详情字段列表。
///
/// - 非 List（未设置/老数据）→ null：代表「全部显示」，向后兼容。
/// - List（含空列表）→ 对应的字段顺序列表：空列表代表「全部隐藏」。
List<LiveExpandedDetailField>? parseLiveExpandedDetailFields(dynamic raw) {
  if (raw is! List) return null;
  final result = <LiveExpandedDetailField>[];
  for (final item in raw) {
    if (item is! String) continue;
    for (final field in LiveExpandedDetailField.values) {
      if (field.value == item) {
        result.add(field);
        break;
      }
    }
  }
  return result;
}

/// 转储设置列表为原始字符串列表（null 保持 null）。
List<String>? encodeLiveExpandedDetailFields(
  List<LiveExpandedDetailField>? fields,
) => fields == null ? null : [for (final f in fields) f.value];

class LiveDisplaySettings {
  final bool showCourseName;
  final bool showLocation;
  final bool showCountdown;
  final LiveCountdownTextStyle countdownTextStyle;
  final bool showStageText;
  final bool useShortName;
  final bool hidePrefixText;
  final LiveDuringClassTimeDisplayMode duringClassTimeDisplayMode;
  final bool enableMiuiIslandLabelImage;
  final MiuiIslandLabelStyle miuiIslandLabelStyle;
  final MiuiIslandLabelContent miuiIslandLabelContent;
  final String miuiIslandLabelFontColor;
  final MiuiIslandLabelFontWeight miuiIslandLabelFontWeight;
  final MiuiIslandLabelRenderQuality miuiIslandLabelRenderQuality;
  final double miuiIslandLabelFontSize;
  final double miuiIslandLabelOffsetX;
  final double miuiIslandLabelOffsetY;
  final String? miuiIslandLabelLogoPath;
  final double miuiIslandLabelLogoCornerRadius;
  final MiuiIslandExpandedIconMode miuiIslandExpandedIconMode;
  final String? miuiIslandExpandedIconPath;

  /// 展开态详情字段（可见 + 顺序）；null = 全部显示（默认/老数据）。
  final List<LiveExpandedDetailField>? expandedDetailFields;

  const LiveDisplaySettings({
    required this.showCourseName,
    required this.showLocation,
    required this.showCountdown,
    required this.countdownTextStyle,
    required this.showStageText,
    required this.useShortName,
    required this.hidePrefixText,
    required this.duringClassTimeDisplayMode,
    required this.enableMiuiIslandLabelImage,
    required this.miuiIslandLabelStyle,
    required this.miuiIslandLabelContent,
    required this.miuiIslandLabelFontColor,
    required this.miuiIslandLabelFontWeight,
    required this.miuiIslandLabelRenderQuality,
    required this.miuiIslandLabelFontSize,
    required this.miuiIslandLabelOffsetX,
    required this.miuiIslandLabelOffsetY,
    required this.miuiIslandLabelLogoPath,
    required this.miuiIslandLabelLogoCornerRadius,
    required this.miuiIslandExpandedIconMode,
    required this.miuiIslandExpandedIconPath,
    this.expandedDetailFields,
  });

  LiveDisplaySettings copyWith({
    bool? showCourseName,
    bool? showLocation,
    bool? showCountdown,
    LiveCountdownTextStyle? countdownTextStyle,
    bool? showStageText,
    bool? useShortName,
    bool? hidePrefixText,
    LiveDuringClassTimeDisplayMode? duringClassTimeDisplayMode,
    bool? enableMiuiIslandLabelImage,
    MiuiIslandLabelStyle? miuiIslandLabelStyle,
    MiuiIslandLabelContent? miuiIslandLabelContent,
    String? miuiIslandLabelFontColor,
    MiuiIslandLabelFontWeight? miuiIslandLabelFontWeight,
    MiuiIslandLabelRenderQuality? miuiIslandLabelRenderQuality,
    double? miuiIslandLabelFontSize,
    double? miuiIslandLabelOffsetX,
    double? miuiIslandLabelOffsetY,
    String? miuiIslandLabelLogoPath,
    bool clearMiuiIslandLabelLogoPath = false,
    double? miuiIslandLabelLogoCornerRadius,
    MiuiIslandExpandedIconMode? miuiIslandExpandedIconMode,
    String? miuiIslandExpandedIconPath,
    bool clearMiuiIslandExpandedIconPath = false,
    List<LiveExpandedDetailField>? expandedDetailFields,
    bool clearExpandedDetailFields = false,
  }) {
    return LiveDisplaySettings(
      showCourseName: showCourseName ?? this.showCourseName,
      showLocation: showLocation ?? this.showLocation,
      showCountdown: showCountdown ?? this.showCountdown,
      countdownTextStyle: countdownTextStyle ?? this.countdownTextStyle,
      showStageText: showStageText ?? this.showStageText,
      useShortName: useShortName ?? this.useShortName,
      hidePrefixText: hidePrefixText ?? this.hidePrefixText,
      duringClassTimeDisplayMode:
          duringClassTimeDisplayMode ?? this.duringClassTimeDisplayMode,
      enableMiuiIslandLabelImage:
          enableMiuiIslandLabelImage ?? this.enableMiuiIslandLabelImage,
      miuiIslandLabelStyle: miuiIslandLabelStyle ?? this.miuiIslandLabelStyle,
      miuiIslandLabelContent:
          miuiIslandLabelContent ?? this.miuiIslandLabelContent,
      miuiIslandLabelFontColor:
          miuiIslandLabelFontColor ?? this.miuiIslandLabelFontColor,
      miuiIslandLabelFontWeight:
          miuiIslandLabelFontWeight ?? this.miuiIslandLabelFontWeight,
      miuiIslandLabelRenderQuality:
          miuiIslandLabelRenderQuality ?? this.miuiIslandLabelRenderQuality,
      miuiIslandLabelFontSize:
          miuiIslandLabelFontSize ?? this.miuiIslandLabelFontSize,
      miuiIslandLabelOffsetX:
          miuiIslandLabelOffsetX ?? this.miuiIslandLabelOffsetX,
      miuiIslandLabelOffsetY:
          miuiIslandLabelOffsetY ?? this.miuiIslandLabelOffsetY,
      miuiIslandLabelLogoPath: clearMiuiIslandLabelLogoPath
          ? null
          : miuiIslandLabelLogoPath ?? this.miuiIslandLabelLogoPath,
      miuiIslandLabelLogoCornerRadius:
          miuiIslandLabelLogoCornerRadius ??
          this.miuiIslandLabelLogoCornerRadius,
      miuiIslandExpandedIconMode:
          miuiIslandExpandedIconMode ?? this.miuiIslandExpandedIconMode,
      miuiIslandExpandedIconPath: clearMiuiIslandExpandedIconPath
          ? null
          : miuiIslandExpandedIconPath ?? this.miuiIslandExpandedIconPath,
      expandedDetailFields: clearExpandedDetailFields
          ? null
          : expandedDetailFields ?? this.expandedDetailFields,
    );
  }
}

class SectionTime {
  final String startTime;
  final String endTime;

  const SectionTime({required this.startTime, required this.endTime});

  Map<String, dynamic> toJson() {
    return {'startTime': startTime, 'endTime': endTime};
  }

  factory SectionTime.fromJson(Map<String, dynamic> json) {
    final rawStart = json['startTime'];
    final rawEnd = json['endTime'];
    if (rawStart is! String || rawStart.trim().isEmpty) {
      throw const FormatException('missing section startTime');
    }
    if (rawEnd is! String || rawEnd.trim().isEmpty) {
      throw const FormatException('missing section endTime');
    }
    return SectionTime(startTime: rawStart, endTime: rawEnd);
  }

  SectionTime copyWith({String? startTime, String? endTime}) {
    return SectionTime(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get displayText => '$startTime-$endTime';

  /// 逐条解析节次表，**坏条目补位而不是跳过**。
  ///
  /// 本课程把 `Course.startSection` 当作这张表的**位置下标**使用
  /// （`time_scheme_logic` 的 `sections[startIndex]`、provider 的 `sections[index]`），
  /// 所以「跳过一条坏记录」会让它之后的每一节全部指向相邻后一节的时间：12 节的
  /// 模板丢掉第 4 节，第 4 节起每门课都显示后一节的时间，用户会按错时间到教室，
  /// 而界面看起来完全正常。同仓 `warehouse_location_time_schemes` 的
  /// `requireContiguousFromOne` 已经在守这个不变量（注释原话「节次按位置对齐，
  /// 缺一节会让『第 3 节』指向错误的时间」），只有这两条解析链没接上。
  ///
  /// 补位值优先取 [fallbackTemplate] 的同位节次（懒取，正常数据不付构造代价）；
  /// 越界则留空时间。空时间在作息管理页渲染为 `-`，即只有那一格显示异常，其余
  /// 节次保持正确 —— 比整表平移更容易被发现。
  ///
  /// 返回值里的 [healedCount] 用于让调用方区分「部分坏」（按位补）与
  /// 「整表都坏」（没有信息可对齐，只能整套回落）。
  static ({List<SectionTime> sections, int healedCount}) parseListAligned(
    List<dynamic> rawSections, {
    required List<SectionTime> Function() fallbackTemplate,
  }) {
    final parsed = <SectionTime>[];
    var healedCount = 0;
    for (final (index, item) in rawSections.indexed) {
      try {
        if (item is! Map) {
          throw const FormatException('section entry is not a map');
        }
        parsed.add(SectionTime.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        healedCount += 1;
        final template = fallbackTemplate();
        parsed.add(
          index < template.length
              ? template[index]
              : const SectionTime(startTime: '', endTime: ''),
        );
      }
    }
    return (sections: parsed, healedCount: healedCount);
  }
}