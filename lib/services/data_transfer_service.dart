import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';

class AppDataBackup {
  final String? profileName;
  final List<Course> courses;
  final TimetableSettings settings;
  final int currentWeek;
  final DateTime exportedAt;

  const AppDataBackup({
    this.profileName,
    required this.courses,
    required this.settings,
    required this.currentWeek,
    required this.exportedAt,
  });
}

class DataTransferService {
  static const int schemaVersion = 1;
  static const String fileExtension = 'mikcb.json';

  String buildBackupJson({
    String? profileName,
    required List<Course> courses,
    required TimetableSettings settings,
    required int currentWeek,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'mikcb',
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profileName': profileName,
      'currentWeek': currentWeek,
      'settings': settings.toJson(),
      'courses': courses.map((course) => course.toJson()).toList(),
    });
  }

  AppDataBackup parseBackupJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final app = json['app'] as String?;
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;

    if (app != 'mikcb' || version != schemaVersion) {
      throw const FormatException('不是可识别的 mikcb 数据文件');
    }

    final rawCourses = (json['courses'] as List<dynamic>? ?? const [])
        .map((item) => Course.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final rawSettings = json['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('缺少设置数据');
    }

    return AppDataBackup(
      profileName: (json['profileName'] as String?)?.trim().isEmpty == true
          ? null
          : json['profileName'] as String?,
      courses: rawCourses,
      settings: TimetableSettings.fromJson(
        Map<String, dynamic>.from(rawSettings),
      ),
      currentWeek: ((json['currentWeek'] as num?)?.toInt() ?? 1).clamp(1, 30),
      exportedAt: DateTime.tryParse((json['exportedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> exportAndShare({
    String? profileName,
    required List<Course> courses,
    required TimetableSettings settings,
    required int currentWeek,
  }) async {
    final now = DateTime.now();
    final filename =
        'mikcb-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.$fileExtension';
    final bytes = Uint8List.fromList(
      utf8.encode(
        buildBackupJson(
          profileName: profileName,
          courses: courses,
          settings: settings,
          currentWeek: currentWeek,
        ),
      ),
    );

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/json',
          name: filename,
        ),
      ],
      text: '这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置。',
      subject: profileName == null ? '轻屿课表备份' : '$profileName - 轻屿课表备份',
    );
  }
}
