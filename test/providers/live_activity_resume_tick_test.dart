import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 回归钉（第 27 轮，回前台链路抛错之后 30 秒心跳永久停摆）。
///
/// `_liveHandleAppResumed`（timetable/live_activity_controller.dart:164-175 原形）
/// 的第一句就无条件 `host._liveActivityTimer?.cancel()`，而重排
/// `_liveScheduleActivityTick(host)` 只在**最后一句**，中间两次 await 都会外抛：
/// - `syncTemporalContext()` 走 `_runMutation` → 落盘；
///   `schedule_date_rule_repository.dart:141-146`（季节日期规则到点批量套用）
///   对 `saveProfiles` 是 catch→回滚→rethrow，
///   而 `StorageService._setStringChecked`（storage_service.dart:465 区）在
///   `commit()` 返回 false 时确实抛 `StateError('storage_write_failed')`；
/// - `_runLiveSurfaceExclusive(...)` 里的原生通道调用也可能抛。
///
/// 抛出后调用方 `handleAppResumed`（timetable_provider.dart:645-659）把异常吞进日志
/// `live_activity_resume_recovery_failed`，界面毫无提示，而本次会话的心跳就此没有：
/// 跨日/跨周不再切周次、超级岛不再随课程边界切换、桌面卡片的刷新触发点不再补排，
/// 只能杀 App 恢复（`_liveScheduleActivityTick` 全仓只有两个调用点）。
class _ThrowingOnResumeProvider extends TimetableProvider {
  _ThrowingOnResumeProvider()
    : super(
        storageService: StorageService.forTesting(),
        autoInitialize: false,
        enableLiveActivitySync: true,
      );

  /// 只在被要求的那一次抛。`initialize()` 链路里的 `_bootstrapHolidayAwareSurfaces`
  /// 也会起心跳并 `unawaited(syncTemporalContext())`（live_activity_controller.dart:159），
  /// 无差别抛错会让那条后台 Future 变成未处理错误、串到别的用例上去。
  bool throwNext = false;

  @override
  Future<bool> syncTemporalContext({DateTime? now}) {
    if (throwNext) {
      throwNext = false;
      return Future<bool>.error(StateError('simulated_resume_persist_failure'));
    }
    return super.syncTemporalContext(now: now);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('回前台链路抛错之后，30 秒心跳仍然挂着', () async {
    final provider = _ThrowingOnResumeProvider();
    addTearDown(provider.dispose);
    await provider.initialize();

    // 不断言「进入前心跳已在」：`initialize()` 是否顺手起心跳取决于节假日面是否
    // 走 `_bootstrapHolidayAwareSurfaces` 那条支路，本用例要钉的只有出去的那一步
    // —— 抛出之后 `finally` 仍必须把表续上（修复前这里恒为 false）。
    provider.throwNext = true;
    // `handleAppResumed` 把异常吞进日志 live_activity_resume_recovery_failed，
    // 所以这里不该外抛。
    await provider.handleAppResumed();

    expect(
      hasLiveActivityTickForTesting(provider),
      isTrue,
      reason: '修复前这里是 false：cancel 之后重排被抛出跳过，心跳整会话死掉',
    );
  });

  test('回前台成功时也只有一条心跳（不重复堆表）', () async {
    final provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: true,
    );
    addTearDown(provider.dispose);
    await provider.initialize();

    await provider.handleAppResumed();
    await provider.handleAppResumed();

    expect(hasLiveActivityTickForTesting(provider), isTrue);
  });
}
