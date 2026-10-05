import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 架构棘（第二十四轮）：**引导页不能把 `updateTimetableSettings` 的失败丢掉**。
///
/// 正源：`timetable_provider.dart:3848-3867` 在落盘失败时回滚内存、
/// `notifyListeners()`，然后按注释所说 **rethrow**（"原始失败更有价值"）。
/// 接法也是现成的：`reportSettingsPersistFailure`
/// （`timetable_settings_screen.dart:123-137`，弹 `saveFailed` toast），
/// 设置页六个站点全都接了（`settings_appearance.dart:408`、
/// `settings_appearance_editor.dart:505`、`settings_general.dart:140` 等）。
///
/// 引导页原先两处没接：`:775` 的
/// `unawaited(provider.updateTimetableSettings(next))`（个性化页主题/种子色/
/// 视觉效果/菜单样式全走它）与 `:322` 语言下拉里连 `unawaited` 都没有的裸调用。
/// 后果：磁盘写失败时用户刚选的语言/主题**自己跳回旧值、零提示**，
/// 异常落进 zone 成为未处理异步错误；而引导页是首次启动必经路径。
///
/// 为什么用棘而不是 widget 用例：本仓的整页 `testWidgets` + FakeAsync 会在
/// 注入写失败后不收尾（`did not complete`，本文件的历史版本踩过），而这条规则
/// 是纯文本可判的 —— 调用点的 await/catch 形态就写在文件里。
void main() {
  final file = File('lib/screens/user_guide_screen.dart');

  test('引导页里对 updateTimetableSettings 的每个调用都被 await 且失败有出口', () {
    expect(file.existsSync(), isTrue, reason: '请在仓库根目录运行本测试');
    final lines = file.readAsLinesSync();

    final offenders = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.contains('updateTimetableSettings(')) {
        continue;
      }
      // 定义处/注释行不参与判定。
      if (line.startsWith('//') ||
          line.startsWith('///') ||
          line.startsWith('Future<')) {
        continue;
      }
      final awaited = line.contains('await ');
      final discarded = line.startsWith('unawaited(');
      if (!awaited || discarded) {
        offenders.add('${i + 1}: $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'updateTimetableSettings 在落盘失败时会 rethrow；不 await 就等于把失败丢掉。'
          '请走 await + try/catch → reportSettingsPersistFailure：\n'
          '${offenders.join('\n')}',
    );
  });

  test('引导页确实接了设置页那条统一的失败提示', () {
    final text = file.readAsLinesSync().join('\n');
    expect(
      text,
      contains('reportSettingsPersistFailure'),
      reason: '失败必须让用户看见（同仓六个设置站点都用这个 helper）',
    );
  });

  test('考试页的三处写入也必须被 await（同一形状的第二个宿主）', () {
    // `addExam`/`updateExam`/`deleteExam`（timetable_provider.dart:3239-3280）
    // 内部都是 `await _persistActiveProfileState()` 且没有 try/catch → 落盘失败会
    // reject。`add_exam_screen.dart` 原先写完就 `Navigator.pop`：页面照常关闭、
    // 看起来成功，异常落进 zone，考试只在内存里（add 路径刻意不回滚），杀掉 app 就没了。
    // 同一个函数对"没选课程/没选日期"都会弹 toast，说明失败可见是这页的既定意图。
    final target = File('lib/screens/add_exam_screen.dart');
    expect(target.existsSync(), isTrue);
    final lines = target.readAsLinesSync();
    final mutating = RegExp(
      r'\.(addExam|updateExam|deleteExam)\s*\(',
    );
    final offenders = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!mutating.hasMatch(line) ||
          line.startsWith('//') ||
          line.startsWith('///')) {
        continue;
      }
      if (!line.contains('await ') || line.startsWith('unawaited(')) {
        offenders.add('${i + 1}: $line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '考试写入失败会 reject，必须 await + try/catch 提示，失败时不要 pop：\n'
          '${offenders.join('\n')}',
    );
  });

  test('天气与主题设置里的 provider 写入都不能发了不管', () {
    // 契约核对过：`updateSettings`（timetable_provider.dart:332-337）
    // `await _persistActiveProfileState()` 且**无 try/catch** → reject；
    // `saveTheme`/`renameTheme`/`deleteTheme` 走 `_applySavedThemes`（:349-356），
    // 失败时**回滚内存 + rethrow**；`applyThemeWithUndo`（:306-319）await updateSettings
    // → 同样 reject。原先这些点在 UI 里都是裸调用或 unawaited：
    // 天气六个开关按下去当场生效、重启回旧值且零提示；主题更糟 ——
    // `_applyThemeWithUndo` 在写入 future 都没接的情况下紧接着弹"已更改 + 撤销"，
    // 失败时用户看到"改好了"，撤销按钮撤销的是一份根本没存下的改动。
    final targets = <String, RegExp>{
      'lib/screens/settings/settings_weather.dart': RegExp(
        r'\.(updateSettings|updateTimetableSettings)\s*\(',
      ),
      'lib/screens/settings/settings_appearance.dart': RegExp(
        r'\.(updateSettings|applyThemeWithUndo|saveTheme|deleteTheme|renameTheme)\s*\(',
      ),
      // 9345fa80 之后的第三个宿主：情侣三色写入先改内存再 await 落盘、失败不回滚。
      'lib/screens/couple_timetable_settings_screen.dart': RegExp(
        r'\.updatePartnerCoupleColors\s*\(',
      ),
    };

    final allOffenders = <String>[];
    for (final entry in targets.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: entry.key);
      final lines = file.readAsLinesSync();
      final offenders = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!entry.value.hasMatch(line) ||
            line.startsWith('//') ||
            line.startsWith('///')) {
          continue;
        }
        // 方法定义行（如 `Future<void> saveTheme(...)`）不是调用点。
        if (line.startsWith('Future<') || line.startsWith('void ')) {
          continue;
        }
        // 只看"同一条语句"的片段：往前推到语句边界（空行、`{`、`}`、`;`），
        // 这样 `await provider\n  .saveTheme(...)` 这种折行仍然算 awaited，
        // 而上一个 if 里有 await、本行裸调用的情况不会被误判为已处理。
        var start = i;
        while (start > 0) {
          final prev = lines[start - 1].trim();
          if (prev.isEmpty ||
              prev.endsWith('{') ||
              prev.endsWith('}') ||
              prev.endsWith(';')) {
            break;
          }
          start--;
        }
        final statement = lines.sublist(start, i + 1).join(' ');
        final awaited = statement.contains('await ');
        if (!awaited || line.startsWith('unawaited(')) {
          offenders.add('${entry.key}:${i + 1}: $line');
        }
      }
      allOffenders.addAll(offenders);
    }
    // 两个文件一起判：否则第一个文件失败就把第二个文件的违规点藏住了
    // （第一版就是这样，撤掉修复时只看到天气那一行）。
    expect(
      allOffenders,
      isEmpty,
      reason:
          '这些写入在落盘失败时会 reject；不 await 也不提示，就等于把用户的设置'
          '改动吞成"看起来生效了"：\n${allOffenders.join('\n')}',
    );
  });
}
