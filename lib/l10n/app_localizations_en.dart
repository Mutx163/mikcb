// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Qingyu Timetable';

  @override
  String get appTitleDebug => 'Qingyu Timetable Debug';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get previewTitle => 'Preview';

  @override
  String get timetableBackgroundPreview => 'Timetable Background';

  @override
  String get displayModeTitle => 'Display Mode';

  @override
  String get displayModeSubtitle => 'Supports system, light, and dark mode.';

  @override
  String get themeModeLabel => 'Theme Mode';

  @override
  String get themeModeSystem => 'Follow System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get fontSectionTitle => 'App Font';

  @override
  String get fontSectionSubtitle =>
      'Supports system default and MiSans. Falls back automatically if MiSans is unavailable.';

  @override
  String get fontModeLabel => 'Font';

  @override
  String get fontModeSystem => 'Phone Default';

  @override
  String get fontModeMiSans => 'Prefer MiSans';

  @override
  String get languageSectionTitle => 'App Language';

  @override
  String get languageSectionSubtitle =>
      'Follow system or switch manually to supported locales.';

  @override
  String get languageModeLabel => 'Language';

  @override
  String get languageModeSystem => 'Follow System';

  @override
  String get settingsTitle => 'Timetable Settings';

  @override
  String get dailyUsageSectionTitle => 'Daily Use';

  @override
  String get appearanceEntryTitle => 'Appearance';

  @override
  String get appearanceEntrySubtitle =>
      'Theme color, timetable background, and course card colors';

  @override
  String get layoutSectionEntryTitle => 'Layout & Sections';

  @override
  String get layoutSectionEntrySubtitle =>
      'Section times, row height, time column, weekends, and course card layout';

  @override
  String get homeWidgetEntryTitle => 'Home Widgets';

  @override
  String get homeWidgetEntrySubtitle =>
      'Today cards, widget background, and displayed information';

  @override
  String get reminderNotificationSectionTitle => 'Reminders & Notifications';

  @override
  String get userGuideEntryTitle => 'Guide & Permissions';

  @override
  String get userGuideEntrySubtitle =>
      'Short-name suggestions, notifications, auto-start, and battery policy';

  @override
  String get timetableManagementSectionTitle => 'Timetable Management';

  @override
  String get timeSchemeEntryTitle => 'Time Schemes';

  @override
  String get timeSchemeEntrySubtitleNoneSelected =>
      'Switch, edit sections, duplicate, and manage time schemes';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return 'Current: $name · switch, edit sections, and duplicate';
  }

  @override
  String get dataTransferEntryTitle => 'Backup & Migration';

  @override
  String get dataTransferEntrySubtitle =>
      'Export a complete timetable file for others to import directly';

  @override
  String get aboutSupportSectionTitle => 'About & Support';

  @override
  String get feedbackEntryTitle => 'Feedback';

  @override
  String get feedbackEntrySubtitle =>
      'Issue tracker, community channels, and suggestion entry';

  @override
  String get aboutEntryTitle => 'About';

  @override
  String get aboutEntrySubtitle =>
      'Open source info, version updates, and GitHub repositories';

  @override
  String get setSemesterStartDateAction => 'Set Semester Start';

  @override
  String get semesterStartDateAction => 'Semester Start';

  @override
  String get syncCurrentWeekAction => 'Sync Current Week';

  @override
  String semesterWeekCountAction(int count) {
    return '$count weeks';
  }

  @override
  String get selectSemesterWeekCountTitle => 'Select Semester Week Count';

  @override
  String get selectSemesterWeekCountSubtitle =>
      'Adjust this based on your school’s actual teaching weeks.';

  @override
  String get unifiedCourseCardColorTitle => 'Use Unified Course Card Color';

  @override
  String get unifiedCourseCardColorSubtitle =>
      'If disabled, each course keeps its own color.';

  @override
  String get courseImportTitle => 'Import Courses';

  @override
  String get chooseImportMethodTitle => 'Choose Import Method';

  @override
  String get chooseImportMethodSubtitle =>
      'Supports traditional .ics calendar import, AI image import, and warehouse-based academic system import.';

  @override
  String get importMethodIcsTitle => '.ics Calendar Import';

  @override
  String get importMethodIcsSubtitle =>
      'Best for calendar files exported from apps like WakeUp.';

  @override
  String get importMethodIcsFooter =>
      'Pick an .ics file directly. You can append or replace existing courses.';

  @override
  String get importMethodAiTitle => 'Image Import';

  @override
  String get importMethodAiSubtitle =>
      'Best for direct timetable screenshots, including multiple continuous screenshots.';

  @override
  String get importMethodAiFooter =>
      'Copy the prompt, send screenshots to the AI expert mode, paste the JSON result back, then choose semester start date.';

  @override
  String get importMethodWarehouseTitle => 'Academic System Import';

  @override
  String get importMethodWarehouseSubtitle =>
      'Read schools and adapters from qingyu_warehouse and import through the web login flow.';

  @override
  String get importMethodWarehouseFooter =>
      'Choose a school and adapter, then open the academic system page and run the import.';

  @override
  String get icsImportTitle => '.ics Calendar Import';

  @override
  String get applicableScenarioTitle => 'When to use';

  @override
  String get icsScenarioIntro =>
      'If you can already import courses into WakeUp or similar apps and export them as an .ics file, this path is the most stable.';

  @override
  String stepLabel(String step) {
    return 'Step $step';
  }

  @override
  String get icsStep1Subtitle =>
      'Export an .ics calendar file from another timetable app first.';

  @override
  String get icsStep2Subtitle =>
      'Come back here to pick the file and choose append or replace.';

  @override
  String get icsStep3Subtitle =>
      'Before importing, confirm the semester start date and which semester week your timetable week 1 maps to.';

  @override
  String get supportedFilesTitle => 'Supported Files';

  @override
  String get supportedFilesSuffix => 'The file extension must be .ics.';

  @override
  String get supportedFilesImageHint =>
      'If you only have screenshots, go back and choose Image Import instead.';

  @override
  String get chooseIcsFileAction => 'Choose .ics File';

  @override
  String get timetableAppName => 'Qingyu Timetable';

  @override
  String get switchProfileHint => 'Tap to switch timetable';

  @override
  String get moreTooltip => 'More';

  @override
  String get pleaseSetSemesterStartDate =>
      'Please set the semester start date in timetable settings first.';

  @override
  String get deleteScheduleTitle => 'Delete Schedule';

  @override
  String get deleteLessonTitle => 'Delete This Lesson';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get deleteAction => 'Delete';

  @override
  String deletedCourseMessage(String name) {
    return 'Deleted: $name';
  }

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get rescheduleFailed => 'Reschedule failed';

  @override
  String get timetableManagement => 'Timetable Management';

  @override
  String weekLabel(int week) {
    return 'Week $week';
  }

  @override
  String sectionLabel(int section) {
    return 'Section $section';
  }

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackIntro =>
      'If you encounter crashes, timetable display issues, import problems, or want to suggest features, you can use the channels below.';

  @override
  String get feedbackIssueHint =>
      'For issues with reproduction steps, screenshots, app version, or logs, GitHub Issue is recommended first.';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle =>
      'Open the repository issue page to submit bugs, suggestions, or review existing reports.';

  @override
  String get openIssuePage => 'Open Issues';

  @override
  String get copyAddress => 'Copy Link';

  @override
  String get copiedIssueAddress => 'Issue link copied';

  @override
  String get copyXiaohongshuId => 'Copy Xiaohongshu ID';

  @override
  String get copiedXiaohongshuId => 'Xiaohongshu ID copied';

  @override
  String get copyCoolapkId => 'Copy Coolapk ID';

  @override
  String get copiedCoolapkId => 'Coolapk ID copied';

  @override
  String get copyQqGroupId => 'Copy QQ Group ID';

  @override
  String get copiedQqGroupId => 'QQ group ID copied';

  @override
  String get timetableProfilesTitle => 'Timetable Profiles';

  @override
  String get createTimetableTooltip => 'Create timetable';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count courses · Week $week';
  }

  @override
  String get moreActionsTooltip => 'More Actions';

  @override
  String get switchToThisTimetable => 'Switch to this timetable';

  @override
  String get renameAction => 'Rename';

  @override
  String get duplicateAction => 'Duplicate';

  @override
  String get clearCoursesAction => 'Clear Courses';

  @override
  String get usingNow => 'Currently Active';

  @override
  String switchedToProfile(String name) {
    return 'Switched to $name';
  }

  @override
  String get createTimetableTitle => 'Create Timetable';

  @override
  String get timetableNameLabel => 'Timetable Name';

  @override
  String get timetableNameHint => 'e.g. Sophomore Spring';

  @override
  String get createAction => 'Create';

  @override
  String createdProfile(String name) {
    return 'Created timetable: $name';
  }

  @override
  String get renameTimetableTitle => 'Rename Timetable';

  @override
  String get saveAction => 'Save';

  @override
  String renamedProfile(String name) {
    return 'Renamed to $name';
  }

  @override
  String get clearCurrentTimetableTitle => 'Clear Current Timetable';

  @override
  String clearCurrentTimetableMessage(String name) {
    return 'Clear all courses in “$name”? Timetable settings will be kept.';
  }

  @override
  String get clearAction => 'Clear';

  @override
  String clearedProfile(String name) {
    return 'Cleared timetable: $name';
  }

  @override
  String get noCoursesInCurrentProfile => 'This timetable has no courses.';

  @override
  String get deleteTimetableTitle => 'Delete Timetable';

  @override
  String deleteTimetableMessage(String name) {
    return 'Delete “$name”?';
  }

  @override
  String deletedProfile(String name) {
    return 'Deleted timetable: $name';
  }

  @override
  String get keepAtLeastOneProfile => 'Keep at least one timetable';

  @override
  String get dataTransferTitle => 'Backup & Migration';

  @override
  String get fullExportTitle => 'Export';

  @override
  String get fullExportSubtitle =>
      'Export the current timetable, or export all timetables, time schemes, and the current selection.';

  @override
  String get exportCurrentTimetable => 'Export Current Timetable';

  @override
  String get exportAllData => 'Export All Data';

  @override
  String get fullImportTitle => 'Import';

  @override
  String get fullImportSubtitle =>
      'When importing, you can overwrite the current timetable or import it as a new timetable. Export your backup first if possible.';

  @override
  String get chooseFileAndImport => 'Choose File and Import';

  @override
  String get transferOverviewTitle => 'Current Backup Contents';

  @override
  String courseCountBullet(int count) {
    return 'Courses: $count';
  }

  @override
  String currentTimetableBullet(String name) {
    return 'Current timetable: $name';
  }

  @override
  String allTimetablesBullet(int count) {
    return 'All timetables: $count';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return 'Time schemes: $count';
  }

  @override
  String currentWeekBullet(int week) {
    return 'Current week: Week $week';
  }

  @override
  String get semesterStartUnsetBullet => 'Semester start date: not set';

  @override
  String semesterStartBullet(String date) {
    return 'Semester start date: $date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return 'File extension: .$extension';
  }

  @override
  String get selectImportModeTitle => 'Choose Import Mode';

  @override
  String get selectImportModeMessage =>
      'You can overwrite the current timetable, or import the backup as a new standalone timetable.';

  @override
  String get replaceCurrentTimetable => 'Overwrite Current Timetable';

  @override
  String get importAsNewTimetable => 'Import as New Timetable';

  @override
  String get createdNewTimetableAfterImport =>
      'Import succeeded, a new timetable was created';

  @override
  String get backupRestoredSuccess => 'Import succeeded, backup data restored';

  @override
  String get importFailedInvalidFile =>
      'Import failed. Please check whether the file is valid.';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeAppName => 'Qingyu Timetable';

  @override
  String get welcomeSubtitle =>
      'You can start using the app right away, or import courses / restore a backup first.';

  @override
  String get startUsingTitle => 'Start Using';

  @override
  String get startUsingSubtitle =>
      'Enter the app directly and continue the first-use guide';

  @override
  String get importTimetableTitle => 'Import Timetable';

  @override
  String get importTimetableSubtitle =>
      'Import courses from an .ics file or AI parsing result';

  @override
  String get restoreBackupTitle => 'Restore from Backup';

  @override
  String get restoreBackupSubtitle =>
      'Restore old data from a .mikcb backup file';

  @override
  String get viewGuideTitle => 'View Guide';

  @override
  String get viewGuideSubtitle =>
      'Read permissions, island, and basic setup first';

  @override
  String get migrationTitle => 'Migrate Old Data';

  @override
  String get migrationSafeTitle => 'Don’t worry, your data is not lost';

  @override
  String get migrationSafeSubtitle =>
      'We changed the app package name, so you may temporarily see two app icons. This is normal. Your old data is still in the old app. Back it up there first, then import it here.';

  @override
  String get migrationStep1Title => 'Open the old app';

  @override
  String get migrationStep1Subtitle =>
      'Go to Backup & Migration and choose Export All Data. Do not export only the current timetable, and do not uninstall the old app first.';

  @override
  String get migrationStep2Title => 'Save the backup file';

  @override
  String get migrationStep2Subtitle =>
      'After exporting, the old app will open the system share sheet. Prefer Save to Files, and store it in the Download folder.';

  @override
  String get migrationStep3Title => 'Return to this version and import';

  @override
  String get migrationStep3Subtitle =>
      'Return to the new version, choose the .mikcb backup file from Download, and restore it. Only uninstall the old app after confirming everything works here.';

  @override
  String get migrationNoSaveToFilesTitle => 'If “Save to Files” is unavailable';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      'You can first share the backup to any WeChat chat, then open the file in WeChat and save it. It usually ends up in Download or the WeiXin folder. Then return here and import that .mikcb file.';

  @override
  String get openingOldApp => 'Opening old app...';

  @override
  String get openOldAppForBackup => 'Open old app for backup';

  @override
  String get backupDoneGoImport => 'I finished backup, continue to import';

  @override
  String get startFreshWithoutMigration => 'Start fresh without migration';

  @override
  String get openOldAppFailed =>
      'Failed to open the old app. Please return to the home screen and open it manually.';

  @override
  String get supportCreatorTitle => 'Buy the Creator a Coffee';

  @override
  String get supportHeroTitle => 'Support Qingyu Timetable';

  @override
  String get supportHeroSubtitle =>
      'Your support goes directly into timetable maintenance, academic adapter updates, and overall experience improvements.';

  @override
  String get supportChipFixes => 'Bug Fixes';

  @override
  String get supportChipAdapters => 'Adapters';

  @override
  String get supportChipPolish => 'Polish';

  @override
  String get supportMethodTitle => 'Choose a Support Method';

  @override
  String get wechatLabel => 'WeChat';

  @override
  String get alipayLabel => 'Alipay';

  @override
  String get supportWeChatHint => 'Use WeChat to scan and support the creator';

  @override
  String get supportAlipayHint => 'Use Alipay to scan and support the creator';

  @override
  String get viewLargeImage => 'View Large Image';

  @override
  String get saveToGallery => 'Save to Gallery';

  @override
  String get supportCompleteThanks =>
      'Thanks for supporting Qingyu Timetable ❤️';

  @override
  String get supportConfirmed => 'I’ve Supported';

  @override
  String get donorListTitle => 'Acknowledgements';

  @override
  String get donorListLoadFailed =>
      'The online donor list is temporarily unavailable.';

  @override
  String get reloadAction => 'Reload';

  @override
  String updatedAtLabel(String time) {
    return 'Updated at $time';
  }

  @override
  String get donorListEmpty =>
      'The donor list is still empty. You can edit docs/donors.json and publish again.';

  @override
  String get savedToGallery => 'Saved to gallery';

  @override
  String get saveToGalleryFailed => 'Failed to save to gallery';

  @override
  String saveFailedWithError(String error) {
    return 'Save failed: $error';
  }

  @override
  String get courseOverviewTitle => 'Course Overview & Edit';

  @override
  String get addNewCourseTooltip => 'Add New Course';

  @override
  String get emptyCourseOverviewHint =>
      'Long press the timetable or tap the top-right button to add a course';

  @override
  String conflictDetectedMessage(int count) {
    return '$count scheduled entries have actual conflicts. Conflicting items are highlighted below.';
  }

  @override
  String conflictCountLabel(int count) {
    return 'Conflicts: $count';
  }

  @override
  String scheduledCountLabel(int count) {
    return '$count entries';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '$count entries · expand to review conflicts';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return 'Time: Weekday $day · Sections $start-$end';
  }

  @override
  String get teacherUnset => 'Unknown Teacher';

  @override
  String get locationUnset => 'Unknown Location';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  Teacher: $teacher  Room: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  Teacher: $teacher  Room: $location\nConflicting courses: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => 'Confirm Delete';

  @override
  String confirmDeleteCourseMessage(String name) {
    return 'Delete course “$name”?';
  }

  @override
  String get currentScheduleTitle => 'Current Schedule Entry';

  @override
  String get currentScheduleSubtitle =>
      'Weekday, sections, room, weeks, and odd/even settings here only affect this single schedule entry.';

  @override
  String get timeSchemeLabel => 'Time Scheme';

  @override
  String followCurrentTimetableWithName(String name) {
    return 'Follow current timetable ($name)';
  }

  @override
  String get followCurrentTimetableDescription =>
      'By default this course follows the timetable’s main time scheme, which suits most courses.';

  @override
  String get overrideTimeSchemeDescription =>
      'This course will use the selected scheme separately instead of following the timetable’s main schedule.';

  @override
  String get weekdayLabel => 'Weekday';

  @override
  String get startSectionLabel => 'Start Section';

  @override
  String get endSectionLabel => 'End Section';

  @override
  String timeRangeLabel(String start, String end) {
    return 'Time: $start - $end';
  }

  @override
  String get locationLabel => 'Location';

  @override
  String get singleLessonWeekTitle => 'Lesson Week';

  @override
  String get singleLessonWeekSubtitle =>
      'Single lessons only appear in one week, which is ideal for make-up or temporary classes.';

  @override
  String get selectWeekLabel => 'Select Week';

  @override
  String get weekSettingsTitle => 'Week Settings';

  @override
  String get rangeWeeksLabel => 'Continuous Weeks';

  @override
  String get customWeeksLabel => 'Custom Weeks';

  @override
  String get startWeekLabel => 'Start Week';

  @override
  String get endWeekLabel => 'End Week';

  @override
  String get allWeeksFilter => 'All';

  @override
  String get oddWeeksFilter => 'Odd Weeks';

  @override
  String get evenWeeksFilter => 'Even Weeks';

  @override
  String get rangeWeeksAllHint =>
      'Schedule continuously from the start week to the end week.';

  @override
  String get rangeWeeksOddHint => 'Keep only odd weeks in the selected range.';

  @override
  String get rangeWeeksEvenHint =>
      'Keep only even weeks in the selected range.';

  @override
  String get selectAllAction => 'Select All';

  @override
  String get selectOddWeeksAction => 'Odd Weeks';

  @override
  String get selectEvenWeeksAction => 'Even Weeks';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '$count weeks selected: Week $weeks';
  }

  @override
  String get courseColorTitle => 'Course Color';

  @override
  String get customPaletteAction => 'Custom Palette Color';

  @override
  String get colorPaletteTitle => 'Color Palette';

  @override
  String get colorHexLabel => 'Color Hex';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String hueLabel(int value) {
    return 'Hue $value';
  }

  @override
  String saturationLabel(int value) {
    return 'Saturation $value%';
  }

  @override
  String brightnessLabel(int value) {
    return 'Brightness $value%';
  }

  @override
  String get useThisColor => 'Use This Color';

  @override
  String get selectAtLeastOneWeek => 'Please select at least one week';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get courseAddedSuccess => 'Course added successfully';

  @override
  String get courseUpdatedSuccess => 'Course updated successfully';

  @override
  String get aboutTitle => 'About';

  @override
  String get loadingText => 'Loading...';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get aboutHeroSubtitle =>
      'An open-source Android project focused on timetable viewing, course reminders, and the HyperOS island experience.';

  @override
  String get platformLabel => 'Platform';

  @override
  String get focusLabel => 'Focus';

  @override
  String get updateLabel => 'Updates';

  @override
  String get prereleaseIncluded => 'Includes prerelease';

  @override
  String get stableOnly => 'Stable only';

  @override
  String get aboutUpdatesTitle => 'App Updates';

  @override
  String get aboutUpdatesSubtitle =>
      'Check updates, download now, and open testing / diagnostics tools.';

  @override
  String get aboutChangelogTitle => 'Changelog';

  @override
  String get aboutChangelogSubtitle => 'View update notes for all versions';

  @override
  String get aboutPositioningTitle => 'Project Positioning';

  @override
  String get aboutPositioningSubtitle =>
      'What it is, who it is for, and its core capabilities.';

  @override
  String get aboutPositioningBullet1 =>
      'Supports weekly timetable view, course add/edit/delete, and .ics import.';

  @override
  String get aboutPositioningBullet2 =>
      'Supports academic system web import and full backup migration for adapted schools.';

  @override
  String get aboutPositioningBullet3 =>
      'Supports live notifications; HyperOS 3.0.300+ supports island / focus notification presentation.';

  @override
  String get aboutPositioningBullet4 =>
      'Supports multi-timetable profiles, time schemes, theme colors, and card style customization.';

  @override
  String get aboutImportMigrationTitle => 'Import & Migration';

  @override
  String get aboutImportMigrationSubtitle =>
      'Current import methods, backup restore, and migration advice.';

  @override
  String get aboutImportMigrationBullet1 =>
      'The current version already supports academic system web import for adapted schools; enter Import Courses > Academic System Import, then choose a school and adapter.';

  @override
  String get aboutImportMigrationBullet2 =>
      'If your school is not adapted yet, you can still import into WakeUp or a similar app first, export as a calendar file, and then import it here.';

  @override
  String get aboutImportMigrationBullet3 =>
      'If someone else is already using this app, they can export a full backup and you can restore it directly in Backup & Migration.';

  @override
  String get aboutImportMigrationBullet4 =>
      'If you know packet capture, web debugging, or JavaScript, you are welcome to contribute adapters in qingyu_warehouse.';

  @override
  String get aboutContributorsTitle => 'Contributors';

  @override
  String get aboutContributorsSubtitle =>
      'Developers and academic system adapter contributors.';

  @override
  String get aboutRepositoryTitle => 'Open Source Repositories';

  @override
  String get aboutAppLogsTitle => 'App logs';

  @override
  String get aboutAppLogsSubtitle =>
      'Open the dedicated page for full app logs across error / warn / info / debug / verbose levels';

  @override
  String get appLogsShareText =>
      'These are the app logs exported from Qingyu Timetable. They include local runtime records across the whole app for troubleshooting updates, imports, notifications, screens, and crashes.';

  @override
  String get appLogsShareSubject => 'Qingyu Timetable - App logs';

  @override
  String get appLogsRecordingEnabled => 'App log recording is on';

  @override
  String get appLogsRecordingDisabled => 'App log recording is off';

  @override
  String get appLogsCopyAction => 'Copy logs';

  @override
  String get appLogsCopied => 'Current logs copied';

  @override
  String get appLogsExportAction => 'Export logs';

  @override
  String get appLogsClearAction => 'Clear logs';

  @override
  String get appLogsCleared => 'App logs cleared';

  @override
  String get appLogsClearFailed => 'Failed to clear app logs';

  @override
  String get aboutRepositorySubtitle =>
      'GitHub source, releases, and feedback entry.';

  @override
  String get timeSchemeTitle => 'Time Schemes';

  @override
  String get newSchemeTooltip => 'Create Scheme';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections sections · $profiles timetables · $courses course entries · $overrideCourses override entries';
  }

  @override
  String get viewUsageAction => 'View Usage';

  @override
  String get applyToCurrentTimetable => 'Apply to Current Timetable';

  @override
  String get editSectionsAction => 'Edit Sections';

  @override
  String get createTimeSchemeTitle => 'Create Time Scheme';

  @override
  String get timeSchemeNameLabel => 'Scheme Name';

  @override
  String get timeSchemeNameHint => 'e.g. Summer Schedule';

  @override
  String get renameTimeSchemeTitle => 'Rename Time Scheme';

  @override
  String renamedToMessage(String name) {
    return 'Renamed to $name';
  }

  @override
  String get deleteTimeSchemeTitle => 'Delete Time Scheme';

  @override
  String deleteTimeSchemeMessage(String name) {
    return 'Delete “$name”? A scheme in use cannot be deleted.';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return 'Deleted time scheme: $name';
  }

  @override
  String get timeSchemeInUseMessage =>
      'This scheme is currently used by a timetable.';

  @override
  String get copiedTimeSchemeMessage => 'Time scheme copied';

  @override
  String appliedTimeSchemeMessage(String name) {
    return 'Applied time scheme: $name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return 'Usage of “$name”';
  }

  @override
  String get timeSchemeUsageIntro =>
      'Review the total impact first, then decide whether to edit this scheme directly or duplicate it before making changes.';

  @override
  String get profileCountLabel => 'Profiles';

  @override
  String get courseCountLabel => 'Courses';

  @override
  String get overrideTimeSchemeLabel => 'Override Entries';

  @override
  String get directlyBoundProfilesTitle =>
      'Profiles directly using this scheme';

  @override
  String get directlyBoundProfilesEmpty =>
      'No timetable is directly using this scheme.';

  @override
  String get directlyBoundProfilesSubtitle =>
      'Timetables in this list use this scheme as their main time schedule.';

  @override
  String get followMainSchemeCoursesTitle =>
      'Courses following the timetable main scheme';

  @override
  String get followMainSchemeCoursesEmpty =>
      'No course is indirectly using this scheme via its timetable.';

  @override
  String get followMainSchemeCoursesSubtitle =>
      'These courses do not set an override time scheme and follow the timetable’s main schedule.';

  @override
  String get overrideSchemeCoursesTitle =>
      'Courses using this as an override scheme';

  @override
  String get overrideSchemeCoursesEmpty =>
      'No course is using this scheme as an override.';

  @override
  String get overrideSchemeCoursesSubtitle =>
      'These courses will continue using this scheme even if their timetable changes its main schedule.';

  @override
  String get closeAction => 'Close';

  @override
  String get editTimeSchemeTitle => 'Edit Time Scheme';

  @override
  String get backToSchemeList => 'Back to Scheme List';

  @override
  String get currentInUse => 'Currently Used';

  @override
  String get quickGenerateAction => 'Quick Generate';

  @override
  String get addSectionAction => 'Add Section';

  @override
  String get removeLastSectionAction => 'Remove Last Section';

  @override
  String get resetDefaultAction => 'Restore Defaults';

  @override
  String get sectionTimesTitle => 'Section Times';

  @override
  String get sectionTimesSubtitle =>
      'If the current timetable is using this scheme, the section count cannot be lower than the maximum section already in use.';

  @override
  String get schemeListCurrentLabel => 'Current';

  @override
  String get schemeListCountLabel => 'Count';

  @override
  String get sectionCountLabel => 'Sections';

  @override
  String get quickGenerateTimeSchemeTitle => 'Quick Generate Timetable Times';

  @override
  String get addBreakRuleAction => 'Add Break Rule';

  @override
  String get afterSectionLabel => 'After Section';

  @override
  String get breakDurationMinutesLabel => 'Break Duration (min)';

  @override
  String get fillNumbersValidationMessage =>
      'Please fill both section count and duration with numbers';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      'The current timetable and some courses are using this time scheme. Saving will update all related timetables and courses.';

  @override
  String get timeSchemeEditorActiveHint =>
      'The current timetable is using this time scheme. Saving will update every timetable that relies on it.';

  @override
  String get timeSchemeEditorOverrideHint =>
      'Some courses are using this time scheme as an override. Saving will update every referenced course.';

  @override
  String get editTimeAction => 'Edit Time';

  @override
  String editingSchemeLabel(String name) {
    return 'Editing: $name';
  }

  @override
  String get copiedTimeSchemeShortMessage => 'Time scheme copied';

  @override
  String get unnamedTimeScheme => 'Unnamed Scheme';

  @override
  String get unsetLabel => 'Not Selected';

  @override
  String get timeSchemeUsageCourseRefPrefix => 'Course references: ';

  @override
  String get mainTimeSchemeLabel => 'Main Scheme';

  @override
  String get overrideTimeSchemeShortLabel => 'Override Scheme';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first and $count course entries';
  }

  @override
  String get morningSectionCountLabel => 'Morning Sections';

  @override
  String get morningFirstSectionTimeLabel => 'First Morning Class Time';

  @override
  String get afternoonSectionCountLabel => 'Afternoon Sections';

  @override
  String get afternoonFirstSectionTimeLabel => 'First Afternoon Class Time';

  @override
  String get eveningSectionCountLabel => 'Evening Sections';

  @override
  String get eveningFirstSectionTimeLabel => 'First Evening Class Time';

  @override
  String get classDurationMinutesLabel => 'Single Class Duration (min)';

  @override
  String get smallBreakDurationMinutesLabel => 'Short Break Duration (min)';

  @override
  String get largeBreakRulesTitle => 'Long Break Rules';

  @override
  String get noLargeBreakRulesHint =>
      'No long break rule has been set. The short break duration will be used everywhere.';

  @override
  String get deleteRuleTooltip => 'Delete Rule';

  @override
  String get generateAction => 'Generate';

  @override
  String get liveSettingsTitle => 'Island & Notifications';

  @override
  String get liveReminderTimingEntryTitle => 'Reminder Timing';

  @override
  String get liveReminderTimingEntrySubtitle =>
      'Before class, during class / before end toggles, and when to switch into highlighted reminders.';

  @override
  String get liveBeforeClassDisplayEntryTitle => 'Before Class Display';

  @override
  String get liveDuringEndDisplayEntryTitle =>
      'During Class / Before End Display';

  @override
  String get liveKeepAliveEntryTitle => 'Keep Alive';

  @override
  String get liveKeepAliveEntrySubtitle =>
      'Hide from recents, accessibility keep-alive helper, and permission shortcuts.';

  @override
  String get liveTestingEntryTitle => 'Testing & Diagnostics';

  @override
  String get liveTestingEntrySubtitle =>
      'Send test notifications and inspect island diagnostics logs.';

  @override
  String get followBeforeClassSetting => 'Follow Before-class Settings';

  @override
  String get liveReminderTimingTitle => 'Reminder Timing';

  @override
  String get liveReminderSwitchesTitle => 'Reminder Switches';

  @override
  String get liveReminderSwitchesSubtitle =>
      'Different reminder windows can be combined freely; these switches do not replace each other.';

  @override
  String get beforeClassReminderTitle => 'Before Class Reminder';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return 'Trigger $minutes minutes before class starts';
  }

  @override
  String get duringClassReminderTitle => 'During Class / Before End Reminder';

  @override
  String get duringClassReminderSubtitle =>
      'Only affects the period after class starts and before it ends';

  @override
  String get liveClassReminderLeadTitle =>
      'When to switch to highlighted island reminders before class ends';

  @override
  String get liveClassReminderLeadOptionImmediate =>
      'Switch immediately when class starts';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return 'Switch $minutes min before class ends';
  }

  @override
  String get liveDisplayModeTitle => 'Display Style';

  @override
  String get liveDisplayModeSubtitle => 'Applies to enabled reminder windows.';

  @override
  String get duringClassStatusNotificationTitle =>
      'During-class Status Notification';

  @override
  String get duringClassStatusNotificationImmediate =>
      'Keep a status notification after class begins';

  @override
  String get duringClassStatusNotificationBeforeEnd =>
      'Keep a regular notification until highlighted reminders begin before class ends';

  @override
  String get duringClassStatusNotificationPersistent =>
      'Keep a regular during-class notification, then switch before class ends';

  @override
  String get enableIslandDisplayTitle => 'Enable Island / Dynamic Presentation';

  @override
  String get enableIslandDisplaySubtitle =>
      'Disable this if you never want the app to trigger system island presentation';

  @override
  String get liveTimeThresholdTitle => 'Timing Thresholds';

  @override
  String get liveTimeThresholdSubtitle =>
      'Controls when reminders appear, when highlighted reminders start, and when to switch to second-level countdown.';

  @override
  String get beforeClassPopupLabel => 'Before-class trigger';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes min';
  }

  @override
  String get beforeEndSecondsLabel => 'Before-end second-level threshold';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds sec';
  }

  @override
  String timeCorrectionLabel(String value) {
    return 'Bell-time correction: $value';
  }

  @override
  String get timeCorrectionHelp =>
      'If the school bell is early, shift earlier. If the bell is late, shift later.';

  @override
  String get duringEndTimeDisplayLabel =>
      'During-class / before-end time style';

  @override
  String get duringEndTimeDisplayHelp =>
      'Choose whether compact reminders show nearest time or the total remaining time.';

  @override
  String get liveDisplayContentTitle => 'Display Content';

  @override
  String get liveDisplayContentSubtitle =>
      'These settings only affect the current stage and do not change the other reminder stage.';

  @override
  String get showCourseNameTitle => 'Show Course Name';

  @override
  String get preferShortNameTitle => 'Prefer Short Course Name';

  @override
  String get preferShortNameSubtitle =>
      'Short names work best within 3 characters.';

  @override
  String get showLocationTitle => 'Show Location';

  @override
  String get showCountdownTitle => 'Show Countdown';

  @override
  String get countdownFormatLabel => 'Countdown Format';

  @override
  String get countdownFormatHelp =>
      'Minute-only styles refresh by minute; second-based styles refresh by second.';

  @override
  String get showStageTextTitle => 'Show Stage Label';

  @override
  String get showStageTextSubtitle =>
      'If countdown is hidden, you can still show labels like before class / in class / before end.';

  @override
  String get hidePrefixTextTitle => 'Hide Prefix Text';

  @override
  String get hidePrefixTextSubtitle =>
      'For example, hide prefixes like “before class”.';

  @override
  String get beforeClassQuickActionTitle => 'Before-class Quick Action';

  @override
  String get beforeClassQuickActionSubtitle =>
      'Only appears in the expanded before-class reminder. Do Not Disturb may open a system permission page on first use.';

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => 'Left Icon & Expanded View';

  @override
  String get liveIslandVisualSubtitle =>
      'The left text icon, expanded large icon, and custom image are all stored separately for the current stage.';

  @override
  String get liveMiuiLabelImageTitle => 'Xiaomi Island Left Text Icon';

  @override
  String get liveMiuiLabelImageSubtitle =>
      'Only effective on Xiaomi-style island layouts. It renders course name or location into the left icon slot.';

  @override
  String get liveMiuiLabelContentLabel => 'Left Text Content';

  @override
  String get liveMiuiLabelStyleLabel => 'Left Icon Style';

  @override
  String get liveMiuiLabelLogoTitle => 'Left Icon Logo';

  @override
  String get liveMiuiLabelLogoSubtitle =>
      'Only applies to the icon + text style. If not selected, the app icon remains the fallback.';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return 'Left Icon Corner Radius $value';
  }

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return 'Left Text Size $value';
  }

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return 'Left Text Horizontal Offset $value';
  }

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return 'Left Text Vertical Offset $value';
  }

  @override
  String get liveMiuiLabelFontWeightLabel => 'Left Text Weight';

  @override
  String get liveMiuiLabelRenderQualityLabel => 'Left Text Render Quality';

  @override
  String get liveMiuiExpandedIconLabel => 'Expanded Large Icon';

  @override
  String get selectImageAction => 'Choose Image';

  @override
  String get replaceImageAction => 'Replace Image';

  @override
  String get liveDisplayConfigModeTitle => 'Configuration Mode';

  @override
  String get liveDisplayConfigModeSubtitle =>
      'When enabled, during-class and before-end reminders fully follow the before-class display settings, and the controls below become read-only.';

  @override
  String get followBeforeClassDisplayTitle =>
      'Follow Before-class Display Settings';

  @override
  String get liveKeepAliveTitle => 'Keep Alive';

  @override
  String get liveKeepAliveOptionsTitle => 'Keep-alive Options';

  @override
  String get liveKeepAliveOptionsSubtitle =>
      'Used to improve island and reminder stability in background scenarios.';

  @override
  String get hideFromRecentsTitle => 'Hide from Recents';

  @override
  String get hideFromRecentsSubtitle =>
      'When enabled, the app will try not to appear in the recent tasks list.';

  @override
  String get keepAliveServiceTitle => 'Qingyu Timetable Keep-alive Service';

  @override
  String get keepAliveServiceEnabledSubtitle =>
      'Currently enabled. The system will keep the accessibility-based keep-alive helper available.';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      'Currently disabled. You can open system accessibility settings and enable the Qingyu Timetable keep-alive service manually.';

  @override
  String get goEnableAction => 'Enable Now';

  @override
  String get layoutEntryTitle => 'Layout & Sections';

  @override
  String get layoutEntrySubtitle =>
      'Section times, row height, time column, weekend visibility, and card layout';

  @override
  String get remindersSectionTitle => 'Reminders & Notifications';

  @override
  String get liveGuideEntryTitle => 'Guide & Permissions';

  @override
  String get liveGuideEntrySubtitle =>
      'Short-name suggestions, notifications, auto-start, and battery policy';

  @override
  String get managementSectionTitle => 'Timetable Management';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return 'Current: $name · switch, edit sections, and duplicate';
  }

  @override
  String get timeSchemeEntrySubtitle =>
      'Switch, edit section times, duplicate, and manage time schemes';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return 'Week $current / $total';
  }

  @override
  String get semesterStartUnset => 'Semester start date not set';

  @override
  String semesterStartSet(String date) {
    return 'Semester start: $date';
  }

  @override
  String get setSemesterStartDate => 'Set Semester Start';

  @override
  String get semesterStartDateLabel => 'Semester Start Date';

  @override
  String syncedCurrentWeekMessage(int week) {
    return 'Synced to week $week';
  }

  @override
  String get pickSemesterWeekCountTitle => 'Choose Semester Week Count';

  @override
  String get pickSemesterWeekCountSubtitle =>
      'Different schools may use different total teaching weeks.';

  @override
  String weekCountItem(int count) {
    return '$count weeks';
  }

  @override
  String get diagnosticsLogIntro =>
      'Supports both Markdown and raw views so you can inspect full logs directly on your phone.';

  @override
  String get diagnosticsRawTab => 'Raw';

  @override
  String get diagnosticsStructuredTab => 'Structured';

  @override
  String get diagnosticsLevelLabel => 'Level';

  @override
  String get diagnosticsLevelAll => 'All';

  @override
  String get diagnosticsLevelError => 'Error';

  @override
  String get diagnosticsLevelWarn => 'Warn';

  @override
  String get diagnosticsLevelInfo => 'Info';

  @override
  String get diagnosticsLevelDebug => 'Debug';

  @override
  String get diagnosticsLevelVerbose => 'Verbose';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return 'Showing $shown of $total logs';
  }

  @override
  String get diagnosticsNoMatchingTitle => 'No logs match this filter';

  @override
  String get diagnosticsNoMatchingSubtitle =>
      'Switch back to \"All\" or check the raw view to continue debugging.';

  @override
  String get diagnosticsLevelInferred => 'Inferred level';

  @override
  String get diagnosticsRawFilteredHint =>
      'The raw view follows the current level filter and only shows matching log blocks.';

  @override
  String get diagnosticsEmptyTitle => 'No Logs Yet';

  @override
  String get diagnosticsEmptySubtitle =>
      'There are currently no island diagnostics logs to display.';

  @override
  String get diagnosticsLogTitleFallback => 'Island Diagnostics Log';

  @override
  String get diagnosticsDeviceInfoTitle => 'Device & Export Info';

  @override
  String get diagnosticsContentTitle => 'Log Content';

  @override
  String get diagnosticsRecentLogsTitle => 'Recent Logs';

  @override
  String get diagnosticsUnknownCategory => 'Uncategorized Event';

  @override
  String get diagnosticsExportedAt => 'Exported At';

  @override
  String get diagnosticsTime => 'Time';

  @override
  String get diagnosticsCategory => 'Category';

  @override
  String get diagnosticsMessage => 'Message';

  @override
  String get diagnosticsStackTrace => 'Stack Trace';

  @override
  String get firstUseGuideTitle => 'First Use Guide';

  @override
  String get guideAndPermissionsTitle => 'Guide & Permissions';

  @override
  String get refreshStatusTooltip => 'Refresh Status';

  @override
  String get guideHeroTitle =>
      'Finish this page first, then start using the app';

  @override
  String get guideHeroSubtitle =>
      'Authorize the essentials on the first screen. Below you’ll also see HyperOS support, short-name setup, and import guidance, so keep scrolling.';

  @override
  String get guideChipPermissions => 'Permissions';

  @override
  String get guideChipShortName => 'Short Names';

  @override
  String get guideChipImport => 'Import Timetable';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 Ready';
  }

  @override
  String get guideBottomReachedHint =>
      'You’ve reached the end. If everything looks right, you can start using the app now.';

  @override
  String get guideScrollHint =>
      'Scroll down to continue. HyperOS support, the permission checklist, short-name setup, and import methods are all below.';

  @override
  String get guideRequestNotificationFirst =>
      'Request Notification Permission First';

  @override
  String get quickSetupTitle => 'Quick Setup';

  @override
  String get quickSetupSubtitle =>
      'Put the 5 most important entries first so you don’t need to search for them later.';

  @override
  String get quickActionNotificationsTitle => 'Notification Settings';

  @override
  String get quickActionNotificationsSubtitle =>
      'Make sure notifications can be sent';

  @override
  String get quickActionIslandTitle => 'Island Permission';

  @override
  String get quickActionIslandSubtitle => 'Check promoted notifications';

  @override
  String get quickActionAutoStartTitle => 'Auto Start';

  @override
  String get quickActionAutoStartSubtitle => 'Avoid background kills';

  @override
  String get quickActionBatteryTitle => 'Unlimited Battery';

  @override
  String get quickActionBatterySubtitle => 'Avoid reminder interruption';

  @override
  String get quickActionKeepAliveTitle => 'Keep-Alive Helper';

  @override
  String get quickActionKeepAliveSubtitle => 'Improve background stability';

  @override
  String get guidePrivacyConsentLabel =>
      'I have read and agree to the Umeng privacy notice';

  @override
  String get guideRequireConsentHint =>
      'Please scroll to the end, review the notes, and check consent before starting.';

  @override
  String get guideContinueHint => 'Keep scrolling to finish the guide.';

  @override
  String get exitAppAction => 'Exit App';

  @override
  String get continueReadingAction => 'Continue Reading';

  @override
  String get agreeAndStartAction => 'Agree and Start';

  @override
  String get startUsingAction => 'Start Using';

  @override
  String get editSingleLessonTitle => 'Edit Single Lesson';

  @override
  String get editCourseTitle => 'Edit Course';

  @override
  String get addSingleLessonTitle => 'Add Single Lesson';

  @override
  String get addCourseTitle => 'Add Course';

  @override
  String get deleteCourseTitle => 'Delete Course';

  @override
  String get courseDeleted => 'Course deleted';

  @override
  String get addMethodTitle => 'Add Mode';

  @override
  String get singleLessonLabel => 'Single Lesson';

  @override
  String get recurringLessonLabel => 'Recurring Lesson';

  @override
  String get singleLessonHint =>
      'Best for make-up classes or temporary one-off lessons.';

  @override
  String get recurringLessonHint =>
      'Best for regular classes that repeat over many weeks.';

  @override
  String get sharedInfoTitle => 'Shared Info';

  @override
  String get sharedInfoHint =>
      'Name, short name, teacher, description, nature, and color will sync to other entries with the same course name.';

  @override
  String get reuseExistingCourseLabel => 'Reuse Existing Course';

  @override
  String get reuseExistingCourseHelper =>
      'Pick an existing course to autofill name, teacher, and other shared info';

  @override
  String get manualInputLabel => 'Enter Manually';

  @override
  String get noTemplateCoursesHint =>
      'There are no existing courses yet. Add one manually first, then future temporary lessons can reuse it.';

  @override
  String get courseNameLabel => 'Course Name';

  @override
  String get courseNameHelper =>
      'For island display, 3 Chinese characters or a short name works best.';

  @override
  String get pleaseEnterCourseName => 'Please enter the course name';

  @override
  String get courseShortNameOptional => 'Course Short Name (Optional)';

  @override
  String get teacherLabel => 'Teacher';

  @override
  String get courseNatureLabel => 'Course Nature';

  @override
  String get courseDescriptionOptional => 'Course Description (Optional)';

  @override
  String get currentScheduleHint =>
      'Weekday, sections, room, week range, and odd/even settings here only affect this specific entry.';

  @override
  String followProfileTimeScheme(String name) {
    return 'Follow current timetable ($name)';
  }

  @override
  String get timeSchemeOverrideLabel => 'Class Time Scheme';

  @override
  String get lessonWeeksTitle => 'Weeks';

  @override
  String get singleLessonWeekHint =>
      'A single lesson appears in only one week, ideal for temporary additions or make-up classes.';

  @override
  String get rangeWeekLabel => 'Continuous Weeks';

  @override
  String get customWeekLabel => 'Custom Weeks';

  @override
  String get allWeeksLabel => 'All';

  @override
  String get oddWeeksLabel => 'Odd Weeks';

  @override
  String get evenWeeksLabel => 'Even Weeks';

  @override
  String get allWeeksHint =>
      'Schedule continuously from the start week to the end week.';

  @override
  String get oddWeeksHint => 'Keep only odd weeks within the selected range.';

  @override
  String get evenWeeksHint => 'Keep only even weeks within the selected range.';

  @override
  String get customPaletteColor => 'Custom Color Picker';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count sets';
  }

  @override
  String profileCountValue(int count) {
    return '$count';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return 'Starts at $start';
  }

  @override
  String get weekdayShortMonday => 'Mon';

  @override
  String get weekdayShortTuesday => 'Tue';

  @override
  String get weekdayShortWednesday => 'Wed';

  @override
  String get weekdayShortThursday => 'Thu';

  @override
  String get weekdayShortFriday => 'Fri';

  @override
  String get weekdayShortSaturday => 'Sat';

  @override
  String get weekdayShortSunday => 'Sun';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '$weekday $startSection-$endSection';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName ($weekday $startSection-$endSection, $usageType)';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekday $startSection-$endSection';
  }

  @override
  String get timeRangeValidationNoCrossDay =>
      'End time must be later than start time';

  @override
  String get timeSchemeNameEmptyValidation =>
      'Time scheme name cannot be empty';

  @override
  String get liveTimeCorrectionNone => 'No correction';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return 'Delay by ${seconds}s';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return 'Advance by ${seconds}s';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return 'Switch to the focused reminder as soon as class starts, then show second-level countdown in the last ${seconds}s before class ends';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return 'Keep the normal in-class notification first, switch to focused / class-end reminder $minutes minutes before class ends, then show second-level countdown in the last ${seconds}s';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return 'Switch to the Island / focused reminder $minutes minutes before class ends, then show second-level countdown in the last ${seconds}s';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return 'Start the focused reminder $minutes minutes before class ends, then show second-level countdown in the last ${seconds}s';
  }

  @override
  String get liveSettingsEntrySubtitle =>
      'Reminder timing, Island display, notification bar, and display content';

  @override
  String get timetableProfilesEntrySubtitle =>
      'Create, switch, duplicate, rename, and delete timetables';

  @override
  String get homeTitleSectionTitle => 'Home title';

  @override
  String get homeTitleSectionSubtitle =>
      'Controls the style of the timetable switch entry at the top left of the home page.';

  @override
  String get homeTitleStyleLabel => 'Title style';

  @override
  String get themeSeedSectionTitle => 'App theme color';

  @override
  String get themeSeedSectionSubtitle =>
      'Affects the top bar, accent color, and global primary tone.';

  @override
  String get timetableBackgroundColorSectionTitle =>
      'Timetable background color';

  @override
  String get timetableBackgroundColorSectionSubtitle =>
      'Only affects the large background of the timetable page.';

  @override
  String get defaultTimetablePreviewName => 'Default timetable';

  @override
  String get beforeClassDisplaySettingsTitle => 'Before-class reminder display';

  @override
  String get duringEndDisplaySettingsTitle => 'In-class / end reminder display';

  @override
  String get liveDisplaySummaryShortName => 'Short name';

  @override
  String get liveDisplaySummaryCourseName => 'Course name';

  @override
  String get liveDisplaySummaryLocation => 'Location';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return 'Countdown ($style)';
  }

  @override
  String get liveDisplaySummaryStageText => 'Stage text';

  @override
  String get liveDisplaySummaryLeftLabelImage => 'Left label image';

  @override
  String get liveDisplaySummaryMinimal => 'Minimal display';

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => 'Current status';

  @override
  String get guideStatusNotificationPermission => 'Notification permission';

  @override
  String get guideStatusEnabled => 'Enabled';

  @override
  String get guideStatusDisabled => 'Disabled';

  @override
  String get guideStatusIslandSupport => 'Promoted notification / Island';

  @override
  String get guideStatusSystemAllowed => 'Allowed by system';

  @override
  String get guideStatusEnabledPending =>
      'Enabled but not yet confirmed by system';

  @override
  String get guideStatusSuggestedCheck => 'Needs checking';

  @override
  String get guideStatusBatteryOptimization => 'Battery optimization';

  @override
  String get guideStatusBatteryUnrestricted => 'Unrestricted';

  @override
  String get guideStatusBatteryRestricted => 'Restricted';

  @override
  String get guideStatusKeepAlive => 'Background keep-alive helper';

  @override
  String get guideStatusAndroidVersion => 'Android version';

  @override
  String get guideStatusVersionUnknown => 'Unknown';

  @override
  String get guideStatusIslandSystemSupport => 'Island system support';

  @override
  String get guideStatusIslandSystemRequirement =>
      'Requires HyperOS 3.0.300 or above';

  @override
  String get guideStatusIslandHint =>
      'If you mainly want to use the Island, first make sure your system version is at least HyperOS 3.0.300, then complete the permission checklist below in order.';

  @override
  String get guidePermissionChecklistTitle => 'Permission checklist';

  @override
  String get guidePermissionChecklistSubtitle =>
      'Follow this order for the easiest setup and the lowest chance of missing anything.';

  @override
  String get guideChecklistRequestNotificationTitle =>
      'Request notification permission';

  @override
  String get guideChecklistRequestNotificationSubtitle =>
      'This is required for all reminders';

  @override
  String get guideChecklistOpenNotificationTitle =>
      'Open notification settings';

  @override
  String get guideChecklistOpenNotificationSubtitle =>
      'Check the master switch, lock-screen display, and live notification permission';

  @override
  String get guideChecklistOpenIslandTitle =>
      'Open promoted notification settings';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'On HyperOS 3.0.300 and above, also check promoted / Island notifications';

  @override
  String get guideChecklistOpenAutoStartTitle => 'Open auto-start settings';

  @override
  String get guideChecklistOpenAutoStartSubtitle =>
      'Allow the app to launch on boot and stay active in the background';

  @override
  String get guideChecklistOpenBatteryTitle => 'Open battery settings';

  @override
  String get guideChecklistOpenBatterySubtitle =>
      'Set it to Unrestricted to avoid missed reminders';

  @override
  String get guideChecklistOpenKeepAliveTitle => 'Open keep-alive helper';

  @override
  String get guideChecklistOpenKeepAliveSubtitle =>
      'Further improves Island and reminder stability in the background';

  @override
  String get guideShortNameAdviceTitle => 'Course short-name tips';

  @override
  String get guideShortNameAdviceSubtitle =>
      'The Island supports course short names. Short names are not generated automatically, so you need to fill them in on the course edit page yourself. Keeping them within 3 characters is usually the most stable.';

  @override
  String get guideShortNameRecommended => 'Recommended';

  @override
  String get guideShortNameNotRecommended => 'Not recommended';

  @override
  String get guideShortNameRecommendedExample => 'Calc / Prob / CNC';

  @override
  String get guideShortNameNotRecommendedExample =>
      'Advanced Mathematics A(1) / CNC Technology and Applications';

  @override
  String get guideSetCourseShortNameAction => 'Set course short name';

  @override
  String get guideImportMethodsTitle => 'Timetable import methods';

  @override
  String get guideImportMethodsSubtitle =>
      'This version already supports web login import for some school systems. If your school is not supported yet, there are still other migration options.';

  @override
  String get guideImportMethodStep1 =>
      'Go to \"Import Courses > Academic System Import\" first, choose your school and adapter, then complete the import directly in the in-app web page.';

  @override
  String get guideImportMethodStep2 =>
      'If your school is not supported yet, you can first import courses into WakeUp or another timetable app, export them as a calendar file, and then import them into this app.';

  @override
  String get guideImportMethodStep3 =>
      'If someone else is already using this app, they can export a full backup and you can import it directly to restore courses and settings.';

  @override
  String get guideImportMethodExtra =>
      'If you know packet capture, web debugging, or JavaScript, you are also welcome to help add school adapters so more schools can import directly.';

  @override
  String get guideFinalTipsTitle => 'Three final tips';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 and above is required for the Island. If your system version is lower, the app can still send normal reminders.';

  @override
  String get guideFinalTip2 =>
      '2. Adjust the before-class popup and in-class / near-end reminder thresholds in Settings first.';

  @override
  String get guideFinalTip3 =>
      '3. After finishing the system permission setup, use a test notification to verify everything. If the Island still disappears occasionally, check auto-start and battery policy first.';

  @override
  String get guidePrivacyHelperRequireConsent =>
      'By checking the box, you confirm that you have read and agreed to the Umeng-related privacy notes, privacy content, and disclaimer above.';

  @override
  String get guidePrivacyHelperViewOnly =>
      'This page keeps the same privacy, third-party SDK, and disclaimer information shown during first launch so you can review it at any time. You do not need to agree again here.';

  @override
  String get guidePrivacySectionTitle =>
      'Privacy, third-party SDKs, and disclaimer';

  @override
  String get guidePrivacyParagraph1 =>
      'The core features of this app are designed to run locally. Timetables, time schemes, course records, and most settings are stored on your device by default.';

  @override
  String get guidePrivacyParagraph2 =>
      'The app only exchanges data with external services when you actively use networked features such as update checks, update downloads, import/export, or when you agree to initialize Umeng-related SDKs.';

  @override
  String get guidePrivacyParagraph3 =>
      'This app integrates the Umeng Mobile Analytics SDK, Umeng App Performance Monitoring SDK, and advanced operations analytics dependencies. They are used for analytics, app performance monitoring, and advanced operations analysis, and they are initialized only after you agree.';

  @override
  String get guidePrivacyParagraph4 =>
      'According to Umeng documentation, these SDKs may process information such as device info (IMEI, MAC, Android ID, OAID, IDFA, OpenUDID, GUID, SIM IMSI, etc.), network status, device identifiers, and app list / location-related information used by advanced operations analytics dependencies.';

  @override
  String get guideRiskTitle => 'Disclaimer and risk notes';

  @override
  String get guideRiskParagraph1 =>
      '1. Island behavior, promoted notifications, background reminders, and keep-alive effects depend on system version, device model, vendor policy, permissions, auto-start, battery policy, and other external conditions. Consistent behavior across all devices cannot be guaranteed.';

  @override
  String get guideRiskParagraph2 =>
      '2. Update checks, mirror downloads, system downloader, import/export, and sharing depend on network conditions, third-party services, and system file capabilities. If failures, throttling, or file issues occur, please refer to the Release page, your own backups, and system prompts.';

  @override
  String get guideRiskParagraph3 =>
      '3. Before migrating, importing, or overwriting data, please confirm that your backup files are complete and usable, and keep files containing timetable information safe. Risks caused by deletion, overwriting, sharing, or improper storage are the user\'s responsibility.';

  @override
  String get guideUmengPrivacyLink =>
      'Umeng Privacy Policy: https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable =>
      'There are no Island diagnostic logs to view yet.';

  @override
  String get liveDiagnosticsViewerTitle => 'Island diagnostic logs';

  @override
  String get liveDiagnosticsShareText =>
      'These are the Island diagnostic logs exported from Qingyu Timetable. They can help investigate issues such as the Island not appearing.';

  @override
  String get liveDiagnosticsShareSubject =>
      'Qingyu Timetable - Island diagnostic logs';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      'This is the Island status snapshot exported from the current test diagnostics page in Qingyu Timetable. It can help investigate issues such as the Island not appearing.';

  @override
  String get liveDiagnosticsSnapshotShareSubject =>
      'Qingyu Timetable - Island status snapshot';

  @override
  String get liveDiagnosticsNothingToExport =>
      'There is no log file or status snapshot available to export right now.';

  @override
  String get liveDiagnosticsCleared =>
      'Island diagnostic logs have been cleared. Collection will start again afterward.';

  @override
  String get liveDiagnosticsClearFailed =>
      'Failed to clear Island diagnostic logs';

  @override
  String get liveTestingNotRefreshed => 'Not refreshed yet';

  @override
  String get liveTestingTitle => 'Testing & diagnostics';

  @override
  String get liveTestingNotificationTitle => 'Test notifications';

  @override
  String get liveTestingNotificationSubtitle =>
      'Used to verify the Island, notification bar, and course short-name display.';

  @override
  String get liveTestingSendAction => 'Send test notification';

  @override
  String get liveTestingUmengHint =>
      'The two buttons below are shown only in test builds and are used to verify Umeng U-APM crash and ANR reporting.';

  @override
  String get liveTestingCrashAction => 'Crash test';

  @override
  String get liveTestingAnrAction => 'ANR test';

  @override
  String get liveTestingIslandStatusTitle => 'Island status diagnostics';

  @override
  String get liveTestingIslandStatusSubtitle =>
      'This section shows the native live service status, notification build result, and the reason it is not appearing on the Island.';

  @override
  String get liveTestingServiceStatusRunning => 'Service running';

  @override
  String get liveTestingServiceStatusStopped => 'Service stopped';

  @override
  String get liveTestingNoIslandReasonTitle => 'Why it is not on the Island';

  @override
  String get liveTestingNoIslandReasonEmpty =>
      'No blocking reason at the moment';

  @override
  String get liveTestingRefreshAction => 'Refresh diagnostics';

  @override
  String get liveTestingRefreshing => 'Refreshing';

  @override
  String get liveTestingExportAction => 'Export and share logs';

  @override
  String get liveTestingExporting => 'Exporting';

  @override
  String get liveTestingAutoRefreshTitle => 'Auto refresh';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return 'Refresh diagnostic status automatically every $seconds seconds';
  }

  @override
  String get liveTestingAutoRefreshOff =>
      'When off, diagnostics update only when you refresh manually so you can inspect the current state more steadily.';

  @override
  String liveTestingRefreshedAt(String time) {
    return 'Last refreshed: $time';
  }

  @override
  String get liveTestingSectionEnvironment => 'Environment & permissions';

  @override
  String get liveTestingSectionService => 'Service status';

  @override
  String get liveTestingSectionCourse => 'Course data';

  @override
  String get liveTestingSectionTiming => 'Time & stage';

  @override
  String get liveTestingSectionSwitches => 'Stage switches';

  @override
  String get liveTestingSectionDisplay => 'Island display config';

  @override
  String get liveTestingSectionNotification => 'Notification decision result';

  @override
  String get liveTestingSectionRecentLogs => 'Recent diagnostic logs';

  @override
  String get liveTestingRawDataTitle => 'Raw debug data';

  @override
  String get liveTestingRawDataSubtitle =>
      'Collapsed by default. Expand it only when you need to verify the full native fields.';

  @override
  String get liveTestingExpandRawJson => 'Expand raw JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle =>
      'Prevents large raw payloads from taking over the page';

  @override
  String get liveTestingLocalLogsTitle => 'Local diagnostic logs';

  @override
  String get liveTestingLocalLogsSubtitle =>
      'Export the log file with one tap and share it directly with the developer, or clear it and collect again.';

  @override
  String get liveTestingClearLogsAction => 'Clear logs';

  @override
  String get liveTestingClearingLogs => 'Clearing';

  @override
  String get liveTestingViewPhoneLogsAction => 'View device logs';

  @override
  String get liveTestingMoreTesterOptionsAction => 'More tester options';

  @override
  String get yesLabel => 'Yes';

  @override
  String get noLabel => 'No';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle =>
      'Shows the current native diagnostic fields.';

  @override
  String get liveTestingCrashSoon =>
      'A Umeng U-APM test crash is about to be triggered. Reopen the app afterward to check whether it was reported.';

  @override
  String get liveTestingAnrSoon =>
      'A ~30-second main-thread freeze is about to be triggered. Test outside flutter run, then reopen the app afterward to check Umeng.';

  @override
  String get liveTestingNoCourseAvailable =>
      'There is no course available for testing right now.';

  @override
  String get liveTestingTestCourseNote =>
      'This note is shown here. You can edit it on the course edit page.';

  @override
  String get liveTestingNotificationSent =>
      'A before-class test notification has been sent. It should enter the before-class reminder stage in about 8 seconds.';

  @override
  String sendFailedWithError(String error) {
    return 'Failed to send: $error';
  }

  @override
  String get homeWidgetSettingsTitle => 'Home widgets';

  @override
  String get homeWidgetTodayCourseTitle => 'Today\'s course widgets';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      'The first batch supports 2×2, 2×4, and 4×4 sizes. Tapping a widget opens the home page directly, and it refreshes automatically when classes start and end.';

  @override
  String get homeWidgetQuickAddTitle => 'Quick add to home screen';

  @override
  String get homeWidgetCheckingPinSupport =>
      'Checking whether the current launcher supports in-app widget pinning…';

  @override
  String get homeWidgetPinSupported =>
      'If supported, the system add confirmation will appear directly. It is not a separate permission dialog; once confirmed, the widget will be pinned to the home screen.';

  @override
  String get homeWidgetPinUnsupported =>
      'If the current launcher does not support in-app widget pinning, long-press the home screen → Widgets → Qingyu Timetable to add it manually.';

  @override
  String get homeWidgetBackgroundStyleLabel => 'Background style';

  @override
  String get homeWidgetShowLocationTitle => 'Show location';

  @override
  String get homeWidgetShowLocationSubtitle =>
      'When turned off, the widget secondary info will prioritize week info and course count.';

  @override
  String get homeWidgetShowCountdownTitle => 'Show countdown';

  @override
  String get homeWidgetShowCountdownSubtitle =>
      'The refresh switch is kept for now and will later be used to show remaining time before the next class and during class.';

  @override
  String get homeWidgetCountdownLeadTitle => 'Countdown lead time';

  @override
  String get homeWidgetCountdownLeadSubtitle =>
      'Set how many minutes before class to automatically switch to countdown mode.';

  @override
  String get homeWidgetCountdownLeadAlways => 'Always show';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '$minutes min before class';
  }

  @override
  String get widgetCountdownStyleTitle => 'Countdown style';

  @override
  String get homeWidgetHideCompletedTitle => 'Hide completed classes';

  @override
  String get homeWidgetHideCompletedSubtitle =>
      'When enabled, the 2×2, 2×4, and 4×4 course lists show only classes that have not finished yet.';

  @override
  String get homeWidgetShowTomorrowTitle => 'Show tomorrow\'s classes';

  @override
  String get homeWidgetShowTomorrowSubtitle =>
      'When enabled, the widget automatically switches to tomorrow\'s classes after today\'s classes end.';

  @override
  String get homeWidgetHeightAdjustTitle => 'Card height adjustment';

  @override
  String get defaultLabel => 'Default';

  @override
  String higherByValue(String value) {
    return 'Higher by $value';
  }

  @override
  String lowerByValue(String value) {
    return 'Lower by $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => 'Card corner radius';

  @override
  String get homeWidgetDescriptionTitle => 'Notes';

  @override
  String get homeWidgetDescriptionText =>
      'Widgets currently prioritize today\'s courses. On days without classes, the full card stays visible instead of turning blank. If you switch timetables or change styles, the home-screen widgets refresh as well.';

  @override
  String homeWidgetPinRequested(String label) {
    return 'The request to add \"$label\" has been sent. Please confirm it in the system dialog and place it on the home screen.';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return 'Your current launcher does not support in-app widget pinning. Long-press the home screen → Widgets → Qingyu Timetable, then add \"$label\" manually.';
  }

  @override
  String get homeWidgetInvalidType =>
      'Invalid widget type. Please try again later.';

  @override
  String homeWidgetPinFailedManual(String label) {
    return 'Failed to request widget pinning. Long-press the home screen → Widgets → Qingyu Timetable, then add \"$label\" manually.';
  }

  @override
  String get layoutSettingsTitle => 'Layout & sections';

  @override
  String get layoutDensityTitle => 'Timetable density';

  @override
  String get layoutAutoFitHeightTitle => 'Auto fill screen height';

  @override
  String get layoutAutoFitHeightSubtitle =>
      'When enabled, the page automatically fills to the bottom based on the current section count instead of leaving blank space below.';

  @override
  String get layoutHideWeekendsTitle => 'Hide weekends';

  @override
  String get layoutHideWeekendsSubtitle =>
      'When enabled, only Monday to Friday are shown on the home page and the remaining columns expand automatically.';

  @override
  String get layoutEnableHapticsTitle => 'Enable in-app haptic feedback';

  @override
  String get layoutEnableHapticsSubtitle =>
      'When off, interactions such as page switching no longer trigger light vibration.';

  @override
  String get layoutTimeColumnDisplayLabel => 'Home page time column';

  @override
  String get layoutTimeColumnWidthLabel => 'Time column width';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel =>
      '\"Back to current week\" button style';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      'Defaults to the current inline style, or switch to a small floating button in the bottom-right of week view.';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline =>
      'Inline in time column';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating =>
      'Floating bottom-right';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return 'Floating button opacity $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle =>
      'Only applies to the floating bottom-right style.';

  @override
  String layoutCourseCardGapLabel(String value) {
    return 'Course card spacing $value';
  }

  @override
  String layoutSectionHeightLabel(String value) {
    return 'Row height $value';
  }

  @override
  String layoutCompactFontSizeLabel(String value) {
    return 'Compact font size $value';
  }

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return 'Course card font size $value';
  }

  @override
  String get layoutCourseCardDisplayTitle => 'Course card display';

  @override
  String get layoutCourseCardDisplaySubtitle =>
      'Course name, teacher, and classroom are shown by default. Other information can be toggled freely per timetable.';

  @override
  String get layoutShowTeacherTitle => 'Show teacher';

  @override
  String get layoutShowClassroomTitle => 'Show classroom';

  @override
  String get layoutShowTimeTitle => 'Show time';

  @override
  String get layoutShowTimeLabelsTitle => 'Show class start/end labels';

  @override
  String get layoutShowTimeLabelsSubtitle =>
      'When off, only the time points are shown, without the \"start\" / \"end\" labels.';

  @override
  String get layoutShowWeeksTitle => 'Show weeks';

  @override
  String get layoutShowWeeksSubtitle =>
      'For example, weeks 1-16 or odd/even weeks';

  @override
  String get layoutShowDescriptionTitle => 'Show course description';

  @override
  String get layoutShowDescriptionSubtitle =>
      'Off by default and compressed first when space is limited';

  @override
  String get layoutShowOtherWeeksTitle =>
      'Show courses outside the current week';

  @override
  String get layoutShowOtherWeeksSubtitle =>
      'Off by default. When enabled, courses not in the current week are shown in semi-transparent gray.';

  @override
  String get layoutVerticalAlignLabel => 'Vertical alignment';

  @override
  String get layoutHorizontalAlignLabel => 'Horizontal alignment';

  @override
  String get layoutShowConflictBadgeTitle =>
      'Show conflict pill on the home page';

  @override
  String get layoutShowConflictBadgeSubtitle =>
      'When off, the home timetable no longer shows the \"Conflict\" pill for conflicting courses.';

  @override
  String layoutConflictOpacityLabel(int value) {
    return 'Conflict course opacity $value%';
  }

  @override
  String get layoutConflictOpacitySubtitle =>
      'Conflicting courses are automatically stacked. Lower opacity makes multiple courses visible at the same time.';

  @override
  String get layoutTipsText =>
      'Time schemes have been moved to the Settings home page. This page mainly adjusts row height, time column, weekend visibility, and course card layout. If you only want to change the time for the current timetable, duplicate a time scheme first and then apply it.';

  @override
  String currentWeekCompact(int week) {
    return 'Week $week';
  }

  @override
  String get sampleCourseNumericalControl => 'CNC';

  @override
  String get sampleCourseAdvancedMath => 'Calculus';

  @override
  String get sampleTeacherZhang => 'Prof. Zhang';

  @override
  String get sampleCourseEnglish => 'English';

  @override
  String get sampleTeacherLi => 'Prof. Li';

  @override
  String get aboutRepositorySheetTitle => 'Open-source repositories';

  @override
  String get aboutRepositorySheetHint =>
      'If you want to add academic-system adapters for more schools, you should also check the qingyu_warehouse repository.';

  @override
  String get aboutOpenGitHubAction => 'Open GitHub';

  @override
  String get aboutOpenWarehouseRepoAction => 'Open adapter repository';

  @override
  String get copiedRepositoryAddress => 'Repository address copied';

  @override
  String get copiedWarehouseRepositoryAddress =>
      'Adapter repository address copied';

  @override
  String get aboutUpdateScreenTitle => 'Version updates';

  @override
  String get aboutUpdateStatusTitle => 'Update status';

  @override
  String get aboutRefreshCheckTooltip => 'Check again';

  @override
  String get aboutCheckingLatestVersion =>
      'Checking the latest version information…';

  @override
  String get aboutReadVersionFailed =>
      'Unable to read version information right now. Please try again later.';

  @override
  String get aboutReadVersionFailedHint =>
      'If GitHub access is unstable on your network, try again later or switch to the domestic download route below.';

  @override
  String get aboutViewReleaseAction => 'View Release';

  @override
  String get aboutDownloadNowAction => 'Download now';

  @override
  String get aboutOpenDownloadPageAction => 'Open download page';

  @override
  String get aboutCurrentVersionLabel => 'Current version';

  @override
  String get aboutLatestVersionLabel => 'Latest version';

  @override
  String get aboutUnreleasedLabel => 'Not released';

  @override
  String get aboutVersionChannelLabel => 'Release channel';

  @override
  String get aboutPrereleaseChannel => 'Prerelease';

  @override
  String get aboutUpdateAvailableHint =>
      'You can simply tap \"Download now\" below. Speed test, mirrors, and prerelease options have been moved into Advanced Options.';

  @override
  String get aboutUpdateNoUpdateHint =>
      'The current version is already usable. If you want to try prereleases, enable prerelease checks in Advanced Options below.';

  @override
  String aboutUpdatedAt(String time) {
    return 'Updated at: $time';
  }

  @override
  String get aboutUpdateNowTitle => 'Update now';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      'For normal use, just tap Download now once. If downloading is slow, fails, or you need a different route, use Advanced Options below.';

  @override
  String get aboutUpdateNowOtherSubtitle =>
      'On the current platform, the app opens the download page directly instead of installing in-app.';

  @override
  String get aboutMirrorDownloadHint =>
      'Domestic download is currently prioritized. On most domestic networks, tapping \"Download now\" is enough.';

  @override
  String get aboutOriginalDownloadHint =>
      'International-source download is currently prioritized. If downloading is slow or unreachable, switch back to domestic download.';

  @override
  String get aboutUseSystemDownloaderAction => 'Use system downloader';

  @override
  String get aboutOpenReleasePageAction => 'Open Release page';

  @override
  String get aboutDownloadMethodTitle => 'Download method';

  @override
  String get aboutDownloadMethodSubtitle =>
      'Domestic download is recommended by default. Only switch to the international source if you can access GitHub reliably.';

  @override
  String get aboutDownloadMethodMirror => 'Domestic download';

  @override
  String get aboutDownloadMethodOriginal => 'International source';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return 'Currently using domestic download · $current. Recent speed tests recommend \"$recommended\" instead, and you can switch in Advanced Options if needed.';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return 'Currently using domestic download · $current. If downloading is slow or fails, use Advanced Options to test, switch routes, or enter a custom address.';
  }

  @override
  String get aboutOriginalModeHint =>
      'You are currently using the international source. This is recommended only if your network can access GitHub reliably; otherwise, switch back to domestic download.';

  @override
  String get aboutReleaseNotesTitle => 'Release notes';

  @override
  String get aboutReleaseNotesSubtitle =>
      'Shows the Release notes of the currently detected version.';

  @override
  String get aboutAdvancedOptionsTitle => 'Advanced options';

  @override
  String get aboutAdvancedOptionsSubtitle =>
      'Expand only when downloads are slow, you need to switch routes manually, or you want prerelease checks.';

  @override
  String get aboutMirrorSectionTitle => 'Download routes & mirrors';

  @override
  String get aboutMirrorSectionMirrorHint =>
      'You are currently using domestic download. Here you can switch routes manually, run speed tests, or enter a custom download address.';

  @override
  String get aboutMirrorSectionOriginalHint =>
      'You are currently using the international source. The route settings below take effect only after you switch back to domestic download.';

  @override
  String get aboutFillCustomMirrorFirst =>
      'Enter a custom download address first';

  @override
  String get aboutCurrentCustomMirrorTitle => 'Current custom download address';

  @override
  String get aboutCurrentMirrorTitle => 'Current download route address';

  @override
  String get aboutCurrentCustomMirrorHint =>
      'You are currently using the address you entered manually.';

  @override
  String get aboutCurrentMirrorHint =>
      'If the current route fails, switch to another built-in route or use a custom address instead.';

  @override
  String get aboutProbeMirrorsAction => 'Test speed and recommend';

  @override
  String get aboutProbingMirrors => 'Testing speed…';

  @override
  String get aboutEditCustomMirrorAction => 'Edit custom address';

  @override
  String get aboutSetCustomMirrorAction => 'Enter custom address';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return 'Switch to recommended: $label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      'Domestic download is not currently enabled, so the route settings here will not take effect. Switch back to domestic download first if needed.';

  @override
  String get aboutRecentProbeResultsTitle => 'Recent speed-test results';

  @override
  String get aboutUnavailable => 'Unavailable';

  @override
  String get aboutRecommended => 'Recommended';

  @override
  String get aboutCheckPrereleaseTitle => 'Check prerelease versions';

  @override
  String get aboutCheckPrereleaseSubtitle =>
      'When enabled, prereleases are also included in update checks. It is recommended to keep this off for normal use.';

  @override
  String get aboutDiagnosticsTitle => 'Testing & diagnostics';

  @override
  String get aboutDiagnosticsSubtitle =>
      'Expand this only when the Island does not appear or when you need to send feedback to the developer.';

  @override
  String get aboutRecordDiagnosticsTitle => 'Record app logs';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      'When enabled, key local logs across the whole app are continuously recorded, including error / warn / info / debug / verbose levels for update, import, notification, and crash troubleshooting.';

  @override
  String get aboutExportDiagnosticsAction => 'Export app logs';

  @override
  String get aboutViewPhoneLogsAction => 'Open logs page';

  @override
  String get aboutClearAndRecollectAction => 'Clear and collect again';

  @override
  String get aboutLiveDiagnosticsEnabled => 'App log recording enabled';

  @override
  String get aboutLiveDiagnosticsDisabled => 'App log recording disabled';

  @override
  String get aboutNoDiagnosticsExportYet =>
      'There are no app logs to export yet.';

  @override
  String get aboutProbeNoMirrorFound =>
      'Speed test finished, but no available mirror route was found yet.';

  @override
  String aboutProbeCurrentFastest(String label) {
    return 'Speed test finished. The current route \"$label\" is already the fastest available one.';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return 'Speed test finished. Recommended switch: \"$label\".';
  }

  @override
  String get switchAction => 'Switch';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error. You can switch to a domestic mirror and try again.';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error. It is recommended to switch to \"$label\" and try again.';
  }

  @override
  String get aboutSetMirrorSourceTitle => 'Set mirror source';

  @override
  String get aboutMirrorPrefixLabel => 'Mirror prefix';

  @override
  String get aboutMirrorPrefixInvalid =>
      'Invalid mirror source format. Please enter a complete http or https address.';

  @override
  String get aboutMirrorSaved => 'Mirror source saved';

  @override
  String get aboutDownloadCancelled => 'Download cancelled';

  @override
  String get aboutInstallReady =>
      'The installation package is ready and the installer page has been opened. If no system prompt appears, install it later from notifications or your file manager.';

  @override
  String get aboutUpdatePackageTitle => 'Qingyu Timetable update package';

  @override
  String get aboutUpdatePackageDescription =>
      'The download has been handed to the system download manager. You can install it directly from the system notification once it finishes.';

  @override
  String get aboutSystemDownloaderQueued =>
      'The task has been handed to the system download manager. Check progress in the system notification or download list.';

  @override
  String get aboutSystemDownloaderFailed =>
      'Failed to call the system download manager';

  @override
  String get aboutDownloadCancelling => 'Cancelling download…';

  @override
  String aboutDownloadingBytes(String value) {
    return 'Downloading update $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return 'Downloading update $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint =>
      'The mirror did not return a total file size yet, so only the downloaded size is shown for now.';

  @override
  String get aboutCancelDownloadAction => 'Cancel download';

  @override
  String get aboutContributorsScreenTitle => 'Contributors';

  @override
  String get aboutDevelopersTitle => 'Developers';

  @override
  String get aboutDeveloperMaintainerSubtitle =>
      'Qingyu Timetable development and maintenance';

  @override
  String get aboutWarehouseMaintainersTitle =>
      'Academic-system adapter maintainers';

  @override
  String get aboutWarehouseMaintainersIntro =>
      'The names below are summarized from the maintainer field in the qingyu_warehouse adapter repository. If cached data already exists locally, the cache is shown first and then refreshed in the background.';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return 'Unable to read the maintainer list right now: $error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty =>
      'No maintainer information has been loaded yet.';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count adapter items';
  }

  @override
  String get aboutParticipateWarehouseTitle => 'Contribute adapters';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      'If you know packet capture, web debugging, JavaScript, or are willing to maintain your school\'s academic system long-term, you are welcome to submit new school adapters and fixes to qingyu_warehouse.';

  @override
  String get importFileReadFailed => 'Unable to read the selected file';

  @override
  String get importReplaceExistingTitle => 'Import courses';

  @override
  String importReplaceExistingMessage(String name) {
    return 'When importing $name, replace existing courses?';
  }

  @override
  String get importNoCoursesRecognized =>
      'No importable courses were recognized';

  @override
  String get importConfirmSemesterMappingTitle =>
      'Confirm semester start date and week mapping';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      'Please select the semester start date in your school calendar. The system has inferred a default week mapping from the earliest class date in the file, and you can still adjust it manually.';

  @override
  String importOverwriteCount(int count) {
    return 'Imported and replaced $count course entries';
  }

  @override
  String importUpdatedCount(int count) {
    return 'Timetable updated: added or updated $count course entries';
  }

  @override
  String get importNoCourseChanges =>
      'There are no new or updated courses to import';

  @override
  String get aiImportTitle => 'Image-based import';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return 'Recognized $courseCount courses, up to section $sectionCount$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return ', $count warnings';
  }

  @override
  String get aiWorkflowCompactTitle => 'Copy prompt -> Doubao OCR -> Import';

  @override
  String get aiWorkflowCompactSubtitle =>
      'Doubao Expert Mode -> Copy JSON -> Choose semester date';

  @override
  String get aiWorkflowTitle =>
      'Copy prompt -> Doubao OCR -> Paste JSON -> Import';

  @override
  String get aiWorkflowSubtitle =>
      'Copy the prompt first, switch Doubao to Expert Mode from the lower-left corner, then send both the timetable screenshots and the prompt together. Copy the JSON returned by Doubao back here, then choose the semester date after tapping Import.';

  @override
  String get aiPromptShortAction => 'Prompt';

  @override
  String get aiExpertModeSuggestion =>
      'Doubao Expert Mode is recommended. Multiple images are supported, and screenshots should include weekday headers.';

  @override
  String get aiHintExpertMode => 'Switch Doubao to Expert Mode first';

  @override
  String get aiHintSendScreenshot =>
      'Send screenshots together with the prompt';

  @override
  String get aiHintCopyJsonBack => 'Copy the returned JSON';

  @override
  String get aiHintPickSemesterAfterImport =>
      'Choose semester date after import';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => 'Paste the JSON returned by AI';

  @override
  String aiCourseCountChip(int count) {
    return '$count courses';
  }

  @override
  String get aiParseFailedChip => 'Parse failed';

  @override
  String get aiPasteJsonHintShort => 'Paste the JSON returned by AI';

  @override
  String get aiPasteJsonHintLong =>
      'Paste the JSON returned by Doubao here exactly as-is, then tap Import. Pure JSON is supported, and ```json code blocks are also accepted.';

  @override
  String get detailAction => 'Details';

  @override
  String get aiParseErrorTitle => 'Parse error';

  @override
  String get viewDetailsAction => 'View details';

  @override
  String get aiWorkflowFooter =>
      'Copy the prompt -> send screenshots and prompt to Doubao -> paste the JSON back here -> tap Import -> choose semester date.';

  @override
  String get previewAction => 'Preview';

  @override
  String get confirmImportAction => 'Confirm import';

  @override
  String get promptCopiedHint =>
      'Prompt copied. Go to Doubao and send the screenshots with the prompt.';

  @override
  String get clipboardNoText => 'There is no usable text in the clipboard';

  @override
  String get aiPromptSheetTitle => 'OCR prompt';

  @override
  String get aiPromptSheetSubtitle =>
      'Doubao is recommended. Switch it to Expert Mode first, then send the full prompt below together with the timetable screenshots so it returns JSON only. After generation, copy the JSON back to this page and choose the semester date after tapping Import.';

  @override
  String get aiPreviewTitle => 'Parse preview';

  @override
  String get aiPasteJsonFirst => 'Please paste the JSON returned by AI first';

  @override
  String get aiParseFailedIncompleteJson =>
      'Parsing failed. Please make sure you pasted the complete JSON.';

  @override
  String get importAiResultTitle => 'Import AI parsing result';

  @override
  String get importAiReplaceMessage =>
      'Replace the existing courses with the current AI parsing result?';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      'Please choose the semester start date from your school calendar, then confirm which calendar week corresponds to Week 1 in the timetable. If there are no classes in the first week, this usually needs to be changed to Week 2.';

  @override
  String aiWarningExtraSuffix(int count) {
    return ', plus $count recognition warnings';
  }

  @override
  String get pasteAction => 'Paste';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      'The academic-system script has returned course weeks. Please confirm the semester start date in the school calendar; if there are no classes in the first few weeks, you can map timetable Week 1 to a later calendar week.';

  @override
  String aiPreviewCourseCount(int count) {
    return 'Course count: $count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return 'Max section: $section';
  }

  @override
  String get aiPreviewWarningsTitle => 'Recognition warnings';

  @override
  String get aiPreviewCoursesTitle => 'Course preview';

  @override
  String aiPreviewRemainingCourses(int count) {
    return 'The remaining $count entries will be written into the current timetable after import.';
  }

  @override
  String get warehouseMissingSchoolTitle =>
      'Cannot find your school in the list?';

  @override
  String get warehouseMissingSchoolSubtitle =>
      'Just open the feedback page and file an Issue. It helps a lot if you include the school name, academic-system URL, logged-in timetable page link, or screenshots.';

  @override
  String get laterAction => 'Maybe later';

  @override
  String get goFeedbackAction => 'Go to feedback';

  @override
  String get warehouseFeedbackMissingSchoolTitle =>
      'Missing school? Go to feedback';

  @override
  String get warehouseCustomDebugTitle => 'Custom debug';

  @override
  String get warehouseRootLoadFailedTitle =>
      'Unable to read the adapter repository right now';

  @override
  String get searchSchoolHint => 'Search school name, initials, or code';

  @override
  String get clearSearchTooltip => 'Clear';

  @override
  String get noMatchingSchools => 'No matching school found';

  @override
  String get noAvailableSchools => 'No schools available yet';

  @override
  String get searchSchoolSuggestion =>
      'Try the full school name, initials, or the school code used in the repository.';

  @override
  String get deleteDebugRecordTitle => 'Delete debug record';

  @override
  String deleteDebugRecordMessage(String name) {
    return 'Delete \"$name\"? This will not affect courses that have already been imported.';
  }

  @override
  String deletedDebugRecord(String name) {
    return 'Deleted debug record: $name';
  }

  @override
  String get customDebugName => 'Custom debug';

  @override
  String get localDebugMaintainer => 'Local debug';

  @override
  String get customDebugDescription =>
      'User-saved custom academic-system debug script';

  @override
  String get addDebugRecordTooltip => 'Add debug record';

  @override
  String get customDebugIntroTitle =>
      'Keep your own academic-system debug records here';

  @override
  String get customDebugIntroSubtitle =>
      'Each record can save a custom URL and a full script. Once saved, you can tap \"Start debug\" next time to reuse it directly instead of searching for the entry from a school detail page again.';

  @override
  String get addDebugRecordAction => 'Add debug record';

  @override
  String get noSavedDebugRecords => 'No saved debug records yet';

  @override
  String get noSavedDebugRecordsHint =>
      'Add one first and paste the URL and script in. After that, you can reuse it directly.';

  @override
  String debugScriptLength(int count) {
    return 'Script $count chars';
  }

  @override
  String get startDebugAction => 'Start debug';

  @override
  String get editAction => 'Edit';

  @override
  String get scriptFileReadFailed => 'Unable to read the script file';

  @override
  String scriptFileImported(String name) {
    return 'Imported script file: $name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return 'Failed to import script file: $error';
  }

  @override
  String get debugRecordNameRequired =>
      'Please enter a debug record name first';

  @override
  String get invalidImportUrl => 'Please enter a valid academic-system URL';

  @override
  String get debugScriptRequired => 'Please enter or import a script first';

  @override
  String get editDebugRecordTitle => 'Edit debug record';

  @override
  String get addDebugRecordTitle => 'Add debug record';

  @override
  String get savingAction => 'Saving…';

  @override
  String get debugRecordFormula => 'One record = one URL + one script';

  @override
  String get debugRecordFormulaSubtitle =>
      'Useful when you repeatedly debug the same school or keep multiple script sets for different schools. Records remain saved and can be edited at any time.';

  @override
  String get debugRecordNameLabel => 'Record name';

  @override
  String get debugRecordNameHint => 'Example: Chongqing Jidian - new system';

  @override
  String get importUrlLabel => 'Academic-system URL';

  @override
  String get debugScriptLabel => 'Debug script';

  @override
  String get importFromFileAction => 'Import from file';

  @override
  String get debugScriptHint =>
      'Paste the full script exported by the browser extension here';

  @override
  String get saveDebugRecordAction => 'Save debug record';

  @override
  String get fillUrlThenImport => 'Enter URL before importing';

  @override
  String get webLoginImport => 'Web login import';

  @override
  String get savedImportUrlHint =>
      'Academic-system URL saved. You can import directly next time.';

  @override
  String get adapterIntroSubtitle =>
      'You can view adapter info, the login entry, and script status here.';

  @override
  String get schoolLabel => 'School';

  @override
  String get categoryLabel => 'Category';

  @override
  String get maintainerLabel => 'Maintainer';

  @override
  String get adapterInfoTitle => 'Adapter info';

  @override
  String get scriptPathLabel => 'Script path';

  @override
  String get loginEntryLabel => 'Login entry';

  @override
  String get unsetConfigLabel => 'Not configured';

  @override
  String get adapterOverrideImportUrlHint =>
      'The manually overridden login address is currently in use.';

  @override
  String get repositoryLabel => 'Repository';

  @override
  String get scriptStatusTitle => 'Script status';

  @override
  String scriptLoadedLength(int count) {
    return 'Script loaded successfully. Length: $count chars.';
  }

  @override
  String get scriptEmpty => 'Script is empty';

  @override
  String get openLoginInAppAction => 'Open login page in app';

  @override
  String get openInSystemBrowserAction => 'Open in system browser';

  @override
  String get copiedImportLoginUrl => 'Academic-system login URL copied';

  @override
  String get copyLoginAddressAction => 'Copy login address';

  @override
  String get copiedScriptRawUrl => 'Raw script URL copied';

  @override
  String get copyScriptAddressAction => 'Copy script address';

  @override
  String get customLoginAddressAction => 'Custom login address';

  @override
  String get editCustomLoginAddressAction => 'Edit custom login address';

  @override
  String get clearCustomLoginAddressAction => 'Clear custom address';

  @override
  String get restoreRepositoryAddressAction => 'Restore repository address';

  @override
  String get invalidLoginEntryUrl => 'Invalid login entry URL';

  @override
  String get savedCustomLoginAddress => 'Custom login address saved';

  @override
  String get clearedCustomLoginAddress => 'Custom login address cleared';

  @override
  String get restoredRepositoryImportUrl => 'Repository login address restored';

  @override
  String get backToCurrentWeekAction => 'Back';

  @override
  String get nonCurrentWeekLabel => 'Not this week';

  @override
  String get conflictLabel => 'Conflict';

  @override
  String get selectWeekTitle => 'Select week';

  @override
  String availableWeeksCount(int count) {
    return '$count weeks';
  }

  @override
  String goToWeekLabel(int week) {
    return 'Week $week';
  }

  @override
  String get homeMenuUpdateTitle => 'Software update';

  @override
  String get homeMenuProfilesTitle => 'Timetables';

  @override
  String get homeMenuOverviewTitle => 'Course overview';

  @override
  String get homeMenuAddCourseTitle => 'Add course';

  @override
  String get homeMenuImportTitle => 'Import courses';

  @override
  String get homeMenuSettingsTitle => 'Timetable settings';

  @override
  String get homeMenuCoffeeTitle => 'Buy me a coffee';

  @override
  String get homeMenuFeedbackTitle => 'Feedback';

  @override
  String get switchTimetableTitle => 'Switch timetable';

  @override
  String get switchTimetableSubtitleEmpty =>
      'Tap a timetable below to switch the current view immediately.';

  @override
  String switchTimetableSubtitleCurrent(String name) {
    return 'Current: $name. Tap a timetable below to switch immediately.';
  }

  @override
  String get todayTimetableTitle => 'Today\'s Timetable';

  @override
  String get dayTimetableTitle => 'Day Timeline';

  @override
  String get backToWeekViewAction => 'Back to Week View';

  @override
  String get backToTodayAction => 'Back to Today';

  @override
  String get ongoingCourseBadge => 'In Class';

  @override
  String get dayViewEmptyTitle => 'No classes today';

  @override
  String shortNamePrefix(String value) {
    return 'Short name: $value';
  }

  @override
  String teacherPrefix(String value) {
    return 'Teacher: $value';
  }

  @override
  String locationPrefix(String value) {
    return 'Location: $value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return 'You are viewing Week $week. You can reschedule this class occurrence directly.';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return 'You are viewing Week $week, but this course does not occur this week, so it cannot be rescheduled as the current-week occurrence.';
  }

  @override
  String get editActionShort => 'Edit';

  @override
  String get rescheduleAction => 'Reschedule';

  @override
  String get deleteActionShort => 'Delete';

  @override
  String get deleteModeTitle => 'Delete mode';

  @override
  String get deleteModeSubtitle =>
      'You can delete the whole schedule entry or just the single occurrence shown for the current week.';

  @override
  String get deleteCourseAction => 'Delete course';

  @override
  String get deleteOccurrenceAction => 'Delete occurrence';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '\"Delete course\" removes all weeks of this schedule entry; \"Delete occurrence\" removes only the occurrence in Week $week.';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return 'This card is not an actual occurrence in Week $week, so only the whole schedule entry can be deleted.';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return 'Delete the schedule entry \"$name\"?\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return 'Delete the occurrence of \"$name\" in Week $week?\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return 'Deleted the occurrence in Week $week';
  }

  @override
  String get noChangesDetected => 'No changes detected';

  @override
  String get rescheduleCurrentOccurrenceTitle =>
      'Reschedule this week\'s occurrence';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return 'Only the occurrence in Week $week will be adjusted. The original class in that week will be removed automatically, while other weeks stay unchanged.';
  }

  @override
  String get rescheduleTargetWeekLabel => 'Move to week';

  @override
  String get weekdayFieldLabel => 'Weekday';

  @override
  String get startSectionFieldLabel => 'Start section';

  @override
  String get endSectionFieldLabel => 'End section';

  @override
  String get courseLocationFieldLabel => 'Class location';

  @override
  String get confirmRescheduleAction => 'Confirm reschedule';

  @override
  String get homeTitleStyleClassicLabel => 'Classic text';

  @override
  String get homeTitleStyleBrandLabel => 'Large logo';

  @override
  String get homeTitleStyleClassicDescription =>
      'Keeps the original title style with text only; tap it to switch timetables.';

  @override
  String get homeTitleStyleBrandDescription =>
      'Shows a large logo and the smaller timetable name for a stronger branded look.';

  @override
  String get widgetBackgroundStyleGlass => 'Translucent glass';

  @override
  String get widgetBackgroundStyleSolid => 'Solid card';

  @override
  String get widgetBackgroundStyleGradient => 'Gradient card';

  @override
  String get homeWidgetTargetCompact22 => 'Main card 2×2';

  @override
  String get homeWidgetTargetMiniList22 => 'Mini list 2×2';

  @override
  String get homeWidgetTargetMedium24 => 'Overview 2×4';

  @override
  String get homeWidgetTargetLarge44 => 'List 4×4';

  @override
  String get addCourseSheetTitle => 'Add Content';

  @override
  String get addCourseSheetSubtitle =>
      'Blank timetable areas do not respond to taps. Choose clearly whether to add a one-off lesson, a recurring course, or a one-time schedule item.';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday Sections $startSection-$endSection';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday Sections $startSection-$endSection · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return 'Rescheduled to Week $week $weekday Sections $startSection-$endSection';
  }

  @override
  String courseCountSummary(int count) {
    return '$count courses';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return 'In Class · $minutes min left';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return 'Ending Soon · $minutes min left';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return 'In Progress · $minutes min left';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return 'Ending Soon · $minutes min left';
  }

  @override
  String get currentBadge => 'Current';

  @override
  String get feedbackXiaohongshuTitle => 'Xiaohongshu';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return 'Xiaohongshu ID: $id';
  }

  @override
  String get feedbackCoolapkTitle => 'Coolapk';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return 'Coolapk ID: $id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ Group';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return 'Group ID: $id';
  }

  @override
  String get copiedCurrentTimetable => 'Current timetable copied';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return 'Sections $startSection-$endSection';
  }

  @override
  String classStartsAtLabel(String time) {
    return 'Starts at $time';
  }

  @override
  String classEndsAtLabel(String time) {
    return 'Ends at $time';
  }

  @override
  String get invalidSectionTimeFormat => 'Invalid section time format';

  @override
  String get noSectionTimesToSave => 'No section times to save';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName imported sections';
  }

  @override
  String get unnamedScript => 'Unnamed script';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return 'Local debug mode: $scriptName';
  }

  @override
  String get executeImportScriptTooltip => 'Run import script';

  @override
  String get switchToMobileWebTooltip => 'Switch to mobile page';

  @override
  String get switchToDesktopWebTooltip => 'Switch to desktop page';

  @override
  String get rememberCurrentInputTooltip => 'Remember current input';

  @override
  String get fillRememberedTooltip => 'Fill remembered account';

  @override
  String get clearRememberedTooltip => 'Clear remembered account';

  @override
  String get copyCurrentAddressTooltip => 'Copy current address';

  @override
  String get copiedCurrentAddress => 'Current address copied';

  @override
  String get warehouseLoginHintLocalDebug =>
      'Currently using local debug script mode';

  @override
  String get warehouseLoginHintImport =>
      'Log in to the academic system here, then run import';

  @override
  String get currentPageModeDesktop => 'Current page mode: Desktop';

  @override
  String get currentPageModeMobile => 'Current page mode: Mobile';

  @override
  String localScriptLabel(String scriptName) {
    return 'Local script: $scriptName';
  }

  @override
  String get webAddressHint => 'Enter web address';

  @override
  String get goAction => 'Go';

  @override
  String rememberedAccountLabel(String username) {
    return 'Remembered account: $username';
  }

  @override
  String get importingAction => 'Importing...';

  @override
  String get executeLocalDebugScriptAction => 'Run local debug script';

  @override
  String get executeImportScriptAction => 'Run import script';

  @override
  String get invalidWebAddress => 'Invalid web address';

  @override
  String get injectingLocalDebugScript => 'Injecting local debug script';

  @override
  String get injectingAdapterScript => 'Injecting adapter script';

  @override
  String get localDebugScriptInjected => 'Local debug script injected';

  @override
  String get scriptInjected => 'Script injected';

  @override
  String get scriptInjectionFailed => 'Script injection failed';

  @override
  String executeFailedWithError(String error) {
    return 'Execution failed: $error';
  }

  @override
  String get importFlowFinished => 'Import flow finished';

  @override
  String get defaultContinuePrompt => 'Please continue as prompted';

  @override
  String get inputRequiredTitle => 'Input required';

  @override
  String get pleaseEnterFourDigitYear => 'Please enter a four-digit year';

  @override
  String get pleaseChooseTitle => 'Please choose';

  @override
  String get invalidCourseConfigFormat => 'Invalid course config format';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return 'Failed to save course config: $error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return 'Failed to save section times: $error';
  }

  @override
  String get invalidCourseDataFormat => 'Invalid course data format';

  @override
  String get noImportableCoursesFromScript =>
      'No importable courses returned by the script';

  @override
  String importCourseCountPrompt(int count) {
    return '$count courses were recognized. Import them?';
  }

  @override
  String get importCancelledStatus => 'Import cancelled';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return 'Failed to apply returned time scheme: $error';
  }

  @override
  String get importInterruptedStatus => 'Import interrupted';

  @override
  String get importFailedStatus => 'Import failed';

  @override
  String importFailedWithError(String error) {
    return 'Import failed: $error';
  }

  @override
  String get unknownTeacher => 'Unknown teacher';

  @override
  String get unknownLocation => 'Unknown location';

  @override
  String get autofillLoginTitle => 'Autofill login info';

  @override
  String autofillLoginMessage(String username) {
    return 'A remembered account $username was found. Autofill it now?';
  }

  @override
  String get notNowAction => 'Not now';

  @override
  String get autofillAction => 'Autofill';

  @override
  String get rememberPasswordTitle => 'Remember password';

  @override
  String rememberPasswordMessage(String username) {
    return 'Remember the login info for $username and autofill it next time?';
  }

  @override
  String get dontRememberAction => 'Don\'t remember';

  @override
  String get rememberAndAutofillAction => 'Remember and autofill';

  @override
  String get savedRememberedLoginStatus => 'Remembered login saved';

  @override
  String get autofilledRememberedLoginStatus => 'Remembered login autofilled';

  @override
  String get noRecognizedLoginInputs => 'No recognized login inputs';

  @override
  String get noUsernameOrPasswordRecognized =>
      'No username or password was recognized';

  @override
  String get rememberedCurrentLoginStatus => 'Current login remembered';

  @override
  String get rememberedCurrentLoginSuccess => 'Current login remembered';

  @override
  String rememberLoginFailedWithError(String error) {
    return 'Failed to remember login: $error';
  }

  @override
  String get clearedRememberedLoginStatus => 'Remembered login cleared';

  @override
  String get clearedRememberedLoginSuccess => 'Remembered login cleared';

  @override
  String get addScheduleTitle => 'Add Schedule';

  @override
  String get editScheduleTitle => 'Edit Schedule';

  @override
  String get addScheduleAction => 'Add Schedule';

  @override
  String get scheduleTitleLabel => 'Schedule Title';

  @override
  String get scheduleTitleHint =>
      'For example: team meeting, pickup, office visit';

  @override
  String get scheduleTitleRequired => 'Please enter a schedule title';

  @override
  String get scheduleInfoSectionTitle => 'Schedule Info';

  @override
  String get scheduleInfoSectionSubtitle =>
      'Schedule items are inserted into the day-view timeline for a specific date and do not change course data.';

  @override
  String get scheduleTimeSectionTitle => 'Time Arrangement';

  @override
  String get scheduleTimeSectionSubtitle =>
      'Choose the exact date and time range for this schedule item.';

  @override
  String get scheduleAppearanceSectionTitle => 'Appearance';

  @override
  String get scheduleAppearanceSectionSubtitle =>
      'Pick a color that makes schedule items easy to distinguish from courses.';

  @override
  String get scheduleLocationLabel => 'Location';

  @override
  String get scheduleLocationHint => 'Optional';

  @override
  String get scheduleDateLabel => 'Date';

  @override
  String get scheduleStartDateLabel => 'Start Date';

  @override
  String get scheduleEndDateLabel => 'End Date';

  @override
  String get scheduleStartTimeLabel => 'Start Time';

  @override
  String get scheduleEndTimeLabel => 'End Time';

  @override
  String get scheduleColorLabel => 'Schedule Color';

  @override
  String get scheduleNoteLabel => 'Note';

  @override
  String get scheduleNoteHint => 'Optional';

  @override
  String get scheduleBadgeLabel => 'Schedule';

  @override
  String scheduleCountSummary(int count) {
    return '$count schedules';
  }

  @override
  String get scheduleTimeRangeInvalid =>
      'End time must be later than the start time';

  @override
  String get scheduleDateRangeInvalid =>
      'End date cannot be earlier than the start date';

  @override
  String get scheduleSingleDayHint =>
      'For same-day schedules, the end time must be later than the start time.';

  @override
  String get scheduleCrossDayHint =>
      'Cross-day schedules are sliced into the corresponding day view automatically.';

  @override
  String get scheduleSavedHint => 'Schedule added';

  @override
  String get scheduleUpdatedHint => 'Schedule updated';

  @override
  String get crossDayBadgeLabel => 'Cross-day';

  @override
  String deleteScheduleMessage(String title) {
    return 'Delete schedule \"$title\"?';
  }

  @override
  String get scheduleDeletedHint => 'Schedule deleted';

  @override
  String get examListTitle => 'Exams';

  @override
  String get addExam => 'Add Exam';

  @override
  String get editExam => 'Edit Exam';

  @override
  String get saveExam => 'Save Exam';

  @override
  String get noExams => 'No exams scheduled';

  @override
  String get examToday => 'Exam today';

  @override
  String daysUntilExam(int days) {
    return '$days days until exam';
  }

  @override
  String get examPassed => 'Completed';

  @override
  String get linkCourse => 'Linked Course';

  @override
  String get linkCourseRequired => 'Please select a course';

  @override
  String get examNameLabel => 'Exam Name';

  @override
  String get examNameRequired => 'Please enter exam name';

  @override
  String get examDateLabel => 'Exam Date';

  @override
  String get examDateHint => 'Select date';

  @override
  String get examDateRequired => 'Please select exam date';

  @override
  String get examStartTimeLabel => 'Start Time';

  @override
  String get examEndTimeLabel => 'End Time';

  @override
  String get examLocationLabel => 'Exam Room';

  @override
  String get examLocationHint => 'Leave empty to use classroom';

  @override
  String get sameAsClassroom => 'Same as classroom';

  @override
  String get examSeatLabel => 'Seat Number';

  @override
  String get examReminderLabel => 'Reminder';

  @override
  String get examNoteLabel => 'Note';

  @override
  String get deleteExam => 'Delete Exam';

  @override
  String deleteExamConfirm(String name) {
    return 'Delete exam \"$name\"?';
  }

  @override
  String get examBadgeLabel => 'Exam';

  @override
  String get examCountdownToday => 'Today';

  @override
  String examCountdownDays(int days) {
    return 'in $days days';
  }

  @override
  String get sortAction => 'Sort';

  @override
  String get sortByAdded => 'By date added';

  @override
  String get sortByName => 'By course name';

  @override
  String get sortBySchedule => 'By schedule time';

  @override
  String scheduleEntryTitle(int index) {
    return 'Schedule entry $index';
  }

  @override
  String get addScheduleEntryAction => 'Add schedule entry';

  @override
  String get deleteScheduleEntryAction => 'Delete entry';

  @override
  String get holidaySettingsEntryTitle => 'Holiday Marking';

  @override
  String get holidaySettingsEntrySubtitle =>
      'Mark statutory holidays and makeup workdays on timetable';

  @override
  String get holidayMakeupWorkday => 'Workday';

  @override
  String get holidaySettingsTitle => 'Holiday Marking';

  @override
  String get holidayEnableTitle => 'Enable holiday marking';

  @override
  String get holidayEnableSubtitle =>
      'When enabled, statutory holidays and makeup workdays will be marked on the timetable';

  @override
  String get holidayDataSectionTitle => 'Holiday Data';

  @override
  String get holidayDataYear => 'Year';

  @override
  String get holidayDataCount => 'Count';

  @override
  String get holidayDataEmpty => 'No holiday data yet';

  @override
  String get holidayCheckUpdate => 'Check for updates';

  @override
  String get holidayUpcomingSectionTitle => 'Upcoming Holidays';

  @override
  String get holidayNoUpcoming => 'No upcoming holidays';

  @override
  String get holidayBadgeLabel => 'Holiday';

  @override
  String get holidayStatusLabel => 'Holiday';

  @override
  String get suspendedBadgeLabel => 'Suspended';

  @override
  String get suspendedStatusLabel => 'Suspended';

  @override
  String get courseActionSuspend => 'Suspend';

  @override
  String get courseActionUnsuspend => 'Restore';

  @override
  String get suspendSheetTitle => 'Suspend';

  @override
  String get suspendSheetSubtitle => 'Choose suspension scope';

  @override
  String get suspendThisWeek => 'This week';

  @override
  String get suspendThisWeekDesc => 'Suspend this week only';

  @override
  String get suspendAllWeeks => 'All weeks';

  @override
  String get suspendAllWeeksDesc => 'Suspend all weeks';

  @override
  String get unsuspendAllWeeks => 'Restore all';

  @override
  String get unsuspendAllWeeksDesc => 'Restore all weeks';

  @override
  String get customHolidayTitle => 'Custom Holidays';

  @override
  String get customHolidayAdd => 'Add Holiday';

  @override
  String get customHolidayEdit => 'Edit Holiday';

  @override
  String get customHolidayDelete => 'Delete';

  @override
  String get customHolidayDeleteConfirm => 'Delete this custom holiday?';

  @override
  String get customHolidayNameLabel => 'Holiday name';

  @override
  String get customHolidayStartDate => 'Start date';

  @override
  String get customHolidayEndDate => 'End date';

  @override
  String get customHolidayType => 'Type';

  @override
  String get customHolidayTypeVacation => 'Holiday';

  @override
  String get customHolidayTypeWorkday => 'Workday';

  @override
  String get customHolidayEmpty => 'No custom holidays';

  @override
  String get customHolidayNameRequired => 'Please enter a holiday name';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => 'Select teacher';

  @override
  String get selectLocationTitle => 'Select location';

  @override
  String get historyRecordsLabel => 'History';

  @override
  String get noHistoryRecords => 'No history yet';

  @override
  String get weekPickerTitle => 'Select weeks';

  @override
  String get selectTimeSchemeTitle => 'Select time scheme';

  @override
  String get manageTimeSchemesAction => 'Manage time schemes';

  @override
  String get examDefaultName => 'Final Exam';

  @override
  String get examDateWeekPickerTitle => 'Select exam date';

  @override
  String get weekPickerCalendarTooltip => 'Use calendar picker';

  @override
  String get thisWeekLabel => 'This week';

  @override
  String get guidePrivacyPageTitle => 'Privacy Policy';

  @override
  String get guidePermissionsPageTitle => 'Permissions';

  @override
  String get guideTipsPageTitle => 'Tips';

  @override
  String get guidePrevButton => 'Previous';

  @override
  String get guideNextButton => 'Next';

  @override
  String get guidePermissionsHeader => 'System Permissions';

  @override
  String get guidePermissionsSubtitle =>
      'Complete these settings for Super Island and reminders to work properly';

  @override
  String get guidePermissionsFooterHint =>
      'Tap to open system settings. Statuses that can be detected will refresh automatically when you return. Auto-start is limited by the system; use the switch on the system page as the source of truth.';

  @override
  String get guideTipsHeader => 'Tips';

  @override
  String get guideTipsSubtitle => 'These can always be found in Settings';

  @override
  String get guidePrivacyReadBeforeUse => 'Please read and agree before use';

  @override
  String get guidePrivacyViewOnly =>
      'Privacy, third-party SDKs, and disclaimer';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year Official Holidays';
  }

  @override
  String get holidayUpdateLog => 'Update Log';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count entries';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month/$start - $end';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth/$startDay - $endMonth/$endDay';
  }

  @override
  String get liveTestingHolidayOverride => 'Holiday Status Override';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      'Simulate holiday status for testing reminders and widgets';

  @override
  String get liveTestingHolidayModeEnabled => 'Holiday Mode Enabled';

  @override
  String get liveTestingHolidayModeDisabled => 'Holiday Mode Disabled';

  @override
  String get liveTestingHolidayModeEnabledDesc =>
      'Reminders and widgets will hide all courses';

  @override
  String get liveTestingHolidayModeDisabledDesc => 'Using normal holiday data';

  @override
  String get textColorTitle => 'Text Colors';

  @override
  String get textColorSubtitle =>
      'Customize text colors for each area of the timetable';

  @override
  String get textColorIndependentDetail => 'Set detail colors independently';

  @override
  String get textColorCourseCardTitle => 'Course card title color';

  @override
  String get textColorCourseCardDetail => 'Course card detail color';

  @override
  String get textColorWeekdayBar => 'Weekday bar font color';

  @override
  String get textColorTimeAxis => 'Time axis font color';

  @override
  String get textColorSelectColor => 'Select Color';

  @override
  String get textColorCurrentColor => 'Current color';
}
