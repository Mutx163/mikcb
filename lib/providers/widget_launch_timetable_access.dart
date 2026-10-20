import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import '../services/widget_launch_router.dart';
import 'timetable_provider.dart';

/// [WidgetLaunchTimetable] 的宿主适配器：把 [TimetableProvider] 的公开面
/// 以窄端口交给桌面卡片分流（`lib/services/widget_launch_router.dart`）。
///
/// 服务在 providers 下层，不能反向 import 本文件；端口抽象由服务自己定义，
/// 本适配器住 providers 层（providers → services 是合法方向），由组合根
/// （main.dart）与测试构造注入。方法体一律一行转发，不做业务判断——
/// 分流的语义（时序、守卫、副作用）全部留在路由器里。
class WidgetLaunchProviderAccess implements WidgetLaunchTimetable {
  WidgetLaunchProviderAccess(this._provider);

  final TimetableProvider _provider;

  @override
  Future<void> initialize() => _provider.initialize();

  @override
  bool get hasPartnerBinding => _provider.hasPartnerBinding;

  @override
  TimetableProfile? get partnerProfile => _provider.partnerProfile;

  @override
  TimetableSettings get settings => _provider.settings;

  @override
  Future<String?> updateTimetableSettings(TimetableSettings settings) =>
      _provider.updateTimetableSettings(settings);

  @override
  Future<void> switchProfile(String profileId) =>
      _provider.switchProfile(profileId);
}
