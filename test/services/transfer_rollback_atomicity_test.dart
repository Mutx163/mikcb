import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/transfer_package.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';

/// 合并导入的失败回滚必须是**一次原子操作**（回归钉，2026-10-02）。
///
/// 原来的 `applyToProvider`：快照在 `runMutationExclusive` **门外**生成
/// （`unified_transfer_service.dart:407-424`），catch 里的 `_restore` 也在门外
/// （`:452`），而 `_restore` 自己又是三次各自独立的加锁写（`:842-860`）。
/// 于是：
/// - 取快照与拿到锁之间的写入（别的标签页刚 PATCH 成功、HTTP 已回 200）会被
///   回滚静默抹掉；
/// - 回滚三步之间任何写入都能插进来，形成半回滚；
/// - `_restore` 自身抛出时，异常直接从 catch 里逃出去，破坏
///   「applyToProvider 不抛异常，只返回 TransferApplyResult」的调用方契约。
///
/// 失败注入用的是设备级日期规则条数上限（`maxRulesPerDevice = 2`）：
/// `_merge` 先导入课程（`:620`），最后才在 `_mergeRulesAndLocations` 里
/// 被 `provider.replaceScheduleDateRules` 抛 ArgumentError —— 前半单已落盘，
/// 回滚必须把它撤干净。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TimetableProvider> booted() async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      Course(
        id: 'local-1',
        name: '本地课程',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    return provider;
  }

  /// 本机的 + 包内三节日期规则（合并后 3 > 2，落盘时被拒）。
  TransferPackage threeRulePackage(
    UnifiedTransferService service,
    TimetableProvider provider,
  ) {
    final base =
        jsonDecode(
          service.buildCurrentPackage(provider: provider).encode(),
        ) as Map<String, dynamic>;
    base['scheduleDateRules'] = [
      for (var index = 0; index < 3; index++)
        {
          'id': 'r-$index',
          'name': '规则$index',
          'timeSchemeId': 'scheme-1',
          'enabled': false,
          'startDate': '2026-0${index + 1}-01',
          'endDate': '2026-0${index + 1}-02',
        },
    ];
    // 规则引用的作息必须随包携带，否则 _diffService.validate 会以
    // time_rule_scheme_missing 直接拒单（那是校验失败，不是回滚路径）。
    base['timeSchemes'] = [
      {
        'id': 'scheme-1',
        'name': '包内作息',
        'sections': [
          {'startTime': '08:00', 'endTime': '08:45'},
          {'startTime': '08:55', 'endTime': '09:40'},
        ],
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      },
    ];
    // 包内课程换成一个本机没有的 id：回滚必须把它撤掉，测试才看得出差别。
    final localCourse = (base['courses'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .first;
    base['courses'] = [
      Map<String, dynamic>.from(localCourse)
        ..['id'] = 'new-in-package'
        ..['name'] = '包内课程',
    ];
    return service.parseCompatible(
      jsonEncode(base),
      channel: TransferChannel.file,
    );
  }

  test('导入失败后状态整体还原，且 applyToProvider 只返回结果不抛异常', () async {
    final provider = await booted();
    addTearDown(provider.dispose);
    final service = UnifiedTransferService();
    final incoming = threeRulePackage(service, provider);

    final result = await service.applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );

    expect(result.applied, isFalse);
    expect(result.error, 'transfer_import_failed');
    expect(result.undoToken, isNull, reason: '失败的单子不该留下可撤销的令牌');
    // 包内课程被撤掉，本机课程与规则表原样保留。
    expect(provider.courses.map((c) => c.id), contains('local-1'));
    expect(
      provider.courses.map((c) => c.id),
      isNot(contains('new-in-package')),
      reason: '`_merge` 已 importParsedCourses，回滚必须撤销这半单',
    );
    expect(provider.scheduleDateRules, isEmpty);
  });

  test('回滚期间到达的并发写入不被抹掉', () async {
    final provider = await booted();
    addTearDown(provider.dispose);
    final service = UnifiedTransferService();
    final incoming = threeRulePackage(service, provider);

    // 同一轮事件循环里并发发起：导入与一条普通写请求争同一把写锁。
    final importFuture = service.applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );
    final concurrentWrite = provider.addCourse(
      Course(
        id: 'concurrent-1',
        name: '并发新增的课',
        teacher: '李老师',
        location: 'B301',
        dayOfWeek: 3,
        startSection: 1,
        endSection: 1,
        startTime: '10:00',
        endTime: '10:45',
      ),
    );

    final result = await importFuture;
    await concurrentWrite;

    expect(result.applied, isFalse);
    expect(
      provider.courses.map((c) => c.id),
      contains('concurrent-1'),
      reason: '并发写与失败的导入无关：快照与 _restore 都在门外时，'
          '它会被按更早的快照整表覆盖掉',
    );
    expect(
      provider.courses.map((c) => c.id),
      isNot(contains('new-in-package')),
    );
  });

  test('失败导入不留撤销令牌，成功导入才留', () async {
    final provider = await booted();
    addTearDown(provider.dispose);
    // 另一台设备：课程 id 不冲突，合并应当成功并留下可撤销令牌。
    final source = await booted();
    addTearDown(source.dispose);
    await source.addCourse(
      Course(
        id: 'src-1',
        name: '来源课程',
        teacher: '王老师',
        location: 'C202',
        dayOfWeek: 5,
        startSection: 3,
        endSection: 4,
        startTime: '14:00',
        endTime: '15:40',
      ),
    );
    final service = UnifiedTransferService();
    final incoming = service.buildCurrentPackage(provider: source);

    final result = await service.applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: TransferApplyMode.merge,
    );

    expect(result.applied, isTrue, reason: result.error ?? 'ok');
    expect(result.undoToken, isNotNull);
    expect(provider.courses.map((c) => c.id), contains('src-1'));
  });
}
