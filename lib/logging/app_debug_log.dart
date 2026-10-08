import 'package:flutter/foundation.dart';

/// Unified debug console logging with Chinese messages.
void appDebugLog(String tag, String message) {
  if (kDebugMode) {
    debugPrint('[$tag] $message');
    return;
  }
  // Always print for forensic tags so profile/release diagnostics can be
  // captured from logcat even when kDebugMode is false.
  const forensicTags = <String>{'LocationTimeApply', 'LocationTimeApplyUI'};
  if (!forensicTags.contains(tag)) {
    return;
  }
  // 这个例外不能把课表内容原样交出去：logcat 是整机共享缓冲区
  // （`adb logcat` / 任何拿到调试授权的人都能读，且写入后无法回收），
  // 而这两条取证链的每一行都带学生可读的字段 ——
  // `time_scheme_logic.dart:425/449/461` 与 `timetable_provider.dart:2011/2031/
  // 2060/2133/1957` 打的是 `course=<课程名> loc=<教室>`，
  // `location_time_match_screen.dart:208` 更是一次拼 12 门课的
  // `课程名|id|钟点|教室`。release 下只抹掉可识别到人的字段，
  // 保留 id/计数/模板名/节次这些仍能定位问题的量，取证能力不降级。
  debugPrint('[$tag] ${redactPersonalFields(message)}');
}

/// 可识别到人的 `key=value` 字段（课程名、教师、教室、地点组、命中关键词，
/// 以及**名字列表**字段）。
///
/// 这是这份字段表的**唯一来源**：`app_log_service.dart` 的持久化日志用它判断
/// 某个结构化 extras 的键要不要整值抹掉 —— 两处必须同源，否则又是一个
/// "改了这份、漏了那份"。
///
/// 值到下一个空格或 `|` 为止，因此 `a|b` 形式的拼接日志也能逐段命中。
/// 前置边界要求 key 独立成词，`courses=12`/`schoolName=…` 这类
/// 计数与机构名不会被误伤。
///
/// ⚠️ 不要往里加 `samples`：那是性能探针的**计数**字段
/// （`timetable_screen.dart:4321` 的 `samples=${probe.samples}`），
/// 抹掉它等于"过度脱敏答非所问"（本仓为这件事返工过，见
/// `weather_service.dart:298`）。要覆盖名字列表，用语义明确的键名
/// （`overflowNames` / `changeSamples`）。
const Set<String> personalLogFieldKeys = <String>{
  'course',
  'courseName',
  'name',
  'shortName',
  'teacher',
  'loc',
  'location',
  'groupName',
  'group',
  'keyword',
  'className',
  'studentName',
  // 名字**列表**（2026-10-08 补）：`schedule_rule_apply.dart:314-315` 与
  // `location_time_match_screen.dart:216` 打的是 `overflowNames=课程名,课程名`，
  // 而 `changeSamples` 里是 `课程名|id|…`，原先一条都匹配不上，
  // 课程名原样进了 release 日志（含可导出的那份）。
  'overflowNames',
  'changeSamples',
};

final RegExp _personalFieldPattern = RegExp(
  r'(^|[ &|])(' + personalLogFieldKeys.join('|') + r')=([^\s|]*)',
);

/// 把个人信息字段改成 `key=**`，其余文本原样保留。
String redactPersonalFields(String message) {
  return message.replaceAllMapped(
    _personalFieldPattern,
    (Match match) => '${match.group(1)}${match.group(2)}=**',
  );
}
