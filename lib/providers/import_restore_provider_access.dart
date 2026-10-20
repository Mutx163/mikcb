import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../services/import_time_scheme_restore_point.dart';
import 'timetable_provider.dart';

/// [ImportTimeSchemeRestoreHost] 的宿主适配器：把 [TimetableProvider] 的公开面
/// 以窄端口交给教务导入的作息恢复点（`lib/services/import_time_scheme_restore_point.dart`）。
///
/// 服务在 providers 下层，不能反向 import 本文件；端口抽象由服务自己定义，
/// 本适配器住 providers 层（providers → services 是合法方向），由调用点
/// （四个导入屏、测试）构造注入。成员一律一行转发，恢复时序（先删副本、
/// 再写回整份设置）全部留在恢复点里。
class ImportRestoreProviderAccess implements ImportTimeSchemeRestoreHost {
  ImportRestoreProviderAccess(this._provider);

  final TimetableProvider _provider;

  @override
  TimetableSettings get settings => _provider.settings;

  @override
  List<TimeScheme> get timeSchemes => _provider.timeSchemes;
  @override
  Future<String?> updateTimetableSettings(TimetableSettings settings) =>
      _provider.updateTimetableSettings(settings);

  @override
  Future<bool> deleteTimeScheme(String schemeId) =>
      _provider.deleteTimeScheme(schemeId);
}
