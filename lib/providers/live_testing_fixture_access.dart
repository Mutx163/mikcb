import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../services/live_testing_fixture_service.dart';
import 'timetable_provider.dart';

/// [LiveTestingFixtureHost] 的宿主适配器：把 [TimetableProvider] 的公开面
/// 以窄端口交给测试课表夹具（`lib/services/live_testing_fixture_service.dart`）。
///
/// 服务在 providers 下层，不能反向 import 本文件；端口抽象由服务自己定义，
/// 本适配器住 providers 层（providers → services 是合法方向），由调用点
/// （测试课表页、调试深链、live_testing_trigger、测试）构造注入。
/// 成员一律一行转发：夹具的安装/清理时序（initialize → 清旧 → 建/改作息 →
/// 套用 → 按解析导入）全部留在服务里。
class LiveFixtureProviderAccess implements LiveTestingFixtureHost {
  LiveFixtureProviderAccess(this._provider);

  final TimetableProvider _provider;

  @override
  Future<void> initialize() => _provider.initialize();

  @override
  List<TimeScheme> get timeSchemes => _provider.timeSchemes;

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
  Future<TimeScheme> createTimeScheme({
    required String name,
    List<SectionTime>? sections,
  }) => _provider.createTimeScheme(name: name, sections: sections);

  @override
  List<Course> get courses => _provider.courses;

  @override
  Future<void> deleteCourse(String courseId) =>
      _provider.deleteCourse(courseId);

  @override
  Future<String?> applyTimeScheme(String schemeId) =>
      _provider.applyTimeScheme(schemeId);

  @override
  TimetableSettings get settings => _provider.settings;

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
  Future<void> addCourse(Course course) => _provider.addCourse(course);

  @override
  Future<void> updateCourse(Course course) => _provider.updateCourse(course);
}
