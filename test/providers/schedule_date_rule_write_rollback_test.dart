import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 日期规则这一族的「改内存 → 落盘失败」必须整体退回（2026-10-05 审查）。
///
/// 本仓已经反复确立过这个形状：`_applySavedThemes`（主题族）、
/// `_commitLocationGroupChange`（地点分组族）、`_timetableCreateTimeScheme` /
/// `_timetableApplyTimeScheme`（作息族）、`deleteProfile` 都是「先抓旧值 → await
/// 落库 → catch 里回滚并 rethrow」。理由写在它们各自的注释里：这些类大量入口是
/// 「先改内存、后写盘」，落盘抛错（磁盘满、`commit()` 返回 false）时内存已变、盘上
/// 没变，而下一次任意成功写入会经 `_mergeActiveProfileIntoProfilesList` 把这份从未
/// 落库的改动当成既有状态落盘 —— 用户视角是"明明弹了失败，过几天课表真的变了"。
///
/// 日期规则（`schedule_date_rule_*`）这一族当时漏了：
/// · `_applyDueScheduleDateRulesDetailed` 会把**每一个** profile 的
///   `settings.activeTimeSchemeId` / 节次表换掉，并按新节次表重写所有未锁课程的
///   钟点，然后才 `await saveProfiles(_profiles)`（`timetable_provider.dart:1835-1868`），
///   中间没有任何 try/catch；
/// · 紧接着 `_scheduleDateRuleLastAppliedSignature = signature`（:1869）在
///   `saveScheduleDateRuleLastAppliedSignature`（:1870）**之前**就写进内存；
/// · create / update / delete / replace 四个入口都是 `_scheduleDateRules = next;`
///   之后 `await _persistScheduleDateRules()`（:1633-1634、:1669-1670、
///   :1686-1692、:1712-1713），同样没有回滚。
///
/// 下面用可注入的 StorageService 精确地让**那一次**写盘失败来钉住它们，并且都
/// 追一条"之后再成功写一次" —— 因为幻影只有被下一次写入坐实到盘上才算真的丢数据。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  int profilesFailures = 0;
  int rulesFailures = 0;
  int signatureFailures = 0;

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    if (profilesFailures > 0) {
      profilesFailures--;
      return Future<void>.error(StateError('test_profiles_write_failed'));
    }
    return super.saveProfiles(profiles);
  }

  @override
  Future<void> saveScheduleDateRules(List<ScheduleDateRule> rules) {
    if (rulesFailures > 0) {
      rulesFailures--;
      return Future<void>.error(StateError('test_rules_write_failed'));
    }
    return super.saveScheduleDateRules(rules);
  }

  @override
  Future<void> saveScheduleDateRuleLastAppliedSignature(String? signature) {
    if (signatureFailures > 0) {
      signatureFailures--;
      return Future<void>.error(StateError('test_signature_write_failed'));
    }
    return super.saveScheduleDateRuleLastAppliedSignature(signature);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FailingStorage storage;
  late TimetableProvider provider;

  Future<TimetableProvider> boot() async {
    final created = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await created.initialize();
    return created;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = _FailingStorage();
    provider = await boot();
  });

  tearDown(() {
    provider.dispose();
  });

  String iso(DateTime date) => ScheduleDateRuleLogic.formatIsoDate(date);

  final today = DateTime.now();

  List<SectionTime> sections({required String firstStartMinute, int count = 4}) {
    // 每节 45 分钟、节间不留空，起始分钟用来把两套作息明显区分开。
    return List<SectionTime>.generate(count, (index) {
      final startMinutes = int.parse(firstStartMinute) + index * 45;
      final endMinutes = startMinutes + 45;
      String clock(int minutes) =>
          '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
          '${(minutes % 60).toString().padLeft(2, '0')}';
      return SectionTime(
        startTime: clock(startMinutes),
        endTime: clock(endMinutes),
      );
    });
  }

  Course courseAt(String id, {required int day, required int section}) {
    return Course(
      id: id,
      name: '课$id',
      teacher: '老师',
      location: 'A$id',
      dayOfWeek: day,
      startSection: section,
      endSection: section,
      startTime: '08:00',
      endTime: '08:45',
    );
  }

  /// 一条指向 `schemeId`、覆盖今天、且**不自动套用**的规则。
  Future<ScheduleDateRule> stageRule(String schemeId, {bool resync = false}) async {
    final rule = ScheduleDateRule(
      id: 'rule-1',
      name: '换季作息',
      timeSchemeId: schemeId,
      startDate: iso(today),
      endDate: iso(today.add(const Duration(days: 3))),
    );
    await provider.replaceScheduleDateRules([rule], resync: resync);
    return rule;
  }

  Map<String, String> clocksOf(Iterable<Course> courses) => {
    for (final item in courses) item.id: item.startTime,
  };

  group('日期规则批量套用的落盘失败回滚', () {
    test('saveProfiles 失败后每个课表的作息与钟点都要回到套用前', () async {
      final scheme = await provider.createTimeScheme(
        name: '冬季作息',
        sections: sections(firstStartMinute: '480'),
      );
      await provider.addCourse(courseAt('c1', day: 2, section: 2));
      await provider.createProfile(name: '第二份课表');
      await provider.addCourse(courseAt('c2', day: 4, section: 3));
      final firstProfileId = provider.profiles.first.id;
      await provider.switchProfile(firstProfileId);
      await provider.addCourse(courseAt('c3', day: 5, section: 2));

      await stageRule(scheme.id);

      final schemesBefore = {
        for (final profile in provider.profiles)
          profile.id: profile.settings.activeTimeSchemeId,
      };
      final sectionsBefore = {
        for (final profile in provider.profiles)
          profile.id: profile.settings.sections.map((s) => s.startTime).toList(),
      };
      final clocksBefore = {
        for (final profile in provider.profiles)
          profile.id: clocksOf(profile.courses),
      };
      final activeSchemeBefore = provider.settings.activeTimeSchemeId;
      final activeClocksBefore = clocksOf(provider.courses);

      storage.profilesFailures = 1;
      await expectLater(
        provider.applyDueScheduleDateRulesDetailed(),
        throwsA(isA<StateError>()),
      );

      // 内存：三个 profile 的默认作息、节次表、课程钟点都要原样。
      expect(
        provider.settings.activeTimeSchemeId,
        activeSchemeBefore,
        reason: '活动课表的默认作息不能被一次没落成功的套用改掉',
      );
      expect(clocksOf(provider.courses), activeClocksBefore);
      for (final profile in provider.profiles) {
        expect(profile.settings.activeTimeSchemeId, schemesBefore[profile.id]);
        expect(
          profile.settings.sections.map((s) => s.startTime).toList(),
          sectionsBefore[profile.id],
        );
        expect(clocksOf(profile.courses), clocksBefore[profile.id]);
      }
      expect(provider.scheduleDateRuleLastAppliedSignature, isNull);

      // 盘上：幻影必须被下一次成功写入坐实才算丢数据，所以再成功写一次。
      await provider.addCourse(courseAt('c9', day: 6, section: 1));
      final onDisk = await storage.getProfiles();
      expect(onDisk, hasLength(provider.profiles.length));
      for (final profile in onDisk) {
        expect(
          profile.settings.activeTimeSchemeId,
          schemesBefore[profile.id],
          reason: '落盘失败的批量套用不该被下一次写入永久落盘',
        );
        // 只看断言开始时就已经存在的课程：c9 是这一步故意成功写进去的。
        final diskClocks = clocksOf(profile.courses);
        clocksBefore[profile.id]!.forEach((courseId, startMinutes) {
          expect(
            diskClocks[courseId],
            startMinutes,
            reason: '课程 $courseId 的钟点被一次没落成功的套用坐实到了盘上',
          );
        });
      }
    });

    test('节次超限时不写盘也不留改动', () async {
      // 与上一条对照：本来就不该动手的分支（failedWhileDue）不动内存。
      final scheme = await provider.createTimeScheme(
        name: '只有两节',
        sections: sections(firstStartMinute: '570', count: 2),
      );
      await provider.addCourse(courseAt('c1', day: 2, section: 8));
      await stageRule(scheme.id);

      final schemeBefore = provider.settings.activeTimeSchemeId;
      final result = await provider.applyDueScheduleDateRulesDetailed();

      expect(result.outcome, ScheduleDateRuleApplyOutcome.sectionOverflow);
      expect(result.failedWhileDue, isTrue);
      expect(provider.settings.activeTimeSchemeId, schemeBefore);
      expect(provider.scheduleDateRuleLastAppliedSignature, isNull);
    });
  });

  group('「已套用标记」的内存与盘一致', () {
    test('课表写成功但标记写失败时，内存不得记下这个标记', () async {
      final scheme = await provider.createTimeScheme(
        name: '秋季作息',
        sections: sections(firstStartMinute: '480'),
      );
      await provider.addCourse(courseAt('c1', day: 3, section: 1));
      await stageRule(scheme.id);

      storage.signatureFailures = 1;
      await expectLater(
        provider.applyDueScheduleDateRulesDetailed(),
        throwsA(isA<StateError>()),
      );

      // 盘上确实没有这个标记（重启后要重新套用）—— 内存必须跟着盘上走，
      // 否则本次会话以为"已套用"，而盘上的真相是"没套用"。
      expect(provider.scheduleDateRuleLastAppliedSignature, isNull);
      expect(await storage.getScheduleDateRuleLastAppliedSignature(), isNull);
      // 而课表已经落在盘上，内存就该保持已套用的样子（回滚反而是双向错配）。
      expect(provider.settings.activeTimeSchemeId, scheme.id);
      expect(
        (await storage.getProfiles()).first.settings.activeTimeSchemeId,
        scheme.id,
      );
    });
  });

  group('日期规则 CRUD 的落盘失败回滚', () {
    test('createScheduleDateRule 写盘失败后不该留下幻影规则', () async {
      final scheme = await provider.createTimeScheme(
        name: '幻影用的作息',
        sections: sections(firstStartMinute: '480'),
      );
      final before = provider.scheduleDateRules.length;

      storage.rulesFailures = 1;
      await expectLater(
        provider.createScheduleDateRule(
          name: '会被写失败的规则',
          timeSchemeId: scheme.id,
          startDate: iso(today),
          endDate: iso(today.add(const Duration(days: 2))),
        ),
        throwsA(isA<StateError>()),
      );

      expect(provider.scheduleDateRules, hasLength(before));
      expect(
        provider.scheduleDateRules.any((rule) => rule.name == '会被写失败的规则'),
        isFalse,
      );

      await provider.addCourse(courseAt('c1', day: 1, section: 1));
      expect(await storage.getScheduleDateRules(), hasLength(before));
    });

    test('deleteScheduleDateRule 写盘失败后规则必须还在', () async {
      final scheme = await provider.createTimeScheme(
        name: '要删的作息',
        sections: sections(firstStartMinute: '480'),
      );
      final saveResult = await provider.createScheduleDateRule(
        name: '留着别丢',
        timeSchemeId: scheme.id,
        startDate: iso(today.add(const Duration(days: 10))),
        endDate: iso(today.add(const Duration(days: 12))),
      );
      final ruleId = saveResult.rule.id;

      storage.rulesFailures = 1;
      await expectLater(
        provider.deleteScheduleDateRule(ruleId),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.scheduleDateRules.map((rule) => rule.id),
        contains(ruleId),
      );

      await provider.addCourse(courseAt('c1', day: 1, section: 1));
      expect(
        (await storage.getScheduleDateRules()).map((rule) => rule.id),
        contains(ruleId),
        reason: '删除没落成功却在内存里生效，会被下一次写入坐实成永久删除',
      );
    });

    test('replaceScheduleDateRules 写盘失败后列表要回到原样', () async {
      final scheme = await provider.createTimeScheme(
        name: '替换用的作息',
        sections: sections(firstStartMinute: '480'),
      );
      final original = await stageRule(scheme.id);
      expect(provider.scheduleDateRules, hasLength(1));

      storage.rulesFailures = 1;
      await expectLater(
        provider.replaceScheduleDateRules(
          [
            original.copyWith(name: '改坏的名字'),
            ScheduleDateRule(
              id: 'rule-extra',
              name: '多余的一条',
              timeSchemeId: scheme.id,
              startDate: iso(today.add(const Duration(days: 20))),
              endDate: iso(today.add(const Duration(days: 21))),
            ),
          ],
          resync: false,
        ),
        throwsA(isA<StateError>()),
      );

      expect(provider.scheduleDateRules, hasLength(1));
      expect(provider.scheduleDateRules.single.id, original.id);
      expect(provider.scheduleDateRules.single.name, original.name);
    });
  });
}
