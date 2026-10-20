import '../models/course.dart';
import '../models/schedule_item.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import '../services/couple_webdav_service.dart';
import '../services/partner_timetable_service.dart';
import 'timetable_provider.dart';

/// [CoupleWebdavTimetableHost] 的宿主适配器：把 [TimetableProvider] 的公开面
/// 以窄端口交给情侣云盘读写（`lib/services/couple_webdav_service.dart`）。
///
/// 服务在 providers 下层，不能反向 import 本文件；端口抽象由服务自己定义，
/// 本适配器住 providers 层（providers → services 是合法方向），由调用点
/// （couple_timetable_settings_screen、测试）构造注入。成员一律一行转发：
/// 拉取路径「先下载、后判绑定、再导入」与上传路径「先查凭证、后初始化、
/// 再活读五个字段」的时序全部留在服务里。
class CoupleWebdavProviderAccess implements CoupleWebdavTimetableHost {
  CoupleWebdavProviderAccess(this._provider);

  final TimetableProvider _provider;

  @override
  Future<void> initialize() => _provider.initialize();

  @override
  bool get hasPartnerBinding => _provider.hasPartnerBinding;

  @override
  Future<PartnerImportResult> importPartnerTimetable(String content) =>
      _provider.importPartnerTimetable(content);

  @override
  TimetableProfile? get activeProfile => _provider.activeProfile;

  @override
  List<Course> get courses => _provider.courses;

  @override
  List<ScheduleItem> get scheduleItems => _provider.scheduleItems;

  @override
  TimetableSettings get settings => _provider.settings;

  @override
  int get currentWeek => _provider.currentWeek;
}
