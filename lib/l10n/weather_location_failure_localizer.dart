import '../services/device_location_service.dart';
import 'app_localizations.dart';

/// 把定位失败原因翻成一句人话。
///
/// 单独一层的原因与 `weather_category_localizer.dart` 相同：失败原因是纯数据
/// （服务层要能无 UI 单测），文案要跟着语言走。设置子页与选城市页共用这一份，
/// 免得两处的说法分叉。
abstract final class WeatherLocationFailureLocalizer {
  static String message(AppLocalizations l10n, DeviceLocationFailure failure) {
    return switch (failure) {
      DeviceLocationFailure.serviceDisabled =>
        l10n.weatherLocationServiceDisabled,
      DeviceLocationFailure.permissionDenied =>
        l10n.weatherLocationPermissionDenied,
      DeviceLocationFailure.permissionDeniedForever =>
        l10n.weatherLocationPermissionDeniedForever,
      DeviceLocationFailure.timeout => l10n.weatherLocationTimeout,
      DeviceLocationFailure.failed => l10n.weatherLocationFailed,
      DeviceLocationFailure.addressUnavailable =>
        l10n.weatherLocationAddressUnavailable,
    };
  }
}
