import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 架构棘（第 32 轮）：**"今天上完/没课 → 卡片整体切到明天课表"这条门禁只许有一份实现**。
///
/// 正源：`TodayWidgetSupport.isShowingTomorrowCourses`（:1157-1167）先判
/// `isExamOngoing` 再看状态，注释写得很清楚
/// （"Don't demote a live exam in favor of tomorrow's course preview"）。
///
/// 起因：`TodayMiniListWidgetProvider.kt:63-65` 把这条规则内联抄了一份
/// `state == "completed" || state == "no_course"`，**少了考试维**。后果是考试日
/// 当天课程已上完、考试还在进行中时，2×2 卡整张切成明天的课表（标题 :78、周数 :86、
/// 行 :94、"还剩 N 门" :127 全跟着走），而它的状态胶囊 :31 按 `displayStatusState`
/// 仍渲染"考试中"配色 —— 一张卡同时说"考试进行中"和"明天有课"。其余 6 张今日卡
/// （Compact :54 / Large :78 / Medium :50 与 :102 / Strip :59 / Wide :59）都走共享函数，
/// 连这个文件自己 :30-31 的注释都写着"与其他 Provider 统一口径"。
///
/// 为什么用棘而不是 Kotlin 用例：判据在 `RemoteViews` 装配里，纯 JVM 单测要拖进
/// Android 框架；而"不许再抄一份"这个约束本身就是可静态检查的，与本仓
/// `test/architecture/` 里其余几道棘同源。摘掉共享调用、改回内联那份，此棘立刻红。
void main() {
  test('今日系卡片不得内联重复「切到明天」的状态门禁', () {
    final widgetDir = Directory(
      'android/app/src/main/kotlin/com/mutx163/qingyu',
    );
    expect(widgetDir.existsSync(), isTrue, reason: '需在仓库根运行');

    // 判据：`val isShowingTomorrow = ...` 这条语句里自己并列 completed/no_course
    // 两个状态（= 抄了一份门禁），而不是调用共享实现。
    // 只扫这一条语句，是为了放行别的谓词 —— 例如 `TodayWideWidgetProvider.kt:61-62`
    // 的 isSparseEnded（"结束且无明日可列 → 右栏收起"）本来就用了同一对状态，
    // 那是另一条规则，不是这条门禁的副本。
    final assign = RegExp(r'val\s+isShowingTomorrow\s*=');
    final inlineStatePair = RegExp(
      r'state\s*==\s*"completed"[^&\n]*\|\|[^&\n]*state\s*==\s*"no_course"',
    );
    final sharedCall = RegExp(r'isShowingTomorrowCourses\s*\(');
    final providerName = RegExp(r'^Today\w*WidgetProvider\.kt$');

    final offenders = <String>[];
    final files =
        widgetDir
            .listSync()
            .whereType<File>()
            .where((f) => providerName.hasMatch(f.uri.pathSegments.last))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files.length, greaterThanOrEqualTo(6), reason: 'glob 不能静默匹配不到文件');

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!assign.hasMatch(lines[i])) {
          continue;
        }
        // Kotlin 的这条赋值可能折成 2~3 行，取往后 3 行当语句体。
        final statement = lines
            .sublist(i, (i + 4).clamp(0, lines.length))
            .join(' ');
        if (inlineStatePair.hasMatch(statement) &&
            !sharedCall.hasMatch(statement)) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '这些卡片自己抄了「切到明天」的门禁，会漏掉共享实现里的维度'
          '（考试进行中不得被明日预告顶掉），改成调用 '
          'TodayWidgetSupport.isShowingTomorrowCourses：\n${offenders.join('\n')}',
    );
  });
}
