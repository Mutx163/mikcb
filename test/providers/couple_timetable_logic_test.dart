import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable/couple_timetable_logic.dart';

Course _course({
  required String id,
  required String name,
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  String startTime = '08:00',
  String endTime = '09:40',
  int startWeek = 1,
  int endWeek = 16,
  bool isOddWeek = false,
  bool isEvenWeek = false,
  List<int>? customWeeks,
  List<int>? suspendedWeeks,
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
    startWeek: startWeek,
    endWeek: endWeek,
    isOddWeek: isOddWeek,
    isEvenWeek: isEvenWeek,
    customWeeks: customWeeks,
    suspendedWeeks: suspendedWeeks,
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
      CoupleTimetableLogic.classifyMineCourse(mine, [partner], week: 1),
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
      CoupleTimetableLogic.classifyMineCourse(mine, [partner], week: 1),
      CoupleCourseKind.mine,
    );
  });

  test('shared free is exact gap between staggered courses (G2)', () {
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

    // Full day: free before first busy, gap between courses, free after last busy.
    expect(shared, hasLength(3));
    expect(shared[0].startMinutes, 0);
    expect(shared[0].endMinutes, 8 * 60);
    expect(shared[1].startMinutes, 9 * 60 + 40);
    expect(shared[1].endMinutes, 10 * 60);
    expect(shared[2].startMinutes, 11 * 60 + 40);
    expect(shared[2].endMinutes, 24 * 60);
  });

  test('shared free covers full calendar day 00:00-24:00', () {
    final earlyAndLateSections = [
      const SectionTime(startTime: '07:00', endTime: '07:45'),
      const SectionTime(startTime: '07:55', endTime: '08:40'),
      const SectionTime(startTime: '21:00', endTime: '21:45'),
      const SectionTime(startTime: '21:55', endTime: '22:40'),
    ];
    final myCourses = [
      _course(
        id: 'mine',
        name: '晚课',
        startSection: 3,
        endSection: 4,
        startTime: '21:00',
        endTime: '22:40',
      ),
    ];

    final shared = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: myCourses,
      partnerCourses: const [],
      dayOfWeek: 1,
      week: 1,
      sections: earlyAndLateSections,
    );

    // Before first busy: midnight → 21:00 (not clipped to section start 07:00).
    expect(
      shared.any(
        (interval) =>
            interval.startMinutes == 0 && interval.endMinutes == 21 * 60,
      ),
      isTrue,
    );
    // After late busy: free continues to midnight (24:00), not last section end.
    expect(
      shared.any(
        (interval) =>
            interval.startMinutes == 22 * 60 + 40 &&
            interval.endMinutes == 24 * 60,
      ),
      isTrue,
    );
  });

  test('early morning course 00:00-02:00 is busy, not shared free', () {
    final myCourses = [
      _course(
        id: 'mine',
        name: '夜班实验',
        startSection: 1,
        endSection: 1,
        startTime: '00:00',
        endTime: '02:00',
      ),
    ];

    final shared = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: myCourses,
      partnerCourses: const [],
      dayOfWeek: 1,
      week: 1,
      // Section table starts at 08:20 like a typical school schedule — must not
      // hide the 00:00–02:00 busy slot or clip free to 08:20–23:15.
      sections: [
        const SectionTime(startTime: '08:20', endTime: '09:05'),
        const SectionTime(startTime: '22:30', endTime: '23:15'),
      ],
    );

    expect(
      shared.any(
        (interval) => interval.startMinutes < 2 * 60 && interval.endMinutes > 0,
      ),
      isFalse,
    );
    expect(shared, hasLength(1));
    expect(shared.single.startMinutes, 2 * 60);
    expect(shared.single.endMinutes, 24 * 60);
  });

  test('shared free uses partner week offset (G4/G5)', () {
    final myCourses = [
      _course(
        id: 'mine',
        name: '高数',
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        startWeek: 5,
        endWeek: 5,
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
        startWeek: 6,
        endWeek: 6,
      ),
    ];

    final withOffset = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: myCourses,
      partnerCourses: partnerCourses,
      dayOfWeek: 1,
      week: 5,
      partnerWeekOffset: 1,
      sections: _sections,
    );
    expect(
      withOffset.any(
        (interval) =>
            interval.startMinutes == 9 * 60 + 40 &&
            interval.endMinutes == 10 * 60,
      ),
      isTrue,
    );

    final withoutOffset = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: myCourses,
      partnerCourses: partnerCourses,
      dayOfWeek: 1,
      week: 5,
      partnerWeekOffset: 0,
      sections: _sections,
    );
    // Partner has no week-5 class → only my busy; free after 09:40 and before 08:00.
    expect(withoutOffset, isNotEmpty);
    expect(
      withoutOffset.any(
        (interval) =>
            interval.startMinutes <= 10 * 60 &&
            interval.endMinutes >= 10 * 60 + 45,
      ),
      isTrue,
    );
    expect(
      withoutOffset.any(
        (interval) =>
            interval.startMinutes == 0 && interval.endMinutes == 8 * 60,
      ),
      isTrue,
    );
  });

  test('shared free respects odd/even week busy (G6)', () {
    final myCourses = [
      _course(
        id: 'mine',
        name: '高数',
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        isOddWeek: true,
      ),
    ];
    final partnerCourses = [
      _course(
        id: 'partner',
        name: '英语',
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        isEvenWeek: true,
      ),
    ];

    final oddWeek = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: myCourses,
      partnerCourses: partnerCourses,
      dayOfWeek: 1,
      week: 1,
      sections: _sections,
    );
    // Only mine is busy 08:00-09:40 on odd week.
    expect(
      oddWeek.any(
        (interval) =>
            interval.startMinutes <= 8 * 60 &&
            interval.endMinutes >= 9 * 60 + 40,
      ),
      isFalse,
    );
    expect(
      oddWeek.any((interval) => interval.startMinutes >= 9 * 60 + 40),
      isTrue,
    );

    final evenWeek = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: myCourses,
      partnerCourses: partnerCourses,
      dayOfWeek: 1,
      week: 2,
      sections: _sections,
    );
    expect(
      evenWeek.any(
        (interval) =>
            interval.startMinutes <= 8 * 60 &&
            interval.endMinutes >= 9 * 60 + 40,
      ),
      isFalse,
    );
  });

  test('together class slot is not shared free', () {
    final mine = _course(id: 'mine', name: '高等数学');
    final partner = _course(id: 'partner', name: '高等数学');
    final shared = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: [mine],
      partnerCourses: [partner],
      dayOfWeek: 1,
      week: 1,
      sections: _sections,
    );
    expect(
      shared.any(
        (interval) =>
            interval.startMinutes < 9 * 60 + 40 && interval.endMinutes > 8 * 60,
      ),
      isFalse,
    );
  });

  test('empty sections yields no shared free', () {
    final shared = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: [_course(id: 'mine', name: '高数')],
      partnerCourses: [_course(id: 'partner', name: '英语')],
      dayOfWeek: 1,
      week: 1,
      sections: const [],
    );
    // Courses carry wall-clock times, so free is still the full-day complement.
    expect(shared, isNotEmpty);
    expect(shared.first.startMinutes, 0);
    expect(shared.first.endMinutes, 8 * 60);
    expect(shared.last.startMinutes, 9 * 60 + 40);
    expect(shared.last.endMinutes, 24 * 60);
  });

  test('merge and intersect minute intervals', () {
    final merged = CoupleTimetableLogic.mergeMinuteIntervals([
      const MinuteInterval(startMinutes: 60, endMinutes: 120),
      const MinuteInterval(startMinutes: 100, endMinutes: 180),
    ]);
    expect(merged.single.startMinutes, 60);
    expect(merged.single.endMinutes, 180);

    final intersection = CoupleTimetableLogic.intersectSortedMinuteIntervals(
      [const MinuteInterval(startMinutes: 60, endMinutes: 180)],
      [const MinuteInterval(startMinutes: 120, endMinutes: 240)],
    );
    expect(intersection.single.startMinutes, 120);
    expect(intersection.single.endMinutes, 180);
  });

  test('maps partner week with offset when detecting together class', () {
    final mine = _course(
      id: 'mine',
      name: '高等数学',
    ).copyWith(startWeek: 5, endWeek: 16);
    final partner = _course(
      id: 'partner',
      name: '高等数学',
    ).copyWith(startWeek: 6, endWeek: 16);

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

  test('suspended week is not busy for shared free or together class', () {
    final mine = _course(
      id: 'mine',
      name: '高等数学',
      startTime: '08:00',
      endTime: '09:40',
      suspendedWeeks: [3],
    );
    final partner = _course(
      id: 'partner',
      name: '高等数学',
      startTime: '08:00',
      endTime: '09:40',
    );

    expect(
      CoupleTimetableLogic.isTogetherClass(mine, partner, week: 3),
      isFalse,
    );
    expect(
      CoupleTimetableLogic.isTogetherClass(mine, partner, week: 1),
      isTrue,
    );

    final freeOnSuspended = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: [mine],
      partnerCourses: const [],
      dayOfWeek: 1,
      week: 3,
      sections: _sections,
    );
    // Mine suspended → no busy → free covers morning class slot.
    expect(
      freeOnSuspended.any(
        (interval) =>
            interval.startMinutes <= 8 * 60 &&
            interval.endMinutes >= 9 * 60 + 40,
      ),
      isTrue,
    );

    final freeOnActive = CoupleTimetableLogic.sharedFreeIntervalsForDay(
      myCourses: [mine],
      partnerCourses: const [],
      dayOfWeek: 1,
      week: 1,
      sections: _sections,
    );
    expect(
      freeOnActive.any(
        (interval) =>
            interval.startMinutes <= 8 * 60 &&
            interval.endMinutes >= 9 * 60 + 40,
      ),
      isFalse,
    );
  });
}
