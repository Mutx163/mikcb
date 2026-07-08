import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';

class AppDataBackup {
  final String? profileName;
  final List<Course> courses;
  final List<Exam> exams;
  final TimetableSettings settings;
  final int currentWeek;
  final DateTime exportedAt;

  const AppDataBackup({
    this.profileName,
    required this.courses,
    this.exams = const [],
    required this.settings,
    required this.currentWeek,
    required this.exportedAt,
  });
}

class FullAppDataBackup {
  final List<TimetableProfile> profiles;
  final String? activeProfileId;
  final List<TimeScheme> timeSchemes;
  final DateTime exportedAt;

  const FullAppDataBackup({
    required this.profiles,
    required this.activeProfileId,
    required this.timeSchemes,
    required this.exportedAt,
  });
}

class DataTransferService {
  static const int schemaVersion = 1;
  static const String fileExtension = 'mikcb';

  String buildBackupJson({
    String? profileName,
    required List<Course> courses,
    List<Exam> exams = const [],
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
      'exams': exams.map((exam) => exam.toJson()).toList(),
    });
  }

  AppDataBackup parseBackupJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final app = json['app'] as String?;
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;

    if (app != 'mikcb' || version != schemaVersion) {
      throw const FormatException('unrecognized_mikcb_data_file');
    }

    final rawCourses = (json['courses'] as List<dynamic>? ?? const [])
        .map((item) => Course.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final rawSettings = json['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('missing_settings_data');
    }
    final settings = TimetableSettings.fromJson(
      Map<String, dynamic>.from(rawSettings),
    );

    return AppDataBackup(
      profileName: (json['profileName'] as String?)?.trim().isEmpty == true
          ? null
          : json['profileName'] as String?,
      courses: rawCourses,
      exams: (json['exams'] as List<dynamic>? ?? const [])
          .map((item) => Exam.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      settings: settings,
      currentWeek: clampCurrentWeekToSettings(
        ((json['currentWeek'] as num?)?.toInt() ?? 1).clamp(1, 30),
        settings,
      ),
      exportedAt:
          DateTime.tryParse((json['exportedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  bool isFullBackupJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    return json['backupType'] == 'full';
  }

  String buildFullBackupJson({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
    required List<TimeScheme> timeSchemes,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'mikcb',
      'schemaVersion': schemaVersion,
      'backupType': 'full',
      'exportedAt': DateTime.now().toIso8601String(),
      'activeProfileId': activeProfileId,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'timeSchemes': timeSchemes.map((scheme) => scheme.toJson()).toList(),
    });
  }

  FullAppDataBackup parseFullBackupJson(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final app = json['app'] as String?;
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    final backupType = json['backupType'] as String?;

    if (app != 'mikcb' || version != schemaVersion || backupType != 'full') {
      throw const FormatException('unrecognized_mikcb_full_backup');
    }

    final rawProfiles = json['profiles'];
    final rawTimeSchemes = json['timeSchemes'];
    if (rawProfiles is! List || rawTimeSchemes is! List) {
      throw const FormatException('missing_full_backup_data');
    }

    return FullAppDataBackup(
      profiles: rawProfiles
          .map(
            (item) => TimetableProfile.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      activeProfileId: json['activeProfileId'] as String?,
      timeSchemes: rawTimeSchemes
          .map(
            (item) =>
                TimeScheme.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      exportedAt:
          DateTime.tryParse((json['exportedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> exportAndShare({
    String? profileName,
    required List<Course> courses,
    List<Exam> exams = const [],
    required TimetableSettings settings,
    required int currentWeek,
    required String shareText,
    required String shareSubject,
  }) async {
    final now = DateTime.now();
    final filename =
        'mikcb-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.$fileExtension';
    final bytes = Uint8List.fromList(
      utf8.encode(
        buildBackupJson(
          profileName: profileName,
          courses: courses,
          exams: exams,
          settings: settings,
          currentWeek: currentWeek,
        ),
      ),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: filename),
        ],
        text: shareText,
        subject: shareSubject,
      ),
    );
  }

  Future<void> exportFullBackupAndShare({
    required List<TimetableProfile> profiles,
    required String? activeProfileId,
    required List<TimeScheme> timeSchemes,
    required String shareText,
    required String shareSubject,
  }) async {
    final now = DateTime.now();
    final filename =
        'mikcb-full-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.$fileExtension';
    final bytes = Uint8List.fromList(
      utf8.encode(
        buildFullBackupJson(
          profiles: profiles,
          activeProfileId: activeProfileId,
          timeSchemes: timeSchemes,
        ),
      ),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: filename),
        ],
        text: shareText,
        subject: shareSubject,
      ),
    );
  }
}
