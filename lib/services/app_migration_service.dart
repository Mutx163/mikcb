import 'package:flutter/services.dart';
import '../utils/timed_method_channel.dart';

class AppMigrationService {
  static const String oldReleasePackage = 'com.example.university_timetable';
  static const String oldDebugPackage =
      'com.example.university_timetable.debug';

  static const MethodChannel _channel = TimedMethodChannel(
    'com.mutx163.qingyu/migration',
  );

  Future<String?> findInstalledLegacyPackage({List<String>? candidates}) async {
    try {
      final result = await _channel.invokeMethod<String?>(
        'findInstalledPackage',
        candidates ?? const [oldReleasePackage, oldDebugPackage],
      );
      return result?.trim().isEmpty ?? true ? null : result;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> openPackage(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openPackage',
        packageName,
      );
      return result == true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
