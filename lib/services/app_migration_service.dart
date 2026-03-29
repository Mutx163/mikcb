import 'package:flutter/services.dart';

class AppMigrationService {
  static const String oldReleasePackage = 'com.example.university_timetable';
  static const String oldDebugPackage =
      'com.example.university_timetable.debug';

  static const MethodChannel _channel =
      MethodChannel('com.mutx163.qingyu/migration');

  Future<String?> findInstalledLegacyPackage({
    List<String>? candidates,
  }) async {
    final result = await _channel.invokeMethod<String?>(
      'findInstalledPackage',
      candidates ?? const [oldReleasePackage, oldDebugPackage],
    );
    return result?.trim().isEmpty ?? true ? null : result;
  }

  Future<bool> openPackage(String packageName) async {
    final result = await _channel.invokeMethod<bool>(
      'openPackage',
      packageName,
    );
    return result == true;
  }
}
