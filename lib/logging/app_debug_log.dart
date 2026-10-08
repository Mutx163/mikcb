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
/// `weather_service.dart:298`）。名字列表一律用语义明确的键名
/// （`overflowNames` / `changeSamples` / `sampleOverrides`）。
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
  'keywords',
  'className',
  'studentName',
  // 名字**列表**（2026-10-08 补）：`schedule_rule_apply.dart:314-315` 与
  // `location_time_match_screen.dart:216` 打的是 `overflowNames=课程名,课程名`，
  // 而 `changeSamples` 里是 `课程名|id|…`，原先一条都匹配不上，
  // 课程名原样进了 release 日志（含可导出的那份）。
  'overflowNames',
  'changeSamples',
  // `location_time_match_screen.dart:217` 那条**名字**样本行原先挂在 `samples=`
  // 下，而 `samples` 不能进表（保护性能计数），于是它只靠内层的 `name=`/`loc=`
  // 逐段命中 —— 而值到空格为止，`name=高等数学|id=…` 这种以 `name=` 开头的
  // **第一段**命中的却是 `samples=` 的边界，整段漏出去。改成语义明确的键。
  'sampleOverrides',
};

/// 名字**列表**型字段：值是「一串用分隔符连起来的名字」。
///
/// 这类必须**整值盖住** —— `overflowNames=A,B,C`、`changeSamples=A|id|说明 || …`
/// 里每个元素都是**以名字开头**的（`schedule_rule_apply.dart:191-194` 就是
/// `'${course.name}|${course.id}|…'`），元素内部根本没有 `key=` 可供逐段匹配；
/// 上一版「值到空格为止」只能盖住第 1 个元素的第 1 段，
/// 第 2~12 门课名连同课程 id 原样进了导出日志（2026-10-08 复核实测 7/8 绕过）。
/// extras 那条出口一直就是整值抹的（`app_log_service.dart` 见到表里的键就抹），
/// message 这条出口原先没跟上。
final Set<String> _listValuedPersonalFieldKeys = {
  'overflownames',
  'changesamples',
  'sampleoverrides',
  'keywords',
};

/// 「分隔符列表」型字段：值里的元素**全部**是名字，逗号之间不再有可识别的边界，
/// 所以要吃到**下一个空白**为止（`overflowNames=高等数学,大学英语` → 整段抹掉）。
/// 这条仍然保住同行后面的 `changeSamples=…`，因为两者之间本来就有空格。
///
/// `keywords` 还多一层：生产上它的值总是**方括号包起来**的
/// （`schedule_rule_apply.dart:68` 的 `keywords=[$keywords]`，内部分隔符是 `|`），
/// 所以认 `]` 作终止符 —— 用空白当边界会在 `[一教(exact)|六教(regex)]`
/// 的 `|` 处停下，把后半截漏出去。
///
/// 而 `changeSamples` / `sampleOverrides` 用的是 `" || "`（**空格**分隔），
/// 元素内部还有 `need=` / `schemeHas=` 这种长得像字段的 token
/// （`schedule_rule_apply.dart:191-194`），没法用空白当边界，只能吃到行尾
/// （见 [redactPersonalFields]）。
final Set<String> _commaListValuedPersonalFieldKeys = {
  'overflownames',
  'keywords',
};

