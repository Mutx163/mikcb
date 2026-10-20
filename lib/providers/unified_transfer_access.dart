import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/location_time_group.dart';
import '../models/partner_timetable_binding.dart';
import '../models/schedule_date_rule.dart';
import '../models/schedule_item.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import '../services/unified_transfer_service.dart';
import 'timetable_provider.dart';

/// [UnifiedTransferPort] 的宿主适配器：把 [TimetableProvider] 的公开面以窄端口
/// 交给统一传输管线（`lib/services/unified_transfer_service.dart`）。
///
/// 服务在 providers 下层，不能反向 import 本文件；端口抽象由服务自己定义，
/// 本适配器住 providers 层（providers → services 是合法方向），由调用点注入：
/// 屏层（`data_transfer_screen` / `time_scheme_management_screen`）、测试，以及
/// 同层服务的独立参数（`app_sync_snapshot_service` 的 `transferPort`）。
///
/// 成员一律**一行转发**，不改语义：
/// - [runMutationExclusive] 必须原样透传——它承载「快照 → 应用 → 回滚」同一次
///   持锁的不变量（见 `applyToProvider` 的注释），包一层自己的锁会破坏原子性；
/// - [partnerBinding] 是撤销令牌快照要用的绑定，读的是活值。
class UnifiedTransferProviderAccess implements UnifiedTransferPort {
  UnifiedTransferProviderAccess(this._provider);

  final TimetableProvider _provider;

  @override
  Future<void> initialize() => _provider.initialize();

  @override
  Future<T> runMutationExclusive<T>(Future<T> Function() action) =>
      _provider.runMutationExclusive(action);

  @override
  List<TimetableProfile> get profiles => _provider.profiles;

  @override
  String? get activeProfileId => _provider.activeProfileId;

  @override
  TimetableProfile? get activeProfile => _provider.activeProfile;

  @override
  List<Course> get courses => _provider.courses;

  @override
  List<CourseTask> get tasks => _provider.tasks;

  @override
  List<ScheduleItem> get scheduleItems => _provider.scheduleItems;

  @override
  List<Exam> get exams => _provider.exams;

  @override
  TimetableSettings get settings => _provider.settings;

  @override
  int get currentWeek => _provider.currentWeek;

  @override
  List<TimeScheme> get timeSchemes => _provider.timeSchemes;

  @override
  List<ScheduleDateRule> get scheduleDateRules => _provider.scheduleDateRules;

  @override
  List<LocationTimeGroup> get locationTimeGroups =>
      _provider.locationTimeGroups;

  @override
  PartnerTimetableBinding? get partnerBinding => _provider.partnerBinding;

  @override
  Course? getCourseById(String id) => _provider.getCourseById(id);

  @override
  CourseTask? getTaskById(String id) => _provider.getTaskById(id);

  @override
  ScheduleItem? getScheduleItemById(String id) =>
      _provider.getScheduleItemById(id);

  @override
  Future<String?> importAppDataBackup(String content) =>
      _provider.importAppDataBackup(content);

  @override
  Future<String?> importFullAppDataBackup(String content) =>
      _provider.importFullAppDataBackup(content);

  @override
  Future<int> importParsedCourses(
    List<Course> importedCourses, {
    required bool replaceExisting,
    required String source,
  }) => _provider.importParsedCourses(
    importedCourses,
    replaceExisting: replaceExisting,
    source: source,
  );

  @override
  Future<TimeScheme> createTimeScheme({
    required String name,
    List<SectionTime>? sections,
  }) => _provider.createTimeScheme(name: name, sections: sections);

  @override
  Future<String?> updateTimeScheme({
    required String schemeId,
    required String name,
    required List<SectionTime> sections,
  }) => _provider.updateTimeScheme(
    schemeId: schemeId,
    name: name,
    sections: sections,
  );

  @override
  Future<void> updateSettings(TimetableSettings settings) =>
      _provider.updateSettings(settings);

  @override
  Future<void> setCurrentWeek(int week, {bool notify = true}) =>
      _provider.setCurrentWeek(week, notify: notify);

  @override
  Future<void> addTask(CourseTask task) => _provider.addTask(task);

  @override
  Future<void> updateTask(CourseTask task) => _provider.updateTask(task);

  @override
  Future<void> addScheduleItem(ScheduleItem item) =>
      _provider.addScheduleItem(item);

  @override
  Future<void> updateScheduleItem(ScheduleItem item) =>
      _provider.updateScheduleItem(item);

  @override
  Future<void> addExam(Exam exam) => _provider.addExam(exam);

  @override
  Future<void> updateExam(Exam exam) => _provider.updateExam(exam);

  @override
  Future<void> replaceLocationTimeGroups(
    List<LocationTimeGroup> groups, {
    bool resync = true,
  }) => _provider.replaceLocationTimeGroups(groups, resync: resync);

  @override
  Future<void> replaceScheduleDateRules(
    List<ScheduleDateRule> rules, {
    bool resync = true,
  }) => _provider.replaceScheduleDateRules(rules, resync: resync);

  @override
  Future<void> restorePartnerBinding(PartnerTimetableBinding? binding) =>
      _provider.restorePartnerBinding(binding);
}
