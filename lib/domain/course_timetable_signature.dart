import '../models/course.dart';

/// 课表内容的**内容指纹**：用来判断「这次自动更新到底有没有改到课表」。
///
/// ## 为什么需要它
///
/// 自动更新是静默跑的，用户事先并不知道它在抓。若成功、失败、没有变化三种结局
/// 都弹提示，每次打开软件都要被打扰一次；反过来什么都不提示，失败时用户又无从
/// 知道要手动下拉补一次。所以判据是「真的变了才说一句」—— 那就需要一个能比较的
/// 指纹。
///
/// ## 为什么不用导入回调里的 `importedCount`
///
/// 那个计数来自 WebView 那侧的导入流程（`importParsedCourses` 的返回值），只在
/// 后台导入回调里一次性给出，且**为 0 时也可能是「课表被覆盖成了另一份」**。
/// 指纹比的是「更新前 / 更新后的课表内容」，与导入走哪条路无关，也不需要在那个
/// 3,600 行的页面里再开一个回调口子。
///
/// ## 覆盖哪些字段
///
/// 只收**用户看得见、且教务会改**的字段：课名、老师、地点、星期、节次、周次、
/// 单双周、自定义周、停课周、自定义钟点。刻意不收 `id` / `color` / `note` /
/// 备注 / 作业：这些是本机编辑物或随机分配物，收进来会让「只是重新导入了一遍
/// 颜色」被判成「有新课程」。
///
/// 顺序无关（先排序再拼），因为导入回来的顺序不保证稳定。
String timetableContentSignature(List<Course> courses) {
  if (courses.isEmpty) {
    return 'empty';
  }
  final rows = <String>[
    for (final course in courses)
      [
        course.name.trim(),
        course.teacher.trim(),
        course.location.trim(),
        course.dayOfWeek,
        course.startSection,
        course.endSection,
        course.startWeek,
        course.endWeek,
        course.isOddWeek ? 'o' : '-',
        course.isEvenWeek ? 'e' : '-',
        _weeks(course.customWeeks),
        _weeks(course.suspendedWeeks),
        course.hasCustomTime ? '${course.startTime}-${course.endTime}' : '-',
      ].join('|'),
  ]..sort();
  return '${rows.length}#${_fnv1a32(rows.join('\n'))}';
}

String _weeks(List<int>? weeks) {
  if (weeks == null || weeks.isEmpty) {
    return '-';
  }
  final sorted = List<int>.from(weeks)..sort();
  return sorted.join(',');
}

/// FNV-1a 32 位。**不用 `String.hashCode`**：Dart 的字符串哈希不保证跨进程
/// 稳定（每个 isolate 有独立的哈希盐），既写不进测试期望值，也认不出
/// 「隔一次启动一比就全都不一样」这种假变化。
String _fnv1a32(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
