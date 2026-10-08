import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 架构棘：所有「落盘失败会抛」的 provider 写入，调用点必须 await 且失败有出口。
///
/// ## 为什么需要这条
///
/// 本仓的写入契约（见 `timetable/course_repository.dart` 开头）是：
/// **改内存 → await 落盘 → catch 回滚 + rethrow**。也就是说 provider 层的删除 /
/// 写入失败**一定会 reject**。而 UI 层历史上反复犯同一个错：裸 `await` 接在确认
/// 弹窗之后，既不 try/catch，紧接着还照常弹「已删除」并关页。
///
/// 用户视角是三件事同时发生：
///  1. 异常落进 zone，成为未处理异步错误（release 里没有任何提示）；
///  2. 确认弹窗已经关掉，界面零反馈 —— 「点了删除，什么也没发生」；
///  3. 内存已回滚、盘上没变，于是下一次任意成功写入前，数据一直是对的，
///     用户却以为已经删掉了。
///
/// 第 28 轮补过一批（考试页 / 任务页 / 外观页），2026-10-08 审核又发现**五个**
/// 同形状的漏网，而且都是「同一个文件里另一个方法已经修了、这个没修」：
/// `add_course_screen.dart` 删单门课修了、删整组课没修；`timetable_profiles_screen.dart`
/// 清空课表修了、删课表没修；`add_schedule_item_screen.dart` 删整条修了、
/// 删单次/整系列没修。**按 diff 一行行修，必然漏掉孪生方法。**
///
/// 所以这里不再逐个登记，而是**扫全 `lib/screens` + `lib/widgets`**：
/// 任何 `.xxx(` 形态的 provider 写入调用，都要求它在 try 块内被 await。
///
/// ## 为什么用文本判定而不是 widget 用例
///
/// 注入写失败后跑整页 widget 用例会不收尾（`user_guide_settings_failure_guard_test.dart`
/// 头注释记录了这个坑），而「调用点有没有被 try 包着」是纯文本可判的事实。
///
/// 花括号感知：从每个调用点向上回溯，遇到 `try` 且括号配平，就认为有出口。
/// 避免了「只按最近一层块边界判」把 `try { if (x) { await … } }` 里的 if 块
/// 误报成没有出口（同文件第 44-49 行记过一次这个教训，那次没有实现花括号感知）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 这些 provider 方法在落盘失败时会 rethrow（写入契约，见 course_repository.dart
  /// 开头与 timetable_provider.dart 各 `_rollback*Write`）。只列确定会抛的：
  /// `addCourse` / `addTask` 这类「加的就是用户刚填的那条」的**刻意不回滚**，
  /// 但它们同样会 reject（抛错只是不回滚），所以一并要求接住。
  const rethrowingProviders = <String>{
    // 课程族
    'addCourse',
    'updateCourse',
    'deleteCourse',
    'deleteCourseGroup',
    'addCourseGroup',
    'updateCourseGroup',
    'applyCourseRecolors',
    'toggleCourseSuspension',
    'suspendAllWeeks',
    'unsuspendAllWeeks',
    'deleteCourseOccurrence',
    'rescheduleCourseOccurrence',
    'clearActiveProfileCourses',
    // 作业族
    'addTask',
    'updateTask',
    'toggleTaskCompleted',
    'deleteTask',
    // 日程族
    'addScheduleItem',
    'updateScheduleItem',
    'deleteScheduleItem',
    'deleteScheduleItemOccurrence',
    'updateScheduleItemOccurrence',
    'deleteScheduleItemInstance',
    'updateScheduleItemInstance',
    'updateScheduleItemSeries',
    'deleteScheduleItemSeries',
    // 考试族
    'addExam',
    'updateExam',
    'deleteExam',
    // 课表档案族
    'addProfile',
    'renameProfile',
    'deleteProfile',
    'duplicateActiveProfile',
    // 提醒 / 假期
    'setClassReminder',
    'removeClassReminder',
    'addCustomHoliday',
    'addCustomHolidays',
    'removeCustomHoliday',
    'updateCustomHoliday',
    'deleteCustomHoliday',
    // 地点分组 / 日期规则
    'updateLocationTimeGroup',
    'deleteLocationTimeGroup',
    'replaceLocationTimeGroups',
    'updateScheduleDateRule',
    'deleteScheduleDateRule',
    'replaceScheduleDateRules',
    // 作息族
    'createTimeScheme',
    'renameTimeScheme',
    'duplicateTimeScheme',
    'updateTimeScheme',
    'deleteTimeScheme',
    'applyTimeScheme',
    // 设置族
    'updateSettings',
    'updateTimetableSettings',
    'saveTheme',
    'deleteTheme',
    'renameTheme',
    'applyThemeWithUndo',
    // 情侣同步
    'updatePartnerWeekOffset',
    'updatePartnerCoupleColors',
    'restorePartnerBinding',
    // 导入落库
    'importParsedCourses',
    'importWakeUpCalendar',
  };

  final callPattern = RegExp(
    '\\.(${rethrowingProviders.join('|')})\\s*\\(',
  );

  test('UI 层调用会 rethrow 的 provider 写入时，必须 await 且在 try 内', () {
    final roots = <String>[
      for (final dir in <String>['lib/screens', 'lib/widgets'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => f.path),
    ];
    expect(roots, isNotEmpty, reason: '扫描范围为空，棘会假绿');

    final offenders = <String>[];
    var checked = 0;

    for (final path in roots) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!callPattern.hasMatch(line)) {
          continue;
        }
        // 注释与定义处不参与判定。
        if (line.startsWith('//') ||
            line.startsWith('///') ||
            line.startsWith('*') ||
            line.contains('=> ') && line.contains('Future<void>') ||
            line.startsWith('Future<')) {
          continue;
        }
        checked++;
        if (!_isInsideTryCatch(lines, i) && !_hasCatchErrorHandler(lines, i)) {
          offenders.add('$path:${i + 1}: $line');
        }
      }
    }

    expect(
      checked,
      greaterThanOrEqualTo(80),
      reason: '只扫到 $checked 处调用，规则本身可能已经匹配不到东西了',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'provider 的删除/写入在落盘失败时会 rethrow（见 course_repository.dart '
          '开头的写入契约）。裸 await 接在确认弹窗之后 = 「点了删除、零提示、'
          '未处理异步错误」，而下面往往还照常报成功并关页。\n'
          '请写成 try { await … } catch (_) { 弹失败 toast 并 return; }\n'
          '${offenders.join('\n')}',
    );
  });

  test('棘自己不是空转：仓库里确实存在「会抛的 provider 方法」', () {
    final provider = File('lib/providers/timetable_provider.dart');
    expect(provider.existsSync(), isTrue);
    final text = provider.readAsStringSync();
    final present = rethrowingProviders
        .where((name) => text.contains('$name('))
        .toList();
    expect(
      present.length,
      greaterThanOrEqualTo(30),
      reason: '只有 ${present.length} 个方法名能在 provider 里找到，名单该更新了',
    );
  });
}

