import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/lan_edit_provider_host.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 局域网"整组替换"接口的 id 守卫（2026-10-05 审查）。
///
/// `lan_edit_api_handlers.dart:454-460` 用 `existingId: slotMap['id'] as String?`
/// 把客户端给的 id 原样传下去，而 `LanEditProviderHost.courseFromApiJson`
/// （`lan_edit_provider_host.dart:477`）是
/// `id: existingId ?? _suppliedCourseId(json['id']) ?? const Uuid().v4()`。
/// `_suppliedCourseId` 会把空串/纯空白归一成 null（:44-49），但 `existingId`
/// 是 `''` 时 `??` 直接短路 —— 归一函数根本没有机会跑。后果：
/// - 造出一行 id 为空的课程，而路由是 `/api/v1/courses/([^/]+)`，空 id 永远
///   匹配不到 → 这一行在网页上再也改不动、删不掉；
/// - 删除按 id 等值摘除（`timetable/course_repository.dart:97` 的
///   `removeWhere((c) => c.id == courseId)`），于是"删一次掉两行"，
///   而批量计数只加 1 —— 与 `lan_edit_api_handlers.dart:154-160` 那段
///   `_rejectIdConflict` 自述的危害完全一致。
///
/// 另一半：`replaceCourseGroup`（:237-254）只在**新建分组**分支里逐条
/// `_rejectIdConflict(slot.id)`，改组分支（`updateCourseGroup`）完全不查 →
/// 客户端可以把某个 slot 的 id 写成"另一门不相干课程"的 id，整组替换后就出现
/// 两行同 id。本仓对 LAN 传来的 id 早就定了"撞车就拒"的口径（同文件 :161-176
/// 与 :173 的 createCourse 路径），这里是漏了分支，不是新规则。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableProvider provider;
  late LanEditProviderHost host;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = TimetableProvider(
      // 每个用例一份独立存储：原先用的是共享单例，前一个用例的课程会漏进下一个
      // （新 provider `initialize()` 从同一个单例里读到上一轮的内存态），
      // 于是「库里已有几个同 id」变成隐性依赖 —— 新加的用例单跑绿、全跑红。
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    host = LanEditProviderHost(provider);
  });

  tearDown(() {
    provider.dispose();
  });

  Course slot({required String id, required String name}) {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'teacher': '王老师',
      'location': 'A101',
      'dayOfWeek': 1,
      'startSection': 1,
      'endSection': 2,
    };
    // 与 handler 完全同一形状：json 里的 id 与 existingId 都给。
    return LanEditProviderHost.courseFromApiJson(
      json,
      sections: provider.settings.sections,
      semesterWeekCount: provider.settings.semesterWeekCount,
      existingId: json['id'] as String?,
    );
  }

  group('LAN 课程 id 守卫', () {
    test('空串 id 不能被接受：必须回落到新生成的 uuid', () {
      final built = slot(id: '', name: '大学英语');

      expect(
        built.id.trim(),
        isNotEmpty,
        reason: '空 id 的课程行再也无法被 /api/v1/courses/<id> 寻址，'
            '而且删除按 id 等值摘除会一次掉两行',
      );
    });

    test('整组替换时，slot 带着别的课程的 id 必须被拒', () async {
      await provider.addCourse(
        slot(id: 'owned-1', name: '高等数学'),
      );
      await provider.addCourse(
        slot(id: 'other-1', name: '线性代数'),
      );

      await expectLater(
        host.replaceCourseGroup(
          originalName: '高等数学',
          slots: [
            slot(id: 'other-1', name: '高等数学'),
          ],
        ),
        throwsA(isA<ArgumentError>()),
        reason: '改组分支不查撞车，就会造出两行同 id：删一次掉两行',
      );
      expect(
        provider.courses.where((course) => course.id == 'other-1'),
        hasLength(1),
      );
    });

    test('对照：改自己这一组（沿用本组 id）照常整组替换', () async {
      await provider.addCourse(slot(id: 'g1', name: '高等数学'));

      final saved = await host.replaceCourseGroup(
        originalName: '高等数学',
        slots: [
          slot(id: 'g1', name: '高等数学'),
          slot(id: '', name: '高等数学'),
        ],
      );

      expect(saved, hasLength(2));
      expect(
        provider.courses.where((course) => course.name == '高等数学'),
        hasLength(2),
      );
    });

    test('对照：新建分组时的撞车检查保持原样', () async {
      await provider.addCourse(slot(id: 'taken-1', name: '结构力学'));

      await expectLater(
        host.replaceCourseGroup(
          originalName: null,
          slots: [slot(id: 'taken-1', name: '新名字课程')],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('同一请求里两个 slot 用同一个 id 必须被拒（两道检查都漏这一维）', () async {
      await provider.addCourse(slot(id: 'g1', name: '高等数学'));

      await expectLater(
        host.replaceCourseGroup(
          originalName: '高等数学',
          slots: [
            slot(id: 'g1', name: '高等数学'),
            slot(id: 'g1', name: '高等数学'),
          ],
        ),
        throwsA(isA<ArgumentError>()),
        reason: '两个 slot 互相撞车时「库里有没有」一条都查不出来（本组 id 本来就算合法），'
            '整组替换后会留下两行同 id',
      );
      expect(
        provider.courses.where((course) => course.id == 'g1'),
        hasLength(1),
        reason: '拒单不得留下半单：整组替换必须整体不发生',
      );
    });

    test('对照：请求内 id 各不相同照常整组新建', () async {
      final saved = await host.replaceCourseGroup(
        originalName: null,
        slots: [
          slot(id: 'n1', name: '新组课程'),
          slot(id: 'n2', name: '新组课程'),
        ],
      );

      expect(saved, hasLength(2));
      expect(
        provider.courses.where((course) => course.name == '新组课程'),
        hasLength(2),
      );
    });
  });
}
