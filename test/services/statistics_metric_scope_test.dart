import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/services/statistics_service.dart';

/// 统计里的三处口径错误（回归钉，2026-10-02）。
///
/// 1. 「教学楼课时」卡面写「节」，喂进去的却是**到访周数**：`roomCounts` 累加的
///    是 `activeWeeks`（教室行的「N 次」正是这个口径），楼栋行又原样把这份计数
///    当作课时上报。两节大课连上 16 周，教室行「16 次」对，楼栋行显示「16 节」，
///    正确值是 32 节（`sectionCount × activeWeeks`，与教师/课程统计同一口径）。
/// 2. 钟点串用字符串比较（`startTime.compareTo('08:00') <= 0` 判早八、
///    `compareTo('12:00') < 0` 判上午）。空串按字典序恒小于任何非空串，所以
///    **作息按位补空产生的空钟点课**会被算进早八课时与上午占比：分子被撑大、
///    成就 `early_bird` 提前解锁、`morning_person` 进度虚高。同时未补零的
///    `8:00`（'8' > '0'）反而被判定不是早八。
/// 3. 「单日跨教学楼数」没有像另两处那样过滤空教室，`_buildingOf('')` 原样返回
///    空串并进集合 → 一节无教室的线上课被算成第 N 栋楼，成就 `building_hopper`
///    提前解锁。
void main() {
  Course course({
    required String id,
    required String location,
    required int dayOfWeek,
    required int startSection,
    required int endSection,
    required String startTime,
    required String endTime,
    int startWeek = 1,
    int endWeek = 16,
  }) {
    return Course(
      id: id,
      name: '课程$id',
      teacher: '张老师',
      location: location,
      dayOfWeek: dayOfWeek,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      startWeek: startWeek,
      endWeek: endWeek,
    );
  }

  List<Achievement> achievements(List<Course> courses, int week) =>
      StatisticsService.calculateAchievements(
        allCourses: courses,
        currentWeek: week,
      );

  Achievement byId(List<Achievement> items, String id) => items.firstWhere(
    (item) => item.id == id,
    orElse: () => throw StateError('缺少成就 $id'),
  );

  group('教学楼课时口径', () {
    test('楼栋累加的是课时而不是到访周数', () {
      final stats = StatisticsService.calculateVenueStats(
        allCourses: [
          course(
            id: 'a',
            location: '教A-101',
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            startTime: '08:00',
            endTime: '09:40',
          ),
        ],
        currentWeek: 16,
      );

      // 教室行仍是「到访 16 次」，楼栋行必须是 2 节 × 16 周 = 32 节。
      expect(stats.topRooms.single.visits, 16);
      expect(stats.buildings.single.sections, 32);
    });
  });

  group('空钟点不参与早八与上午占比', () {
    test('洞节次的空钟点不算早八，未补零的 8:00 算', () {
      final achievementsList = achievements([
        course(
          id: 'blank',
          location: '教A-101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '',
          endTime: '',
        ),
        course(
          id: 'early',
          location: '教A-102',
          dayOfWeek: 2,
          startSection: 1,
          endSection: 1,
          startTime: '8:00',
          endTime: '8:45',
        ),
      ], 16);

      expect(
        byId(achievementsList, 'early_bird').progressCurrent,
        1,
        reason: '只有 8:00 那节算早八；空钟点不能按字典序当「≤08:00」',
      );
    });

    test('空钟点不撑大上午占比', () {
      final list = achievements([
        course(
          id: 'morning',
          location: '教A-101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
        course(
          id: 'blank',
          location: '教B-101',
          dayOfWeek: 3,
          startSection: 5,
          endSection: 6,
          startTime: '',
          endTime: '',
        ),
      ], 16);

      // 分子=2、分母=4（分母是全部课时，包含无时间的课）→ 50%。
      // 修复前空串被判为上午，进度虚高成 100%。
      expect(byId(list, 'morning_person').progressCurrent, 50);
    });
  });

  group('单日跨教学楼数', () {
    test('无教室的课不算一栋楼', () {
      final list = achievements([
        course(
          id: 'a',
          location: 'A-101',
          dayOfWeek: 3,
          startSection: 1,
          endSection: 1,
          startTime: '08:00',
          endTime: '08:45',
        ),
        course(
          id: 'b',
          location: 'B-203',
          dayOfWeek: 3,
          startSection: 3,
          endSection: 3,
          startTime: '10:00',
          endTime: '10:45',
        ),
        course(
          id: 'online',
          location: '',
          dayOfWeek: 3,
          startSection: 5,
          endSection: 5,
          startTime: '14:00',
          endTime: '14:45',
        ),
      ], 16);

      expect(
        byId(list, 'building_hopper').progressCurrent,
        2,
        reason: '周三只有 A、B 两栋楼，线上课不该算第三栋',
      );
    });
  });
}