/// 调用表达式后面接了 `.catchError(...)` / `.then(...)` 且带失败分支。
///
/// 这也是合法的失败出口，本仓已有这种写法：乐观语义的开关用
/// `unawaited(provider.updateTimetableSettings(...).catchError((Object _) { … }))`
/// （`settings_live.dart:954`、`timetable_screen.dart:1582`）—— 花括号栈判定看不到
/// 这种链式写法，会误报，所以单独放行。
bool _hasCatchErrorHandler(List<String> lines, int index) {
  // 从调用行往下看 14 行：`unawaited(provider.updateX(...).catchError(...))`
  // 这种链式写法里，`.catchError` 排在多行调用之后，分号可能远在十几行外，
  // 所以这里**不做语句边界提前退出** —— 只按「往后 14 行内有没有 .catchError」
  // 判定。这会放过少量「本语句没有、下一语句有」的误放行，代价是漏报一两个，
  // 比把合法写法误报成红线要好（棘一旦误报就会被整体关掉）。
  final end = (index + 14).clamp(0, lines.length);
  for (var i = index; i < end; i++) {
    if (_stripCommentsAndStrings(lines[i]).contains('.catchError(')) {
      return true;
    }
  }
  return false;
}

/// 从文件开头扫到 [index]，判断这个调用点是否处在某个 try 块内。
///
/// 实现：一个真正的**块栈**。逐行去掉注释与字符串后，把每一行的 `{` / `}`
/// 压栈/弹栈；遇到 `try` 就往栈里记一条「try 开始」。扫描到调用点所在行时，
/// 栈里还有没有 try 标记，就是答案。
///
/// 之前的写法是「找到第一个 try 就锁定它，再数括号配不配平」，有两个错：
///  1. 方法体里第一个 try 早就闭合了，而调用点在它**之后** —— 那样会误判成
///     「不在 try 内」（`add_course_screen.dart:1460` 这种：函数开头别处有 try，
///     而删课那行自己裸着，是真 bug，但机制不同）；
///  2. 计数没有区分「哪个花括号关掉了哪个」。
/// 栈模型对这两种都对。
///
/// ⚠️ 必须去掉注释与字符串再数：本仓注释里大量出现 `try {`、`{`、`}` 字样，
/// 按原文数会把栈算错（`user_guide_settings_failure_guard_test.dart` 头注释
/// 就是一处）。这也是第一版误报 `clearActiveProfileCourses` 的原因。
bool _isInsideTryCatch(List<String> lines, int index) {
  var depth = 0;
  final tryDepths = <int>[];

  for (var i = 0; i <= index; i++) {
    final code = _stripCommentsAndStrings(lines[i]);
    if (RegExp(r'\btry\b').hasMatch(code)) {
      // `try` 后面必然跟着 `{`（本仓无 `try` 单行无块写法），记下它此刻的深度，
      // 这一行随后压栈时深度会 +1。
      tryDepths.add(depth);
    }
    for (final ch in code.codeUnits) {
      if (ch == 0x7B) {
        depth++;
      } else if (ch == 0x7D) {
        depth--;
        // 关掉了 try 所在的那一层 ⇒ 这个 try 已经结束。
        while (tryDepths.isNotEmpty && tryDepths.last >= depth) {
          tryDepths.removeLast();
        }
      }
    }
  }
  return tryDepths.isNotEmpty;
}

/// 去掉行注释与字符串字面量，避免注释/文本里的花括号与 `try` 影响判定。
String _stripCommentsAndStrings(String line) {
  var out = '';
  var inSingle = false;
  var inDouble = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == "'" && !inDouble) inSingle = !inSingle;
    if (ch == '"' && !inSingle) inDouble = !inDouble;
    if (inSingle || inDouble) continue;
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
      break;
    }
    out += ch;
  }
  return out;
}
