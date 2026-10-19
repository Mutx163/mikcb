import '../domain/holiday_resolver.dart';
import '../models/holiday_entry.dart';
import '../models/timetable_settings.dart';
import 'app_log_service.dart';
import 'holiday_service.dart';

/// 节假日加载/自定义假期写入口需要的最小依赖面。
///
/// 由 `TimetableProvider` 侧的适配器实现：读/写已加载的假期数据、取远程
/// 年度数据、自定义假期存储、live surface 串行门与重推副作用、通知界面。
/// 服务本身不碰 provider 私有字段，可用假端口单测。
abstract interface class TimetableHolidayPort {
  HolidayData? get holidayData;
  set holidayData(HolidayData? value);
  TimetableSettings get settings;
  Future<HolidayData> fetchHolidayData(int year);
  Future<void> clearCache(int year);
  Future<List<HolidayEntry>?> loadCustomHolidays();
  Future<void> saveCustomHolidays(List<HolidayEntry> entries);
  Future<void> addCustomHoliday(HolidayEntry entry);
  Future<void> removeCustomHoliday(String groupId);
  Future<void> updateCustomHoliday(
    String groupId,
    List<HolidayEntry> newEntries,
  );
  Future<T> runLiveSurfaceExclusive<T>(Future<T> Function() action);
  void resetLiveSurfaceTracking();
  Future<void> updateLiveActivity();
  void notifyStateChanged();
}

/// 节假日域用例：加载（含跨年 + 自定义合并）、刷新、自定义假期增删改、
/// 以及「某天是不是假期/调休上班日」的展示判定。
///
/// 2026-10-19 从 `TimetableProvider` 的节假日族方法搬出；行为保持原样：
/// - 加载失败不致命：吞掉并留一条 `holiday_data_refresh_failed` 日志；
/// - 自定义假期本地数据损坏（`null`）时**禁止**按空列表 append 写回，
///   否则一次保存会把真实数据覆盖清零；
/// - 加载成功后必须重置 live surface 签名并重推一次，桌面卡片才会认出假期。
class TimetableHolidayService {
  TimetableHolidayService(this._port, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TimetableHolidayPort _port;

  /// 取「现在」的口子：跨年那一周的假期要按当前周加载邻年数据，
  /// 单测需要固定日期才能覆盖这条路径。默认就是 [DateTime.now]。
  final DateTime Function() _now;

  /// 加载节假日数据；live surface 串行门与 `switchProfile` 共用，
  /// 避免交错时用旧课表推送一次小组件。
  Future<void> load() => _port.runLiveSurfaceExclusive(_loadImpl);

  Future<void> _loadImpl() async {
    try {
      final now = _now();
      final data = await _port.fetchHolidayData(now.year);
      final allEntries = <HolidayEntry>[...data.entries];
      // 跨年那一周的假期可能整段挂在邻年响应里（本仓库 fixture 的元旦就是
      // 2026-12-31..2027-01-02），只取 now.year 会把 12 月末当上课日排课。
      for (final year in holidayYearsToLoad(now).where((y) => y != now.year)) {
        allEntries.addAll((await _port.fetchHolidayData(year)).entries);
      }
      // Merge user-defined custom holidays. Null means the persisted data is
      // corrupted (logged inside the service): skip merging instead of
      // treating it as "no data" so a later save cannot wipe real entries.
      final customEntries = await _port.loadCustomHolidays();
      if (customEntries != null) {
        allEntries.addAll(customEntries);
      }
      _port.holidayData = HolidayData(
        year: data.year,
        version: data.version,
        entries: allEntries,
      );
      _port.notifyStateChanged();
      // Holiday data is not stored in timetable profiles; force home widget /
      // live schedule resync so desktop widgets pick up vacation days.
      _port.resetLiveSurfaceTracking();
      // Full body: home widget + schedule snapshot + stopLiveUpdate when holiday.
      await _port.updateLiveActivity();
    } catch (e, stackTrace) {
      // Holiday data is non-critical; keep going but leave a trace so a
      // "vacation days missing on widget" report is diagnosable.
      await AppLogService.instance.warn(
        'holiday_data_refresh_failed',
        e.toString(),
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 指定日期的节假日条目
  HolidayEntry? getHolidayForDate(DateTime date) {
    return _port.holidayData?.entryForDate(date);
  }

  /// Refresh holiday data (clear cache and reload)
  Future<void> refresh() async {
    await Future.wait(holidayYearsToLoad(_now()).map(_port.clearCache));
    await load();
  }

  /// 用户自定义假期列表（不含远程/内置数据）
  ///
  /// 本地数据损坏时返回空列表兜底（损坏详情由 service 落日志），只读
  /// 展示场景无法修复损坏，也没有写回风险。
  Future<List<HolidayEntry>> getCustomHolidays() async {
    return await _port.loadCustomHolidays() ?? const [];
  }

  /// 读取自定义假期，数据损坏时返回 null（区别于「没有数据」的空列表）。
  /// 供设置页区分「暂无」与「损坏」并给出提示条（getCustomHolidays 会把
  /// 损坏兜底成空列表，用户会误以为没有数据，见 Issue #52 审核 S4）。
  Future<List<HolidayEntry>?> loadCustomHolidaysOrNull() {
    return _port.loadCustomHolidays();
  }

  /// 新增一条自定义假期
  Future<void> addCustomHoliday(HolidayEntry entry) async {
    await _port.addCustomHoliday(entry);
    await load();
  }

  /// 批量新增自定义假期（单次 load → append → save，避免逐条写入的竞态问题）
  Future<void> addCustomHolidays(List<HolidayEntry> entries) async {
    final existing = await _port.loadCustomHolidays();
    if (existing == null) {
      // 本地数据损坏：禁止把空列表 append 后写回（会覆盖清零真实数据）。
      throw const HolidayCustomSaveException(
        'custom holiday storage corrupted; refusing to overwrite',
      );
    }
    existing.addAll(entries);
    await _port.saveCustomHolidays(existing);
    await load();
  }

  /// 按 groupId 删除自定义假期
  Future<void> removeCustomHoliday(String groupId) async {
    await _port.removeCustomHoliday(groupId);
    await load();
  }

  /// 按 groupId 更新自定义假期
  Future<void> updateCustomHoliday(
    String groupId,
    List<HolidayEntry> newEntries,
  ) async {
    await _port.updateCustomHoliday(groupId, newEntries);
    await load();
  }

  /// 指定日期是否为假期（应隐藏课程）
  bool isHoliday(DateTime date) {
    return HolidayResolver.isHoliday(
      date,
      data: _port.holidayData,
      overrideEnabled: _port.settings.holidayOverrideEnabled,
      markingEnabled: _port.settings.enableHolidayMarking,
    );
  }

  /// 指定日期是否为调休上班日
  bool isAdjustedWorkday(DateTime date) {
    return HolidayResolver.isAdjustedWorkday(date, data: _port.holidayData);
  }
}
