import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/lan_edit_provider_host.dart';

/// PATCH 的合并基线必须在**写锁之内**取（2026-10-05 审查）。
///
/// `lan_edit_api_handlers.dart` 的 `_handlePatchCourse` 原先是这样排序的：
/// `existing = host.findCourse(id)` → `await _readJsonBody(request)`（读取体预算最长
/// 20 秒，见 `_bodyReadBudget`）→ `await _ensureWriteProfileTarget(...)` →
/// `mergeCoursePatch(existing, patch)` → `await host.updateCourse(updated)`。
/// 后两步之间那两个真实 await 就是竞态窗口：期间本机的任何改动（手机还停在编辑页、
/// 另一台设备刚写过的字段、导入或云同步落下的更新）都会被"过期基线 + 整份 Course
/// 覆盖"静默抹掉，而 HTTP 还回 200 并把请求体原样回显 —— 网页显示"已保存"，
/// 手机上那次改动凭空消失，且没有任何错误信号。
///
/// 同仓另外两处已经承认并收口过同一族危险（`lan_edit_provider_host.dart` 里
/// `updateCourse` 的事后置条件、`unified_transfer_service.dart` 的快照-应用-回滚 +
/// `test/services/transfer_rollback_atomicity_test.dart`），唯独 PATCH 这条读-改-写
/// 还在门外。修法是把整段读-改-写搬进 `host.mutateCourse`（provider 侧走
/// `runMutationExclusive`）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const courseId = 'c1';

  Course baseCourse() => Course(
    id: courseId,
    name: '高等数学',
    teacher: '王老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  Future<(TimetableProvider, LanEditProviderHost)> boot() async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(baseCourse());
    return (provider, LanEditProviderHost(provider));
  }

  Course stored(TimetableProvider provider) => provider.courses.firstWhere(
    (course) => course.id == courseId,
  );

  group('mutateCourse 的锁内读-改-写', () {
    test('基线在读到写锁之后取：门被占着时不许提前读，也不许覆盖门内的写', () async {
      final (provider, host) = await boot();

      final started = Completer<void>();
      var releaseGate = false;
      // 模拟"本机正在写这门课"：占住门，等外部信号后再改 location。
      final holder = provider.runMutationExclusive(() async {
        started.complete();
        while (!releaseGate) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await provider.updateCourse(
          stored(provider).copyWith(location: '本机改的教室'),
        );
      });
      await started.future;

      Course? baseline;
      var transformRan = false;
      final patchWrite = host.mutateCourse(courseId, (existing) async {
        transformRan = true;
        baseline = existing;
        return existing.copyWith(teacher: '网页改的老师');
      });

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        transformRan,
        isFalse,
        reason: '门被占着时必须还在排队 —— 提前读基线就是这条缺陷的本质',
      );

      releaseGate = true;
      final saved = await patchWrite;
      await holder;

      expect(
        baseline?.location,
        '本机改的教室',
        reason: '基线必须是锁内读到的那一份，否则本机刚写的教室会被过期基线抹掉',
      );
      expect(saved, isNotNull);
      expect(stored(provider).teacher, '网页改的老师');
      expect(
        stored(provider).location,
        '本机改的教室',
        reason: '两个写者都要留下自己的字段，而不是后写者整份覆盖',
      );
    });

    test('记录在锁外被删掉时返回 null，回调不许执行', () async {
      final (provider, host) = await boot();

      var invoked = false;
      final deletion = provider.runMutationExclusive(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await provider.deleteCourse(courseId);
      });
      final result = await host.mutateCourse(courseId, (existing) async {
        invoked = true;
        return existing.copyWith(teacher: '不该被写');
      });
      await deletion;

      expect(result, isNull);
      expect(
        invoked,
        isFalse,
        reason: '没有基线就没有可合并的对象，回调执行只会把课表里的行凭空加回来',
      );
    });

    test('回调抛错时不写任何东西，错误原样交给调用方', () async {
      final (provider, host) = await boot();

      await expectLater(
        host.mutateCourse(courseId, (existing) async {
          throw ArgumentError('course_name_required');
        }),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        stored(provider).name,
        '高等数学',
        reason: '校验失败必须发生在写之前，且不能留下半套状态',
      );
    });
  });
}