/// 一条**结构性**的个人字段匹配：
/// - key 大小写不敏感、允许 `=` 前后有空格（`COURSE=` / `course =`）；
/// - key 可以在行首（`multiLine` + `^`），上一版没开 `multiLine`，
///   于是续行开头的 `course=` 一条都匹配不上。
///
/// 值分两种，由 [redactPersonalFields] 按 key 决定取哪一段：
/// - 标量型：到下一个空白 / `&` / `|` 为止，这样 `a|b|c` 的拼接日志能逐段命中、
///   取证量（id / 钟点 / 计数）不丢。
/// - 列表型（[_listValuedPersonalFieldKeys]）：连分隔符与空白一起吃到**行尾**。
///   `changeSamples` 用 `" || "` 拼接，只吃到空白的话第 2~12 门课名照样漏出；
///   而样本元素本身就长得像字段对（`…|REJECT overflow need=9-9 schemeHas=8`），
///   所以不能用「下一个 `key=`」当终止条件，只能吃到行尾。
///   这些字段在生产里**本来就排在行尾**（`schedule_rule_apply.dart:318`、
///   `location_time_match_screen.dart:217` 都是拼接的末项），实际不吃亏。
///
/// ⚠️ 所以这是**一次遍历**，不是两遍：两遍会让先跑的那条正则用贪婪的
/// `[^\n]*` 把整行吞掉（`overflowNames` 先命中 → 后面 `changeSamples`
/// 整段原样留下，正是实测里 `线性代数`/`大学物理` 漏出的原因）。
/// 所以匹配统一用**懒惰**的标量值，列表型在回调里按 key 决定要不要
/// 把后续内容一并吃掉。
final RegExp _personalFieldPattern = RegExp(
  r'(^|[\s&|])([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^\s&|]*)',
  caseSensitive: false,
  multiLine: true,
);

/// [personalLogFieldKeys] 的小写索引，供大小写不敏感的查表用。
///
/// ⚠️ 查表必须走这个而不是 `key.toLowerCase()`：表里有 camelCase 的键
/// （`overflowNames` / `changeSamples` / `sampleOverrides`），
/// 直接小写会变成 `overflownames` 而查不到 —— 那正是本轮修好正则后
/// 名字列表反而整段漏出去的原因。
final Set<String> _personalFieldKeysLower = {
  for (final key in personalLogFieldKeys) key.toLowerCase(),
};

/// 把个人信息字段改成 `key=**`，其余文本原样保留。
///
/// 只在 key 命中 [personalLogFieldKeys] 时改写；其它 key 一律原样保留，
/// 取证能力不降级（id / 计数 / 模板名 / 节次这些仍能定位问题的量都在）。
String redactPersonalFields(String message) {
  final out = StringBuffer();
  var cursor = 0;
  for (final match in _personalFieldPattern.allMatches(message)) {
    final key = match.group(2)!;
    final lowered = key.toLowerCase();
    // 不是个人字段：不动它；cursor 也不动，这段留给 substring 原样带走。
    if (!_personalFieldKeysLower.contains(lowered)) {
      continue;
    }
    // 已经被前面的列表型字段整段吃掉了，跳过（否则 substring 会越界）。
    if (match.start < cursor) {
      continue;
    }
    out.write(message.substring(cursor, match.start));
    if (_listValuedPersonalFieldKeys.contains(lowered)) {
      // 列表型：连分隔符一起吃掉。`overflowNames=A,B` 元素全是名字，
      // 吃到下一个空白为止即可（同行后面的 `changeSamples=…` 仍能处理）；
      // `changeSamples=A|id … || B|id` 那种空格分隔、元素内部还有
      // `need=` / `schemeHas=` 这种长得像字段的 token 的，只能吃到行尾。
      final newline = message.indexOf('\n', match.start);
      final lineEnd = newline == -1 ? message.length : newline;
      var stopAt = lineEnd;
      if (_commaListValuedPersonalFieldKeys.contains(lowered)) {
        final closeBracket = message.indexOf(']', match.end);
        if (closeBracket != -1 && closeBracket < lineEnd) {
          // `keywords=[…]`：方括号自己定了界，吃到 `]` 为止。
          stopAt = closeBracket + 1;
        } else {
          for (var i = match.end; i < lineEnd; i++) {
            final c = message.codeUnitAt(i);
            // 空白算边界（`|`/`&` 不算：它们正是列表自身的分隔符）。
            if (c == 0x20 || c == 0x09 || c == 0x0d) {
              stopAt = i;
              break;
            }
          }
        }
      }
      out.write('${match.group(1)}$key=**');
      cursor = stopAt;
    } else {
      out.write('${match.group(1)}$key=**');
      cursor = match.end;
    }
  }
  out.write(message.substring(cursor));
  return out.toString();
}
