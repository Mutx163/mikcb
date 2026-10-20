import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/statistics_export_options.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/widgets/statistics/statistics_export_document.dart';
import 'package:university_timetable/widgets/timetable_share_export.dart';

/// 分享链路「文档组装上移」的**参数透传契约**（task-10）。
///
/// 背景：`services/statistics_share_service.dart` 与
/// `services/timetable_share_service.dart` 原先自己拼导出文档，为此反向 import
/// 了 `widgets/`（统计另加 `ui/`，课表另加 `providers/`）。改法是**文档构造
/// 上移给调用方**：服务只收一个已拼好的 `Widget`。
///
/// 这类改动最大的风险不是「图出不来」，而是**参数在中间层被吞掉**——用户看到
/// 的是「图能分享，但分享的是整周而不是那一天」。存量测试一个都抓不到：
/// `test/widgets/timetable_export_document_test.dart` 直接构造文档，绕过了
/// 组装这一层。所以这里**直接对着文档实例的字段断言**，不 pump、不渲染。
///
/// 咬合探针（做完请做一遍）：把 `timetableShareDocument` 里的
/// `dayOfWeek: dayOfWeek,` 删掉 → 第 2 条必须红。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
  });

  group('课表分享：文档组装透传', () {
    test('week / dayOfWeek 原样进入文档（日视图不能退化成整周）', () {
      final document = timetableShareDocument(
        provider: provider,
        settings: provider.settings,
        week: 11,
        dayOfWeek: 3,
      );

      expect(document.week, 11, reason: '周次丢了，分享出去的就是别的周');
      expect(
        document.dayOfWeek,
        3,
        reason: '日视图退化成整周 —— 用户点「分享这一天」却拿到整张周表',
      );
      expect(
        identical(document.settings, provider.settings),
        isTrue,
        reason: '设置对象应原样转手（文档内部靠它清壁纸、定底色的入口）',
      );
    });

    test('dayOfWeek 为空 = 整周（周视图），不是被默认成周一', () {
      final document = timetableShareDocument(
        provider: provider,
        settings: provider.settings,
        week: 5,
      );

      expect(document.week, 5);
      expect(
        document.dayOfWeek,
        isNull,
        reason: 'null 表示整周；补成 1 会把周视图分享成「只有周一」',
      );
    });

    test('provider 实例原样转手（文档读的是同一份课表状态）', () {
      final document = timetableShareDocument(
        provider: provider,
        settings: provider.settings,
        week: 1,
      );

      expect(identical(document.provider, provider), isTrue);
    });
  });

  group('统计分享：文档组装透传', () {
    test('options / 列表原样进入文档', () {
      // 统计侧由屏层直接 `StatisticsExportDocument(...)` 组装（无中间函数），
      // 这里钉的是「服务改成收 Widget 之后，屏层该传什么」这件事仍然成立。
      const options = StatisticsExportOptions(
        modules: {StatisticsExportModule.overview},
      );
      const stats = SemesterStats(
        totalCourses: 7,
        totalSections: 42,
        totalWeeks: 20,
        longestStreak: 5,
        dailyAverages: [],
        natureStats: CourseNatureStats(
          requiredCount: 3,
          electiveCount: 4,
          requiredSections: 20,
          electiveSections: 22,
        ),
        courseRanking: [],
      );

      const document = StatisticsExportDocument(
        options: options,
        semesterStats: stats,
        achievements: [],
        stories: [],
      );

      expect(document.options, same(options));
      expect(document.semesterStats, same(stats));
      expect(document.achievements, isEmpty);
      expect(document.stories, isEmpty);
    });
  });
}
