import 'dart:convert';

enum AppUpdateDownloadSource {
  original,
  mirror,
}

extension AppUpdateDownloadSourceX on AppUpdateDownloadSource {
  String get value => switch (this) {
        AppUpdateDownloadSource.original => 'original',
        AppUpdateDownloadSource.mirror => 'mirror',
      };

  String get label => switch (this) {
        AppUpdateDownloadSource.original => '原版下载',
        AppUpdateDownloadSource.mirror => '镜像下载',
      };

  static AppUpdateDownloadSource fromValue(String? value) {
    return AppUpdateDownloadSource.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppUpdateDownloadSource.original,
    );
  }
}

class SectionTime {
  final String startTime;
  final String endTime;

  const SectionTime({
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory SectionTime.fromJson(Map<String, dynamic> json) {
    return SectionTime(
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );
  }

  SectionTime copyWith({
    String? startTime,
    String? endTime,
  }) {
    return SectionTime(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  String get displayText => '$startTime-$endTime';
}

class TimetableSettings {
  final List<SectionTime> sections;
  final String? activeTimeSchemeId;
  final double sectionHeight;
  final double compactFontSize;
  final int semesterWeekCount;
  final DateTime? semesterStartDate;
  final bool showConflictBadgeOnTimetable;
  final bool liveShowCourseName;
  final bool liveShowLocation;
  final bool liveShowCountdown;
  final bool liveEnableBeforeClass;
  final bool liveEnableDuringClass;
  final bool liveEnableBeforeEnd;
  final bool livePromoteDuringClass;
  final bool liveShowDuringClassNotification;
  final bool liveUseShortName;
  final bool liveHidePrefixText;
  final int liveShowBeforeClassMinutes;
  final int liveClassReminderStartMinutes;
  final int liveEndSecondsCountdownThreshold;
  final String themeSeedColor;
  final String timetablePageBackgroundColor;
  final bool timetableUseUnifiedCardColor;
  final String timetableUnifiedCardColor;
  final String appUpdateDownloadSource;
  final String appUpdateMirrorUrlPrefix;

  const TimetableSettings({
    required this.sections,
    this.activeTimeSchemeId,
    this.sectionHeight = 68,
    this.compactFontSize = 9,
    this.semesterWeekCount = 20,
    this.semesterStartDate,
    this.showConflictBadgeOnTimetable = true,
    this.liveShowCourseName = true,
    this.liveShowLocation = true,
    this.liveShowCountdown = true,
    this.liveEnableBeforeClass = true,
    this.liveEnableDuringClass = true,
    this.liveEnableBeforeEnd = true,
    this.livePromoteDuringClass = true,
    this.liveShowDuringClassNotification = true,
    this.liveUseShortName = true,
    this.liveHidePrefixText = false,
    this.liveShowBeforeClassMinutes = 20,
    this.liveClassReminderStartMinutes = 0,
    this.liveEndSecondsCountdownThreshold = 60,
    this.themeSeedColor = '#2563EB',
    this.timetablePageBackgroundColor = '#F8FAFC',
    this.timetableUseUnifiedCardColor = false,
    this.timetableUnifiedCardColor = '#2563EB',
    this.appUpdateDownloadSource = 'original',
    this.appUpdateMirrorUrlPrefix = 'https://ghfast.top/',
  });

  factory TimetableSettings.defaults() {
    return const TimetableSettings(
      sections: [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        SectionTime(startTime: '08:55', endTime: '09:40'),
        SectionTime(startTime: '10:00', endTime: '10:45'),
        SectionTime(startTime: '10:55', endTime: '11:40'),
        SectionTime(startTime: '14:00', endTime: '14:45'),
        SectionTime(startTime: '14:55', endTime: '15:40'),
        SectionTime(startTime: '16:00', endTime: '16:45'),
        SectionTime(startTime: '16:55', endTime: '17:40'),
        SectionTime(startTime: '19:00', endTime: '19:45'),
        SectionTime(startTime: '19:55', endTime: '20:40'),
      ],
      activeTimeSchemeId: null,
      sectionHeight: 68,
      compactFontSize: 9,
      semesterWeekCount: 20,
      semesterStartDate: null,
      showConflictBadgeOnTimetable: true,
      liveShowCourseName: true,
      liveShowLocation: true,
      liveShowCountdown: true,
      liveEnableBeforeClass: true,
      liveEnableDuringClass: true,
      liveEnableBeforeEnd: true,
      livePromoteDuringClass: true,
      liveShowDuringClassNotification: true,
      liveUseShortName: true,
      liveHidePrefixText: false,
      liveShowBeforeClassMinutes: 20,
      liveClassReminderStartMinutes: 0,
      liveEndSecondsCountdownThreshold: 60,
      themeSeedColor: '#2563EB',
      timetablePageBackgroundColor: '#F8FAFC',
      timetableUseUnifiedCardColor: false,
      timetableUnifiedCardColor: '#2563EB',
      appUpdateDownloadSource: 'original',
      appUpdateMirrorUrlPrefix: 'https://ghfast.top/',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sections': sections.map((section) => section.toJson()).toList(),
      'activeTimeSchemeId': activeTimeSchemeId,
      'sectionHeight': sectionHeight,
      'compactFontSize': compactFontSize,
      'semesterWeekCount': semesterWeekCount,
      'semesterStartDate': semesterStartDate?.millisecondsSinceEpoch,
      'showConflictBadgeOnTimetable': showConflictBadgeOnTimetable,
      'liveShowCourseName': liveShowCourseName,
      'liveShowLocation': liveShowLocation,
      'liveShowCountdown': liveShowCountdown,
      'liveEnableBeforeClass': liveEnableBeforeClass,
      'liveEnableDuringClass': liveEnableDuringClass,
      'liveEnableBeforeEnd': liveEnableBeforeEnd,
      'livePromoteDuringClass': livePromoteDuringClass,
      'liveShowDuringClassNotification': liveShowDuringClassNotification,
      'liveUseShortName': liveUseShortName,
      'liveHidePrefixText': liveHidePrefixText,
      'liveShowBeforeClassMinutes': liveShowBeforeClassMinutes,
      'liveClassReminderStartMinutes': liveClassReminderStartMinutes,
      'liveEndSecondsCountdownThreshold': liveEndSecondsCountdownThreshold,
      'themeSeedColor': themeSeedColor,
      'timetablePageBackgroundColor': timetablePageBackgroundColor,
      'timetableUseUnifiedCardColor': timetableUseUnifiedCardColor,
      'timetableUnifiedCardColor': timetableUnifiedCardColor,
      'appUpdateDownloadSource': appUpdateDownloadSource,
      'appUpdateMirrorUrlPrefix': appUpdateMirrorUrlPrefix,
    };
  }

  factory TimetableSettings.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    if (rawSections.isEmpty) {
      return TimetableSettings.defaults();
    }

    return TimetableSettings(
      sections: rawSections
          .map((item) =>
              SectionTime.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      activeTimeSchemeId: json['activeTimeSchemeId'] as String?,
      sectionHeight: (json['sectionHeight'] as num?)?.toDouble() ?? 68,
      compactFontSize: (json['compactFontSize'] as num?)?.toDouble() ?? 9,
      semesterWeekCount: (json['semesterWeekCount'] as num?)?.toInt() ?? 20,
      semesterStartDate: (json['semesterStartDate'] as num?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['semesterStartDate'] as num).toInt(),
            )
          : null,
      showConflictBadgeOnTimetable:
          json['showConflictBadgeOnTimetable'] as bool? ?? true,
      liveShowCourseName: json['liveShowCourseName'] as bool? ?? true,
      liveShowLocation: json['liveShowLocation'] as bool? ?? true,
      liveShowCountdown: json['liveShowCountdown'] as bool? ?? true,
      liveEnableBeforeClass: json['liveEnableBeforeClass'] as bool? ?? true,
      liveEnableDuringClass: json['liveEnableDuringClass'] as bool? ?? true,
      liveEnableBeforeEnd: json['liveEnableBeforeEnd'] as bool? ?? true,
      livePromoteDuringClass: json['livePromoteDuringClass'] as bool? ?? true,
      liveShowDuringClassNotification:
          json['liveShowDuringClassNotification'] as bool? ?? true,
      liveUseShortName: json['liveUseShortName'] as bool? ?? true,
      liveHidePrefixText: json['liveHidePrefixText'] as bool? ?? false,
      liveShowBeforeClassMinutes:
          (json['liveShowBeforeClassMinutes'] as num?)?.toInt() ?? 20,
      liveClassReminderStartMinutes:
          (json['liveClassReminderStartMinutes'] as num?)?.toInt() ?? 0,
      liveEndSecondsCountdownThreshold:
          (json['liveEndSecondsCountdownThreshold'] as num?)?.toInt() ?? 60,
      themeSeedColor: json['themeSeedColor'] as String? ?? '#2563EB',
      timetablePageBackgroundColor:
          json['timetablePageBackgroundColor'] as String? ?? '#F8FAFC',
      timetableUseUnifiedCardColor:
          json['timetableUseUnifiedCardColor'] as bool? ?? false,
      timetableUnifiedCardColor:
          json['timetableUnifiedCardColor'] as String? ?? '#2563EB',
      appUpdateDownloadSource:
          json['appUpdateDownloadSource'] as String? ?? 'original',
      appUpdateMirrorUrlPrefix:
          json['appUpdateMirrorUrlPrefix'] as String? ?? 'https://ghfast.top/',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TimetableSettings.fromJsonString(String jsonString) {
    return TimetableSettings.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  TimetableSettings copyWith({
    List<SectionTime>? sections,
    String? activeTimeSchemeId,
    double? sectionHeight,
    double? compactFontSize,
    int? semesterWeekCount,
    DateTime? semesterStartDate,
    bool? showConflictBadgeOnTimetable,
    bool? liveShowCourseName,
    bool? liveShowLocation,
    bool? liveShowCountdown,
    bool? liveEnableBeforeClass,
    bool? liveEnableDuringClass,
    bool? liveEnableBeforeEnd,
    bool? livePromoteDuringClass,
    bool? liveShowDuringClassNotification,
    bool? liveUseShortName,
    bool? liveHidePrefixText,
    int? liveShowBeforeClassMinutes,
    int? liveClassReminderStartMinutes,
    int? liveEndSecondsCountdownThreshold,
    String? themeSeedColor,
    String? timetablePageBackgroundColor,
    bool? timetableUseUnifiedCardColor,
    String? timetableUnifiedCardColor,
    String? appUpdateDownloadSource,
    String? appUpdateMirrorUrlPrefix,
  }) {
    return TimetableSettings(
      sections: sections ?? this.sections,
      activeTimeSchemeId: activeTimeSchemeId ?? this.activeTimeSchemeId,
      sectionHeight: sectionHeight ?? this.sectionHeight,
      compactFontSize: compactFontSize ?? this.compactFontSize,
      semesterWeekCount: semesterWeekCount ?? this.semesterWeekCount,
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
      showConflictBadgeOnTimetable:
          showConflictBadgeOnTimetable ?? this.showConflictBadgeOnTimetable,
      liveShowCourseName: liveShowCourseName ?? this.liveShowCourseName,
      liveShowLocation: liveShowLocation ?? this.liveShowLocation,
      liveShowCountdown: liveShowCountdown ?? this.liveShowCountdown,
      liveEnableBeforeClass:
          liveEnableBeforeClass ?? this.liveEnableBeforeClass,
      liveEnableDuringClass:
          liveEnableDuringClass ?? this.liveEnableDuringClass,
      liveEnableBeforeEnd: liveEnableBeforeEnd ?? this.liveEnableBeforeEnd,
      livePromoteDuringClass:
          livePromoteDuringClass ?? this.livePromoteDuringClass,
      liveShowDuringClassNotification: liveShowDuringClassNotification ??
          this.liveShowDuringClassNotification,
      liveUseShortName: liveUseShortName ?? this.liveUseShortName,
      liveHidePrefixText: liveHidePrefixText ?? this.liveHidePrefixText,
      liveShowBeforeClassMinutes:
          liveShowBeforeClassMinutes ?? this.liveShowBeforeClassMinutes,
      liveClassReminderStartMinutes:
          liveClassReminderStartMinutes ?? this.liveClassReminderStartMinutes,
      liveEndSecondsCountdownThreshold: liveEndSecondsCountdownThreshold ??
          this.liveEndSecondsCountdownThreshold,
      themeSeedColor: themeSeedColor ?? this.themeSeedColor,
      timetablePageBackgroundColor:
          timetablePageBackgroundColor ?? this.timetablePageBackgroundColor,
      timetableUseUnifiedCardColor:
          timetableUseUnifiedCardColor ?? this.timetableUseUnifiedCardColor,
      timetableUnifiedCardColor:
          timetableUnifiedCardColor ?? this.timetableUnifiedCardColor,
      appUpdateDownloadSource:
          appUpdateDownloadSource ?? this.appUpdateDownloadSource,
      appUpdateMirrorUrlPrefix:
          appUpdateMirrorUrlPrefix ?? this.appUpdateMirrorUrlPrefix,
    );
  }

  int get sectionCount => sections.length;

  List<int> get availableWeeks =>
      List.generate(semesterWeekCount, (index) => index + 1);

  SectionTime sectionAt(int section) => sections[section - 1];
}
