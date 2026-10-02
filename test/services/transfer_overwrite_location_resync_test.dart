import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/transfer_package.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';

/// 覆盖导入换完地点分组后必须重烤钟点（回归钉，2026-10-02）。
///
/// `_overwrite` 的顺序是「先 `importAppDataBackup`，后 `_replaceRulesAndLocations`」，
/// 而前者烤课程钟点用的是**接收方原有**的地点分组（`_timetableImportAppDataBackup`
/// 全程不碰分组）。原来换分组时传 `resync: false`，于是最终状态自相矛盾：课程
/// 时间是旧楼的教学节次，盘上分组却是新的。用户看不到任何异常，只有真的去上课时
/// 才发现时间不对；要等下一次任意地点规则改动才被静默改对。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TimetableProvider> bootedWith({
    required String schemeName,
    required String startTime,
    required String endTime,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterWeekCount: 16),
    );
    final scheme = await provider.createTimeScheme(
      name: schemeName,
      sections: [SectionTime(startTime: startTime, endTime: endTime)],
    );
    await provider.createLocationTimeGroup(
      name: '$schemeName 教学楼组',
      timeSchemeId: scheme.id,
      keywords: const [LocationKeyword(pattern: 'A')],
    );
    await provider.addCourse(
      Course(
        id: 'c1',
        name: '结构力学',
        teacher: '周老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 1,
        startTime: startTime,
        endTime: endTime,
      ),
    );
    return provider;
  }

  test('覆盖导入后课程钟点跟随发来的地点分组，而不是留在接收方旧口径', () async {
    final receiver = await bootedWith(
      schemeName: '平时作息',
      startTime: '08:30',
      endTime: '09:15',
    );
    final sender = await bootedWith(
      schemeName: '发来的作息',
      startTime: '10:00',
      endTime: '10:45',
    );
    addTearDown(receiver.dispose);
    addTearDown(sender.dispose);

    // scope 默认即 currentTimetable（整表当前课表），这里不再显式重复。
    final incoming = UnifiedTransferService().buildCurrentPackage(
      provider: sender,
    );
    final result = await UnifiedTransferService().applyToProvider(
      provider: receiver,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );

    expect(result.applied, isTrue, reason: result.error);
    expect(
      receiver.courses.single.startTime,
      '10:00',
      reason: '分组已经换成发来的那份，钟点必须一起重烤',
    );
  });
}
