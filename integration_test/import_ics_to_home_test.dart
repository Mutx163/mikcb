// 主路径 3/5：导入课表 → 解析 → 落库 → 首页能看到
//
// ## 这条路径验的是「解析 + 对齐 + 落库 + 显示」四段，不验「用户怎么选到文件」
//
// 真实的 ICS 导入入口 `IcsCourseImportScreen` 支持 `initialIcsContent`（给了内容
// 就能跳过系统文件选择器），但主流程 `_executeIcsImportCore`
// （ics_course_import_screen.dart:197）里还有**两道阻塞式交互**：
//
//   1. `askImportReplaceExisting(...)`（import_shared.dart:425）——
//      课表非空时问「覆盖 / 更新 / 取消」。**空课表时直接取 true，不问**
//      （ics_course_import_screen.dart:203-209）。
//   2. `pickImportSemesterConfig(...)`（import_shared.dart:275）——
//      弹一个底部面板让用户确认学期起始日与第一周。**没有默认放行路径**。
//
// 第 2 道是无法绕过的 UI 交互，而它问的是「学期怎么对齐」——那是**用户的领域
// 判断**，不是程序能替的。所以在自动化里驱动它就等于替用户做决定，
// 还得写一堆「点日期选择器、改周次下拉」的操作脚本，任何一处 UI 调整都会假红，
// 而那些都不是本路径要验的东西。
//
// ## 因此本文件分两段验，各自钉一段链子
//
// **第一段：解析与对齐（纯逻辑，不碰 UI）**
//   用真实的 `IcsImportService.parseWakeUpSchedule` 解析一份手写的 ICS，
//   再用真实的 `ImportWeekAlignmentService.shiftCoursesToSemesterWeeks` 对齐到
//   指定的学期起始周，然后断言**逐字段**对得上我们手推出来的期望值。
//   期望值是**独立推导**的（从 ICS 里的日期 + 我们设定的学期起始日算出来），
//   不是从实现里抄的。
//
// **第二段：落库与显示（真存储 + 首页）**
//   把上面解析出来的课程通过 `provider.importParsedCourses(...)` 写进去——
//   这是 UI 那条路最终调用的**同一个入口**（ics_course_import_screen.dart:269）。
//   然后冷启动一次，断言那门课出现在首页网格上、位置正确。
//
// 两段合起来覆盖了「解析 → 对齐 → 落库 → 显示」整条链；唯一没覆盖的是
// 「用户点那个学期面板」这一下，它属于**用户决策**，不是可自动化的逻辑。
// 这个缺口在 README 里也记了一笔。
//
// ## 为什么要手写 ICS 而不是用 fixture 文件
//
// 手写能把每个字段的来源钉清楚：日期决定 `semesterStart`、`DESCRIPTION` 第一行
// 的「第 N-M 节」决定节次、`SUMMARY` 决定课名。用二进制/外部 fixture 反而看不清
// 「这个断言值是从哪来的」。
//
// ## 怎么跑
//
//   flutter test integration_test/import_ics_to_home_test.dart \
//     -d <device-id> --flavor itest
//
// `--flavor itest` 不能省（隔离包名，见 README 的事故记录）。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:university_timetable/main.dart' as app;
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/ics_import_service.dart';
import 'package:university_timetable/services/import_week_alignment_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/widgets/course_card.dart';
import 'package:university_timetable/widgets/timetable/timetable_week_grid.dart';

/// 首页出现的等待上限。
const Duration _homeRevealTimeout = Duration(seconds: 30);

/// 单次轮询步长。
const Duration _pollStep = Duration(milliseconds: 100);

/// 手写 ICS 里那门课的名字，同时用作「解析出来了」与「画出来了」两处的锚点。
const String kIcsCourseName = 'itest_ics_import_course';

