import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/services/statistics_service.dart';

/// 数据故事卡的「最常去的教室」必须跳过本周还没开课的课（第 32 轮）。
///
/// 缺陷：`statistics_service.dart:309-316` 把 `allCourses` 里**所有**有地点的课
/// 都累进 `roomCounts`，累的值是 `_countActiveWeeks(course, currentWeek)`，
/// 却没有像同文件 `:703-707`（`calculateVenueStats`，同一页的另一张卡）那样
/// `if (activeWeeks == 0) continue;`。于是第 3 周时一门第 10 周才开的课
/// 也进了候选集，卡片文案变成「你最常去的教室是 B101，共去了 **0** 次」
/// （`app_zh.arb` 的 favoriteRoom 模板），全为 0 时 `sortedRooms.first`
/// 退化成"取第一条课程"；:335 的楼栋数也把没开课的教室算进去，
/// 与同一页 `calculateVenueStats` 的楼栋数互相打脸。
///
/// 同文件 :335-337 的注释记着 ff0ae83d 修过"两份提取口径分叉"这一类问题，
/// 这次是同一族的漏网处。
void main() {
  Course course({
    required String id,
    required String location,
    required int startWeek,
    required int endWeek,
    int dayOfWeek = DateTime.monday,
  }) {
    return Course(
      id: id,
      name: '课$id',
      teacher: '老师',
      location: location,
      dayOfWeek: dayOfWeek,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      startWeek: startWeek,
      endWeek: endWeek,
    );
  }

  List<DataStory> stories({
    required List<Course> courses,
    required int currentWeek,
  }) {
    return StatisticsService.generateDataStories(
      allCourses: courses,
      currentWeek: currentWeek,
    );
  }

  Iterable<DataStory> favorites(List<DataStory> stories) {
    return stories.where((story) => story.type == StoryType.favoriteRoom);
  }

  test('本周之前还没开课时，不发「最常去的教室」故事', () {
    // 第 3 周，唯一的课第 10 周才开 —— 到访次数是 0，这张卡不该出现。
    final result = stories(
      courses: [
        course(id: 'late', location: 'B101', startWeek: 10, endWeek: 16),
      ],
      currentWeek: 3,
    );

    expect(
      favorites(result),
      isEmpty,
      reason: '门都没开过的教室不能当"最常去"，更不能写着「共去了 0 次」',
    );
  });

  test('活跃教室照常被选出，且未开课的教室不参与', () {
    final result = stories(
      courses: [
        course(id: 'active', location: 'A101', startWeek: 1, endWeek: 4),
        course(id: 'late', location: 'B101', startWeek: 10, endWeek: 16),
      ],
      currentWeek: 3,
    );

    final favorite = favorites(result).single;
    expect(favorite.room, 'A101');
    expect(favorite.visitCount, 3);
    expect(
      result.any((story) => story.room == 'B101'),
      isFalse,
      reason: '第 10 周才开的教室不该出现在任何故事里',
    );
  });
}
