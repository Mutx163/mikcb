import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/providers/timetable/couple_timetable_logic.dart';

Course _course({
  required String id,
  required String name,
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  String startTime = '08:00',
  String endTime = '09:40',
}) {
  return Course(
    id: id,
    name: name,
    teacher: 'T',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
  );
}

final _sections = [
  const SectionTime(startTime: '08:00', endTime: '08:45'),
  const SectionTime(startTime: '08:55', endTime: '09:40'),
  const SectionTime(startTime: '10:00', endTime: '10:45'),
  const SectionTime(startTime: '10:55', endTime: '11:40'),
];

void main() {
  test('detects together class when names match and sections overlap', () {
    final mine = _course(id: 'mine', name: '高等数学');
    final partner = _course(id: 'partner', name: '高等数学');

    expect(
      CoupleTimetableLogic.isTogetherClass(mine, partner, week: 1),
      isTrue,
    );
    expect(
      CoupleTimetableLogic.classifyMineCourse(
        mine,
        [partner],
        week: 1,
      ),
      CoupleCourseKind.together,
    );
  });

  test('does not mark together when only time overlaps', () {
    final mine = _course(id: 'mine', name: '高等数学');
    final partner = _course(id: 'partner', name: '大学英语');

    expect(
      CoupleTimetableLogic.isTogetherClass(mine, partner, week: 1),
      isFalse,
    );
    expect(
      CoupleTimetableLogic.classifyMineCourse(
        mine,
        [partner],
        week: 1,
      ),
      CoupleCourseKind.mine,
    );
  });

  test('computes shared free intervals with two-pointer intersection', () {
    final myCourses = [
      _course(
        id: 'mine',
        name: '高数',
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    ];
    final partnerCourses = [
      _course(
        id: 'partner',
        name: '英语',
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ),
    ];

    final shared = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: myCourses,
      partnerCourses: partnerCourses,
      dayOfWeek: 1,
      week: 1,
      sections: _sections,
    );

    expect(shared, isNotEmpty);
    expect(shared.first.startMinutes, greaterThanOrEqualTo(9 * 60 + 40));
    expect(shared.last.endMinutes, lessThanOrEqualTo(10 * 60));
  });

  test('merge and intersect minute intervals', () {
    final merged = CoupleTimetableLogic.mergeMinuteIntervals([
      const MinuteInterval(startMinutes: 60, endMinutes: 120),
      const MinuteInterval(startMinutes: 100, endMinutes: 180),
    ]);
    expect(merged.single.startMinutes, 60);
    expect(merged.single.endMinutes, 180);

    final intersection = CoupleTimetableLogic.intersectSortedMinuteIntervals(
      [
        const MinuteInterval(startMinutes: 60, endMinutes: 180),
      ],
      [
        const MinuteInterval(startMinutes: 120, endMinutes: 240),
      ],
    );
    expect(intersection.single.startMinutes, 120);
    expect(intersection.single.endMinutes, 180);
  });

  test('maps partner week with offset when detecting together class', () {
    final mine = _course(id: 'mine', name: '高等数学').copyWith(
      startWeek: 5,
      endWeek: 16,
    );
    final partner = _course(id: 'partner', name: '高等数学').copyWith(
      startWeek: 6,
      endWeek: 16,
    );

    expect(
      CoupleTimetableLogic.isTogetherClass(mine, partner, week: 5),
      isFalse,
    );
    expect(
      CoupleTimetableLogic.isTogetherClass(
        mine,
        partner,
        week: 5,
        partnerWeekOffset: 1,
      ),
      isTrue,
    );
    expect(CoupleTimetableLogic.partnerWeekForMyWeek(5, 1), 6);
    expect(CoupleTimetableLogic.clampWeekOffset(99), 15);
    expect(CoupleTimetableLogic.clampWeekOffset(-99), -15);
  });
}
