import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/class_reminder.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/class_reminder_service.dart';
import 'package:university_timetable/services/exam_reminder_service.dart';

/// 回归钉（第二十二轮，requestCode 去重登记表与实际发出的码）：
///
/// `assignDistinctRequestCodes`（exam_reminder_service.dart:100-129）的候选码
/// 一律**重算**：`stableRequestCode(fire.examId, fire.offsetMinutes)`（:114），
/// 撞了就换码，`probe == 0` 时原样返回 `fire`（:124）—— 于是登记进 `taken`
/// 的是"重算出来的码"，而真正随快照发给原生的是 `fire.requestCode`。
///
/// 三个生产源里有两个恰好相等（:241 日程、:365 考试都写成
/// `stableRequestCode(id, offsetMinutes)`），第三个不是：单节课提醒
/// （class_reminder_service.dart:110）的真实码是
/// `stableRequestCode(entry.id, entry.minuteOfDay)`，而它的 `offsetMinutes`
/// 被**刻意**固定为 0（同文件 :100-107 的注释说明为什么要这样填）。
/// `reconcile`（:405-413）把这一路作为 `additionalFires` 合进同一个批次。
/// 结果：单节课提醒实际占用码从未进登记表，别的 fire 撞上它时不被判为冲突，
/// 两条拿到同一个 PendingIntent 身份，原生
/// `getBroadcast(FLAG_UPDATE_CURRENT)` 让后写入的整条顶掉前一条 —— 正是
/// :86-95 这段注释声称要堵死的故障。
void main() {
  ExamReminderFire fire({
    required String examId,
    required int offsetMinutes,
    required int requestCode,
    int fireAtMillis = 1_000_000,
  }) => ExamReminderFire(
    examId: examId,
    offsetMinutes: offsetMinutes,
    fireAtMillis: fireAtMillis,
    examStartMillis: fireAtMillis,
    title: '提醒',
    body: '',
    requestCode: requestCode,
  );

  group('单节课提醒的码与重算值不同源', () {
    test('buildFires 产出的码不等于 stableRequestCode(examId, offsetMinutes)', () {
      const entry = ClassReminderEntry(
        courseId: 'course-1',
        date: '2026-03-01',
        minuteOfDay: 540,
      );
      expect(entry.id, 'classreminder:course-1@2026-03-01');

      final built = ClassReminderService.buildFires(
        entries: [entry],
        resolveCourse: (_) => Course(
          id: 'course-1',
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '09:00',
          endTime: '10:40',
        ),
        now: DateTime(2026), // 2026-01-01 本地零点
      );

      expect(built, hasLength(1));
      // 这条断言就是"候选码不能重算"的前提：offsetMinutes 是 0，
      // 而实际码含 minuteOfDay。
      expect(
        built.single.requestCode,
        isNot(
          ExamReminderService.stableRequestCode(
            built.single.examId,
            built.single.offsetMinutes,
          ),
        ),
      );
    });
  });

  group('登记表必须记实际发出去的码', () {
    test(
      '单节课提醒实际占用的码与考试火撞名时，必须消解而不是双双原样返回',
      () {
        // 复现真实形状：class 提醒带着它自己的码（含 minuteOfDay），
        // 恰好等于另一条考试 fire 按 (examId, offsetMinutes) 算出的自然码。
        final examCode = ExamReminderService.stableRequestCode('exam-7', 30);
        final classFire = fire(
          examId: 'classreminder:course-1@2026-03-01',
          offsetMinutes: 0,
          requestCode: examCode,
          fireAtMillis: 10,
        );
        final examFire = fire(
          examId: 'exam-7',
          offsetMinutes: 30,
          requestCode: examCode,
          fireAtMillis: 20,
        );

        final assigned = ExamReminderService.assignDistinctRequestCodes([
          classFire,
          examFire,
        ]);

        expect(
          assigned.map((f) => f.requestCode).toSet(),
          hasLength(2),
          reason: '同一个 PendingIntent 身份只能有一条：原生是后写顶掉前写',
        );
        // 排序后 'classreminder:…' 字典序在前，它先占自己实际携带的码，
        // 后一条才被换码（消解只动撞上的那一条）。
        expect(
          assigned.firstWhere((f) => f.examId == classFire.examId).requestCode,
          examCode,
        );
      },
    );

    test('两条携带同一个码的 fire 不会一起原样通过', () {
      final shared = ExamReminderService.stableRequestCode('whatever', 123);
      final assigned = ExamReminderService.assignDistinctRequestCodes([
        fire(examId: 'a', offsetMinutes: 0, requestCode: shared, fireAtMillis: 1),
        fire(examId: 'b', offsetMinutes: 0, requestCode: shared, fireAtMillis: 2),
      ]);

      expect(assigned.map((f) => f.requestCode).toSet(), hasLength(2));
    });

    test('码本来自然相等时仍然换码（不破坏既有消解行为）', () {
      final assigned = ExamReminderService.assignDistinctRequestCodes([
        fire(
          examId: 'a',
          offsetMinutes: 30,
          requestCode: ExamReminderService.stableRequestCode('a', 30),
          fireAtMillis: 1,
        ),
        fire(
          examId: 'a',
          offsetMinutes: 30,
          requestCode: ExamReminderService.stableRequestCode('a', 30),
          fireAtMillis: 2,
        ),
      ]);

      expect(assigned.map((f) => f.requestCode).toSet(), hasLength(2));
    });

    test('分配结果只取决于集合，与拼装顺序无关', () {
      final examCode = ExamReminderService.stableRequestCode('exam-7', 30);
      final batch = [
        fire(
          examId: 'classreminder:course-1@2026-03-01',
          offsetMinutes: 0,
          requestCode: examCode,
          fireAtMillis: 10,
        ),
        fire(
          examId: 'exam-7',
          offsetMinutes: 30,
          requestCode: examCode,
          fireAtMillis: 20,
        ),
        fire(
          examId: 'exam-8',
          offsetMinutes: 15,
          requestCode: ExamReminderService.stableRequestCode('exam-8', 15),
          fireAtMillis: 30,
        ),
      ];

      final forward = ExamReminderService.assignDistinctRequestCodes(batch);
      final reversed = ExamReminderService.assignDistinctRequestCodes(
        batch.reversed.toList(),
      );

      for (final item in forward) {
        expect(
          reversed
              .firstWhere(
                (f) =>
                    f.examId == item.examId &&
                    f.fireAtMillis == item.fireAtMillis,
              )
              .requestCode,
          item.requestCode,
        );
      }
    });
  });
}