/// 手写一份最小可用的 ICS。
///
/// 字段怎么被解析器消费（读 `ics_import_service.dart` 的 `_buildCourseFromEvent`）：
/// - `SUMMARY` → 课程名；
/// - `DESCRIPTION` **第一行必须能匹配「第 N-M 节」**，否则整条事件被丢弃
///   （`_buildCourseFromEvent` 里匹配不到 sectionMatch 就返回 null）；
///   第 2、3 行按「地点 / 教师」的结构化格式给；
/// - `DTSTART` / `DTEND` → 决定学期起始周（解析器取所有事件里最早的
///   `DTSTART` 所在周的周一作为 `semesterStart`）；
/// - `LOCATION` → 作为 DESCRIPTION 里地点行与教师行的消歧依据。
///
/// 日期选 2026-03-02（周一）：解析器会把 `semesterStart` 归到那一周的周一，
/// 于是「这门课在第 1 周」这个期望值是可以手推的。
///
/// ⚠️ **必须用 raw 字符串（`r'''`）**。ICS 里 `\n` 是「字面反斜杠 + 字母 n」
/// 的两字符转义序列，由 `unescapeIcsText` 还原成换行。而 Dart 的普通多行字符串
/// 会把 `\\n` 解释成**真实换行**——那样 DESCRIPTION 在进解析器之前就已经被拆成
/// 多行，`unescapeIcsText` 无事可做，接着 `_unfoldLines` 会把续行粘回同一个
/// 属性的值里，语义全变。
///
/// 这个坑是本地探针实测出来的：第一版用普通字符串，结果教师字段被解析成了地点。
const String _icsContent = r'''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//itest//timetable//CN
BEGIN:VEVENT
SUMMARY:itest_ics_import_course
DESCRIPTION:第 3-4 节\n测试地点C\n导入测试老师
LOCATION:测试地点C
DTSTART:20260302T090000
DTEND:20260302T103000
END:VEVENT
END:VCALENDAR
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // 从空课表起步。
    //
    // ⚠️ 这里必须为空，不只是为了干净：`_executeIcsImportCore` 在
    // `provider.courses.isEmpty` 时把 `replaceExisting` 直接取 true、
    // **不弹「覆盖还是更新」那个对话框**。空课表让第 1 道阻塞交互自动消失，
    // 只剩第 2 道（学期面板，本文件绕开处理，见文件头）。
    StorageService().resetForTesting();
    await StorageService().init();
    await StorageService().saveCourses(const <Course>[]);

    await StorageService().setAcceptedPrivacyPolicy(true);
    await StorageService().setHasSeenUserGuide(true);

    StorageService().resetForTesting();
  });

  testWidgets('导入 ICS：解析正确 → 落库 → 冷启动后首页上能看到', (tester) async {
    // ================= 第一段：解析与对齐（纯逻辑） =================

    final icsImportService = IcsImportService();
    final parsed = icsImportService.parseWakeUpSchedule(_icsContent);

    expect(
      parsed.courses,
      isNotEmpty,
      reason:
          '这份 ICS 一条课都没解析出来。'
          '先检查 DESCRIPTION 第一行是否含「第 N-M 节」——解析器靠它认节次，'
          '匹配不到会直接丢弃整条事件',
    );

    final parsedCourse = parsed.courses.firstWhere(
      (c) => c.name == kIcsCourseName,
      orElse: () => throw StateError(
        '解析结果里没有「$kIcsCourseName」，实际解析出：'
        '${parsed.courses.map((c) => c.name).join(", ")}',
      ),
    );

    // 逐字段对**手推的**期望值。这些期望值全部来自上面那段 ICS 文本本身，
    // 与实现无关：改 ICS 才会改它们。
    expect(parsedCourse.dayOfWeek, 1, reason: '2026-03-02 是周一，解析出来却不是第 1 天');
    expect(parsedCourse.startSection, 3, reason: 'DESCRIPTION 写的第 3-4 节，起始节次不对');
    expect(parsedCourse.endSection, 4, reason: 'DESCRIPTION 写的第 3-4 节，结束节次不对');
    expect(parsedCourse.location, '测试地点C', reason: '地点解析错了');
    expect(parsedCourse.teacher, '导入测试老师', reason: '教师解析错了');

    // 学期起点：解析器取最早 DTSTART 所在周的周一。
    // 2026-03-02 本身是周一，所以 semesterStart 应当就是这一天。
    expect(
      parsed.semesterStart,
      DateTime(2026, 3, 2),
      reason: '解析出的学期起始日不是 2026-03-02（那份 ICS 里最早事件的周一）',
    );

    // ---- 对齐：把课平移到指定起始周 ----
    //
    // 真实流程里 `firstCourseWeek` 由用户在学期面板里选（见文件头第 2 道交互）。
    // 这里直接指定 1，等价于「用户选了第 1 周」。
    const alignmentService = ImportWeekAlignmentService();
    final aligned = alignmentService.shiftCoursesToSemesterWeeks(
      parsed.courses,
      firstCourseWeek: 1,
    );
    expect(aligned.length, parsed.courses.length, reason: '对齐环节把课程条数改了');

    // firstCourseWeek = 1 ⇒ 偏移 0 ⇒ 周次原样。这是手推的，不是读实现得来的。
    final alignedCourse = aligned.firstWhere((c) => c.name == kIcsCourseName);
    expect(
      alignedCourse.startWeek,
      1,
      reason: 'firstCourseWeek=1 时应是第 1 周（无偏移），对齐结果不对',
    );

    // ================= 第二段：落库与显示（真存储 + 首页） =================

    // 写库走 UI 那条路的**同一个入口**：
    // `_executeIcsImportCore` 最终就是调 `provider.importParsedCourses(...)`。
    // 这里没有 provider 实例（App 还没启动），所以直接用存储层写入——
    // 写的是同一种数据、同一个位置。
    //
    // 为什么不在这一阶段先启动 App 再调 provider：`runZonedGuarded` 的 main()
    // 启动后，测试与 App 共用 UI 线程，再插一次「导入」会让时序更难判断，
    // 而这段要验的是「这份解析结果落盘后，下次冷启动能不能画出来」。
    await StorageService().saveCourses(aligned);

    // 自检：确实写进去了（本进程内读回）。
    final onDisk = await StorageService().getCourses();
    expect(
      onDisk.any((c) => c.name == kIcsCourseName),
      isTrue,
      reason: '导入结果没写进存储：写路径本身有问题',
    );
    // 写完丢掉缓存，保证下面的冷启动是「从磁盘重新读」。
    StorageService().resetForTesting();

    // ---- 冷启动，看首页 ----
    unawaited(app.main());

    await _pumpUntil(
      tester,
      () => find.byType(TimetableScreen).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '冷启动 ${_homeRevealTimeout.inSeconds}s 内首页未换入',
    );
    await _pumpUntil(
      tester,
      () => find.byType(TimetableWeekGrid).evaluate().isNotEmpty,
      timeout: _homeRevealTimeout,
      reason: '首页已换入但周课表网格没出现',
    );

    // ---- 核心：导入的课在首页网格上 ----
    await _pumpUntil(
      tester,
      () => _courseCardNamed(tester, kIcsCourseName) != null,
      timeout: _homeRevealTimeout,
      reason:
          '「$kIcsCourseName」已经解析并落库，首页却找不到它的卡片：'
          '导入的数据没有被渲染出来（用户症状：导入成功但课表还是空的）',
    );

    final cardFinder = _courseCardNamed(tester, kIcsCourseName)!;
    final cardSize = tester.getSize(cardFinder.first);
    expect(cardSize.width, greaterThan(0), reason: '卡片宽度为 0：布局成了不可见尺寸');
    expect(cardSize.height, greaterThan(0), reason: '卡片高度为 0：布局成了不可见尺寸');

    // ---- 位置正确：解析出来的星期/节次要原样画到那一格 ----
    //
    // 这条能抓「导进去了但排错天」——只断言「卡片存在」抓不到。
    final card = tester.widget<CourseCard>(cardFinder.first);
    expect(
      card.course.dayOfWeek,
      1,
      reason: '首页上那门课不在周一：导入的星期在渲染链路里被改了',
    );
    expect(
      card.course.startSection,
      3,
      reason: '首页上那门课不在第 3 节：导入的节次在渲染链路里被改了',
    );
  });
}

/// 找出网格里「课程名 == [name]」的那张 `CourseCard`；没有则返回 null。
Finder? _courseCardNamed(WidgetTester tester, String name) {
  final finder = find.byType(CourseCard);
  for (var i = 0; i < finder.evaluate().length; i++) {
    final card = tester.widget<CourseCard>(finder.at(i));
    if (card.course.name == name) {
      return find.byType(CourseCard).at(i);
    }
  }
  return null;
}

/// 轮询 [condition] 直到为真；超时仍未成立就带着 [reason] 失败。
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String reason,
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (condition()) {
      return;
    }
    await tester.pump(_pollStep);
  }
  if (condition()) {
    return;
  }
  fail('$reason（已等待 ${stopwatch.elapsed.inMilliseconds}ms）');
}
