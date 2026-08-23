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
  String get appTitleProfile => 'Qingyu Timetable Profile';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get previewTitle => 'Preview';

  @override
  String get timetableBackgroundPreview => 'Timetable Background';

  @override
  String get displayModeTitle => 'Display Mode';

  @override
  String get displayModeSubtitle => 'Supports system, light, and dark mode';

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
      'Inter is built in; other options use fonts already on your phone';

  @override
  String get fontSectionFootnote =>
      'Brand fonts aren\'t bundled; they work only if already on your system. On Xiaomi, usually only MiSans is obvious. No change means auto fallback—you usually don\'t need to install fonts';

  @override
  String get fontModeLabel => 'Font';

  @override
  String get fontModeSystem => 'App Default';

  @override
  String get fontModeSansSerif => 'System Sans';

  @override
  String get fontModeMiSans => 'MiSans';

  @override
  String get fontModeHarmonyOS => 'HarmonyOS Sans';

  @override
  String get fontModeOppoSans => 'OPPO Sans';

  @override
  String get fontModePingFang => 'PingFang SC';

  @override
  String get fontModeNotoSans => 'Noto Sans';

  @override
  String get fontModeSerif => 'Serif';

  @override
  String get fontModeSongti => 'Songti';

  @override
  String get fontModeMonospace => 'Monospace';

  @override
  String get languageSectionTitle => 'App Language';

  @override
  String get languageSectionSubtitle =>
      'Follow system or switch manually to supported locales';

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
      'App theme mode, fonts, home title and sheet frosted glass';

  @override
  String get appearanceThemeDisplaySectionTitle => 'Theme & Display';

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
  String get timeSchemeEntryNotSelected => 'Not set';

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
  String get coupleTimetableEntryTitle => 'Couple Timetable';

  @override
  String get coupleTimetableEntryBound => 'Linked';

  @override
  String get coupleTimetableModeEnableTooltip => 'Couple timetable on';

  @override
  String get coupleTimetableModeDisableTooltip => 'Couple timetable off';

  @override
  String get coupleTimetableTitle => 'Couple Timetable';

  @override
  String get coupleTimetableIntro =>
      'Export your timetable for your partner, or import their shared file. After binding, open the overlay view to compare schedules';

  @override
  String get coupleTimetableBoundTitle => 'Partner timetable linked';

  @override
  String get coupleTimetableUnboundTitle => 'No partner timetable yet';

  @override
  String get coupleTimetablePartnerNameLabel => 'Partner name';

  @override
  String coupleTimetableLastImportedAt(String time) {
    return 'Last imported: $time';
  }

  @override
  String get coupleTimetableExportForPartner =>
      'Export my timetable for partner';

  @override
  String get coupleTimetableImportPartner => 'Import partner timetable';

  @override
  String get coupleTimetableUnlink => 'Unlink';

  @override
  String get coupleTimetableOpenOverlay => 'Open overlay view';

  @override
  String get coupleTimetableImportSuccess => 'Partner timetable imported';

  @override
  String get coupleTimetableImportUpdated => 'Partner timetable updated';

  @override
  String get coupleTimetableUnlinkConfirmTitle => 'Unlink partner timetable?';

  @override
  String get coupleTimetableUnlinkConfirmMessage =>
      'This removes the locally stored partner timetable and closes the overlay view';

  @override
  String get coupleTimetableUnlinkSuccess => 'Partner timetable unlinked';

  @override
  String get coupleTimetablePrivacyHint =>
      'Your partner only sees the timetable content included in the exported file';

  @override
  String get coupleTimetableOverlayTitle => 'Couple overlay';

  @override
  String get coupleTimetableLegendMine => 'Mine';

  @override
  String get coupleTimetableLegendPartner => 'Partner';

  @override
  String get coupleTimetableLegendTogether => 'Together';

  @override
  String get coupleTimetableLegendFree => 'Shared free';

  @override
  String get coupleTimetableSharedFreeTitle => 'Shared free time today';

  @override
  String get coupleTimetableSharedFreeTitleOtherDay =>
      'Shared free time this day';

  @override
  String get coupleTimetableNoSharedFree => 'No shared free time today';

  @override
  String get coupleTimetableNoSharedFreeOtherDay =>
      'No shared free time this day';

  @override
  String coupleTimetableSharedFreeMeta(int count) {
    return '$count slots';
  }

  @override
  String coupleTimetableSharedFreeMoreCount(int count) {
    return '$count more slots';
  }

  @override
  String get coupleTimetableSharedFreeUnavailable =>
      'Shared free time unavailable';

  @override
  String get coupleTimetableSharedFreeStaleHint =>
      'Partner schedule may be outdated';

  @override
  String get coupleTimetablePartnerReadOnlyBadge =>
      'Partner timetable (read-only)';

  @override
  String get coupleTimetableNotBoundMessage =>
      'Import a partner timetable before opening the overlay view';

  @override
  String get coupleTimetableShareText =>
      'Here is my timetable. Import it in Qingyu Timetable > Couple Timetable to view together.';

  @override
  String get coupleTimetableShareSubject => 'Qingyu Timetable · Couple share';

  @override
  String get coupleTimetableWeekOffsetTitle => 'Week offset';

  @override
  String get coupleTimetableWeekOffsetSubtitle =>
      'When you view week N, partner courses are read from week N + offset. For example, +1 means their semester is one week ahead';

  @override
  String get coupleTimetableWeekOffsetZero => 'No offset';

  @override
  String coupleTimetableWeekOffsetSigned(String offset) {
    return '$offset wk';
  }

  @override
  String coupleTimetableWeekOffsetPreview(int myWeek, int partnerWeek) {
    return 'Viewing your week $myWeek shows partner week $partnerWeek';
  }

  @override
  String get coupleTimetableColorsTitle => 'Overlay colors';

  @override
  String get coupleTimetableColorsSubtitle =>
      'Choose colors for your courses, partner courses, and shared classes in overlay view';

  @override
  String get partnerImportRequiresSingleProfile =>
      'Please import a single-profile backup, not a full backup';

  @override
  String get coupleWebdavTitle => 'Nutstore pull';

  @override
  String get coupleWebdavSubtitle =>
      'Sign in to your partner\'s (or shared) Nutstore account to download their uploaded timetable. Separate from Cloud Sync credentials';

  @override
  String get coupleWebdavNotConnected => 'Not connected to Nutstore';

  @override
  String coupleWebdavConnectedAs(String username) {
    return 'Connected as $username';
  }

  @override
  String coupleWebdavRemotePathHint(String path) {
    return 'Remote file: $path';
  }

  @override
  String coupleWebdavLastPulledAt(String time) {
    return 'Last pulled: $time';
  }

  @override
  String get coupleWebdavConnect => 'Connect Nutstore';

  @override
  String get coupleWebdavDisconnect => 'Disconnect';

  @override
  String get coupleWebdavPullNow => 'Pull partner timetable';

  @override
  String get coupleWebdavUploadForPartner => 'Upload my timetable to Nutstore';

  @override
  String get coupleWebdavLoginSheetTitle =>
      'Connect Nutstore (couple timetable)';

  @override
  String get coupleWebdavLoginSheetSubtitle =>
      'Use an app-specific password. Your partner must upload their timetable to the agreed path first, or upload from their device on the same account';

  @override
  String get coupleWebdavConfirmConnect => 'Connect and pull';

  @override
  String get coupleWebdavMySlotLabel => 'This device slot';

  @override
  String get coupleWebdavMySlotHint =>
      'Both devices must pick different slots: one chooses 1, the other 2, or neither can read the partner timetable';

  @override
  String get coupleWebdavSlotOne => 'Slot 1';

  @override
  String get coupleWebdavSlotTwo => 'Slot 2';

  @override
  String get coupleWebdavTestSuccess => 'Nutstore connection successful';

  @override
  String get coupleWebdavTestFailed =>
      'Connection failed. Check account, app password, and network.';

  @override
  String get coupleWebdavPullImported =>
      'Partner timetable imported from Nutstore';

  @override
  String get coupleWebdavPullUpdated =>
      'Partner timetable updated from Nutstore';

  @override
  String get coupleWebdavPullUnchanged => 'Partner timetable is up to date';

  @override
  String get coupleWebdavUploadSuccess =>
      'Timetable uploaded for your partner to pull';

  @override
  String get coupleWebdavPartnerFileMissing =>
      'Partner timetable file not found. Ask them to upload first.';

  @override
  String get coupleWebdavPullFailed =>
      'Failed to pull partner timetable. Try again later.';

  @override
  String get coupleWebdavNotConnectedError => 'Connect Nutstore first';

  @override
  String get cloudSyncEntryTitle => 'Cloud Sync (WEBDAV)';

  @override
  String get cloudSyncEntrySubtitle =>
      'Sync timetables and import data across devices via Jianguoyun';

  @override
  String get cloudSyncEntryDisabled => 'Off';

  @override
  String get cloudSyncEntryEnabled => 'On';

  @override
  String get cloudSyncEntrySyncing => 'Syncing';

  @override
  String get cloudSyncEntryError => 'Last sync failed';

  @override
  String get cloudSyncTitle => 'Cloud Sync';

  @override
  String get cloudSyncIntroTitle => 'Multi-device sync';

  @override
  String get cloudSyncIntroSubtitle =>
      'Configure Jianguoyun WEBDAV to sync timetables, warehouse accounts, and related settings across devices';

  @override
  String get cloudSyncSettingsSectionTitle => 'Sync settings';

  @override
  String get cloudSyncSettingsSectionSubtitle =>
      'Switch between manual and automatic sync';

  @override
  String get cloudSyncEnabledTitle => 'Enable cloud sync';

  @override
  String get cloudSyncEnabledSubtitle =>
      'When off, no snapshot is uploaded or downloaded';

  @override
  String get cloudSyncProviderTitle => 'Provider';

  @override
  String get cloudSyncProviderJianguoyun => 'Jianguoyun';

  @override
  String get cloudSyncProviderCustom => 'Custom WEBDAV';

  @override
  String get cloudSyncModeTitle => 'Sync mode';

  @override
  String get cloudSyncModeAuto => 'Automatic';

  @override
  String get cloudSyncModeManual => 'Manual';

  @override
  String get cloudSyncAccountTitle => 'Account';

  @override
  String get cloudSyncAccountSubtitle =>
      'Use a Jianguoyun app-specific password, not your login password. Snapshots include remembered school accounts';

  @override
  String get cloudSyncUsernameLabel => 'Email / username';

  @override
  String get cloudSyncUsernameHint => 'Jianguoyun account email';

  @override
  String get cloudSyncPasswordLabel => 'App-specific password';

  @override
  String get cloudSyncPasswordHint =>
      'Generate it in Jianguoyun security settings';

  @override
  String get cloudSyncPasswordStoredHint =>
      'Password saved; leave blank to keep the stored password';

  @override
  String get cloudSyncAdvancedTitle => 'Advanced';

  @override
  String get cloudSyncBaseUrlLabel => 'WEBDAV URL';

  @override
  String get cloudSyncBaseUrlSecurityNote =>
      'HTTPS is recommended. HTTP cleartext connections are allowed but only advised on trusted networks';

  @override
  String get cloudSyncRemoteFolderLabel => 'Remote folder';

  @override
  String get cloudSyncStatusTitle => 'Status';

  @override
  String get cloudSyncLastSyncedLabel => 'Last synced';

  @override
  String get cloudSyncLastErrorLabel => 'Latest error';

  @override
  String cloudSyncLastSyncedAt(String time) {
    return 'Last synced: $time';
  }

  @override
  String get cloudSyncSyncing => 'Syncing…';

  @override
  String cloudSyncLastError(String message) {
    return 'Latest error: $message';
  }

  @override
  String get cloudSyncHelpTitle => 'How to get a Jianguoyun app password';

  @override
  String get cloudSyncHelpBody =>
      'Open Jianguoyun → Account → Security → Add app password. Default WEBDAV URL: https://dav.jianguoyun.com/dav/';

  @override
  String get cloudSyncTestConnection => 'Test connection';

  @override
  String get cloudSyncSyncNow => 'Sync now';

  @override
  String get cloudSyncSyncNowSubtitle =>
      'Keep timetables aligned across devices: pull cloud updates, then upload local changes';

  @override
  String get cloudSyncTestSuccess => 'WEBDAV connection succeeded';

  @override
  String get cloudSyncTestFailed =>
      'WEBDAV connection failed. Check account, app password, and network.';

  @override
  String get cloudSyncResultUploaded => 'Uploaded to cloud';

  @override
  String get cloudSyncResultDownloaded => 'Restored from cloud';

  @override
  String get cloudSyncResultUpToDate => 'Already up to date';

  @override
  String get cloudSyncResultCancelled => 'Sync cancelled';

  @override
  String cloudSyncResultFailed(String message) {
    return 'Sync failed: $message';
  }

  @override
  String get cloudSyncConflictTitle => 'Sync conflict detected';

  @override
  String get cloudSyncConflictBody =>
      'Both this device and the cloud have newer changes. Choose which copy to keep.';

  @override
  String get cloudSyncUseRemoteAction => 'Use cloud';

  @override
  String get cloudSyncKeepLocalAction => 'Keep local';

  @override
  String get cloudSyncAccountSectionTitle => 'Cloud account';

  @override
  String get cloudSyncNotConnectedHint =>
      'Connect Jianguoyun to sync timetables and import data across devices';

  @override
  String get cloudSyncConnectAccount => 'Connect Jianguoyun';

  @override
  String cloudSyncConnectedAs(String email) {
    return 'Connected: $email';
  }

  @override
  String get cloudSyncDisconnect => 'Disconnect';

  @override
  String get cloudSyncDisconnectTitle => 'Disconnect cloud account';

  @override
  String get cloudSyncDisconnectBody =>
      'This removes saved WEBDAV credentials from this device. Local timetables are kept. Continue?';

  @override
  String get cloudSyncLoginSheetTitle => 'Connect Jianguoyun';

  @override
  String get cloudSyncLoginSheetSubtitle =>
      'Use an app-specific password, not your Jianguoyun login password';

  @override
  String get cloudSyncConfirmConnect => 'Connect';

  @override
  String get cloudSyncConnectSuccess => 'Account connected';

  @override
  String get cloudBackupSectionTitle => 'Version history';

  @override
  String get cloudBackupSectionSubtitle =>
      'Saved automatically when you sync. Tap to restore a version';

  @override
  String get cloudBackupCurrentLabel => 'Current version';

  @override
  String get cloudBackupCurrentBadge => 'Current';

  @override
  String get cloudBackupCreateNow => 'Back up now';

  @override
  String get cloudBackupViewAll => 'View all versions';

  @override
  String get cloudBackupEmpty =>
      'No versions yet. They are saved automatically when you sync.';

  @override
  String get cloudBackupSourceAuto => 'Auto backup';

  @override
  String get cloudBackupSourceManual => 'Manual backup';

  @override
  String get cloudBackupDefaultDeviceLabel => 'This device';

  @override
  String get cloudBackupDeviceLabelTitle => 'Device name';

  @override
  String get cloudBackupDeviceLabelHint =>
      'Shown in backup list, e.g. My phone';

  @override
  String cloudBackupSummary(int profileCount, int courseCount) {
    return '$profileCount timetables · $courseCount courses';
  }

  @override
  String get cloudBackupRestoreTitle => 'Restore this backup';

  @override
  String cloudBackupRestoreBody(String time) {
    return 'Restore the timetable from $time. Unsynced local changes will be lost. Continue?';
  }

  @override
  String get cloudBackupRestoreAction => 'Restore';

  @override
  String get cloudBackupRestoreSuccess => 'Backup restored';

  @override
  String cloudBackupRestoreFailed(String message) {
    return 'Restore failed: $message';
  }

  @override
  String get cloudBackupDeleteTitle => 'Delete this backup';

  @override
  String cloudBackupDeleteBody(String time) {
    return 'Delete the cloud backup from $time? This cannot be undone.';
  }

  @override
  String get cloudBackupDeleteSuccess => 'Backup deleted';

  @override
  String cloudBackupDeleteFailed(String message) {
    return 'Delete failed: $message';
  }

  @override
  String get cloudBackupCreateSuccess => 'Backup saved to cloud';

  @override
  String cloudBackupCreateFailed(String message) {
    return 'Backup failed: $message';
  }

  @override
  String get cloudBackupUploadAsCurrentTitle => 'Set as current cloud version';

  @override
  String get cloudBackupUploadAsCurrentBody =>
      'Upload this backup as the current cloud version? Recommended to avoid sync conflicts.';

  @override
  String get cloudBackupUploadAsCurrentYes => 'Set as current';

  @override
  String get cloudBackupUploadAsCurrentNo => 'Local only';

  @override
  String get cloudBackupDetailDevice => 'Device';

  @override
  String get cloudBackupDetailSource => 'Source';

  @override
  String get cloudBackupDetailSummary => 'Contents';

  @override
  String get lanEditEntryTitle => 'LAN editing';

  @override
  String get lanEditEntrySubtitle =>
      'Edit the current timetable from a desktop browser';

  @override
  String get lanEditTitle => 'LAN editing';

  @override
  String get lanEditIntro =>
      'While enabled, a computer on the same Wi-Fi or phone hotspot can edit the current timetable in a browser. Data stays on your LAN and access stops when you turn this off';

  @override
  String get lanEditStart => 'Start LAN editing';

  @override
  String get lanEditStop => 'Stop';

  @override
  String get lanEditStatusRunning => 'LAN editing is active';

  @override
  String get lanEditAddressLabel => 'Address';

  @override
  String get lanEditAddressUnavailable =>
      'No LAN IP detected. Connect to Wi-Fi or enable hotspot.';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => 'Port';

  @override
  String get lanEditCopyAddress => 'Copy address';

  @override
  String get lanEditCopied => 'Address copied';

  @override
  String get lanEditHotspotHint =>
      'If dorm Wi-Fi blocks device-to-device access, try phone hotspot instead';

  @override
  String get lanEditQrHint =>
      'Scan the QR code on a PC browser on the same LAN (link includes PIN)';

  @override
  String get lanEditStartFailed => 'Failed to start';

  @override
  String get lanEditConnectedClientsLabel => 'Connected';

  @override
  String get lanEditConnectedClientsNone => 'None';

  @override
  String lanEditConnectedClientsValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String get lanEditLastActivityLabel => 'Last activity';

  @override
  String get lanEditKeepAliveWhenLeavingTitle => 'Keep open after leaving';

  @override
  String get lanEditKeepAliveWhenLeavingSubtitle =>
      'When on, leaving this page keeps LAN editing running; when off, leaving stops it';

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
      'Adjust this based on your school’s actual teaching weeks';

  @override
  String get unifiedCourseCardColorTitle => 'Use Unified Course Card Color';

  @override
  String get unifiedCourseCardColorSubtitle =>
      'If disabled, each course keeps its own color';

  @override
  String get importRandomCourseColorTitle => 'Random course colors';

  @override
  String get importRandomCourseColorSubtitle =>
      'Assign preset colors by course name and teacher';

  @override
  String get courseImportTitle => 'Import Courses';

  @override
  String get chooseImportMethodTitle => 'Choose Import Method';

  @override
  String get chooseImportMethodSubtitle =>
      'Supports traditional .ics calendar import, AI image import, and warehouse-based academic system import';

  @override
  String get importMethodIcsTitle => '.ics Calendar Import';

  @override
  String get importMethodIcsSubtitle =>
      'Calendar files from other timetable apps';

  @override
  String get importMethodIcsFooter =>
      'Pick an .ics file directly. You can append or replace existing courses.';

  @override
  String get importMethodAiTitle => 'Image Import';

  @override
  String get importMethodAiSubtitle => 'Import from timetable screenshots';

  @override
  String get importMethodAiFooter =>
      'Copy the prompt, send screenshots to the AI expert mode, paste the JSON result back, then choose semester start date.';

  @override
  String get importMethodWarehouseTitle => 'Academic System Import';

  @override
  String get importMethodWarehouseSubtitle => 'Sign in to your school system';

  @override
  String get importMethodWarehouseFooter =>
      'Choose a school and adapter, then open the academic system page and run the import.';

  @override
  String get importMethodSpreadsheetTitle => 'Spreadsheet Import';

  @override
  String get importMethodSpreadsheetSubtitle =>
      'Import from an Excel or CSV template';

  @override
  String get importMethodSpreadsheetFooter =>
      'Supports .csv and .xlsx. Download the template, fill it in, then pick a file.';

  @override
  String get spreadsheetImportTitle => 'Spreadsheet Import';

  @override
  String get spreadsheetScenarioIntro =>
      'The mikcb template maps columns by header: required fields are course name, weekday, sections, and weeks; others are optional. Download the full template or keep only required columns. WakeUp 7-column layout is also supported';

  @override
  String get spreadsheetStep1Subtitle =>
      'Download the full template, or keep only required columns plus 上课周 (or 开始周+结束周) for minimal import';

  @override
  String get spreadsheetStep2Subtitle =>
      'Save as .csv or keep .xlsx when finished';

  @override
  String get spreadsheetStep3Subtitle =>
      'Pick a file to import. Warnings are shown first, then choose append or replace';

  @override
  String get spreadsheetSupportedFilesSuffix =>
      'Supports .csv and .xlsx (first sheet only).';

  @override
  String get chooseSpreadsheetFileAction => 'Choose spreadsheet file';

  @override
  String get downloadSpreadsheetTemplateAction => 'Download mikcb template';

  @override
  String get spreadsheetImportWarningsTitle => 'Import warnings';

  @override
  String get spreadsheetImportWarningsMessage =>
      'These rows were skipped. You can still import the rest:';

  @override
  String get spreadsheetImportWarningsContinue => 'Continue import';

  @override
  String get spreadsheetFormatUnrecognized =>
      'Unrecognized format. Please use the mikcb template; WakeUp-like column layouts are also supported.';

  @override
  String get icsImportTitle => '.ics Calendar Import';

  @override
  String get applicableScenarioTitle => 'When to use';

  @override
  String get icsScenarioIntro =>
      'If you can already import courses into WakeUp or similar apps and export them as an .ics file, this path is the most stable';

  @override
  String stepLabel(String step) {
    return 'Step $step';
  }

  @override
  String get icsStep1Subtitle =>
      'Export an .ics calendar file from another timetable app first';

  @override
  String get icsStep2Subtitle =>
      'Come back here to pick the file and choose append or replace';

  @override
  String get icsStep3Subtitle =>
      'Before importing, confirm the semester start date and which semester week your timetable week 1 maps to';

  @override
  String get supportedFilesTitle => 'Supported Files';

  @override
  String get supportedFilesSuffix => 'The file extension must be .ics.';

  @override
  String get supportedFilesImageHint =>
      'If you only have screenshots, go back and choose Image Import instead';

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
      'If you encounter crashes, timetable display issues, import problems, or want to suggest features, you can use the channels below';

  @override
  String get feedbackIssueHint =>
      'For issues with reproduction steps, screenshots, app version, or logs, GitHub Issue is recommended first';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle =>
      'Open the repository issue page to submit bugs, suggestions, or review existing reports';

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
  String get copiedWechatOaName => 'Official account name copied';

  @override
  String get feedbackWechatOaOpenHint =>
      'Official account name copied. Paste and search in WeChat';

  @override
  String get feedbackOpeningChannel => 'Opening…';

  @override
  String get feedbackOpenChannelFailed => 'Could not open. Details copied.';

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
    return 'Clear all courses in “$name”? Timetable settings will be kept';
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
  String get qrTransferSectionTitle => 'QR Face-to-Face Transfer';

  @override
  String get qrTransferSectionSubtitle =>
      'Bring two phones close and scan to transfer timetables and settings without any network';

  @override
  String get qrTransferSendCurrent => 'Send Current Timetable';

  @override
  String get qrTransferSendAll => 'Send All Data';

  @override
  String get qrTransferScanReceive => 'Scan to Receive';

  @override
  String qrTransferFrameProgress(int sent, int total) {
    return '$sent frames sent, about $total needed';
  }

  @override
  String get qrTransferSendHint =>
      'Ask the other party to open \"Scan to Receive\" and keep the camera pointed at this screen until done';

  @override
  String get qrTransferStop => 'Stop Sending';

  @override
  String get qrTransferScanTitle => 'Scan to Receive';

  @override
  String get qrTransferScanHint =>
      'Point the camera at the other phone\'s screen and hold steady until progress completes';

  @override
  String qrTransferReceiveProgress(int received, int decoded, int total) {
    return '$received frames received · $decoded/$total decoded';
  }

  @override
  String get qrTransferReceiveComplete => 'Data received, importing…';

  @override
  String get qrTransferSessionMismatch =>
      'Detected a different transfer; make sure you are pointing at one stream only';

  @override
  String get qrTransferChecksumFailed =>
      'Transfer verification failed. Please restart.';

  @override
  String get qrTransferRawLengthMismatch =>
      'Received data length verification failed. Please restart.';

  @override
  String get qrTransferDecompressionFailed =>
      'Could not decompress the received data. Please restart.';

  @override
  String get qrTransferPlaintextWarning =>
      'QR transfer is plaintext. Nearby cameras may read it. Review the source before importing; nothing is overwritten without your confirmation.';

  @override
  String get qrTransferResourceLimit =>
      'Received data exceeded the QR transfer resource limit. Restart and use a smaller backup.';

  @override
  String get qrTransferSessionExpired =>
      'QR transfer timed out. Restart and keep the camera pointed at one screen.';

  @override
  String get qrTransferFullBackupWarning =>
      'This full backup will replace the data on this device after confirmation.';

  @override
  String get qrTransferImportFullBackup => 'Import Full Backup';

  @override
  String get qrTransferDecodeFailed =>
      'Could not decode the QR transfer. Please restart.';

  @override
  String get qrTransferRestart => 'Restart';

  @override
  String get qrTransferSampleFps => 'Sample FPS';

  @override
  String get qrTransferDecodeFps => 'Decode FPS';

  @override
  String get qrTransferReceiveSpeed => 'Receive Speed';

  @override
  String get qrTransferElapsed => 'Elapsed';

  @override
  String get qrTransferNewFrames => 'New Frames';

  @override
  String get qrTransferDuplicateFrames => 'Duplicate Frames';

  @override
  String get qrTransferBlockSize => 'Block Size';

  @override
  String get qrTransferBlockCount => 'Block Count';

  @override
  String get qrTransferFileData => 'File Data';

  @override
  String qrTransferFileDataDetail(String rawSize, String compressedSize) {
    return 'Original $rawSize · Compressed $compressedSize';
  }

  @override
  String get fullExportTitle => 'Export';

  @override
  String get fullExportSubtitle =>
      'Export the current timetable, or export all timetables, time schemes, and the current selection';

  @override
  String get exportCurrentTimetable => 'Export Current Timetable';

  @override
  String get exportAllData => 'Export All Data';

  @override
  String get fullImportTitle => 'Import';

  @override
  String get fullImportSubtitle =>
      'When importing, you can overwrite the current timetable or import it as a new timetable. Export your backup first if possible';

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
      'You can overwrite the current timetable, or import the backup as a new standalone timetable';

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
      'You can start using the app right away, or import courses / restore a backup first';

  @override
  String get thirdPartyDisclaimer =>
      'Disclaimer: This app is independently developed by a third-party developer for learning and research purposes only. It is not official Xiaomi software and has no affiliation, partnership, or authorization relationship with Xiaomi Technology Co., Ltd. If you believe any content infringes your rights, please contact the author. We will promptly remove the relevant content upon notification.';

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
      'We changed the app package name, so you may temporarily see two app icons. This is normal. Your old data is still in the old app. Back it up there first, then import it here';

  @override
  String get migrationStep1Title => 'Open the old app';

  @override
  String get migrationStep1Subtitle =>
      'Go to Backup & Migration and choose Export All Data. Do not export only the current timetable, and do not uninstall the old app first';

  @override
  String get migrationStep2Title => 'Save the backup file';

  @override
  String get migrationStep2Subtitle =>
      'After exporting, the old app will open the system share sheet. Prefer Save to Files, and store it in the Download folder';

  @override
  String get migrationStep3Title => 'Return to this version and import';

  @override
  String get migrationStep3Subtitle =>
      'Return to the new version, choose the .mikcb backup file from Download, and restore it. Only uninstall the old app after confirming everything works here';

  @override
  String get migrationNoSaveToFilesTitle => 'If “Save to Files” is unavailable';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      'You can first share the backup to any WeChat chat, then open the file in WeChat and save it. It usually ends up in Download or the WeiXin folder. Then return here and import that .mikcb file';

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
      'Your support goes directly into timetable maintenance, academic adapter updates, and overall experience improvements';

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
  String get supportRunningBadge => 'Active';

  @override
  String get supportTapQrHint => 'Tap to enlarge';

  @override
  String get supportSaveShort => 'Save';

  @override
  String get supportConfirmedShort => 'Supported';

  @override
  String get donorSearchHint => 'Search name or message...';

  @override
  String get donorSortLargeFirst => 'Largest first';

  @override
  String get donorSortSmallFirst => 'Smallest first';

  @override
  String get supportMonthlyGoalLabel => 'Monthly server & certificate renewal';

  @override
  String supportGoalRaised(String raised, String goal) {
    return 'Raised: $raised / Goal $goal';
  }

  @override
  String supportBackerCount(int count) {
    return '$count supporters so far';
  }

  @override
  String get supportDonorListFooter => 'Names are kept permanently 💖';

  @override
  String supportMarqueeThanks(String name, String amount) {
    return '🎉 Thanks to $name for $amount';
  }

  @override
  String get supportMarqueeTail =>
      'Qingyu Timetable keeps running — thank you for your support!';

  @override
  String get scanQrWechatTitle => 'Scan with WeChat';

  @override
  String get scanQrAlipayTitle => 'Scan with Alipay';

  @override
  String get scanQrSubtitle =>
      'Screenshot and scan, thank you for your support!';

  @override
  String get courseOverviewTitle => 'Course Overview & Edit';

  @override
  String get addNewCourseTooltip => 'Add New Course';

  @override
  String get emptyCourseOverviewHint =>
      'Long press the timetable or tap the top-right button to add a course';

  @override
  String conflictDetectedMessage(int count) {
    return '$count scheduled entries have actual conflicts. Conflicting items are highlighted below';
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
      'Weekday, sections, room, weeks, and odd/even settings here only affect this single schedule entry';

  @override
  String get timeSchemeLabel => 'Time Scheme';

  @override
  String followCurrentTimetableWithName(String name) {
    return 'Follow current timetable ($name)';
  }

  @override
  String get followCurrentTimetableDescription =>
      'Without a manual override, auto-match by location keywords; otherwise follow the timetable main scheme';

  @override
  String get overrideTimeSchemeDescription =>
      'This course will use the selected scheme separately instead of following the timetable’s main schedule';

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
      'Single lessons only appear in one week, which is ideal for make-up or temporary classes';

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
      'Schedule continuously from the start week to the end week';

  @override
  String get rangeWeeksOddHint => 'Keep only odd weeks in the selected range';

  @override
  String get rangeWeeksEvenHint => 'Keep only even weeks in the selected range';

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
      'An open-source Android project focused on timetable viewing, course reminders, and the HyperOS island experience';

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
      'Check for updates and download the latest release';

  @override
  String get aboutChangelogTitle => 'Changelog';

  @override
  String get aboutChangelogSubtitle => 'View update notes for all versions';

  @override
  String get aboutPositioningTitle => 'Project Positioning';

  @override
  String get aboutPositioningSubtitle =>
      'What it is, who it is for, and its core capabilities';

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
      'Current import methods, backup restore, and migration advice';

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
      'Developers and academic system adapter contributors';

  @override
  String get aboutRepositoryTitle => 'Open Source Repositories';

  @override
  String get aboutRepositorySubtitle =>
      'GitHub source, releases, and feedback entry';

  @override
  String get aboutOpenSourceLicensesTitle => 'Open Source Licenses';

  @override
  String get aboutOpenSourceLicensesSubtitle =>
      'App license and third-party component licenses';

  @override
  String get aboutOpenSourceLicensesSearchHint => 'Search package name';

  @override
  String get aboutOpenSourceLicensesAppSectionTitle => 'About these licenses';

  @override
  String get aboutOpenSourceLicensesAppLicenseLabel =>
      'Qingyu Timetable source code is released under GPL-3.0-or-later.';

  @override
  String get aboutOpenSourceLicensesIntro =>
      'The list below shows open-source components used by this app and their licenses. Tap an item to read the full text.';

  @override
  String get aboutOpenSourceLicensesExtraSectionTitle => 'About these licenses';

  @override
  String get aboutOpenSourceLicensesExtraUmeng =>
      'Analytics services such as Umeng are enabled only after you accept the privacy policy, and are governed by their own terms and privacy policy.';

  @override
  String get aboutOpenSourceLicensesExtraNote => '';

  @override
  String aboutOpenSourceLicensesPackagesSectionTitle(int count) {
    return 'Open-source components ($count)';
  }

  @override
  String aboutOpenSourceLicensesPackageSubtitle(int count) {
    return '$count license text(s)';
  }

  @override
  String get aboutOpenSourceLicensesLoadFailed =>
      'Failed to load licenses. Please try again later.';

  @override
  String get aboutOpenSourceLicensesEmpty => 'No matching packages';

  @override
  String get aboutAppLogsTitle => 'App logs';

  @override
  String get aboutAppLogsSubtitle => 'View all-level runtime logs';

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
  String get appLogsSourceApp => 'App';

  @override
  String get appLogsSourceNative => 'Super Island';

  @override
  String get appLogsRecordingPausedHint =>
      'Recording is off. The entries below are historical logs only; no new logs will be added';

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
    return 'Delete “$name”? A scheme in use cannot be deleted';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return 'Deleted time scheme: $name';
  }

  @override
  String get timeSchemeInUseMessage =>
      'This scheme is currently used by a timetable';

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
      'Review the total impact first, then decide whether to edit this scheme directly or duplicate it before making changes';

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
      'Timetables in this list use this scheme as their main time schedule';

  @override
  String get followMainSchemeCoursesTitle =>
      'Courses following the timetable main scheme';

  @override
  String get followMainSchemeCoursesEmpty =>
      'No course is indirectly using this scheme via its timetable.';

  @override
  String get followMainSchemeCoursesSubtitle =>
      'These courses do not set an override time scheme and follow the timetable’s main schedule';

  @override
  String get overrideSchemeCoursesTitle =>
      'Courses using this as an override scheme';

  @override
  String get overrideSchemeCoursesEmpty =>
      'No course is using this scheme as an override.';

  @override
  String get overrideSchemeCoursesSubtitle =>
      'These courses will continue using this scheme even if their timetable changes its main schedule';

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
      'If the current timetable is using this scheme, the section count cannot be lower than the maximum section already in use';

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
      'The current timetable and some courses are using this time scheme. Saving will update all related timetables and courses';

  @override
  String get timeSchemeEditorActiveHint =>
      'The current timetable is using this time scheme. Saving will update every timetable that relies on it';

  @override
  String get timeSchemeEditorOverrideHint =>
      'Some courses are using this time scheme as an override. Saving will update every referenced course';

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
      'No long break rule has been set. The short break duration will be used everywhere';

  @override
  String get deleteRuleTooltip => 'Delete Rule';

  @override
  String get generateAction => 'Generate';

  @override
  String get liveSettingsTitle => 'Island & Notifications';

  @override
  String get liveGroupReminders => 'Reminders';

  @override
  String get liveGroupDisplay => 'Display content';

  @override
  String get liveGroupMaintenance => 'Maintenance & self-check';

  @override
  String get liveReminderTimingEntryTitle => 'Reminder Timing';

  @override
  String get liveReminderTimingEntrySubtitle =>
      'Before class, during class and before-end reminders, plus highlight timing';

  @override
  String get liveBeforeClassDisplayEntryTitle => 'Before Class Display';

  @override
  String get liveDuringEndDisplayEntryTitle =>
      'During Class and Before End Display';

  @override
  String get liveKeepAliveEntryTitle => 'Keep Alive';

  @override
  String get liveKeepAliveEntrySubtitle =>
      'Hide from recents, accessibility keep-alive helper, and permission shortcuts';

  @override
  String get liveTestingEntryTitle => 'Testing & Diagnostics';

  @override
  String get liveTestingEntrySubtitle =>
      'Send test notifications and inspect island diagnostics logs';

  @override
  String get followBeforeClassSetting => 'Follow Before-class Settings';

  @override
  String get liveReminderTimingTitle => 'Reminder Timing';

  @override
  String get liveReminderSwitchesTitle => 'Reminder Switches';

  @override
  String get liveReminderSwitchesSubtitle =>
      'Different reminder windows can be combined freely; these switches do not replace each other';

  @override
  String get beforeClassReminderTitle => 'Before Class Reminder';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return 'Trigger $minutes minutes before class starts';
  }

  @override
  String get duringClassReminderTitle => 'During Class and Before End Reminder';

  @override
  String get duringClassReminderSubtitle =>
      'Only affects the period after class starts and before it ends';

  @override
  String get liveClassReminderLeadTitle => 'Highlight timing';

  @override
  String get liveClassReminderLeadOptionImmediate => 'As soon as class starts';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return 'Switch $minutes min before class ends';
  }

  @override
  String get liveDisplayModeTitle => 'Display Style';

  @override
  String get liveDisplayModeSubtitle => 'Applies to enabled reminder windows';

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
  String get enableIslandDisplayTitle => 'Show Island';

  @override
  String get enableIslandDisplaySubtitle =>
      'Disable this if you never want the app to trigger system island presentation';

  @override
  String get liveTimeThresholdTitle => 'Timing Thresholds';

  @override
  String get liveTimeThresholdSubtitle =>
      'Controls when reminders appear, when highlighted reminders start, and when to switch to second-level countdown';

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
  String get timeCorrectionTitle => 'Bell-time correction';

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
      'These settings only affect the current stage and do not change the other reminder stage';

  @override
  String get showCourseNameTitle => 'Show Course Name';

  @override
  String get preferShortNameTitle => 'Prefer Short Course Name';

  @override
  String get preferShortNameSubtitle =>
      'Short names work best within 3 characters';

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
      'If countdown is hidden, you can still show labels like before class / in class / before end';

  @override
  String get hidePrefixTextTitle => 'Hide Prefix Text';

  @override
  String get hidePrefixTextSubtitle =>
      'For example, hide prefixes like “before class”';

  @override
  String get liveIslandPreviewTitle => 'Super Island preview';

  @override
  String get liveIslandPreviewSummaryLabel => 'Summary';

  @override
  String get liveIslandPreviewExpandedLabel => 'Expanded';

  @override
  String get liveIslandPreviewFollowBadge =>
      'Following before-class display settings; adjust those to preview changes';

  @override
  String get liveIslandPreviewStageBeforeClass => 'Before class';

  @override
  String get liveIslandPreviewStageInClass => 'In class';

  @override
  String get liveIslandPreviewStageBeforeEnd => 'Before end';

  @override
  String liveIslandPreviewUntilClassStart(String time) {
    return 'Starts in $time';
  }

  @override
  String liveIslandPreviewUntilClassEnd(String time) {
    return 'Ends in $time';
  }

  @override
  String liveIslandPreviewFinalDismiss(String time) {
    return 'Class ends in $time';
  }

  @override
  String get liveIslandPreviewMilestoneLabel => 'Break';

  @override
  String get liveIslandPreviewSampleCourse => 'Mathematics';

  @override
  String get liveIslandPreviewSampleCourseShort => 'Math';

  @override
  String get liveIslandPreviewSampleLocation => 'Bldg 3-401';

  @override
  String get liveIslandPreviewSampleTeacher => 'Mr. Wang';

  @override
  String get beforeClassQuickActionTitle => 'Before-class Quick Action';

  @override
  String get beforeClassQuickActionSubtitle =>
      'Only appears in the expanded before-class reminder. Silent/DND restores after class ends and on reboot. Do Not Disturb may open a system permission page on first use';

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => 'Left Icon & Expanded View';

  @override
  String get liveIslandVisualSubtitle =>
      'The left text icon, expanded large icon, and custom image are all stored separately for the current stage';

  @override
  String get liveMiuiLabelImageTitle => 'Xiaomi Island Left Text Icon';

  @override
  String get liveMiuiLabelImageSubtitle =>
      'Only effective on Xiaomi-style island layouts. It renders course name or location into the left icon slot';

  @override
  String get liveMiuiLabelContentLabel => 'Left Text Content';

  @override
  String get liveMiuiLabelStyleLabel => 'Left Icon Style';

  @override
  String get liveMiuiLabelLogoTitle => 'Left Icon Logo';

  @override
  String get liveMiuiLabelLogoSubtitle =>
      'Only applies to the icon + text style. If not selected, the app icon remains the fallback';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return 'Left Icon Corner Radius $value';
  }

  @override
  String get liveMiuiLabelLogoCornerRadiusTitle => 'Left icon corner radius';

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return 'Left Text Size $value';
  }

  @override
  String get liveMiuiLabelFontSizeTitle => 'Left text size';

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return 'Left Text Horizontal Offset $value';
  }

  @override
  String get liveMiuiLabelOffsetXTitle => 'Left text horizontal offset';

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return 'Left Text Vertical Offset $value';
  }

  @override
  String get liveMiuiLabelOffsetYTitle => 'Left text vertical offset';

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
      'When enabled, during-class and before-end reminders fully follow the before-class display settings, and the controls below become read-only';

  @override
  String get followBeforeClassDisplayTitle =>
      'Follow Before-class Display Settings';

  @override
  String get liveKeepAliveTitle => 'Keep Alive';

  @override
  String get liveKeepAliveOptionsTitle => 'Keep-alive Options';

  @override
  String get liveKeepAliveOptionsSubtitle =>
      'Used to improve island and reminder stability in background scenarios';

  @override
  String get hideFromRecentsTitle => 'Hide from Recents';

  @override
  String get hideFromRecentsSubtitle =>
      'When enabled, the app will try not to appear in the recent tasks list';

  @override
  String get keepAliveServiceTitle => 'Qingyu Timetable Keep-alive Service';

  @override
  String get keepAliveServiceEnabledSubtitle =>
      'Currently enabled. The system will keep the accessibility-based keep-alive helper available';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      'Currently disabled. You can open system accessibility settings and enable the Qingyu Timetable keep-alive service manually';

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
      'Different schools may use different total teaching weeks';

  @override
  String weekCountItem(int count) {
    return '$count weeks';
  }

  @override
  String get diagnosticsLogIntro =>
      'Supports both Markdown and raw views so you can inspect full logs directly on your phone';

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
      'Switch back to \"All\" or check the raw view to continue debugging';

  @override
  String get diagnosticsLevelInferred => 'Inferred level';

  @override
  String get diagnosticsRawFilteredHint =>
      'The raw view follows the current level filter and only shows matching log blocks';

  @override
  String get diagnosticsTimeSortAscending => 'Oldest first';

  @override
  String get diagnosticsTimeSortDescending => 'Newest first';

  @override
  String get diagnosticsDisplayOptionsTitle => 'View & sort';

  @override
  String get diagnosticsStreamingHint =>
      'Live updates are on. New logs appear automatically';

  @override
  String get diagnosticsEmptyTitle => 'No Logs Yet';

  @override
  String get diagnosticsEmptySubtitle =>
      'There are currently no app logs to display';

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
      'Authorize the essentials on the first screen. Below you’ll also see HyperOS support, short-name setup, and import guidance, so keep scrolling';

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
      'You’ve reached the end. If everything looks right, you can start using the app now';

  @override
  String get guideScrollHint =>
      'Scroll down to continue. HyperOS support, the permission checklist, short-name setup, and import methods are all below';

  @override
  String get guideRequestNotificationFirst =>
      'Request Notification Permission First';

  @override
  String get quickSetupTitle => 'Quick Setup';

  @override
  String get quickSetupSubtitle =>
      'Put the 5 most important entries first so you don’t need to search for them later';

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
      'Please scroll to the end, review the notes, and check consent before starting';

  @override
  String get guideContinueHint => 'Keep scrolling to finish the guide';

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
      'Best for make-up classes or temporary one-off lessons';

  @override
  String get recurringLessonHint =>
      'Best for regular classes that repeat over many weeks';

  @override
  String get sharedInfoTitle => 'Shared Info';

  @override
  String get sharedInfoHint => 'View shared field descriptions';

  @override
  String get sharedInfoSheetItemCourseName =>
      'Course name: Unique identifier. Schedule entries with the same name belong to one course; renaming creates a separate course record.';

  @override
  String get sharedInfoSheetItemShortName =>
      'Course short name: Used for concise display in Super Island and similar surfaces. Must be entered manually; the system does not generate it automatically. Takes effect when Prefer course short name is enabled; limit to about 3 characters when possible.';

  @override
  String get sharedInfoSheetItemSharedSync =>
      'Shared sync: Short name, color, nature, description, and related fields sync to other schedule entries under the same course name.';

  @override
  String get reuseExistingCourseLabel => 'Reuse Existing Course';

  @override
  String get reuseExistingCourseHelper =>
      'Pick an existing course to autofill name, teacher, and other shared info';

  @override
  String get manualInputLabel => 'Enter Manually';

  @override
  String get noTemplateCoursesHint =>
      'There are no existing courses yet. Add one manually first, then future temporary lessons can reuse it';

  @override
  String get courseNameLabel => 'Course Name';

  @override
  String get courseNameHelper =>
      'Serves as the unique course identifier. Entries with the same name are grouped as one course. Enter the full official name; do not abbreviate for display';

  @override
  String get pleaseEnterCourseName => 'Please enter the course name';

  @override
  String get courseShortNameOptional => 'Course short name';

  @override
  String get courseShortNameHelper =>
      'Recommended for concise display in Super Island and similar surfaces. Short names are not generated automatically; enable Prefer course short name to apply. Limit to about 3 characters when possible';

  @override
  String get courseShortNameAutoFillAction => 'First 2 chars';

  @override
  String get teacherLabel => 'Teacher';

  @override
  String get courseNatureLabel => 'Course Nature';

  @override
  String get courseDescriptionOptional => 'Course Description (Optional)';

  @override
  String get currentScheduleHint =>
      'Weekday, sections, room, week range, and odd/even settings here only affect this specific entry';

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
      'A single lesson appears in only one week, ideal for temporary additions or make-up classes';

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
      'Schedule continuously from the start week to the end week';

  @override
  String get oddWeeksHint => 'Keep only odd weeks within the selected range';

  @override
  String get evenWeeksHint => 'Keep only even weeks within the selected range';

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
    return 'Switch to the Island and focused reminder $minutes minutes before class ends, then show second-level countdown in the last ${seconds}s';
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
      'Controls the style of the timetable switch entry at the top left of the home page';

  @override
  String get homeTitleStyleLabel => 'Title style';

  @override
  String get themeSeedSectionTitle => 'App theme color';

  @override
  String get themeSeedSectionSubtitle =>
      'Affects the top bar, accent color, and global primary tone';

  @override
  String get frostedSheetSectionTitle => 'Frosted Glass';

  @override
  String get frostedSheetSectionSubtitle =>
      'Adjust home popup blur and milky frosted brightness. Further right = brighter white glass';

  @override
  String get frostedBlurEnabledTitle => 'Enable Blur';

  @override
  String get frostedBlurEnabledSubtitle =>
      'When off, sheets and home frosted areas keep tint only, without backdrop blur';

  @override
  String get frostedSheetPreviewOpenAction => 'Open Preview Panel';

  @override
  String get frostedSheetPreviewDemoTitle => 'Preview';

  @override
  String get frostedSheetPreviewDemoSubtitle =>
      'Live preview of frosted glass effect';

  @override
  String get frostedSheetBlurLabel => 'Blur Intensity';

  @override
  String get frostedSheetTintLabel => 'Frost brightness';

  @override
  String get timetableBackgroundColorSectionTitle =>
      'Timetable background color';

  @override
  String get timetableBackgroundColorSectionSubtitle =>
      'Used in solid-color mode for the selected display regions; can pair with a background image';

  @override
  String get homePageBackgroundFillLabel => 'Background fill';

  @override
  String get homePageBackgroundFillColor => 'Solid color';

  @override
  String get homePageBackgroundFillImage => 'Image';

  @override
  String get homePageBackgroundImageTitle => 'Background image';

  @override
  String get homePageBackgroundImageSubtitle =>
      'In image mode, applies to the display regions selected below';

  @override
  String get homePageWallpaperTitle => 'Background image';

  @override
  String get homePageWallpaperSubtitle =>
      'One full-screen image. Checked regions below show it through; others use the page color';

  @override
  String get homePageBackdropFollowsWeekPagerTitle =>
      'Background follows week swipe';

  @override
  String get homePageBackdropFollowsWeekPagerSubtitle =>
      'When swiping between weeks, the background image moves with the timetable page';

  @override
  String get homePageBackgroundScopeTitle => 'Background display area';

  @override
  String get homePageBackgroundScopeSubtitle =>
      'Top to bottom: choose which regions show the image; others use the page color';

  @override
  String get homePageBackgroundScopeStatusBar => 'Status bar';

  @override
  String get homePageBackgroundScopeTimetable => 'Timetable area';

  @override
  String get homePageBackgroundScopeWeekdayBar => 'Info bar';

  @override
  String get homePageBackgroundScopeHeader => 'Top bar';

  @override
  String get homePageHeaderBlurTitle => 'Top bar blur';

  @override
  String get homePageHeaderBlurSubtitle =>
      'Frost the title row; includes the status bar when that scope is enabled';

  @override
  String get homePageWeekdayBarBlurTitle => 'Info bar blur';

  @override
  String get homePageWeekdayBarBlurSubtitle =>
      'Frost the week and weekday row over the background image';

  @override
  String get homePageTimeColumnBlurTitle => 'Time column blur';

  @override
  String get homePageTimeColumnBlurSubtitle =>
      'Frost the left section/time column over the background image';

  @override
  String get homePageRegionBlurSectionSubtitle =>
      'Works with a background image. Blur strength follows sheet frosted-glass settings';

  @override
  String get homePagePickImageAction => 'Choose image';

  @override
  String get homePageSwitchImageAction => 'Switch photo';

  @override
  String get homePageClearImageAction => 'Clear image';

  @override
  String get homePageImageNotSelected => 'Not selected';

  @override
  String get wallpaperPositionPickerTitle => 'Adjust wallpaper position';

  @override
  String get wallpaperPositionPickerResetTooltip => 'Reset to center';

  @override
  String get wallpaperPositionPickerDragHint =>
      'Drag the wallpaper to adjust its position';

  @override
  String get wallpaperPositionPickerSwitchWallpaper => 'Change wallpaper';

  @override
  String get wallpaperPositionPickerDone => 'Done';

  @override
  String get wallpaperPositionPickerExit => 'Exit';

  @override
  String get appearanceTextColorsSectionTitle => 'Text colors';

  @override
  String get appearanceTextColorsSectionSubtitle =>
      'Customize course card, weekday bar, and time axis text colors';

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
  String get liveDisplaySummaryLeftLabelImage => 'Icon';

  @override
  String get liveDisplaySummaryMinimal => 'Minimal display';

  @override
  String get liveDisplaySummaryCountdownShort => 'Countdown';

  @override
  String liveDisplaySummaryMore(String first, int count) {
    return '$first, $count items';
  }

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
      'If you mainly want to use the Island, first make sure your system version is at least HyperOS 3.0.300, then complete the permission checklist below in order';

  @override
  String get guidePermissionChecklistTitle => 'Permission checklist';

  @override
  String get guidePermissionChecklistSubtitle =>
      'Follow this order for the easiest setup and the lowest chance of missing anything';

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
      'The Island supports course short names. Short names are not generated automatically, so you need to fill them in on the course edit page yourself. Keeping them within 3 characters is usually the most stable';

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
      'This version already supports web login import for some school systems. If your school is not supported yet, there are still other migration options';

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
      '2. Adjust the before-class popup and in-class and near-end reminder thresholds in Settings first.';

  @override
  String get guideFinalTip3 =>
      '3. After finishing the system permission setup, use a test notification to verify everything. If the Island still disappears occasionally, check auto-start and battery policy first.';

  @override
  String get guidePrivacyHelperRequireConsent =>
      'By checking the box, you confirm that you have read and agreed to the Umeng-related privacy notes, privacy content, and disclaimer above';

  @override
  String get guidePrivacyHelperViewOnly =>
      'This page keeps the same privacy, third-party SDK, and disclaimer information shown during first launch so you can review it at any time. You do not need to agree again here';

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
  String get liveDiagnosticsUnavailable => 'There are no app logs to view yet.';

  @override
  String get liveDiagnosticsViewerTitle => 'Super Island logs';

  @override
  String get liveDiagnosticsShareText =>
      'These are the Super Island related logs exported from Qingyu Timetable. They can help investigate issues such as the Island not appearing.';

  @override
  String get liveDiagnosticsShareSubject =>
      'Qingyu Timetable - Super Island logs';

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
  String get liveDiagnosticsCleared => 'App logs have been cleared.';

  @override
  String get liveDiagnosticsClearFailed => 'Failed to clear app logs';

  @override
  String get liveTestingNotRefreshed => 'Not refreshed yet';

  @override
  String get liveTestingTitle => 'Testing & diagnostics';

  @override
  String get liveTestingNotificationTitle => 'Test notifications';

  @override
  String get liveTestingNotificationSubtitle =>
      'Used to verify the Island, notification bar, and course short-name display';

  @override
  String get liveTestingSendAction => 'Send test notification';

  @override
  String get liveTestingUmengHint =>
      'The two buttons below are shown only in test builds and are used to verify Umeng U-APM crash and ANR reporting';

  @override
  String get liveTestingCrashAction => 'Crash test';

  @override
  String get liveTestingAnrAction => 'ANR test';

  @override
  String get liveTestingIslandStatusTitle => 'Island status diagnostics';

  @override
  String get liveTestingIslandStatusSubtitle =>
      'This section shows the native live service status, notification build result, and the reason it is not appearing on the Island';

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
      'Collapsed by default. Expand it only when you need to verify the full native fields';

  @override
  String get liveTestingExpandRawJson => 'Expand raw JSON';

  @override
  String get liveTestingExpandRawJsonSubtitle =>
      'Prevents large raw payloads from taking over the page';

  @override
  String get liveTestingLocalLogsTitle => 'Local diagnostic logs';

  @override
  String get liveTestingLocalLogsSubtitle =>
      'Export the log file with one tap and share it directly with the developer, or clear it and collect again';

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
      'Shows the current native diagnostic fields';

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
      'This note is shown here. You can edit it on the course edit page';

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
      'The first batch supports 2×2, 2×4, and 4×4 sizes. Tapping a widget opens the home page directly, and it refreshes automatically when classes start and end';

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
      'When turned off, the widget secondary info will prioritize week info and course count';

  @override
  String get homeWidgetShowCountdownTitle => 'Show countdown';

  @override
  String get homeWidgetShowCountdownSubtitle =>
      'The refresh switch is kept for now and will later be used to show remaining time before the next class and during class';

  @override
  String get homeWidgetCountdownLeadTitle => 'Countdown lead time';

  @override
  String get homeWidgetCountdownLeadSubtitle =>
      'Set how many minutes before class to automatically switch to countdown mode';

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
      'When enabled, the 2×2, 2×4, and 4×4 course lists show only classes that have not finished yet';

  @override
  String get homeWidgetShowTomorrowTitle => 'Show tomorrow\'s classes';

  @override
  String get homeWidgetShowTomorrowSubtitle =>
      'When enabled, the widget automatically switches to tomorrow\'s classes after today\'s classes end';

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
      'Widgets currently prioritize today\'s courses. On days without classes, the full card stays visible instead of turning blank. If you switch timetables or change styles, the home-screen widgets refresh as well';

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
      'When enabled, the page automatically fills to the bottom based on the current section count instead of leaving blank space below';

  @override
  String get layoutHideWeekendsTitle => 'Hide weekends';

  @override
  String get layoutHideWeekendsSubtitle =>
      'When enabled, only Monday to Friday are shown on the home page and the remaining columns expand automatically';

  @override
  String get layoutEnableHapticsTitle => 'Enable in-app haptic feedback';

  @override
  String get layoutEnableHapticsSubtitle =>
      'When off, interactions such as page switching no longer trigger light vibration';

  @override
  String pageTransitionSpeedLabel(String speed) {
    return 'Page transition speed $speed×';
  }

  @override
  String get pageTransitionSpeedTitle => 'Page transition speed';

  @override
  String get pageTransitionSpeedSubtitle =>
      'Adjust how fast sub-pages slide in and out. Higher is faster, lower is slower. Multiplied by the system transition animation scale on Android';

  @override
  String pageTransitionSpeedDurationHint(int milliseconds) {
    return 'About $milliseconds ms';
  }

  @override
  String get layoutTimeColumnDisplayLabel => 'Home page time column';

  @override
  String get layoutTimeColumnWidthLabel => 'Time column width';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel =>
      '\"Back to current week\" button style';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      'Defaults to the current inline style, or switch to a small floating button in the bottom-right of week view';

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
  String get layoutBackToCurrentWeekButtonOpacityTitle =>
      'Floating button opacity';

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle =>
      'Only applies to the floating bottom-right style';

  @override
  String layoutCourseCardGapLabel(String value) {
    return 'Course card spacing $value';
  }

  @override
  String get layoutCourseCardGapTitle => 'Course card spacing';

  @override
  String layoutSectionHeightLabel(String value) {
    return 'Row height $value';
  }

  @override
  String get layoutSectionHeightTitle => 'Row height';

  @override
  String layoutCompactFontSizeLabel(String value) {
    return 'Compact font size $value';
  }

  @override
  String get layoutCompactFontSizeTitle => 'Compact font size';

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return 'Course card font size $value';
  }

  @override
  String get layoutCourseCardFontSizeTitle => 'Course card font size';

  @override
  String get layoutCourseCardDisplayTitle => 'Course card display';

  @override
  String get layoutCourseCardDisplaySubtitle =>
      'Course name, teacher, and classroom are shown by default. Other information can be toggled freely per timetable';

  @override
  String get layoutShowTeacherTitle => 'Show teacher';

  @override
  String get layoutShowClassroomTitle => 'Show classroom';

  @override
  String get layoutShowTimeTitle => 'Show time';

  @override
  String get layoutShowTimeLabelsTitle => 'Show start and end labels';

  @override
  String get layoutShowTimeLabelsSubtitle =>
      'When off, only the time points are shown, without the \"start\" and \"end\" labels';

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
      'Off by default. When enabled, courses not in the current week are shown in semi-transparent gray';

  @override
  String get layoutVerticalAlignLabel => 'Vertical alignment';

  @override
  String get layoutHorizontalAlignLabel => 'Horizontal alignment';

  @override
  String get layoutShowConflictBadgeTitle =>
      'Show conflict pill on the home page';

  @override
  String get layoutShowConflictBadgeSubtitle =>
      'When off, the home timetable no longer shows the \"Conflict\" pill for conflicting courses';

  @override
  String layoutConflictOpacityLabel(int value) {
    return 'Conflict course opacity $value%';
  }

  @override
  String get layoutConflictOpacityTitle => 'Conflict course opacity';

  @override
  String get layoutConflictOpacitySubtitle =>
      'Conflicting courses are automatically stacked. Lower opacity makes multiple courses visible at the same time';

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
      'If you want to add academic-system adapters for more schools, you should also check the qingyu_warehouse repository';

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
  String get aboutCheckingForUpdate => 'Checking for updates…';

  @override
  String get aboutReadVersionFailed =>
      'Unable to read version information right now. Please try again later.';

  @override
  String get aboutReadVersionFailedHint =>
      'If GitHub access is unstable on your network, try again later or switch to the domestic download route below';

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
      'You can simply tap \"Download now\" below. Speed test, mirrors, and prerelease options have been moved into Advanced Options';

  @override
  String get aboutUpdateNoUpdateHint =>
      'The current version is already usable. If you want to try prereleases, enable prerelease checks in Advanced Options below';

  @override
  String aboutUpdatedAt(String time) {
    return 'Updated at: $time';
  }

  @override
  String get aboutUpdateNowTitle => 'Update now';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      'For normal use, just tap Download now once. If downloading is slow, fails, or you need a different route, use Advanced Options below';

  @override
  String get aboutUpdateNowOtherSubtitle =>
      'On the current platform, the app opens the download page directly instead of installing in-app';

  @override
  String get aboutMirrorDownloadHint =>
      'Domestic download is currently prioritized. On most domestic networks, tapping \"Download now\" is enough';

  @override
  String get aboutOriginalDownloadHint =>
      'International-source download is currently prioritized. If downloading is slow or unreachable, switch back to domestic download';

  @override
  String get aboutUseSystemDownloaderAction => 'Use system downloader';

  @override
  String get aboutOpenReleasePageAction => 'Open Release page';

  @override
  String get aboutDownloadMethodTitle => 'Download method';

  @override
  String get aboutDownloadMethodSubtitle =>
      'Domestic download is recommended by default. Only switch to the international source if you can access GitHub reliably';

  @override
  String get aboutDownloadMethodMirror => 'Domestic download';

  @override
  String get aboutDownloadMethodOriginal => 'International source';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return 'Currently using domestic download · $current. Recent speed tests recommend \"$recommended\" instead, and you can switch in Advanced Options if needed';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return 'Currently using domestic download · $current. If downloading is slow or fails, use Advanced Options to test, switch routes, or enter a custom address';
  }

  @override
  String get aboutOriginalModeHint =>
      'You are currently using the international source. This is recommended only if your network can access GitHub reliably; otherwise, switch back to domestic download';

  @override
  String get aboutReleaseNotesTitle => 'Release notes';

  @override
  String get aboutReleaseNotesSubtitle =>
      'Shows the Release notes of the currently detected version.';

  @override
  String get aboutAdvancedOptionsTitle => 'Advanced options';

  @override
  String get aboutAdvancedOptionsSubtitle =>
      'Expand only when downloads are slow, you need to switch routes manually, or you want prerelease checks';

  @override
  String get aboutMirrorSectionTitle => 'Download routes & mirrors';

  @override
  String get aboutMirrorSectionMirrorHint =>
      'You are currently using domestic download. Here you can switch routes manually, run speed tests, or enter a custom download address';

  @override
  String get aboutMirrorSectionOriginalHint =>
      'You are currently using the international source. The route settings below take effect only after you switch back to domestic download';

  @override
  String get aboutFillCustomMirrorFirst =>
      'Enter a custom download address first';

  @override
  String get aboutCurrentCustomMirrorTitle => 'Current custom download address';

  @override
  String get aboutCurrentMirrorTitle => 'Current download route address';

  @override
  String get aboutCurrentCustomMirrorHint =>
      'You are currently using the address you entered manually';

  @override
  String get aboutCurrentMirrorHint =>
      'If the current route fails, switch to another built-in route or use a custom address instead';

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
      'Domestic download is not currently enabled, so the route settings here will not take effect. Switch back to domestic download first if needed';

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
      'When enabled, prereleases are also included in update checks. It is recommended to keep this off for normal use';

  @override
  String get aboutDiagnosticsTitle => 'Testing & diagnostics';

  @override
  String get aboutDiagnosticsSubtitle =>
      'Expand this only when the Island does not appear or when you need to send feedback to the developer';

  @override
  String get aboutRecordDiagnosticsTitle => 'Record app logs';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      'When enabled, app runtime logs are recorded locally. Super Island related entries are labeled separately';

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
      'The download has been handed to the system download manager. You can install it directly from the system notification once it finishes';

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
      'The mirror did not return a total file size yet, so only the downloaded size is shown for now';

  @override
  String get aboutCancelDownloadAction => 'Cancel download';

  @override
  String get aboutContinueDownloadAction => 'Resume download';

  @override
  String get aboutDismissDialogAction => 'Close dialog';

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
      'The names below are summarized from the maintainer field in the qingyu_warehouse adapter repository. If cached data already exists locally, the cache is shown first and then refreshed in the background';

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
      'If you know packet capture, web debugging, JavaScript, or are willing to maintain your school\'s academic system long-term, you are welcome to submit new school adapters and fixes to qingyu_warehouse';

  @override
  String get importFileReadFailed => 'Unable to read the selected file';

  @override
  String get importReplaceExistingTitle => 'Import courses';

  @override
  String importReplaceExistingMessage(String name) {
    return 'When importing $name, replace existing courses? This also clears independent agenda items on the current timetable (such as study sessions or meetings).';
  }

  @override
  String get importNoCoursesRecognized =>
      'No importable courses were recognized';

  @override
  String get importConfirmSemesterMappingTitle =>
      'Confirm semester start date and week mapping';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      'Please select the semester start date in your school calendar. The system has inferred a default week mapping from the earliest class date in the file, and you can still adjust it manually';

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
      'Copy the prompt first, switch Doubao to Expert Mode from the lower-left corner, then send both the timetable screenshots and the prompt together. Copy the JSON returned by Doubao back here, then choose the semester date after tapping Import';

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
      'Paste the JSON returned by Doubao here exactly as-is, then tap Import. Pure JSON is supported, and ```json code blocks are also accepted';

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
      'Prompt copied. Go to Doubao and send the screenshots with the prompt';

  @override
  String get clipboardNoText => 'There is no usable text in the clipboard';

  @override
  String get aiPromptSheetTitle => 'OCR prompt';

  @override
  String get aiPromptSheetSubtitle =>
      'Doubao is recommended. Switch it to Expert Mode first, then send the full prompt below together with the timetable screenshots so it returns JSON only. After generation, copy the JSON back to this page and choose the semester date after tapping Import';

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
      'Replace the existing courses with the current AI parsing result? This also clears independent agenda items on the current timetable (such as study sessions or meetings).';

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
      'The academic-system script has returned course weeks. Please confirm the semester start date in the school calendar; if there are no classes in the first few weeks, you can map timetable Week 1 to a later calendar week';

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
      'Just open the feedback page and file an Issue. It helps a lot if you include the school name, academic-system URL, logged-in timetable page link, or screenshots';

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
  String get warehouseImportExecutionLogTitle => 'Import execution log';

  @override
  String get warehouseImportExecutionLogMenuLabel => 'Import execution log';

  @override
  String get warehouseImportExecutionLogShareText =>
      'This is the academic-system import execution log exported from Qingyu Timetable. It includes script injection, bridge messages, timeouts, and import results for troubleshooting.';

  @override
  String get warehouseImportExecutionLogShareSubject =>
      'Qingyu Timetable - Import execution log';

  @override
  String get warehouseImportExecutionLogEmpty =>
      'No import execution records yet. Open the academic-system page, run the import script, then check again.';

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
    return 'Delete \"$name\"? This will not affect courses that have already been imported';
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
      'Each record can save a custom URL and a full script. Once saved, you can tap \"Start debug\" next time to reuse it directly instead of searching for the entry from a school detail page again';

  @override
  String get addDebugRecordAction => 'Add debug record';

  @override
  String get noSavedDebugRecords => 'No saved debug records yet';

  @override
  String get noSavedDebugRecordsHint =>
      'Add one first and paste the URL and script in. After that, you can reuse it directly';

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
      'Useful when you repeatedly debug the same school or keep multiple script sets for different schools. Records remain saved and can be edited at any time';

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
  String get fillUrlThenRecord => 'Enter URL before recording';

  @override
  String get recordImportAction => 'Record import';

  @override
  String get quickImportAction => 'Quick import';

  @override
  String get quickImportTooltip => 'Quick import';

  @override
  String get selectQuickImportTitle => 'Choose quick import';

  @override
  String quickImportMacroSteps(String adapterName, int stepCount) {
    return '$adapterName · $stepCount steps';
  }

  @override
  String quickImportTitle(String name) {
    return 'Quick import - $name';
  }

  @override
  String get noSavedQuickImportRecords => 'No saved quick-import records yet';

  @override
  String get noValidWarehouseLoginUrl =>
      'No valid academic-system login URL found';

  @override
  String get noMacroRecordFound =>
      'No recording found. Complete a recording first.';

  @override
  String get quickImportPlayingTitle => 'Auto-importing…';

  @override
  String get quickImportExecutingScriptTitle =>
      'Playback finished. Running import script…';

  @override
  String get quickImportManualInputTitle => 'Manual action required';

  @override
  String get quickImportManualInputHint =>
      'Complete the required manual step, then tap Continue';

  @override
  String get quickImportCancelImportAction => 'Cancel import';

  @override
  String get quickImportContinueAction => 'Continue';

  @override
  String get quickImportFinishedTitle => 'Import complete';

  @override
  String get quickImportDismissAction => 'Done';

  @override
  String get quickImportRetryAction => 'Retry';

  @override
  String get homePullQuickImportTitle => 'Pull to quick-import';

  @override
  String get homePullQuickImportSubtitle =>
      'Pull down on the home timetable to run warehouse quick import in the background';

  @override
  String get homePullQuickImportFetchingCourses => 'Fetching new courses…';

  @override
  String get homePullQuickImportNeedsManualAction =>
      'Manual action needed. Open the warehouse import page to continue';

  @override
  String quickImportPlaybackStepProgress(int current, int total) {
    return 'Step $current / $total';
  }

  @override
  String get quickImportCancelPlaybackAction => 'Cancel';

  @override
  String get quickImportUnknownError => 'An unknown error occurred';

  @override
  String get recentSchoolLabel => 'Recently used';

  @override
  String get warehouseSchoolTapHint => 'Tap to choose an adapter and import';

  @override
  String get warehouseAdaptersLoadFailedTitle => 'Could not load adapter list';

  @override
  String get stopRecordingTooltip => 'Stop recording';

  @override
  String get startRecordingTooltip => 'Record actions';

  @override
  String get savedImportUrlHint =>
      'Academic-system URL saved. You can import directly next time';

  @override
  String get adapterIntroSubtitle =>
      'You can view adapter info, the login entry, and script status here';

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
      'The manually overridden login address is currently in use';

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
  String get courseConflictSectionTitle => 'Conflicts';

  @override
  String get courseNormalSectionTitle => 'Other courses';

  @override
  String get courseConflictDetailTitle => 'Conflict details';

  @override
  String get courseConflictDetailEntryTitle => 'View conflict details';

  @override
  String get courseConflictDetailEntrySubtitle =>
      'See overlapping schedules and partners';

  @override
  String courseConflictWithCourse(String name) {
    return 'Conflicts with “$name”';
  }

  @override
  String get courseConflictOpenPartnerAction => 'Open partner schedule';

  @override
  String get courseConflictEmpty => 'No conflicts detected';

  @override
  String get courseConflictPairTitle => 'Conflict pair';

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
    return 'You are viewing Week $week. You can reschedule this class occurrence directly';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return 'You are viewing Week $week, but this course does not occur this week, so it cannot be rescheduled as the current-week occurrence';
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
      'You can delete the whole schedule entry or just the single occurrence shown for the current week';

  @override
  String get deleteCourseAction => 'Delete course';

  @override
  String get deleteOccurrenceAction => 'Delete occurrence';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '\"Delete course\" removes all weeks of this schedule entry; \"Delete occurrence\" removes only the occurrence in Week $week';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return 'This card is not an actual occurrence in Week $week, so only the whole schedule entry can be deleted';
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
    return 'Only the occurrence in Week $week will be adjusted. The original class in that week will be removed automatically, while other weeks stay unchanged';
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
      'Keeps the original title style with text only; tap it to switch timetables';

  @override
  String get homeTitleStyleBrandDescription =>
      'Shows a large logo and the smaller timetable name for a stronger branded look';

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
      'Blank timetable areas do not respond to taps. Choose clearly whether to add a one-off lesson, a recurring course, or a one-time schedule item';

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
  String get feedbackWechatOaTitle => 'WeChat Official Account';

  @override
  String feedbackWechatOaSubtitle(String name) {
    return '$name';
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
      'Schedule items are inserted into the day-view timeline for a specific date and do not change course data';

  @override
  String get scheduleTimeSectionTitle => 'Time Arrangement';

  @override
  String get scheduleTimeSectionSubtitle =>
      'Choose the exact date and time range for this schedule item';

  @override
  String get scheduleAppearanceSectionTitle => 'Appearance';

  @override
  String get scheduleAppearanceSectionSubtitle =>
      'Pick a color that makes schedule items easy to distinguish from courses';

  @override
  String get scheduleLocationLabel => 'Location';

  @override
  String get scheduleLocationHint => 'Optional';

  @override
  String get scheduleDateLabel => 'Date';

  @override
  String get scheduleStartGroupLabel => 'Start';

  @override
  String get scheduleEndGroupLabel => 'End';

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
      'For same-day schedules, the end time must be later than the start time';

  @override
  String get scheduleCrossDayHint =>
      'Cross-day schedules are sliced into the corresponding day view automatically';

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
  String get examEndTimeBeforeStart =>
      'End time cannot be earlier than start time';

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
  String get examOverviewCountdown => 'Countdown';

  @override
  String get examOverviewCountdownUnit => 'days left';

  @override
  String examOverviewTodayCount(int count) {
    return '$count today';
  }

  @override
  String examOverviewUpcomingCount(int count) {
    return '$count upcoming';
  }

  @override
  String get examOverviewInProgress => 'Exam in progress';

  @override
  String get examOverviewLiveBadge => 'Live';

  @override
  String examOverviewStartsAt(String time) {
    return 'Starts $time';
  }

  @override
  String examOverviewUntilTime(String time) {
    return 'Until $time';
  }

  @override
  String get examOverviewReminderOn => 'Reminder on';

  @override
  String get examOverviewReminderOff => 'No reminder';

  @override
  String examTimeRange(String start, String end) {
    return '$start – $end';
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
  String get scheduleEntrySingleTitle => 'Class schedule';

  @override
  String get scheduleEntryCardSubtitle =>
      'Set when this course meets, which weeks it runs, and who teaches it where';

  @override
  String get scheduleEntryTimeSectionTitle => 'When';

  @override
  String get scheduleEntryTimeSectionSubtitle =>
      'Pick the weekday and section range. Use the same start/end section for a single period';

  @override
  String get scheduleEntryWeeksSectionTitle => 'Which weeks';

  @override
  String get scheduleEntryPeopleSectionTitle => 'Teacher & location';

  @override
  String get scheduleEntryTimeSchemeSectionTitle => 'Custom time scheme';

  @override
  String get scheduleEntryTimeSchemeSectionSubtitle =>
      'Follows the timetable by default. Change only if this slot uses different bell times';

  @override
  String scheduleSectionNumberLabel(int section) {
    return 'P$section';
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
  String get courseActionEditPrimary => 'Edit course';

  @override
  String get courseActionRescheduleSecondary => 'Reschedule';

  @override
  String get courseActionSuspendSecondary => 'Suspend';

  @override
  String get courseActionDeleteSecondary => 'Delete';

  @override
  String get courseNoteSheetTitle => 'Course Notes';

  @override
  String get courseNoteAction => 'Notes';

  @override
  String get courseNoteSaveAction => 'Save';

  @override
  String get courseNoteTabWholeCourse => 'Course description';

  @override
  String get courseNoteTabThisSession => 'This class';

  @override
  String get courseNoteWholeCourseLabel => 'Course description';

  @override
  String get courseNoteWholeCourseHint =>
      'Shared across same-name courses (e.g. syllabus notes or classroom tips).';

  @override
  String get courseNoteWholeCoursePlaceholder =>
      'e.g. This teacher often takes attendance, classroom is in the new building…';

  @override
  String get courseNoteSessionLabel => 'This-class note';

  @override
  String courseNoteSessionHint(int week) {
    return 'Applies only to week $week for this class — good for homework or what to bring.';
  }

  @override
  String get courseNoteSessionPlaceholder =>
      'e.g. Chapter 3 exercises due, bring a laptop…';

  @override
  String get courseNoteHasHomeworkTitle => 'Has homework';

  @override
  String get courseNoteHasHomeworkSubtitle =>
      'When on, week-view cards show a homework badge';

  @override
  String get courseNoteHomeworkMarked => 'Homework this class';

  @override
  String get courseNoteTileSubtitleEmpty =>
      'Note homework, what to bring, or class reminders';

  @override
  String get courseNoteTileSubtitleWhole => 'Course description set';

  @override
  String get courseNoteTileSubtitleSession => 'This-class note set';

  @override
  String get courseNoteTileSubtitleBoth =>
      'Course description and this-class notes set';

  @override
  String get courseNoteReadOnlyNotice =>
      'Partner courses are view-only for notes.';

  @override
  String get courseNoteDoneEditingAction => 'Done';

  @override
  String courseActionSheetNotice(int week) {
    return 'You are viewing Week $week. If an exam or conflict comes up, you can quickly reschedule or suspend below.';
  }

  @override
  String get courseActionOddWeekShort => 'Odd week';

  @override
  String get courseActionEvenWeekShort => 'Even week';

  @override
  String get courseActionConflictExpandHint =>
      'Expand to see other conflicting courses and switch actions';

  @override
  String get courseActionConflictCollapseHint =>
      'Tap to collapse the conflict list';

  @override
  String get courseActionConflictSwitchAction => 'Switch';

  @override
  String courseActionCoupleRelatedCount(int count) {
    return '$count more couple timetable course(s)';
  }

  @override
  String get courseActionCoupleExpandHint =>
      'Expand to preview partner or shared classes. Tap to switch';

  @override
  String get courseActionCoupleCollapseHint =>
      'Tap to collapse couple timetable courses';

  @override
  String courseActionMixedRelatedCount(int count) {
    return '$count more related course(s)';
  }

  @override
  String get courseActionPartnerReadOnlyNotice =>
      'This course is from your partner\'s timetable and is read-only.';

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
  String get guidePersonalizePageTitle => 'Personalize';

  @override
  String get guidePersonalizeHeader => 'Make it yours';

  @override
  String get guidePersonalizeSubtitle =>
      'These apply immediately and can be changed anytime in Settings → Appearance';

  @override
  String get guidePersonalizeMenuStyleTitle => 'Menu style';

  @override
  String get guidePersonalizeVisualEffectTitle => 'Visual effect';

  @override
  String get guidePersonalizeVisualEffectSolid => 'Solid cards';

  @override
  String get guideVisualEffectGaussianDesc =>
      'Live gaussian blur behind surfaces — layered and translucent';

  @override
  String get guideVisualEffectLiquidDesc =>
      'Liquid glass refraction with extra depth (slightly higher power use)';

  @override
  String get guideVisualEffectSolidDesc => 'No blur effects — best performance';

  @override
  String get guidePersonalizeThemeModeTitle => 'Theme mode';

  @override
  String get guidePersonalizeSeedColorTitle => 'Accent color';

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
      'Tap to open system settings. Statuses that can be detected will refresh automatically when you return. Auto-start is limited by the system; use the switch on the system page as the source of truth';

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
  String get textColorWeekdayBarAccent => 'Weekday bar accent color';

  @override
  String get textColorTimeAxis => 'Time axis font color';

  @override
  String get textColorSelectColor => 'Select Color';

  @override
  String get textColorCurrentColor => 'Current color';

  @override
  String get themeExport => 'Export Theme';

  @override
  String get themeImport => 'Import Theme';

  @override
  String get themeExportSuccess => 'Theme copied to clipboard';

  @override
  String get themeImportSuccess => 'Theme imported';

  @override
  String get themeImportFailed => 'Clipboard content format error';

  @override
  String get themeManageTitle => 'Theme Manager';

  @override
  String get themeManageSubtitle => 'Export, import and switch themes';

  @override
  String get themePreset => 'Preset Themes';

  @override
  String get themeSaved => 'My Themes';

  @override
  String get themeSaveCurrent => 'Save Current Theme';

  @override
  String get themeApply => 'Apply';

  @override
  String get themeDelete => 'Delete';

  @override
  String themeDeleteConfirmMessage(String name) {
    return 'Are you sure you want to delete theme \"$name\"?';
  }

  @override
  String get textColorLowContrastWarning =>
      'Low color contrast may affect readability';

  @override
  String get themeCurrentTheme => 'Current Theme';

  @override
  String themeBasedOnModified(String baseName) {
    return 'Based on $baseName (modified)';
  }

  @override
  String get themeResetToPreset => 'Reset';

  @override
  String get themeUnsavedChangesTitle => 'Unsaved Changes';

  @override
  String get themeUnsavedChangesMessage =>
      'Current theme has unsaved changes. Do you want to save?';

  @override
  String get themeDiscardAndApply => 'Discard & Apply';

  @override
  String get themeNameHint => 'Enter theme name';

  @override
  String get themePresetBlue => 'Default Blue';

  @override
  String get themePresetPurple => 'Night Purple';

  @override
  String get themePresetGreen => 'Forest Green';

  @override
  String get themePresetOrange => 'Warm Orange';

  @override
  String get themePresetEyeCare => 'Eye Care';

  @override
  String get themePresetHighContrast => 'High Contrast';

  @override
  String get themePresetDarkMinimal => 'Dark Minimal';

  @override
  String get themeUndo => 'Undo';

  @override
  String themeChanged(String themeName) {
    return 'Switched to $themeName';
  }

  @override
  String get themeRename => 'Rename';

  @override
  String get themeDuplicate => 'Duplicate';

  @override
  String themeDuplicateCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get themeMoreActions => 'More actions';

  @override
  String get courseNatureRequired => 'Required';

  @override
  String get courseNatureElective => 'Elective';

  @override
  String get homeMenuStatisticsTitle => 'Statistics';

  @override
  String get statisticsTitle => 'Course Statistics';

  @override
  String get statisticsOverview => 'This Week';

  @override
  String get statisticsCourseCount => 'Courses';

  @override
  String get statisticsSectionCount => 'Sections';

  @override
  String get statisticsWeeklyCourses => 'This Week';

  @override
  String get statisticsDailyDistribution => 'Daily Distribution';

  @override
  String get statisticsNatureRatio => 'Required / Elective';

  @override
  String get statisticsCourseList => 'Course List';

  @override
  String get statisticsSectionsUnit => 'sections';

  @override
  String get statisticsSectionUnit => '';

  @override
  String get statisticsNoData => 'No course data';

  @override
  String get statisticsCourseCountRatio => 'By Count';

  @override
  String get statisticsSectionCountRatio => 'By Sections';

  @override
  String statisticsWeekSelector(int week) {
    return 'Week $week';
  }

  @override
  String get statisticsStoryBusiestDayTitle => 'Busiest Day';

  @override
  String statisticsStoryBusiestDayContent(int week, String day, String avg) {
    return 'Through week $week, your busiest day is **$day**, averaging **$avg** sections';
  }

  @override
  String get statisticsStoryLightestDayTitle => 'Lightest Day';

  @override
  String statisticsStoryLightestDayContent(int week, String day, String avg) {
    return 'Through week $week, your lightest day is **$day**, with only **$avg** sections';
  }

  @override
  String get statisticsStoryFavoriteRoomTitle => 'Favorite Room';

  @override
  String statisticsStoryFavoriteRoomContent(int week, String room, int count) {
    return 'Through week $week, your most visited room is **$room**, **$count** visits';
  }

  @override
  String get statisticsStoryBuildingCountTitle => 'Campus Explorer';

  @override
  String statisticsStoryBuildingCountContent(int week, int count) {
    return 'Through week $week, your classes span **$count** buildings';
  }

  @override
  String get statisticsStoryTimeRangeTitle => 'Time Range';

  @override
  String statisticsStoryTimeRangeContent(String earliest, String latest) {
    return 'Your earliest class is **$earliest**, latest is **$latest**';
  }

  @override
  String get statisticsSemesterLabelCourses => 'courses';

  @override
  String get statisticsSemesterLabelSections => 'sections';

  @override
  String get statisticsSemesterLabelWeeks => 'weeks';

  @override
  String get statisticsSemesterLabelDayStreak => 'day streak';

  @override
  String get statisticsAchievementsTitle => 'Achievements';

  @override
  String get statisticsStoriesTitle => 'Data Stories';

  @override
  String get statisticsRankingTitle => 'Course Ranking';

  @override
  String get statisticsNoDataHint => 'Add courses to view statistics';

  @override
  String get statisticsShareLabel => 'Share statistics';

  @override
  String get statisticsExportTitle => 'Export statistics';

  @override
  String get statisticsExportModulesSection => 'Include modules';

  @override
  String get statisticsExportFormatSection => 'Export format';

  @override
  String get statisticsExportFormatImage => 'Long image (PNG)';

  @override
  String get statisticsExportFormatPdf => 'PDF document';

  @override
  String get statisticsExportAction => 'Export';

  @override
  String get statisticsExportSelectModuleHint => 'Select at least one module';

  @override
  String get statisticsExportModuleOverview => 'Semester overview';

  @override
  String get statisticsExportBrandTagline => 'Course info, system experience';

  @override
  String statisticsExportGithubHint(String url) {
    return 'Find us on GitHub: $url';
  }

  @override
  String get statisticsExportQrScanHint => 'Scan for website';

  @override
  String statisticsExportRankingMore(int count) {
    return '$count more courses not shown';
  }

  @override
  String get statisticsShareTitle => 'My Semester Stats';

  @override
  String statisticsRankingSlotDetail(
    String day,
    int startSection,
    int endSection,
  ) {
    return '$day Periods $startSection-$endSection';
  }

  @override
  String get statisticsAchievementEarlyBirdName => 'Early Bird';

  @override
  String get statisticsAchievementEarlyBirdDescription =>
      'Has a class at 8:00 AM';

  @override
  String get statisticsAchievementPerfectAttendanceName => 'Perfect Attendance';

  @override
  String get statisticsAchievementPerfectAttendanceDescription =>
      'Every scheduled week for a course';

  @override
  String get statisticsAchievementWeekendWarriorName => 'Weekend Warrior';

  @override
  String get statisticsAchievementWeekendWarriorDescription =>
      'Has weekend classes';

  @override
  String get statisticsAchievementClassKingName => 'Class King';

  @override
  String get statisticsAchievementClassKingDescription =>
      '6+ classes in one day';

  @override
  String get statisticsAchievementScholarName => 'Scholar';

  @override
  String get statisticsAchievementScholarDescription => '100+ total sections';

  @override
  String get statisticsAchievementBalancedName => 'Balance Master';

  @override
  String get statisticsAchievementBalancedDescription =>
      'Daily section gap ≤ 2';

  @override
  String get statisticsAchievementNightOwlName => 'Night Owl';

  @override
  String get statisticsAchievementNightOwlDescription =>
      'Has classes after 18:00';

  @override
  String get statisticsAchievementExplorerName => 'Explorer';

  @override
  String get statisticsAchievementExplorerDescription =>
      'Used 5+ different rooms';

  @override
  String statisticsNatureLegendDetail(int count, int sections) {
    return '$count courses · $sections sections';
  }

  @override
  String get statisticsWeekCurrentHint => 'This week';

  @override
  String get weeklyReportTitle => 'Weekly Course Summary';

  @override
  String weeklyReportBody(
    int week,
    int sections,
    int courses,
    String delta,
    String busiestDay,
  ) {
    return 'Week $week · $sections sections · $courses courses\n$delta vs last week\nBusiest day: $busiestDay';
  }

  @override
  String get weeklyReportBodyEmpty => 'No classes this week — enjoy the break';

  @override
  String weeklyReportNextFire(String date, String time) {
    return 'Next: $date $time';
  }

  @override
  String get weeklyReportEnabledHint => 'Weekly report enabled';

  @override
  String get weeklyReportDisabledHint => 'Weekly report disabled';

  @override
  String get statisticsCompareTitle => 'Timetable Comparison';

  @override
  String get statisticsCompareActive => 'Active';

  @override
  String get statisticsCompareNone =>
      'No other timetables yet — create one in timetable management';

  @override
  String statisticsCompareDelta(String delta) {
    return '$delta vs active';
  }

  @override
  String get statisticsCompareDetailTitle => 'Comparison Details';

  @override
  String get statisticsCompareWeek => 'Current week';

  @override
  String get statisticsMoreTitle => 'Deep Dive';

  @override
  String get statisticsAchievementMorningPersonName => 'Morning Bird';

  @override
  String get statisticsAchievementMorningPersonDescription =>
      '50%+ morning sections';

  @override
  String get statisticsAchievementGapMasterName => 'Time Manager';

  @override
  String get statisticsAchievementGapMasterDescription =>
      'Longest break ≤ 2 sections';

  @override
  String get statisticsAchievementEarlyBirdDetail =>
      'Unlock: have a class that starts at 08:00 or earlier.';

  @override
  String get statisticsAchievementPerfectAttendanceDetail =>
      'Unlock: at least one course runs every week during its term (no suspension, no odd/even-week gaps).';

  @override
  String get statisticsAchievementWeekendWarriorDetail =>
      'Unlock: have classes on the weekend (Saturday or Sunday).';

  @override
  String get statisticsAchievementClassKingDetail =>
      'Unlock: have 6 or more sections scheduled in a single day.';

  @override
  String get statisticsAchievementScholarDetail =>
      'Unlock: reach 100 total sections in the semester.';

  @override
  String get statisticsAchievementBalancedDetail =>
      'Unlock: daily section counts differ by no more than 2 — a balanced schedule.';

  @override
  String get statisticsAchievementNightOwlDetail =>
      'Unlock: have a class that ends after 18:00.';

  @override
  String get statisticsAchievementExplorerDetail =>
      'Unlock: use 5 or more different rooms.';

  @override
  String get statisticsAchievementFullDayKingDetail =>
      'Unlock: have 8 or more sections in a single day — a full day of classes.';

  @override
  String get statisticsAchievementBuildingHopperDetail =>
      'Unlock: visit 3 or more different buildings in a single day.';

  @override
  String get statisticsAchievementMorningPersonDetail =>
      'Unlock: more than half of your sections start before 12:00.';

  @override
  String get statisticsAchievementGapMasterDetail =>
      'Unlock: the longest daily break between classes is 2 sections or fewer.';

  @override
  String get statisticsAchievementDetailConfirm => 'Got it';

  @override
  String get statisticsAchievementLocked => 'Locked';

  @override
  String get statisticsSettingsTitle => 'Statistics Settings';

  @override
  String get statisticsTabSemester => 'Semester';

  @override
  String get statisticsTabWeek => 'Week';

  @override
  String get statisticsSemesterProgressTitle => 'Semester Progress';

  @override
  String statisticsSemesterProgressRange(String start, String end) {
    return 'Semester $start - $end';
  }

  @override
  String statisticsSemesterProgressAsOf(String date) {
    return 'As of $date';
  }

  @override
  String statisticsSemesterProgressDetail(int done, int total) {
    return '$done of $total sections taken';
  }

  @override
  String statisticsSemesterProgressRemaining(int count) {
    return '$count sections left';
  }

  @override
  String get statisticsTrendTitle => 'Weekly Sections Trend';

  @override
  String statisticsTrendTooltip(int week, int sections) {
    return 'Week $week · $sections sections';
  }

  @override
  String get statisticsComparisonTitle => 'This Week at a Glance';

  @override
  String get statisticsComparisonLastWeek => 'Last Week';

  @override
  String get statisticsComparisonAverage => 'Weekly Average';

  @override
  String statisticsComparisonVsLastWeek(String delta) {
    return '$delta vs last week';
  }

  @override
  String statisticsComparisonVsAverage(String delta) {
    return '$delta vs weekly avg';
  }

  @override
  String get statisticsComparisonNew => 'First week of the semester';

  @override
  String get statisticsHeatmapTitle => 'Semester Heatmap';

  @override
  String get statisticsHeatmapHint => 'Darker means more sections';

  @override
  String get statisticsTimeUtilTitle => 'Time Usage';

  @override
  String get statisticsTimeEarliest => 'Earliest Class';

  @override
  String get statisticsTimeLatest => 'Latest Class';

  @override
  String get statisticsTimeMorning => 'Morning Sections';

  @override
  String get statisticsTimeNoon => 'Noon Sections';

  @override
  String get statisticsTimeEvening => 'Evening Sections';

  @override
  String get statisticsTimeWeekend => 'Weekend Sections';

  @override
  String get statisticsTimeGap => 'Longest Break';

  @override
  String statisticsTimeGapValue(int sections) {
    return '$sections sections';
  }

  @override
  String get statisticsVenueTitle => 'Rooms & Buildings';

  @override
  String get statisticsVenueTopRooms => 'Favorite Rooms';

  @override
  String get statisticsVenueBuildings => 'Sections by Building';

  @override
  String statisticsVenueVisits(int count) {
    return '$count visits';
  }

  @override
  String get statisticsTeacherTitle => 'Teacher Ranking';

  @override
  String statisticsTeacherCourseCount(int count) {
    return '$count courses';
  }

  @override
  String get statisticsAchievementFullDayKingName => 'Full-Day King';

  @override
  String get statisticsAchievementFullDayKingDescription =>
      '8+ sections in a single day';

  @override
  String get statisticsAchievementBuildingHopperName => 'Building Hopper';

  @override
  String get statisticsAchievementBuildingHopperDescription =>
      '3+ buildings in a single day';

  @override
  String statisticsAchievementProgress(int current, int target) {
    return '$current/$target';
  }

  @override
  String get statisticsAchievementDone => 'Unlocked';

  @override
  String get statisticsWeekBusiestDay => 'Busiest Day';

  @override
  String statisticsWeekDailyHint(int week) {
    return 'Tap to view week $week details';
  }

  @override
  String get weekListSeparator => ', ';

  @override
  String courseWeekListLabel(String weeks) {
    return 'Weeks $weeks';
  }

  @override
  String courseWeekRangeLabel(int startWeek, int endWeek, String mode) {
    return 'Weeks $startWeek-$endWeek$mode';
  }

  @override
  String courseWeekSuspendedLabel(String weeks) {
    return 'Suspended weeks $weeks';
  }

  @override
  String get importSemesterStartDateTitle => 'Semester start date';

  @override
  String get importSemesterStartDateSubtitle =>
      'Treat the week containing this date as calendar week 1';

  @override
  String get importFirstCourseWeekMappingLabel =>
      'Timetable week 1 maps to calendar week';

  @override
  String get importFirstCourseWeekMappingSubtitle =>
      'If the first school week has no classes, choose week 2; if the first two weeks are empty, choose week 3.';

  @override
  String get importSemesterMappingNoShiftHint =>
      'After import, timetable week 1 will be treated as calendar week 1.';

  @override
  String importSemesterMappingShiftHint(int shiftedWeeks, int calendarWeek) {
    return 'All course weeks will shift forward by $shiftedWeeks so timetable week 1 lands on calendar week $calendarWeek';
  }

  @override
  String calendarWeekOption(int week) {
    return 'Calendar week $week';
  }

  @override
  String get aboutDownloadPackageMethodTitle => 'Download install method';

  @override
  String get aboutInAppDownloadTitle => 'In-app download';

  @override
  String get aboutInAppDownloadSubtitle =>
      'Install directly in the app after download completes';

  @override
  String get aboutSystemDownloaderTitle => 'System download manager';

  @override
  String get aboutSystemDownloaderChoiceSubtitle =>
      'Hand off to the system download manager';

  @override
  String get syncErrorAuthFailed => 'Invalid username or password';

  @override
  String get syncErrorAccessDenied => 'Access denied';

  @override
  String get syncErrorCertificateError => 'Certificate error';

  @override
  String get syncErrorConnectionTimeout => 'Connection timed out';

  @override
  String get syncErrorConnectionFailed => 'Could not connect to server';

  @override
  String get syncErrorNetworkError => 'Network error';

  @override
  String get syncErrorInvalidResponse => 'Invalid server response';

  @override
  String get syncErrorLocalChangesPendingSync =>
      'Skipped auto sync because local changes are pending';

  @override
  String get syncErrorMissingCredentials => 'Configure sync account first';

  @override
  String get syncErrorBackupNotFound => 'Backup not found';

  @override
  String get syncErrorMissingBackupSnapshot => 'Backup snapshot is missing';

  @override
  String get syncErrorCannotDeleteCurrentBackup =>
      'Cannot delete the current backup';

  @override
  String get syncErrorProviderNotReady => 'Timetable is not ready';

  @override
  String get syncErrorInsecureUrl =>
      'Only HTTPS encrypted connections are supported; HTTP cleartext protocol is disabled.';

  @override
  String get syncErrorSyncFailed => 'Sync failed';

  @override
  String get sectionTimeDisplayHidden => 'Hidden';

  @override
  String get sectionTimeDisplayStartOnly => 'Start time only';

  @override
  String get sectionTimeDisplayStartAndEnd => 'Start and end times';

  @override
  String get examReminderNone => 'No reminder';

  @override
  String get examReminderMin30 => '30 minutes before';

  @override
  String get examReminderHour1 => '1 hour before';

  @override
  String get examReminderHour1AndMin30 => '1 hour and 30 minutes before';

  @override
  String get examReminderDay1 => '1 day before';

  @override
  String get examReminderDay1AndHour1 => '1 day and 1 hour before';

  @override
  String get examReminderCustom => 'Custom';

  @override
  String examReminderOffsetMinutes(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String examReminderOffsetHours(int hours) {
    return '$hours hours before';
  }

  @override
  String examReminderOffsetDays(int days) {
    return '$days days before';
  }

  @override
  String get examReminderCustomEmpty => 'Select at least one reminder time';

  @override
  String get examReminderAddCustom => 'Add reminder';

  @override
  String get examReminderAddCustomTitle => 'Custom reminder time';

  @override
  String get examReminderAddCustomHint =>
      'How long before the exam starts; you can add multiple';

  @override
  String get examReminderPickerDays => 'Days';

  @override
  String get examReminderPickerHours => 'Hours';

  @override
  String get examReminderPickerMinutes => 'Minutes';

  @override
  String get examReminderCustomAlreadyAdded => 'This reminder is already added';

  @override
  String get examReminderCustomInvalid => 'Set a time greater than zero';

  @override
  String get examReminderCustomEmptyHint =>
      'No custom reminders yet — tap below to add';

  @override
  String get debugCopiedJson => 'JSON copied';

  @override
  String get liveDuringClassTimeNearest => 'Nearest time';

  @override
  String get liveDuringClassTimeTotal => 'Total time';

  @override
  String get liveCountdownTextStyleSmart => 'Smart (localized)';

  @override
  String get liveCountdownTextStyleSmartMinS => 'Smart (min/s)';

  @override
  String get liveCountdownTextStyleMinuteSecondCn =>
      'Minutes and seconds (5m19s)';

  @override
  String get liveCountdownTextStyleMinuteSecondColon => 'mm:ss (05:19)';

  @override
  String get liveCountdownTextStyleMinuteSecondMinS => 'min+s (5min19s)';

  @override
  String get liveCountdownTextStyleMinuteSecondMinSlashS => 'min/s (5min/19s)';

  @override
  String get liveCountdownTextStyleMinuteOnlyCn => 'Minutes only (5 min)';

  @override
  String get liveCountdownTextStyleMinuteOnlyMin => 'min (5min)';

  @override
  String get liveCountdownTextStyleMinuteOnlySlash => '/min (5/min)';

  @override
  String get liveCountdownTextStyleSecondOnlyCn => 'Seconds only (5 s)';

  @override
  String get liveCountdownTextStyleSecondOnlyShort => 's (5s)';

  @override
  String get liveCountdownTextStyleSecondOnlySlash => '/s (5/s)';

  @override
  String get miuiIslandLabelStyleTextOnly => 'Text only';

  @override
  String get miuiIslandLabelStyleIconAndText => 'Icon + text';

  @override
  String get miuiIslandLabelContentCourseName => 'Course name';

  @override
  String get miuiIslandLabelContentLocation => 'Room';

  @override
  String get miuiIslandLabelContentCourseNameAndLocation => 'Course + room';

  @override
  String get miuiIslandLabelFontWeightRegular => 'Regular';

  @override
  String get miuiIslandLabelFontWeightMedium => 'Medium';

  @override
  String get miuiIslandLabelFontWeightBold => 'Bold';

  @override
  String get miuiIslandLabelRenderQualityStandard => 'Standard';

  @override
  String get miuiIslandLabelRenderQualityHigh => 'High';

  @override
  String get miuiIslandLabelRenderQualityUltra => 'Ultra';

  @override
  String get miuiIslandExpandedIconAppIcon => 'App icon';

  @override
  String get miuiIslandExpandedIconCustomImage => 'Custom image';

  @override
  String get miuiIslandExpandedIconHidden => 'Hidden';

  @override
  String get liveBeforeClassQuickActionNone => 'Hidden';

  @override
  String get liveBeforeClassQuickActionSilent => 'Turn on silent mode';

  @override
  String get liveBeforeClassQuickActionDoNotDisturb => 'Turn on Do Not Disturb';

  @override
  String get courseCardVerticalAlignTop => 'Top';

  @override
  String get courseCardVerticalAlignCenter => 'Center';

  @override
  String get courseCardVerticalAlignBottom => 'Bottom';

  @override
  String get courseCardVerticalAlignSpaceEvenly => 'Space evenly';

  @override
  String get courseCardHorizontalAlignLeft => 'Left';

  @override
  String get courseCardHorizontalAlignCenter => 'Center';

  @override
  String get courseCardHorizontalAlignRight => 'Right';

  @override
  String get timetableTimeColumnWidthNarrow => 'Narrow';

  @override
  String get timetableTimeColumnWidthWide => 'Wide';

  @override
  String get timetableCourseSpacingNarrow => 'Narrow';

  @override
  String get timetableCourseSpacingWide => 'Wide';

  @override
  String get appUpdateDownloadSourceOriginal => 'GitHub original';

  @override
  String get appUpdateDownloadSourceMirror => 'Mirror';

  @override
  String get appUpdateDownloadChannelPgyer => 'Pgyer download';

  @override
  String get appUpdateDownloadChannelGithub => 'GitHub download';

  @override
  String get appUpdateDownloadChannelPgyerDescription =>
      'Fast download in China, recommended';

  @override
  String get appUpdateDownloadChannelGithubDescription => 'GitHub plus mirrors';

  @override
  String get holidayStatutoryLabel => 'Public holiday';

  @override
  String get serviceMsgImportFileUnrecognized =>
      'Import failed. The file content could not be recognized.';

  @override
  String get serviceMsgImportUseOverwriteForFullBackup =>
      'This is a full data backup. Please import using overwrite current timetable.';

  @override
  String get serviceMsgImportNoProfilesInBackup =>
      'No recoverable timetables were found in the backup file.';

  @override
  String get serviceMsgUnrecognizedMikcbDataFile =>
      'Not a recognizable mikcb data file.';

  @override
  String get serviceMsgMissingSettingsData => 'Settings data is missing.';

  @override
  String get serviceMsgUnrecognizedMikcbFullBackup =>
      'Not a recognizable mikcb full backup file.';

  @override
  String get serviceMsgMissingFullBackupData =>
      'Complete backup data is missing.';

  @override
  String get serviceMsgUseProfileBackupNotFull =>
      'Use a timetable profile backup JSON, not a full data backup.';

  @override
  String get serviceMsgUnrecognizedSyncSnapshot =>
      'Not a recognizable mikcb cloud sync snapshot.';

  @override
  String get serviceMsgMissingSyncTimetableData =>
      'Cloud sync timetable data is missing.';

  @override
  String get serviceMsgSyncSnapshotChecksumFailed =>
      'Cloud sync snapshot verification failed.';

  @override
  String get serviceMsgSyncSnapshotNoProfiles =>
      'No recoverable timetables in the cloud sync snapshot.';

  @override
  String get serviceMsgSyncSnapshotUnrecognized =>
      'Cloud sync snapshot could not be recognized.';

  @override
  String get serviceMsgTimeSchemeNotFound => 'Time scheme not found.';

  @override
  String get serviceMsgTimeSchemeConfigUnavailable =>
      'Current timetable time configuration is unavailable.';

  @override
  String get serviceMsgTimeSchemeNotFoundSelected =>
      'Selected time scheme was not found.';

  @override
  String serviceMsgTimeSchemeSectionsInsufficient(
    int startSection,
    int endSection,
  ) {
    return 'Selected time scheme does not have enough sections for sections $startSection-$endSection';
  }

  @override
  String serviceMsgSectionCountBelowUsage(int requiredMaxSection) {
    return 'Courses go to period $requiredMaxSection';
  }

  @override
  String serviceMsgSectionCountBelowUsageDetail(
    int requiredMaxSection,
    String profileName,
    String courseName,
    int dayOfWeek,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return 'Section count cannot be less than the maximum section in use (section $requiredMaxSection). In use: $profileName · $courseName (weekday $dayOfWeek sections $startSection-$endSection, $usageType)';
  }

  @override
  String get serviceMsgAtLeastOneSectionRequired =>
      'At least one section time must be kept';

  @override
  String serviceMsgSectionEndMustAfterStart(int sectionNumber) {
    return 'Section $sectionNumber end time must be later than start time. Overnight classes are not supported';
  }

  @override
  String serviceMsgSectionStartBeforePreviousEnd(int sectionNumber) {
    return 'Section $sectionNumber start time cannot be earlier than the previous section end time';
  }

  @override
  String get serviceMsgPeriodStartTimeRequired =>
      'Set the first section start time for periods that have sections.';

  @override
  String serviceMsgSectionCrossesMidnight(int sectionNumber) {
    return 'Section $sectionNumber would cross midnight. Overnight classes are not supported';
  }

  @override
  String get serviceMsgClassDurationMustPositive =>
      'Class duration must be greater than 0.';

  @override
  String get serviceMsgBreakDurationMustNonNegative =>
      'Break duration cannot be less than 0.';

  @override
  String get serviceMsgAtLeastOnePeriodSection =>
      'At least one period must have sections';

  @override
  String get serviceMsgInvalidTimeFormat => 'Time format is invalid.';

  @override
  String get serviceMsgLinkedCourseNotFound => 'Linked course was not found.';

  @override
  String get serviceMsgCourseNotFoundForDelete =>
      'Course to delete was not found.';

  @override
  String serviceMsgCourseNotScheduledWeek(int sourceWeek) {
    return 'This course is not scheduled in week $sourceWeek.';
  }

  @override
  String get serviceMsgCourseNotFoundForReschedule =>
      'Course to reschedule was not found.';

  @override
  String get serviceMsgTargetWeekOutOfRange =>
      'Target week is outside the current semester range.';

  @override
  String get serviceMsgAtLeastOneScheduleSlot =>
      'At least one class time slot must be kept.';

  @override
  String get serviceMsgCourseNameRequired => 'Course name cannot be empty.';

  @override
  String get serviceMsgBackupContentRequired =>
      'Backup content cannot be empty.';

  @override
  String get serviceMsgSpreadsheetFormatOrEncodingUnrecognized =>
      'Could not recognize spreadsheet format or encoding. Save CSV as UTF-8 and try again.';

  @override
  String serviceMsgSpreadsheetXlsxParseFailed(String error) {
    return 'Failed to parse XLSX file: $error';
  }

  @override
  String serviceMsgSpreadsheetRowWarning(int rowNumber, String message) {
    return 'Row $rowNumber: $message';
  }

  @override
  String serviceMsgSpreadsheetWakeupInsufficientColumns(
    int rowNumber,
    int columnCount,
  ) {
    return 'WakeUp format needs at least 7 columns, but row $rowNumber has only $columnCount.';
  }

  @override
  String get serviceMsgWeekdayMustBe1To7 => 'Weekday must be between 1 and 7.';

  @override
  String get serviceMsgCustomWeeksRequired => 'Weeks cannot be empty.';

  @override
  String get serviceMsgClassWeeksRequired => 'Class weeks cannot be empty.';

  @override
  String get serviceMsgStartWeekMustBeAtLeast1 =>
      'Start week must be at least 1.';

  @override
  String serviceMsgStartWeekExceedsSemester(
    int startWeek,
    int semesterWeekCount,
  ) {
    return 'Start week $startWeek exceeds semester week count $semesterWeekCount.';
  }

  @override
  String get serviceMsgEndWeekBeforeStartWeek =>
      'End week cannot be earlier than start week.';

  @override
  String get serviceMsgWeeksRangeRequired =>
      'Class weeks or start week + end week must be provided.';

  @override
  String serviceMsgFieldMustBeAtLeast1(String field) {
    return '$field must be at least 1.';
  }

  @override
  String serviceMsgFieldCannotBeLessThan(String startField, String endField) {
    return '$endField cannot be less than $startField.';
  }

  @override
  String serviceMsgSectionOutOfRange(int section, int maxSection) {
    return 'Section $section is outside the time scheme range (1-$maxSection)';
  }

  @override
  String serviceMsgFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgFieldCannotBeEmpty(String field) {
    return '$field cannot be empty.';
  }

  @override
  String serviceMsgSpreadsheetEndWeekClamped(
    int rowNumber,
    int endWeek,
    int semesterWeekCount,
  ) {
    return 'Row $rowNumber: end week $endWeek exceeds semester week count $semesterWeekCount; adjusted to $semesterWeekCount.';
  }

  @override
  String serviceMsgSpreadsheetOddEvenBoth(int rowNumber) {
    return 'Row $rowNumber: odd and even weeks cannot both be selected; treated as odd weeks.';
  }

  @override
  String get serviceMsgFieldCourseName => 'Course name';

  @override
  String get serviceMsgFieldWeekday => 'Weekday';

  @override
  String get serviceMsgFieldStartSection => 'Start section';

  @override
  String get serviceMsgFieldEndSection => 'End section';

  @override
  String get serviceMsgFieldCustomWeeks => 'Weeks';

  @override
  String get serviceMsgFieldClassWeeks => 'Class weeks';

  @override
  String get serviceMsgFieldStartWeek => 'Start week';

  @override
  String get serviceMsgFieldEndWeek => 'End week';

  @override
  String serviceMsgWeekStartInvalid(String itemName) {
    return '$itemName: week range start is invalid.';
  }

  @override
  String serviceMsgWeekRangeInvalid(String itemName) {
    return '$itemName: week range is invalid.';
  }

  @override
  String serviceMsgWeekRangeTooLarge(String itemName) {
    return '$itemName: week range is too large. Please check.';
  }

  @override
  String serviceMsgWeekTokenUnrecognized(String itemName, String token) {
    return '$itemName: unrecognized week token: $token';
  }

  @override
  String serviceMsgWeeksExceedSemesterClamped(
    String itemName,
    int semesterWeekCount,
    String weeks,
  ) {
    return '$itemName contains weeks beyond semester week count $semesterWeekCount ($weeks); excess weeks were ignored.';
  }

  @override
  String get serviceMsgAiResultNotObject =>
      'AI result is not a valid JSON object. Copy the full JSON again.';

  @override
  String serviceMsgAiSchemaMustBe(String schema) {
    return 'schema must be $schema';
  }

  @override
  String get serviceMsgAiCoursesMustBeArray => 'courses must be an array.';

  @override
  String get serviceMsgAiWarningsMustBeArray =>
      'warnings must be a string array.';

  @override
  String get serviceMsgAiWarningItemMustBeString =>
      'Each warnings item must be a string.';

  @override
  String serviceMsgAiCourseNotObject(int index) {
    return 'courses[$index] is not a valid object.';
  }

  @override
  String serviceMsgAiCourseNameEmpty(int index) {
    return 'courses[$index].name cannot be empty.';
  }

  @override
  String serviceMsgAiCourseDayOfWeekInvalid(int index) {
    return 'courses[$index].dayOfWeek must be between 1 and 7.';
  }

  @override
  String serviceMsgAiCourseStartSectionInvalid(int index) {
    return 'courses[$index].startSection must be at least 1.';
  }

  @override
  String serviceMsgAiCourseEndSectionInvalid(int index) {
    return 'courses[$index].endSection cannot be less than startSection';
  }

  @override
  String serviceMsgAiCourseCustomWeeksEmpty(int index) {
    return 'courses[$index].customWeeks cannot be empty.';
  }

  @override
  String serviceMsgAiCourseNatureInvalid(int index) {
    return 'courses[$index].courseNature must be required or elective.';
  }

  @override
  String serviceMsgAiUnknownFields(String targetName, String fields) {
    return '$targetName contains unsupported fields: $fields';
  }

  @override
  String serviceMsgAiFieldMustBeString(String field) {
    return '$field must be a string.';
  }

  @override
  String serviceMsgAiFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgAiWeekListInvalid(String itemName) {
    return '$itemName can only contain integers greater than or equal to 1.';
  }

  @override
  String serviceMsgAiWeekListTypeInvalid(String field) {
    return '$field must be an integer array or week string.';
  }

  @override
  String get serviceMsgNoReleaseAvailable =>
      'No release has been published yet.';

  @override
  String get serviceMsgNoReleaseWithPrerelease =>
      'No stable or prerelease version is available yet.';

  @override
  String serviceMsgUpdateCheckHttpFailed(int statusCode) {
    return 'Update check failed (HTTP $statusCode).';
  }

  @override
  String get serviceMsgUpdateCheckNetworkFailed =>
      'Network error. Unable to check for updates right now.';

  @override
  String get serviceMsgUpdateDownloadUrlUntrusted =>
      'Update download URL failed security validation.';

  @override
  String serviceMsgUpdateDownloadHttpFailed(int statusCode) {
    return 'Download failed (HTTP $statusCode).';
  }

  @override
  String serviceMsgUpdateOpenInstallerFailed(String detail) {
    return 'Failed to open installer: $detail';
  }

  @override
  String serviceMsgUpdateDownloadInstallError(String detail) {
    return 'Download or installation error: $detail';
  }

  @override
  String get serviceMsgInvalidUrl => 'Invalid URL.';

  @override
  String get serviceMsgUpdateAvailablePrerelease =>
      'A new prerelease version is available.';

  @override
  String get serviceMsgUpdateAvailable => 'A new version is available.';

  @override
  String get serviceMsgAlreadyLatest =>
      'You are already on the latest version.';

  @override
  String get serviceMsgShareBackupText =>
      'This is a full backup of the current timetable. Import it to restore courses and settings.';

  @override
  String get serviceMsgShareBackupSubject => 'Qingyu Timetable backup';

  @override
  String serviceMsgShareBackupSubjectNamed(String profileName) {
    return '$profileName - Qingyu Timetable backup';
  }

  @override
  String get serviceMsgShareFullBackupText =>
      'This is a full data backup containing all timetables, the active timetable, and time schemes.';

  @override
  String get serviceMsgShareFullBackupSubject =>
      'Qingyu Timetable - full data backup';

  @override
  String get serviceMsgInvalidRepositoryUrl =>
      'Repository URL format is invalid.';

  @override
  String get serviceMsgIncompleteGithubRepoUrl =>
      'GitHub repository URL is incomplete.';

  @override
  String get serviceMsgIncompleteRawGithubUrl =>
      'raw.githubusercontent.com URL is incomplete.';

  @override
  String get serviceMsgGithubOnlySupported =>
      'Only GitHub repository URLs are supported.';

  @override
  String get serviceMsgWarehouseNoSchoolsIndex =>
      'No school or tool index was found.';

  @override
  String serviceMsgWarehouseNoAdapters(String schoolName) {
    return 'No adapter information was found for $schoolName.';
  }

  @override
  String serviceMsgWarehouseFetchFailedMirror(int candidatesCount) {
    return 'Unable to read the adapter repository. Tried $candidatesCount mirror endpoints. Check your network or switch mirror in Version Update.';
  }

  @override
  String get serviceMsgWarehouseFetchFailedGithub =>
      'Unable to read the adapter repository on GitHub. Check your network or switch to a mirror in Version Update.';

  @override
  String get serviceMsgWarehouseScriptChecksumFailed =>
      'Adapter script integrity check failed: downloaded content does not match the repository\'s declared SHA-256, so execution was blocked. Refresh the school list and try again; if it keeps happening, report the adapter to qingyu_warehouse.';

  @override
  String get serviceMsgManualInputCaptcha =>
      'Enter the captcha manually, then tap Continue.';

  @override
  String get serviceMsgManualInputPassword =>
      'Enter the password manually. If it was auto-filled, tap Continue.';

  @override
  String get serviceMsgMacroNoSteps => 'No recorded steps.';

  @override
  String get serviceMsgMacroUserCancelled => 'Cancelled by user.';

  @override
  String serviceMsgMacroStepFailed(
    int stepIndex,
    int totalSteps,
    String detail,
  ) {
    return 'Step $stepIndex/$totalSteps failed: $detail';
  }

  @override
  String get serviceMsgMacroNavigateUrlEmpty => 'Navigation URL is empty.';

  @override
  String serviceMsgMacroNavigateUrlInvalid(String url) {
    return 'Invalid URL: $url';
  }

  @override
  String get serviceMsgMacroFillSelectorEmpty =>
      'Fill-field selector is empty.';

  @override
  String serviceMsgMacroElementNotFound(String selector) {
    return 'Element not found: $selector';
  }

  @override
  String get serviceMsgMacroClickSelectorEmpty => 'Click selector is empty.';

  @override
  String get serviceMsgMacroUrlPatternEmpty => 'URL pattern is empty.';

  @override
  String get serviceMsgMacroWaitSelectorEmpty => 'Wait selector is empty.';

  @override
  String get serviceMsgMacroManualInputDefault => 'Manual action required.';

  @override
  String serviceMsgMacroPollTimeout(
    String stepLabel,
    int timeoutSeconds,
    String lastError,
  ) {
    return '$stepLabel timed out (${timeoutSeconds}s)$lastError';
  }

  @override
  String get serviceMsgMacroReplayNavigate => 'Navigating…';

  @override
  String get serviceMsgMacroReplayFillField => 'Filling form…';

  @override
  String get serviceMsgMacroReplayClick => 'Clicking…';

  @override
  String get serviceMsgMacroReplayWaitUrl => 'Waiting for navigation…';

  @override
  String get serviceMsgMacroReplayWaitSelector => 'Waiting for page element…';

  @override
  String get serviceMsgMacroReplayWaitManual => 'Waiting for user action…';

  @override
  String get serviceMsgMacroReplayExecuteScript => 'Running import script…';

  @override
  String get serviceMsgMacroReplayDelay => 'Waiting…';

  @override
  String serviceMsgMacroReplayFailed(String detail) {
    return 'Failed: $detail';
  }

  @override
  String serviceMsgMacroReplayPaused(String reason) {
    return 'Waiting for manual action: $reason';
  }

  @override
  String serviceMsgSupportDonorsLoadFailed(String detail) {
    return 'Failed to load supporters list: $detail';
  }

  @override
  String serviceMsgStatisticsShareFailed(String detail) {
    return 'Share failed: $detail';
  }

  @override
  String get serviceMsgAuthFailed => 'Invalid username or password.';

  @override
  String get serviceMsgAccessDenied => 'Access denied.';

  @override
  String get serviceMsgCertificateError => 'Certificate validation failed.';

  @override
  String get serviceMsgConnectionTimeout => 'Connection timed out.';

  @override
  String get serviceMsgConnectionFailed => 'Could not connect to the server.';

  @override
  String get serviceMsgInvalidResponse => 'Invalid server response.';

  @override
  String get serviceMsgSyncFailed => 'Sync failed.';

  @override
  String get serviceMsgUsageTypeOverride => 'override time scheme';

  @override
  String get serviceMsgUsageTypeProfile => 'profile main time scheme';

  @override
  String get dataTransferProfileShareText =>
      'This is a full backup of the current timetable from Qingyu Timetable. Import it to restore courses and settings.';

  @override
  String get dataTransferProfileShareSubject => 'Qingyu Timetable backup';

  @override
  String dataTransferProfileShareSubjectNamed(String profileName) {
    return '$profileName - Qingyu Timetable backup';
  }

  @override
  String get dataTransferFullBackupShareText =>
      'This is a full data backup from Qingyu Timetable, including all timetables, the active timetable, and time schemes.';

  @override
  String get dataTransferFullBackupShareSubject =>
      'Qingyu Timetable - Full data backup';

  @override
  String courseWeekCustomDescription(String weeks) {
    return 'Weeks $weeks';
  }

  @override
  String courseWeekRangeDescription(int startWeek, int endWeek, String mode) {
    return 'Weeks $startWeek-$endWeek$mode';
  }

  @override
  String get courseWeekOddModeSuffix => ' odd weeks';

  @override
  String get courseWeekEvenModeSuffix => ' even weeks';

  @override
  String courseWeekSuspensionDescription(String weeks) {
    return 'Suspended weeks $weeks';
  }

  @override
  String get courseWeekListSeparator => ', ';

  @override
  String holidayLogMemoryCacheHit(int year, int count) {
    return '$year: memory cache hit ($count entries), refreshing in background…';
  }

  @override
  String holidayLogLocalCacheHit(int year, int count) {
    return '$year: local cache hit ($count entries), refreshing in background…';
  }

  @override
  String holidayLogNoCacheFetching(int year) {
    return '$year: no cache, fetching remote data…';
  }

  @override
  String holidayLogRemoteSuccess(int year, int count) {
    return '$year: remote fetch succeeded ($count entries), cached';
  }

  @override
  String holidayLogRemoteFailedBuiltin(int year) {
    return '$year: remote fetch failed, using built-in fallback';
  }

  @override
  String holidayLogBuiltinLoaded(int year, int count) {
    return '$year: loaded built-in data ($count entries)';
  }

  @override
  String holidayLogBackgroundSuccess(int year, int count) {
    return '$year: background update succeeded ($count entries), cache updated';
  }

  @override
  String holidayLogBackgroundNoData(int year) {
    return '$year: background update returned no new data';
  }

  @override
  String get holidayLogPrimaryApiFailed =>
      'Primary API failed, trying fallback API…';

  @override
  String holidayLogRequesting(String uri) {
    return 'Requesting $uri …';
  }

  @override
  String holidayLogPrimaryApiStatus(int statusCode) {
    return 'Primary API responded $statusCode, skipping';
  }

  @override
  String holidayLogPrimaryApiError(String message) {
    return 'Primary API error: $message';
  }

  @override
  String holidayLogPrimaryApiException(String error) {
    return 'Primary API exception: $error';
  }

  @override
  String holidayLogPrimaryApiParsing(int count) {
    return 'Primary API returned $count raw entries, parsing…';
  }

  @override
  String get holidayLogNoValidEntries =>
      'No valid entries after parsing, skipping';

  @override
  String holidayLogFallbackApiStatus(int statusCode) {
    return 'Fallback API responded $statusCode, skipping';
  }

  @override
  String get holidayLogFallbackApiError => 'Fallback API returned an error';

  @override
  String holidayLogFallbackApiParsing(int count) {
    return 'Fallback API returned $count raw entries, parsing…';
  }

  @override
  String holidayLogFallbackApiException(String error) {
    return 'Fallback API exception: $error';
  }

  @override
  String get holidayNameNewYear => 'New Year';

  @override
  String get holidayNameLaborDay => 'Labor Day';

  @override
  String get holidayNameNationalDay => 'National Day';

  @override
  String get holidayNameSpringFestival => 'Spring Festival';

  @override
  String get holidayNameQingming => 'Qingming Festival';

  @override
  String get holidayNameDragonBoat => 'Dragon Boat Festival';

  @override
  String get holidayNameMidAutumn => 'Mid-Autumn Festival';

  @override
  String macroReplayStatusFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String macroReplayStatusPaused(String reason) {
    return 'Waiting for manual action: $reason';
  }

  @override
  String get macroReplayStepNavigating => 'Navigating…';

  @override
  String get macroReplayStepFilling => 'Filling form…';

  @override
  String get macroReplayStepClicking => 'Clicking…';

  @override
  String get macroReplayStepWaitUrl => 'Waiting for navigation…';

  @override
  String get macroReplayStepWaitSelector => 'Waiting for page element…';

  @override
  String get macroReplayStepWaitManual => 'Waiting for user action';

  @override
  String get macroReplayStepExecuteScript => 'Running import script…';

  @override
  String get macroReplayStepDelay => 'Waiting…';

  @override
  String get macroReplayAcceleratedFallbackTip =>
      'Quick path failed; retrying with the full recorded steps…';

  @override
  String get macroReplayNoSteps => 'No recorded steps';

  @override
  String get macroReplayUserCancelled => 'Cancelled by user';

  @override
  String macroReplayStepFailed(int current, int total, String error) {
    return 'Step $current/$total failed: $error';
  }

  @override
  String get macroReplayEmptyNavigateUrl => 'Navigation URL is empty';

  @override
  String macroReplayInvalidUrl(String url) {
    return 'Invalid URL: $url';
  }

  @override
  String get macroReplayEmptyFillSelector => 'Fill selector is empty';

  @override
  String macroReplayFieldNotFound(String selector) {
    return 'Form field not found: $selector';
  }

  @override
  String get macroReplayEmptyClickSelector => 'Click selector is empty';

  @override
  String macroReplayClickNotFound(String selector) {
    return 'Click target not found: $selector';
  }

  @override
  String macroReplayWaitUrlPattern(String pattern) {
    return 'Waiting for URL match: $pattern';
  }

  @override
  String get macroReplayEmptyWaitSelector => 'Wait selector is empty';

  @override
  String macroReplayWaitSelector(String selector) {
    return 'Waiting for element: $selector';
  }

  @override
  String get macroReplayManualActionRequired => 'Manual action required';

  @override
  String macroReplayNavigateTo(String url) {
    return 'Navigate to $url';
  }

  @override
  String get macroReplayWaitPageLoad => 'Waiting for page load';

  @override
  String get macroReplayWaitDomReady => 'Waiting for DOM ready';

  @override
  String get hyperosShowcaseTitle => 'HyperOS UI Kit';

  @override
  String get hyperosShowcaseSectionSummary => 'Summary card';

  @override
  String get hyperosShowcaseKitSubtitle => 'mikcb HyperOS-style components';

  @override
  String get hyperosShowcaseSectionTags => 'Tags / Accordion / Hints';

  @override
  String get hyperosShowcaseAccordionSection1 => 'Section 1';

  @override
  String get hyperosShowcaseAccordionSection1Body =>
      'Content shown after expanding';

  @override
  String get hyperosShowcaseAccordionSection2 => 'Section 2';

  @override
  String get hyperosShowcaseAccordionSection2Body =>
      'Collapsible group replacing FAccordion';

  @override
  String get hyperosShowcaseSectionNavRows => 'List rows · Navigation';

  @override
  String get hyperosShowcaseNavRowWithIcon => 'With icon';

  @override
  String get hyperosShowcaseNavRowNoIconSubtitle => 'No leading tinted icon';

  @override
  String get hyperosShowcaseNavRowDetails => 'Details';

  @override
  String get hyperosShowcaseSectionSwitchRows =>
      'List rows · Switch / Destructive';

  @override
  String get hyperosShowcaseSwitchRowSubtitle => 'Switch row with icon';

  @override
  String get hyperosShowcaseSwitchRowPlain => 'Plain switch row';

  @override
  String get hyperosShowcaseSectionChoiceRows =>
      'List rows · Radio / Select / Date';

  @override
  String get hyperosShowcaseOptionA => 'Option A';

  @override
  String get hyperosShowcaseOptionB => 'Option B';

  @override
  String get hyperosShowcaseOptionC => 'Option C';

  @override
  String get hyperosShowcaseSelectSizeTitle => 'Choose size';

  @override
  String get hyperosShowcaseSizeSmall => 'S';

  @override
  String get hyperosShowcaseSizeMedium => 'M';

  @override
  String get hyperosShowcaseSizeLarge => 'L';

  @override
  String get hyperosShowcaseSectionControls => 'Control card';

  @override
  String get hyperosShowcaseControlsSubtitle => 'Slider, segments, buttons';

  @override
  String get hyperosShowcaseSegmentLeft => 'Left';

  @override
  String get hyperosShowcaseSegmentRight => 'Right';

  @override
  String get hyperosShowcaseSectionInput => 'Input';

  @override
  String get hyperosShowcaseInputHint => 'Enter content';

  @override
  String get hyperosShowcaseInputCardLabel => 'Input in card';

  @override
  String get hyperosShowcaseSectionPicker => 'Wheel picker';

  @override
  String hyperosShowcasePickerCurrentValue(int value) {
    return 'Current value: $value';
  }

  @override
  String get hyperosShowcaseSectionInline => 'Inline basics';

  @override
  String get hyperosShowcaseCheckboxSubtitle => 'Multi-select preference row';

  @override
  String get hyperosShowcaseSectionNavActions => 'Navigation & actions';

  @override
  String get hyperosShowcaseTooltipButton => 'Button with tooltip';

  @override
  String get hyperosShowcaseSectionProgress => 'Progress & refresh';

  @override
  String get hyperosShowcaseSectionColorChip => 'ColorChip';

  @override
  String get hyperosShowcaseSectionNavBar => 'HyperosNavigationBar';

  @override
  String get hyperosShowcaseNavHome => 'Home';

  @override
  String get hyperosShowcaseNavTimetable => 'Timetable';

  @override
  String get hyperosShowcaseNavSettings => 'Settings';

  @override
  String get hyperosShowcaseSectionEmpty => 'Empty / Divider / Decoration';

  @override
  String get hyperosShowcaseEmptySubtitle => 'Placeholder when list is empty';

  @override
  String get hyperosShowcaseActionButton => 'Action';

  @override
  String get hyperosShowcaseDividerRowTitle =>
      'Second row (indented divider above)';

  @override
  String get hyperosShowcaseSectionPressable => 'HyperosPressableRow';

  @override
  String get hyperosShowcaseSectionShell => 'Page shell';

  @override
  String get hyperosShowcaseRootPageDetails => 'Root page without back button';

  @override
  String get hyperosShowcaseSubpageSubtitle =>
      'Current page is Subpage + HyperosListView';

  @override
  String get hyperosShowcaseAlreadyInSubpage => 'Already in Subpage';

  @override
  String get hyperosShowcaseSectionFrosted => 'Frosted header · scroll physics';

  @override
  String get hyperosShowcaseSectionFeedback => 'Feedback · overlays';

  @override
  String get hyperosShowcaseSectionIconColors => 'HyperosIconColors';

  @override
  String get hyperosShowcaseFooterNote =>
      'Visible on the settings home page in non-release builds for component QA';

  @override
  String get hyperosShowcaseUndoAction => 'Undo';

  @override
  String get hyperosShowcaseDialogMessage => 'System-style dialog example';

  @override
  String get hyperosShowcaseConfirmTitle => 'Confirm action';

  @override
  String get hyperosShowcaseConfirmed => 'Confirmed';

  @override
  String get hyperosShowcaseToastDescription =>
      'With icon and subtitle, same as app toast';

  @override
  String get hyperosShowcaseMenuCopy => 'Copy';

  @override
  String get hyperosShowcaseMenuShare => 'Share';

  @override
  String get hyperosShowcaseMenuDelete => 'Delete';

  @override
  String get hyperosShowcaseRefreshDone => 'Refresh complete';

  @override
  String get hyperosShowcaseSearchTooltip => 'Search';

  @override
  String get hyperosShowcaseRootShellLabel => 'Root shell';

  @override
  String get hyperosShowcasePushSubtitle => 'Enter via HyperosNavigation.push';

  @override
  String get hyperosShowcaseSampleText => 'Sample text';

  @override
  String courseImportQuickImportDescription(
    String schoolName,
    String adapterName,
  ) {
    return 'Quick import $schoolName $adapterName';
  }

  @override
  String get courseImportScriptNoCourses =>
      'Import script returned no course data';

  @override
  String get courseImportScriptFailed => 'Script execution failed';

  @override
  String get courseImportRecordingStatus => 'Recording… tap Stop to finish';

  @override
  String get courseImportRecordingStartedTip =>
      'Recording started. Continue through the academic portal as usual';

  @override
  String get courseImportAutoRecordingStartedTip =>
      'Recording your steps in the background. You can save them as quick import after a successful import';

  @override
  String get courseImportRecordingEmptyStatus => 'No actions recorded';

  @override
  String get courseImportRecordingEmptyTip => 'No actions recorded';

  @override
  String get courseImportSaveRecordingTitle => 'Save recording';

  @override
  String courseImportSaveRecordingMessage(int count) {
    return 'Recorded $count steps. Save as quick import?';
  }

  @override
  String courseImportSaveAutoRecordingMessage(int count) {
    return 'Import succeeded. Recorded $count steps. Save this path for next quick import?';
  }

  @override
  String courseImportRecordingSavedStatus(int count) {
    return 'Recording saved ($count steps)';
  }

  @override
  String get courseImportWeekNotProvided => 'Weeks not provided';

  @override
  String get courseImportLocationNotFilled => 'Location not filled';

  @override
  String courseImportPreviewLine(
    String weekday,
    int startSection,
    int endSection,
    String name,
    String location,
    String weekText,
  ) {
    return 'Weekday $weekday Sections $startSection-$endSection  $name  $location  Weeks: $weekText';
  }

  @override
  String courseImportCalendarWeekLabel(int week) {
    return 'Calendar week $week';
  }

  @override
  String get courseImportTermStartDateTitle => 'Term start date';

  @override
  String get courseImportFirstWeekMappingLabel =>
      'Which calendar week is timetable week 1';

  @override
  String get courseImportFirstWeekMappingSubtitle =>
      'If week 1 has no classes, choose week 2; if weeks 1-2 have none, choose week 3.';

  @override
  String get courseImportFirstWeekNoShift =>
      'Import will treat timetable week 1 as calendar week 1.';

  @override
  String courseImportFirstWeekShifted(int weeks, int targetWeek) {
    return 'Import will shift all course weeks by $weeks so timetable week 1 lands on calendar week $targetWeek.';
  }

  @override
  String get courseImportContinueAction => 'Continue import';

  @override
  String get courseImportUpdateRecommendedAction =>
      'Update timetable (recommended)';

  @override
  String get courseImportOverwriteAction => 'Overwrite import';

  @override
  String get courseImportSectionCountInsufficientTitle =>
      'Not enough sections in time scheme';

  @override
  String courseImportSectionCountInsufficientMessage(
    int current,
    int required,
  ) {
    return 'Current time scheme has only $current sections, but import needs up to section $required. Auto-fill and continue?';
  }

  @override
  String get courseImportAutoFillAndImportAction => 'Auto-fill and import';

  @override
  String get courseImportPortalUrlTitle => 'Enter academic portal URL';

  @override
  String get courseImportPortalUrlSaveContinue => 'Save and continue';

  @override
  String get courseImportPortalUrlLabel => 'Portal URL';

  @override
  String get courseImportPortalUrlHint =>
      'Saved URL will be reused next time. You can also edit it on the adapter info page';

  @override
  String get courseImportPortalUrlInvalid => 'Invalid login URL format';

  @override
  String get logAppLoggerInitialized => 'App log service initialized';

  @override
  String get logPrivacyConsentUpdated => 'Privacy consent status updated';

  @override
  String get logAppLogRecordingEnabled => 'App log recording enabled';

  @override
  String get logAppLogRecordingRemainsEnabled =>
      'App log recording remains enabled';

  @override
  String get logStartupFlowStarted => 'Startup flow started';

  @override
  String get logStartupFlowCompletedNoOnboarding =>
      'Startup flow completed (no onboarding)';

  @override
  String get logStartupFlowCompletedAfterGuide =>
      'Startup flow completed (after guide)';

  @override
  String get logStartupFlowFailed =>
      'Startup flow failed; entering degraded mode';

  @override
  String get logAppLifecycleChanged => 'App lifecycle changed';

  @override
  String get logNavigatorRouteReplaced => 'Navigation route replaced';

  @override
  String get logNavigatorRouteChanged => 'Navigation route changed';

  @override
  String get logAppLogsDefaultMigrated =>
      'App log recording enabled by default during migration';

  @override
  String get logTimetableLoadSettingsFailed =>
      'Failed to load timetable settings';

  @override
  String get logTimetableLoadCoursesFailed => 'Failed to load course data';

  @override
  String get logTimetableLoadCurrentWeekFailed => 'Failed to load current week';

  @override
  String get logHomeWidgetPinSupportFailed =>
      'Failed to check home widget pin support';

  @override
  String get logHomeWidgetPinRequestFailed =>
      'Failed to request home widget pin';

  @override
  String get logHomeWidgetSyncFailed => 'Failed to sync home widget snapshot';

  @override
  String get logHomeWidgetClearFailed => 'Failed to clear home widget snapshot';

  @override
  String get logHomeWidgetScheduleFailed =>
      'Failed to schedule home widget refresh';

  @override
  String get logMiuiLiveInitializeFailed =>
      'Failed to initialize MIUI Live Island channel';

  @override
  String get logMiuiLiveOpenPromotedSettingsFailed =>
      'Failed to open Live Island permission settings';

  @override
  String get logMiuiLiveOpenNotificationSettingsFailed =>
      'Failed to open notification settings';

  @override
  String get logMiuiLiveOpenAutostartSettingsFailed =>
      'Failed to open autostart settings';

  @override
  String get logMiuiLiveOpenBatterySettingsFailed =>
      'Failed to open battery optimization settings';

  @override
  String get logMiuiLiveOpenAccessibilitySettingsFailed =>
      'Failed to open accessibility settings';

  @override
  String get logMiuiLiveHideFromRecentsFailed =>
      'Failed to update hide-from-recents';

  @override
  String get logLiveUpdateStartFailed =>
      'Failed to start Live Island from Flutter';

  @override
  String get logLiveUpdateStopFailed =>
      'Failed to stop Live Island from Flutter';

  @override
  String get logLiveUpdateDebugStatusFailed =>
      'Failed to get native Live Island debug status';

  @override
  String get logLiveUpdateSnapshotSyncFailed =>
      'Failed to sync Live Island timetable snapshot';

  @override
  String get logLiveUpdateSnapshotClearFailed =>
      'Failed to clear Live Island timetable snapshot';

  @override
  String get logLiveUpdateSuspendTriggersFailed =>
      'Failed to suspend Live Island schedule triggers';

  @override
  String get logLanEditAuthFailed => 'LAN edit: authentication failed';

  @override
  String get logLanEditCourseCreated => 'LAN edit: course created';

  @override
  String get logLanEditCourseUpdated => 'LAN edit: course updated';

  @override
  String get logLanEditCourseDeleted => 'LAN edit: course deleted';

  @override
  String get logLanEditCourseGroupSaved => 'LAN edit: course group saved';

  @override
  String get logLanEditMergeImported => 'LAN edit: merge backup imported';

  @override
  String get logLanEditCoursesBatchDeleted => 'LAN edit: courses batch deleted';

  @override
  String get logLanEditCurrentWeekSet => 'LAN edit: current week set';

  @override
  String get logLanEditProfileSwitched =>
      'LAN edit: timetable profile switched';

  @override
  String get logLanEditSpreadsheetImported => 'LAN edit: spreadsheet imported';

  @override
  String get logLanEditSessionStarted => 'LAN edit: session started';

  @override
  String get logLanEditSessionStopped => 'LAN edit: session stopped';

  @override
  String get logLiveUpdateTestRequested =>
      'User requested manual Live Island test notification';

  @override
  String get logLiveUpdateTestNoSelection =>
      'Manual Live Island test: no course available';

  @override
  String get logLiveUpdateTestSelectionReady =>
      'Manual Live Island test: target course resolved';

  @override
  String get logLiveUpdateTestSuspendSync =>
      'Manual Live Island test: scheduled sync paused temporarily';

  @override
  String get logLiveUpdateTestStarting =>
      'Manual Live Island test: starting native Live Island';

  @override
  String get logLiveUpdateTestStarted =>
      'Manual Live Island test: native Live Island requested successfully';

  @override
  String get logLiveUpdateTestFailed =>
      'Manual Live Island test: failed before Live Island appeared';

  @override
  String logLiveUpdateSettingsSynced(
    String beforeClass,
    String duringClass,
    String beforeEnd,
    String promote,
    String notification,
    String countdown,
    String courseName,
    String location,
  ) {
    return 'Flutter Live Island settings synced: beforeClass=$beforeClass, duringClass=$duringClass, beforeEnd=$beforeEnd, promote=$promote, notification=$notification, countdown=$countdown, courseName=$courseName, location=$location';
  }

  @override
  String get logFieldSource => 'source';

  @override
  String get logFieldPlatform => 'platform';

  @override
  String get logFieldVersion => 'version';

  @override
  String get logFieldBuildNumber => 'build Number';

  @override
  String get logFieldLoggingEnabled => 'logging Enabled';

  @override
  String get logFieldPrivacyAccepted => 'privacy Accepted';

  @override
  String get logFieldAccepted => 'accepted';

  @override
  String get logFieldPrevious => 'previous';

  @override
  String get logFieldTruncated => 'truncated';

  @override
  String get logFieldTruncatedHint => 'truncated Hint';

  @override
  String get logFieldThrowable => 'throwable';

  @override
  String get logFieldExtras => 'extras';

  @override
  String get logFieldContext => 'context';

  @override
  String get logFieldError => 'error';

  @override
  String get logFieldBrand => 'brand';

  @override
  String get logFieldManufacturer => 'manufacturer';

  @override
  String get logFieldModel => 'model';

  @override
  String get logFieldSdkInt => 'sdk Int';

  @override
  String get logFieldVersionName => 'version Name';

  @override
  String get logFieldChannel => 'channel';

  @override
  String get logFieldHasNotificationPermission => 'has Notification Permission';

  @override
  String get logFieldHasPromotedPermissionDeclared =>
      'has Promoted Permission Declared';

  @override
  String get logFieldCanPostPromotedNotifications =>
      'can Post Promoted Notifications';

  @override
  String get logFieldIgnoringBatteryOptimizations =>
      'ignoring Battery Optimizations';

  @override
  String get logFieldKeepAliveAccessibilityEnabled =>
      'keep Alive Accessibility Enabled';

  @override
  String get logFieldHideFromRecentsEnabled => 'hide From Recents Enabled';

  @override
  String get logFieldTaskRemovedRecently => 'task Removed Recently';

  @override
  String get logFieldLastTaskRemovedAt => 'last Task Removed At';

  @override
  String get logFieldProcessImportance => 'process Importance';

  @override
  String get logFieldAutoStartStatus => 'auto Start Status';

  @override
  String get logFieldLiveEnableBeforeClass => 'live Enable Before Class';

  @override
  String get logFieldLiveEnableDuringClass => 'live Enable During Class';

  @override
  String get logFieldLiveEnableBeforeEnd => 'live Enable Before End';

  @override
  String get logFieldLivePromoteDuringClass => 'live Promote During Class';

  @override
  String get logFieldLiveShowDuringClassNotification =>
      'live Show During Class Notification';

  @override
  String get logFieldLiveShowCountdown => 'live Show Countdown';

  @override
  String get logFieldLiveShowStageText => 'live Show Stage Text';

  @override
  String get logFieldLiveShowCourseName => 'live Show Course Name';

  @override
  String get logFieldLiveShowLocation => 'live Show Location';

  @override
  String get logFieldLiveUseShortName => 'live Use Short Name';

  @override
  String get logFieldLiveHidePrefixText => 'live Hide Prefix Text';

  @override
  String get logFieldLiveDuringClassTimeDisplayMode =>
      'live During Class Time Display Mode';

  @override
  String get logFieldLiveEnableMiuiIslandLabelImage =>
      'live Enable Miui Island Label Image';

  @override
  String get logFieldLiveMiuiIslandLabelStyle => 'live Miui Island Label Style';

  @override
  String get logFieldLiveMiuiIslandLabelContent =>
      'live Miui Island Label Content';

  @override
  String get logFieldLiveMiuiIslandLabelFontColor =>
      'live Miui Island Label Font Color';

  @override
  String get logFieldLiveMiuiIslandLabelFontWeight =>
      'live Miui Island Label Font Weight';

  @override
  String get logFieldLiveMiuiIslandLabelRenderQuality =>
      'live Miui Island Label Render Quality';

  @override
  String get logFieldLiveMiuiIslandLabelFontSize =>
      'live Miui Island Label Font Size';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetX =>
      'live Miui Island Label Offset X';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetY =>
      'live Miui Island Label Offset Y';

  @override
  String get logFieldLiveMiuiIslandExpandedIconMode =>
      'live Miui Island Expanded Icon Mode';

  @override
  String get logFieldLiveShowBeforeClassMinutes =>
      'live Show Before Class Minutes';

  @override
  String get logFieldLiveClassReminderStartMinutes =>
      'live Class Reminder Start Minutes';

  @override
  String get logFieldLiveEndSecondsCountdownThreshold =>
      'live End Seconds Countdown Threshold';

  @override
  String get logFieldState => 'state';

  @override
  String get logFieldRoute => 'route';

  @override
  String get logFieldPreviousRoute => 'previous Route';

  @override
  String get logFieldProfileId => 'profile Id';

  @override
  String get logFieldReason => 'reason';

  @override
  String get logFieldClientIp => 'client Ip';

  @override
  String get logFieldPort => 'port';

  @override
  String get logFieldCourseName => 'course Name';

  @override
  String get logFieldStage => 'stage';

  @override
  String get logFieldFrom => 'from';

  @override
  String get logFieldCurrentWeek => 'current Week';

  @override
  String get logFieldWeekday => 'weekday';

  @override
  String get logFieldUntilMillis => 'until Millis';

  @override
  String get logFieldStartAtMillis => 'start At Millis';

  @override
  String get logFieldMergedCourseCount => 'merged Course Count';

  @override
  String get logFieldDeletedCount => 'deleted Count';

  @override
  String get logFieldRequested => 'requested';

  @override
  String get logFieldTarget => 'target';

  @override
  String get logFieldCount => 'count';

  @override
  String get logFieldValue => 'value';

  @override
  String get logFieldSnapshotLength => 'snapshot Length';

  @override
  String get logFieldStoredSnapshotVersion => 'stored Snapshot Version';

  @override
  String get logFieldIntentIsNull => 'intent Is Null';

  @override
  String get logFieldAction => 'action';

  @override
  String get logFieldStep => 'step';

  @override
  String get logCatAppLoggerInitialized => 'app log: ger initialized';

  @override
  String get logCatPrivacyConsentUpdated => 'privacy consent updated';

  @override
  String get logCatAppLogRecordingEnabled => 'app log: recording enabled';

  @override
  String get logCatStartupFlowStarted => 'startup: started';

  @override
  String get logCatStartupFlowCompleted => 'startup: completed';

  @override
  String get logCatStartupFlowFailed => 'startup: failed';

  @override
  String get logCatAppLifecycleStateChanged => 'app lifecycle state changed';

  @override
  String get logCatRoutePushed => 'route pushed';

  @override
  String get logCatRoutePopped => 'route popped';

  @override
  String get logCatRouteReplaced => 'route replaced';

  @override
  String get logCatFlutterFrameworkError => 'flutter framework error';

  @override
  String get logCatFlutterPlatformError => 'flutter platform error';

  @override
  String get logCatFlutterZoneError => 'flutter zone error';

  @override
  String get logCatAppLogsDefaultMigrated => 'app log: s default migrated';

  @override
  String get logCatTimetableLoadSettingsFailed =>
      'timetable: load settings failed';

  @override
  String get logCatTimetableLoadCoursesFailed =>
      'timetable: load courses failed';

  @override
  String get logCatTimetableLoadCurrentWeekFailed =>
      'timetable: load current week failed';

  @override
  String get logCatHomeWidgetPinSupportFailed =>
      'home widget: pin support failed';

  @override
  String get logCatHomeWidgetPinRequestFailed =>
      'home widget: pin request failed';

  @override
  String get logCatHomeWidgetSyncFailed => 'home widget: sync failed';

  @override
  String get logCatHomeWidgetClearFailed => 'home widget: clear failed';

  @override
  String get logCatHomeWidgetScheduleFailed => 'home widget: schedule failed';

  @override
  String get logCatMiuiLiveInitializeFailed => 'live island: initialize failed';

  @override
  String get logCatMiuiLiveOpenPromotedSettingsFailed =>
      'live island: open promoted settings failed';

  @override
  String get logCatMiuiLiveOpenNotificationSettingsFailed =>
      'live island: open notification settings failed';

  @override
  String get logCatMiuiLiveOpenAutostartSettingsFailed =>
      'live island: open autostart settings failed';

  @override
  String get logCatMiuiLiveOpenBatterySettingsFailed =>
      'live island: open battery settings failed';

  @override
  String get logCatMiuiLiveOpenAccessibilitySettingsFailed =>
      'live island: open accessibility settings failed';

  @override
  String get logCatMiuiLiveHideFromRecentsFailed =>
      'live island: hide from recents failed';

  @override
  String get logCatLiveUpdateFlutterInitializeFailed =>
      'live island: flutter initialize failed';

  @override
  String get logCatLiveUpdateStartFailed => 'live island: start failed';

  @override
  String get logCatLiveUpdateStopFailed => 'live island: stop failed';

  @override
  String get logCatLiveUpdateDebugStatusFailed =>
      'live island: debug status failed';

  @override
  String get logCatLiveUpdateSettingsSynced => 'live island: settings synced';

  @override
  String get logCatLiveUpdateSnapshotSyncFailed =>
      'live island: snapshot sync failed';

  @override
  String get logCatLiveUpdateSnapshotClearFailed =>
      'live island: snapshot clear failed';

  @override
  String get logCatLanEditAuthFailed => 'lan edit auth failed';

  @override
  String get logCatLanEditCourseCreated => 'lan edit course created';

  @override
  String get logCatLanEditCourseUpdated => 'lan edit course updated';

  @override
  String get logCatLanEditCourseDeleted => 'lan edit course deleted';

  @override
  String get logCatLanEditCourseGroupSaved => 'lan edit course group saved';

  @override
  String get logCatLanEditMergeImported => 'lan edit merge imported';

  @override
  String get logCatLanEditCoursesBatchDeleted =>
      'lan edit courses batch deleted';

  @override
  String get logCatLanEditCurrentWeekSet => 'lan edit current week set';

  @override
  String get logCatLanEditSpreadsheetImported =>
      'lan edit spreadsheet imported';

  @override
  String get logCatLanEditSessionStarted => 'lan edit session started';

  @override
  String get logCatLanEditSessionStopped => 'lan edit session stopped';

  @override
  String get logCatLiveUpdateTestRequested => 'live island: test requested';

  @override
  String get logCatLiveUpdateTestNoSelection =>
      'live island: test no selection';

  @override
  String get logCatLiveUpdateTestSelectionReady =>
      'live island: test selection ready';

  @override
  String get logCatLiveUpdateTestSuspendSync =>
      'live island: test suspend sync';

  @override
  String get logCatLiveUpdateTestStarting => 'live island: test starting';

  @override
  String get logCatLiveUpdateTestStarted => 'live island: test started';

  @override
  String get logCatLiveUpdateTestFailed => 'live island: test failed';

  @override
  String get logCatLiveUpdateSnapshotSettings =>
      'live island: snapshot settings';

  @override
  String get logCatLiveUpdateSnapshotSynced => 'live island: snapshot synced';

  @override
  String get logCatLiveUpdateSnapshotCleared => 'live island: snapshot cleared';

  @override
  String get logCatLiveUpdateAlarmTriggered => 'live island: alarm triggered';

  @override
  String get logCatLiveUpdateSchedulerResume => 'live island: scheduler resume';

  @override
  String get logCatLiveUpdateRescheduleHoliday =>
      'live island: reschedule holiday';

  @override
  String get logCatLiveUpdateRescheduleActive =>
      'live island: reschedule active';

  @override
  String get logCatLiveUpdateRescheduleScheduled =>
      'live island: reschedule scheduled';

  @override
  String get logCatLiveUpdateSnapshotParseFailed =>
      'live island: snapshot parse failed';

  @override
  String get logCatLiveUpdateSnapshotInvalidatedAfterUpgrade =>
      'live island: snapshot invalidated after upgrade';

  @override
  String get logCatLiveUpdatePayloadSelected => 'live island: payload selected';

  @override
  String get logCatLiveUpdateSchedulerStartFailed =>
      'live island: scheduler start failed';

  @override
  String get logCatLiveUpdateStartRequested => 'live island: start requested';

  @override
  String get logCatLiveUpdateStopRequested => 'live island: stop requested';

  @override
  String get logCatLiveUpdateServiceMissingPayload =>
      'live island: service missing payload';

  @override
  String get logCatLiveUpdateServiceStarted => 'live island: service started';

  @override
  String get logCatLiveUpdateServiceStartFailed =>
      'live island: service start failed';

  @override
  String get logCatLiveUpdateTaskRemoved => 'live island: task removed';

  @override
  String get logCatLiveUpdateTaskRemovedResumed =>
      'live island: task removed resumed';

  @override
  String get logCatLiveUpdateBeforeClassQuickAction =>
      'live island: before class quick action';

  @override
  String get logCatLiveUpdateBeforeClassQuickActionRestored =>
      'live island: before class quick action restored';

  @override
  String get logCatLiveUpdateStatusBarDismissed =>
      'live island: status bar dismissed';

  @override
  String get logCatLiveUpdateNotPromoted => 'live island: not promoted';

  @override
  String get logCatLiveUpdatePromotedNotShown =>
      'live island: promoted not shown';

  @override
  String get logCatLiveUpdateServiceStopped => 'live island: service stopped';

  @override
  String get logCatKeepAliveAccessibilityConnected =>
      'keep-alive: accessibility connected';

  @override
  String get logCatDiagnosticsEnabled => 'diagnostics: enabled';

  @override
  String get logCatDiagnosticsCleared => 'diagnostics: cleared';

  @override
  String get logCatDiagnosticsBootstrap => 'diagnostics: bootstrap';

  @override
  String get logCatFlutterDiagnostic => 'flutter diagnostic';

  @override
  String get logCatFlutterDiagnosticEvent => 'flutter diagnostic event';

  @override
  String get logCatRenderFailed => 'render failed';

  @override
  String get logCatDebugSnapshot => 'debug snapshot';

  @override
  String get logExportTitle => 'Qingyu Timetable - App logs';

  @override
  String get appUpdateMirrorPresetGhfast => 'Default mirror';

  @override
  String get appUpdateMirrorPresetGhproxyCn => 'Backup mirror 1';

  @override
  String get appUpdateMirrorPresetGhLlkk => 'Backup mirror 2';

  @override
  String get appUpdateMirrorPresetGhProxyCom => 'Backup mirror 3';

  @override
  String get appUpdateMirrorPresetGhproxyNet => 'Backup mirror 4';

  @override
  String get appUpdateMirrorPresetCustom => 'Custom';

  @override
  String get appUpdateMirrorPresetCustomDescription =>
      'Enter a custom mirror URL prefix';

  @override
  String get cloudBackupRetentionTitle => 'Backup retention';

  @override
  String get cloudBackupMaxCountTitle => 'Maximum backups';

  @override
  String get cloudBackupMaxCountSubtitle =>
      'Oldest backups are removed when exceeded';

  @override
  String cloudBackupMaxCountOption(int count) {
    return '$count backups';
  }

  @override
  String get cloudBackupMaxAgeTitle => 'Maximum age';

  @override
  String get cloudBackupMaxAgeSubtitle => 'Backups older than this are removed';

  @override
  String cloudBackupMaxAgeOption(int days) {
    return '$days days';
  }

  @override
  String get statisticsShareText => 'Semester statistics from mikcb';

  @override
  String get aboutUpdateAvailableHeadline => 'Update available';

  @override
  String get aboutAlreadyLatestHeadline => 'Already up to date';

  @override
  String get aboutDownloadChannelSectionTitle => 'Download channel';

  @override
  String get aboutMirrorProbeFailedLabel => 'Failed';

  @override
  String timeSchemeImportSupplementName(String name) {
    return '$name (import supplement)';
  }

  @override
  String profileTimeSchemeName(String profileName) {
    return '$profileName schedule';
  }

  @override
  String get currentProfileTimeSchemeName => 'Current timetable schedule';

  @override
  String get unnamedTimetableProfile => 'Unnamed timetable';

  @override
  String get cloudBackupManualProtectedTitle => 'Protect manual backups';

  @override
  String get cloudBackupManualProtectedSubtitle =>
      'Manual backups are never auto-deleted when enabled';

  @override
  String courseImportPortalUrlMissingBody(
    String schoolName,
    String adapterName,
  ) {
    return '\"$schoolName / $adapterName\" has no default login URL. Enter the school portal URL first.';
  }

  @override
  String guidePermissionsProgressLabel(int ready, int total) {
    return 'Ready $ready/$total';
  }

  @override
  String get locationTimeMatchEntryTitle => 'Location-based schedule';

  @override
  String get locationTimeMatchEntrySubtitle =>
      'Auto-select time schemes by classroom keywords';

  @override
  String get locationTimeMatchTitle => 'Location-based schedule';

  @override
  String get locationTimeMatchSubtitle =>
      'Match time schemes by location keywords. Rematching updates clocks for matched courses only; unmatched courses stay unchanged.';

  @override
  String get locationTimeMatchWeekAxisNote =>
      'Note: the week-view time axis still shows the timetable default scheme. Card/live times use the matched scheme.';

  @override
  String get locationTimeMatchPreviewLabel => 'Try a location';

  @override
  String get locationTimeMatchPreviewHint => 'e.g. A1062 or A主201';

  @override
  String get locationTimeMatchPreviewNoMatch =>
      'No group matched; the default timetable scheme will be used';

  @override
  String locationTimeMatchPreviewResult(
    String group,
    String scheme,
    String keyword,
  ) {
    return 'Matches: $group · $scheme (keyword $keyword)';
  }

  @override
  String get locationTimeMatchApplyActive => 'Rematch current timetable';

  @override
  String get locationTimeMatchApplyTitle => 'Rematch current timetable?';

  @override
  String locationTimeMatchApplyMessage(int count) {
    return '$count courses currently match a location rule. Courses whose sections fit will return to automatic routing and update their clocks; any manual scheme on those courses will be cleared. Unmatched courses will remain unchanged.';
  }

  @override
  String get locationTimeMatchApplyConfirm => 'Rematch';

  @override
  String locationTimeMatchApplyUpdated(int matched, int updated) {
    return 'Rematched $matched courses, updated $updated clocks';
  }

  @override
  String locationTimeMatchApplyAlreadyAligned(int matched) {
    return 'Rematched $matched courses; clocks already correct';
  }

  @override
  String get locationTimeMatchApplyNoneMatched =>
      'No courses matched the place rules';

  @override
  String locationTimeMatchApplyOverflowResult(int matched, int count) {
    return '$count courses cannot map into the scheme (too few sections); apply rejected';
  }

  @override
  String locationTimeMatchApplyOverflowHint(String names) {
    return 'Examples: $names';
  }

  @override
  String get locationTimeMatchEmpty => 'No place groups yet';

  @override
  String get locationTimeMatchCreateGroup => 'New place group';

  @override
  String get locationTimeMatchEditGroup => 'Edit place group';

  @override
  String get locationTimeMatchUnknownScheme => 'Unknown time scheme';

  @override
  String get locationTimeMatchNoKeywords => 'No keywords';

  @override
  String locationTimeMatchBoundScheme(String name) {
    return 'Time scheme: $name';
  }

  @override
  String locationTimeMatchKeywordsLine(String keywords) {
    return 'Keywords: $keywords';
  }

  @override
  String get locationTimeMatchDeleteTitle => 'Delete place group?';

  @override
  String locationTimeMatchDeleteMessage(String name) {
    return 'Delete \"$name\"? Automatically matched courses will return to the timetable default; manually selected schemes will stay unchanged.';
  }

  @override
  String get locationTimeMatchDeleted => 'Place group deleted';

  @override
  String get locationTimeMatchGroupNameLabel => 'Group name';

  @override
  String get locationTimeMatchGroupNameHint => 'e.g. Main building';

  @override
  String get locationTimeMatchBoundSchemeLabel => 'Bound time scheme';

  @override
  String get locationTimeMatchNeedTimeScheme =>
      'Create at least one time scheme first';

  @override
  String get locationTimeMatchEnabledLabel => 'Enable this group';

  @override
  String get locationTimeMatchKeywordsSection => 'Location keywords';

  @override
  String get locationTimeMatchKeywordsHelp =>
      'Pick buildings from your timetable locations, or type keywords (A主, A1, A6). Prefer prefix match; longer keywords win.';

  @override
  String get locationTimeMatchSelectedKeywords => 'Selected keywords';

  @override
  String get locationTimeMatchNoSelectedKeywords => 'No keywords yet';

  @override
  String get locationTimeMatchPickFromLocations =>
      'Pick from timetable locations';

  @override
  String get locationTimeMatchBuildingSuggestions =>
      'Buildings found in timetable';

  @override
  String get locationTimeMatchNoBuildingSuggestions =>
      'No recognizable building locations yet';

  @override
  String get locationTimeMatchAddBuilding => 'Add';

  @override
  String get locationTimeMatchAddAllBuildings => 'Add all uncovered buildings';

  @override
  String locationTimeMatchBuildingRoomCount(int count) {
    return '$count rooms';
  }

  @override
  String locationTimeMatchBuildingGateTags(String tags) {
    return 'Tags: $tags';
  }

  @override
  String locationTimeMatchKeywordExtracted(String keyword) {
    return 'Extracted keyword $keyword';
  }

  @override
  String get locationTimeMatchKeywordAlreadyExists => 'Keyword already added';

  @override
  String locationTimeMatchKeywordUsedByGroup(String group) {
    return 'Keyword already used by \"$group\"';
  }

  @override
  String get locationTimeMatchAddKeyword => 'Add keyword manually';

  @override
  String get locationTimeMatchKeywordLabel => 'Keyword';

  @override
  String get locationTimeMatchKeywordHint => 'A1 / A主';

  @override
  String get locationTimeMatchModeLabel => 'Match mode';

  @override
  String get locationTimeMatchModePrefix => 'Prefix';

  @override
  String get locationTimeMatchModeContains => 'Contains';

  @override
  String get locationTimeMatchModeExact => 'Exact';

  @override
  String get locationTimeMatchKeywordTooShort =>
      'Keyword is very short and may mis-match';

  @override
  String get locationTimeMatchNameRequired => 'Enter a group name';

  @override
  String get locationTimeMatchKeywordRequired => 'Add at least one keyword';

  @override
  String get locationTimeMatchSaved => 'Place group saved';

  @override
  String get locationTimeMatchSaveFailed => 'Save failed';

  @override
  String get followLocationAutoTimeScheme => 'Follow timetable / location auto';

  @override
  String get followLocationAutoTimeSchemeDescription =>
      'Without a manual override, match a time scheme by location keywords; otherwise use the timetable default';

  @override
  String locationTimeMatchedSchemeHint(String scheme) {
    return 'Auto · $scheme';
  }

  @override
  String locationTimeAutoResolvedByGroup(String group, String scheme) {
    return 'Place group \"$group\" → $scheme';
  }

  @override
  String locationTimeAutoResolvedByTimetable(String scheme) {
    return 'Timetable default → $scheme';
  }

  @override
  String get scheduleDateRuleSectionTitle => 'Date-based schedule';

  @override
  String get scheduleDateRuleSectionSubtitle =>
      'On the start date, apply the selected scheme as the default for all timetables. Max 2 non-overlapping rules; location-based schedule takes priority.';

  @override
  String get scheduleDateRuleAdd => 'Add date rule';

  @override
  String get scheduleDateRuleEdit => 'Edit date rule';

  @override
  String get scheduleDateRuleEmpty => 'No date rules';

  @override
  String get scheduleDateRuleNameLabel => 'Rule name';

  @override
  String get scheduleDateRuleNameHint => 'e.g. Summer / Winter';

  @override
  String get scheduleDateRuleStartDate => 'Start date';

  @override
  String get scheduleDateRuleEndDate => 'End date';

  @override
  String get scheduleDateRuleBoundScheme => 'Time scheme';

  @override
  String get scheduleDateRuleEnabled => 'Enabled';

  @override
  String get scheduleDateRuleActiveToday => 'In range today';

  @override
  String scheduleDateRuleRangeSummary(String start, String end) {
    return '$start ~ $end';
  }

  @override
  String get scheduleDateRuleMaxReached => 'At most 2 date rules';

  @override
  String get scheduleDateRuleNeedScheme => 'Create a time scheme first';

  @override
  String get scheduleDateRuleNameRequired => 'Enter a rule name';

  @override
  String get scheduleDateRuleSaved => 'Date rule saved';

  @override
  String get scheduleDateRuleSavedAndApplied =>
      'Date rule saved; every timetable\'s default schedule has been updated today';

  @override
  String get scheduleDateRuleSavedForFuture =>
      'Date rule saved; every timetable\'s default schedule will update on the start date';

  @override
  String get scheduleDateRuleSavedButApplyFailed =>
      'Date rule saved, but today\'s auto-apply failed (check scheme section count)';

  @override
  String get scheduleDateRuleDeleted => 'Date rule deleted';

  @override
  String get scheduleDateRuleDeleteTitle => 'Delete date rule?';

  @override
  String scheduleDateRuleDeleteMessage(String name) {
    return 'Delete “$name”? Already-applied schedules are not rolled back automatically; adjust them manually if needed.';
  }

  @override
  String scheduleDateRuleSaveFailed(String reason) {
    return 'Save failed: $reason';
  }

  @override
  String get scheduleDateRuleErrorMax => 'Limit of 2 rules reached';

  @override
  String get scheduleDateRuleErrorOverlap => 'Date range overlaps another rule';

  @override
  String get scheduleDateRuleErrorInvalidDate => 'Invalid date';

  @override
  String get scheduleDateRuleErrorEndBeforeStart =>
      'End date cannot be before start date';

  @override
  String get scheduleDateRuleErrorSchemeRequired => 'Pick a time scheme';

  @override
  String get scheduleDateRuleErrorNameRequired => 'Enter a name';

  @override
  String get scheduleDateRuleNote =>
      'Location match takes priority over date rules.';

  @override
  String get frostedGlassModeLabel => 'Glass Mode';

  @override
  String get frostedGlassModeFrosted => 'Classic Frosted';

  @override
  String get frostedGlassModeLiquid => 'Liquid Glass';

  @override
  String get frostedGlassModeGaussian => 'Gaussian Blur';

  @override
  String get frostedGlassModeTranslucent => 'Translucent';

  @override
  String get frostedLiquidGlassHint =>
      'Liquid glass requires a high-performance device';

  @override
  String get advancedMaterialTitle => 'Advanced Material';

  @override
  String get advancedMaterialEntrySubtitle => 'Liquid glass parameter tuning';

  @override
  String get liquidGlassPresetLabel => 'Liquid Glass Preset';

  @override
  String get liquidGlassPresetClear => 'Clear';

  @override
  String get liquidGlassPresetLight => 'Light Mist';

  @override
  String get liquidGlassPresetStandard => 'Standard';

  @override
  String get liquidGlassPresetDense => 'Dense';

  @override
  String get liquidGlassPresetCustom => 'Custom';

  @override
  String get courseCardSettingsTitle => 'Course Card';

  @override
  String get courseCardSectionFields => 'Display Fields';

  @override
  String get courseCardSectionLayout => 'Layout';

  @override
  String get courseCardSurfaceStyleLabel => 'Card Appearance';

  @override
  String get courseCardSurfaceStyleSubtitle =>
      'Choose the visual style for course cards';

  @override
  String get courseCardSurfaceStyleSolid => 'Solid';

  @override
  String get courseCardSurfaceStyleGaussian => 'Gaussian Blur';

  @override
  String get courseCardSectionColor => 'Color';

  @override
  String get liveSelfCheckTitle => 'Self-Check';

  @override
  String get collapsibleLargeTitle => 'Collapsible Large Title';

  @override
  String get liquidGlassCustomExpandedTitle => 'Custom Parameters';

  @override
  String get liquidGlassThicknessLabel => 'Thickness';

  @override
  String get liquidGlassBlurLabel => 'Blur Intensity';

  @override
  String get liquidGlassTintLabel => 'Tint Intensity';

  @override
  String get liquidGlassLightIntensityLabel => 'Light Intensity';

  @override
  String get liquidGlassAmbientStrengthLabel => 'Ambient Light Strength';

  @override
  String get liquidGlassRefractiveIndexLabel => 'Refractive Index';

  @override
  String get liquidGlassSaturationLabel => 'Saturation';

  @override
  String get liquidGlassChromaticAberrationLabel => 'Chromatic Aberration';

  @override
  String get liquidGlassLightAngleLabel => 'Light Angle';

  @override
  String get liquidGlassVisibilityLabel => 'Visibility';

  @override
  String get liquidGlassResetAction => 'Reset to Default';

  @override
  String get diagnosticsEntryTitle => 'Diagnostics';

  @override
  String get memoryStatsEntryTitle => 'Memory Stats';

  @override
  String get generalSettingsTitle => 'General';

  @override
  String get settingsResetDefaultsTitle => 'Reset to Defaults';

  @override
  String get settingsResetDefaultsConfirmTitle => 'Confirm Reset';

  @override
  String get settingsResetConfirmBodyCourseCard =>
      'This resets course card fields, layout and colors to their defaults.';

  @override
  String get settingsResetConfirmBodyTimetablePage =>
      'This resets timetable page density, back-to-current-week button and background (including wallpaper) to their defaults.';

  @override
  String get settingsResetConfirmBodyAppearance =>
      'This resets theme mode, fonts, home navigation form, home title, theme color and frosted glass settings to their defaults.';

  @override
  String get settingsResetConfirmBodyHomeWidget =>
      'This resets home widget visibility and appearance to their defaults.';

  @override
  String get settingsResetDoneMessage => 'Settings have been reset';

  @override
  String get timetablePageSettingsTitle => 'Timetable Page';

  @override
  String get timetablePageSectionDensity => 'Density';

  @override
  String get timetablePageSectionBackToWeek => 'Back to Current Week';

  @override
  String get timetablePageSectionBackground => 'Background';

  @override
  String get largeTitleContentGap => '16.0';

  @override
  String get selectTimeTitle => 'Select Time';

  @override
  String get liveSelfCheckSubtitle => 'Run Self-Check';

  @override
  String get frostedSheetPreviewShowTitle => 'Show Preview';

  @override
  String get frostedSheetPreviewShowSubtitle =>
      'Show frosted glass preview at the top';

  @override
  String get aboutSupportUpdatesSectionTitle => 'Support & Updates';

  @override
  String get aboutProductSectionTitle => 'Product';

  @override
  String get aboutCommunitySectionTitle => 'Community';

  @override
  String get selectStartTimeTitle => 'Select Start Time';

  @override
  String get selectEndTimeTitle => 'Select End Time';

  @override
  String get weekdayInkContrastTitle => 'Low Text Contrast';

  @override
  String get weekdayInkContrastBodyDark =>
      'Your weekday bar text color has too little contrast against the dark wallpaper, so it is temporarily using automatic white to stay readable. You can change or reset it under \"Timetable Page → Text Colors\".';

  @override
  String get weekdayInkContrastBodyLight =>
      'Your weekday bar text color has too little contrast against the light wallpaper, so it is temporarily using automatic black to stay readable. You can change or reset it under \"Timetable Page → Text Colors\".';

  @override
  String get gotItAction => 'Got it';

  @override
  String get settingsTimetableSectionTitle => 'Timetable';

  @override
  String get liveIslandLabelEntryEnabled => 'Enabled';

  @override
  String get liveIslandLabelEntryDisabled => 'Disabled';

  @override
  String get settingsDisplayAppearanceSectionTitle => 'Timetable Display';

  @override
  String get settingsReminderDesktopSectionTitle => 'Reminders & Desktop';

  @override
  String get settingsAppSectionTitle => 'App';

  @override
  String get settingsDataShareSectionTitle => 'Data & Sharing';

  @override
  String get coupleTimetableEntryUnboundLabel => 'Unbound';

  @override
  String get settingsAboutSectionTitle => 'About';

  @override
  String get diagnosticsEntrySubtitle => 'Logs · Self-check · Memory';

  @override
  String get settingsSemesterScreenTitle => 'Semester Settings';

  @override
  String get syncCurrentWeekNeedsStartDate =>
      'Please set the semester start date first';

  @override
  String get liveNotificationPermissionMissing =>
      'Notification permission missing';

  @override
  String get developerSectionTitle => 'Developer Options';

  @override
  String get liveTestingFixtureEntryTitle => 'Live Test Fixture';

  @override
  String get hyperosShowcaseEntryTitle => 'HyperOS Component Showcase';

  @override
  String get hyperosShowcaseEntrySubtitle => 'HyperOS component preview';

  @override
  String get miuixShowcaseEntryTitle => 'Miuix Component Showcase';

  @override
  String get miuixShowcaseEntrySubtitle => 'Miuix component preview';

  @override
  String get debugUiOverlayToggleTitle => 'Debug UI Overlay';

  @override
  String get scheduleRepeatSectionTitle => 'Repeat';

  @override
  String get scheduleRepeatNone => 'Does not repeat';

  @override
  String get scheduleRepeatDaily => 'Every day';

  @override
  String get scheduleRepeatWeekly => 'Every week';

  @override
  String get scheduleRepeatEndDateLabel => 'Repeat until';

  @override
  String get scheduleRepeatEndDateHint =>
      'Recurring schedules need an end date';

  @override
  String get scheduleRepeatWeeklyHint =>
      'Repeats on the weekday of the start date';

  @override
  String get scheduleReminderSectionTitle => 'Schedule reminder';

  @override
  String get scheduleReminderOff => 'No reminder';

  @override
  String scheduleReminderMinutes(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get scheduleReminderPermissionMissing =>
      'Notifications are off. The schedule will save, but its reminder may not be delivered';

  @override
  String get scheduleReminderPermissionAction =>
      'Check notification permission';

  @override
  String get scheduleEnabledTitle => 'Enable schedule';

  @override
  String get scheduleDisabledSubtitle => 'Paused; reminders are disabled';

  @override
  String get scheduleEditScopeTitle => 'Edit scope';

  @override
  String get scheduleEditScopeThis => 'This occurrence only';

  @override
  String get scheduleEditScopeAll => 'All repeated occurrences';

  @override
  String get scheduleDeleteScopeTitle => 'Delete scope';

  @override
  String get scheduleDeleteScopeThis => 'Delete this occurrence only';

  @override
  String get scheduleDeleteScopeAll => 'Delete all repeated occurrences';

  @override
  String get scheduleOccurrenceEditHint =>
      'You are editing one occurrence of this recurring schedule';

  @override
  String get scheduleRepeatEndRequired =>
      'Choose an end date for the recurring schedule';

  @override
  String get homeMenuTasksTitle => 'Tasks';

  @override
  String get taskListTitle => 'Tasks';

  @override
  String get addTask => 'Add Task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get saveTask => 'Save Task';

  @override
  String get taskTitleLabel => 'Task title';

  @override
  String get taskTitleHint => 'e.g. Finish chapter 3 exercises';

  @override
  String get taskTitleRequired => 'Enter a task title';

  @override
  String get taskNoteLabel => 'Note';

  @override
  String get taskNoteHint => 'Optional details';

  @override
  String get taskDueDateLabel => 'Due date';

  @override
  String get taskNoDueDate => 'No due date';

  @override
  String get taskCourseLabel => 'Course';

  @override
  String get taskCourseFilter => 'Course filter';

  @override
  String get taskAllCourses => 'All courses';

  @override
  String get taskNoCourse => 'No linked course';

  @override
  String get taskAllFilter => 'All';

  @override
  String get taskTodayFilter => 'Today';

  @override
  String get taskWeekFilter => 'This week';

  @override
  String get taskOverdueSection => 'Overdue';

  @override
  String get taskCompletedSection => 'Completed';

  @override
  String get taskNoTasks => 'No tasks yet';

  @override
  String get taskNoTasksForToday => 'No tasks due today';

  @override
  String get taskNoTasksForWeek => 'No tasks due this week';

  @override
  String get taskNoTasksForCourse => 'No tasks for this course';

  @override
  String get taskDelete => 'Delete task';

  @override
  String get taskDeleteConfirm => 'Delete this task?';

  @override
  String get taskHomeworkDefaultTitle => 'Homework';

  @override
  String get taskAddFromCourse => 'Add task';

  @override
  String get taskViewCourse => 'View course';

  @override
  String get taskSaved => 'Task saved';

  @override
  String get taskUpdated => 'Task updated';

  @override
  String get taskDeleted => 'Task deleted';

  @override
  String get icsExportSectionTitle => 'Calendar export';

  @override
  String get icsExportSectionSubtitle =>
      'Choose courses, exams, and schedules to share as an ICS calendar';

  @override
  String get icsExportTitle => 'Export calendar';

  @override
  String get icsExportProfileLabel => 'Timetable profile';

  @override
  String get icsExportProfileSelectTitle => 'Choose timetable profile';

  @override
  String get icsExportDateRangeTitle => 'Date range';

  @override
  String get icsExportStartDate => 'Start date';

  @override
  String get icsExportEndDate => 'End date';

  @override
  String get icsExportTypesTitle => 'Calendar content';

  @override
  String get icsExportCourses => 'Courses';

  @override
  String get icsExportExams => 'Exams';

  @override
  String get icsExportSchedules => 'Schedules';

  @override
  String get icsExportButton => 'Export and share';

  @override
  String get icsExportSharing => 'Preparing calendar…';

  @override
  String get icsExportNoProfiles =>
      'No timetable profile is available for export';

  @override
  String get icsExportDateRangeInvalid =>
      'Choose an end date on or after the start date';

  @override
  String get icsExportNoSelection =>
      'Select at least one calendar content type';

  @override
  String get icsExportSemesterStartRequired =>
      'Set a semester start date before exporting courses';

  @override
  String get icsExportNoEvents =>
      'No calendar events were found in the selected date range';

  @override
  String get icsExportCancelled => 'Calendar sharing was cancelled';

  @override
  String get icsExportFailed => 'Calendar export failed. Try again later';

  @override
  String icsExportShared(int count) {
    return 'Exported and shared $count calendar events';
  }

  @override
  String get icsExportShareText => 'Calendar file from Qingyu Timetable';

  @override
  String get icsExportShareSubject => 'Qingyu Timetable calendar';

  @override
  String get homeNavigationFormLabel => 'Home form';

  @override
  String get homeNavigationFormClassic => 'Classic';

  @override
  String get homeNavigationFormClassicSubtitle =>
      'Keep the current pages and navigation style';

  @override
  String get homeNavigationFormGlassDock => 'Glass Dock';

  @override
  String get homeNavigationFormGlassDockSubtitle =>
      'Floating liquid-glass pill bar at the bottom: swipe or tap to switch between week view, day view and settings';

  @override
  String get glassDockTabWeek => 'Week';

  @override
  String get glassDockTabDay => 'Day';

  @override
  String get glassDockLayoutLabel => 'Glass dock layout';

  @override
  String get glassDockLayoutOverlay => 'Fullscreen overlay';

  @override
  String get glassDockLayoutOverlaySubtitle =>
      'Timetable fills the screen with the dock floating on top';

  @override
  String get glassDockLayoutInset => 'Reserve space below';

  @override
  String get glassDockLayoutInsetSubtitle =>
      'Timetable leaves compact space at the bottom, dock sits below';

  @override
  String get glassDockInsetClearanceLabel => 'Inset clearance height';

  @override
  String get glassDockEntriesSectionTitle => 'Dock entries';

  @override
  String get glassDockShowDayTabTitle => 'Show day view entry';

  @override
  String get glassDockShowSettingsTabTitle => 'Show settings entry';

  @override
  String get glassDockShowWeekTabTitle => 'Show week view entry';

  @override
  String get glassDockButtonFunctionLabel => 'Standalone button action';

  @override
  String get glassDockShowAddButtonTitle => 'Show add button';

  @override
  String get glassDockShowAddButtonSubtitle =>
      'Show a separate round button next to the bar that opens add-course directly';

  @override
  String get glassDockExtraButtonSemanticLabel => 'Add course';

  @override
  String get homeMenuStyleLabel => 'Top-right menu style';

  @override
  String get homeMenuStyleList => 'List menu';

  @override
  String get homeMenuStyleGrid => 'Eight-tile grid menu';

  @override
  String get homeMenuStyleListSubtitle =>
      'Anchored text list right below the button, all entries at once';

  @override
  String get homeMenuStyleGridSubtitle =>
      'Bottom icon tile sheet (v2.0.5.5 style), buttons customizable';

  @override
  String get homeGridCustomizeTitle => 'Customize grid buttons';

  @override
  String homeGridCustomizeDetails(int count, int max) {
    return '$count/$max enabled';
  }

  @override
  String homeGridEditorHintBody(int max) {
    return 'The grid holds up to $max buttons; drag an item to reorder.';
  }

  @override
  String get homeGridEditorEnabledTitle => 'Enabled';

  @override
  String get homeGridEditorAvailableTitle => 'Available to add';

  @override
  String get homeGridEditorRemoveTooltip => 'Remove';

  @override
  String get homeGridEditorAddTooltip => 'Add';

  @override
  String get homeGridEditorResetAction => 'Reset to default order';

  @override
  String get homeGridEditorAllAdded => 'All entries are enabled';

  @override
  String get homeGridEditorMaxReached => 'Limit reached';

  @override
  String get homeGridEditorPinnedTooltip =>
      'This entry reopens this page and cannot be removed';

  @override
  String get homeMenuCategoryFeatures => 'Features';

  @override
  String get homeMenuCategoryData => 'Data & sync';

  @override
  String get homeMenuCategoryPreferences => 'Preferences';

  @override
  String get homeMenuCategoryAbout => 'About & support';

  @override
  String classAlarmLeadMinutesLabel(int minutes) {
    return '$minutes min ahead';
  }

  @override
  String get classAlarmInvalidTimeToast =>
      'This class\'s period is outside the time scheme; cannot set an alarm';

  @override
  String get classAlarmSheetTitle => 'Class reminder';

  @override
  String classAlarmQuickOption(Object minutes) {
    return 'Remind me $minutes min before class';
  }

  @override
  String get classAlarmCustomOption => 'Pick a custom time…';

  @override
  String classAlarmExistingLabel(Object time) {
    return 'Reminder set for $time';
  }

  @override
  String get classAlarmSetToast => 'Reminder set';

  @override
  String get classAlarmRemovedToast => 'Class reminder removed';

  @override
  String get classAlarmPastToast =>
      'That time has already passed, pick another one';

  @override
  String get classAlarmNoSemesterToast =>
      'Set the semester start date in Settings first';

  @override
  String get classAlarmActionLabel => 'Set alarm for this class';

  @override
  String classAlarmConfirmMessage(String detail) {
    return 'The system clock will create: $detail. System alarms cannot recognize holidays or suspensions and ring anyway; delete them in the system clock.';
  }

  @override
  String classAlarmVariableSuffix(String days) {
    return 'Also, first-class times on $days differ between weeks; no alarm covers these days.';
  }

  @override
  String get classAlarmEntryTitle => 'Class alarms';

  @override
  String get classAlarmGroupSetup => 'Add alarms';

  @override
  String get classAlarmGroupBehavior => 'Ring behavior';

  @override
  String get classAlarmAddAllTitle => 'Batch add class alarms';

  @override
  String get classAlarmRangeNext4Weeks => 'Next 4 weeks';

  @override
  String get classAlarmRangeNext8Weeks => 'Next 8 weeks';

  @override
  String get classAlarmRangeLabel => 'Range';

  @override
  String get classAlarmRangeRemaining => 'This week to semester end';

  @override
  String get classAlarmRangeWhole => 'Whole semester';

  @override
  String get classAlarmLeadTitle => 'Lead time';

  @override
  String get classAlarmSkipUiTitle => 'Skip confirmation page';

  @override
  String get classAlarmSkipUiSubtitle =>
      'Try writing the alarm directly; some devices still show it';

  @override
  String get classAlarmOpenClock => 'Open system clock';

  @override
  String get classAlarmConfirmTitle => 'Create repeating alarms?';

  @override
  String get classAlarmNoSchemeToast =>
      'Select a time scheme in settings first';

  @override
  String get classAlarmNoDataToast =>
      'No timetable found in the selected range';

  @override
  String get classAlarmAddedToast => 'Handed to the system clock';

  @override
  String get classAlarmLaunchFailedToast => 'No clock app found to handle this';

  @override
  String get classAlarmCourseConfirmTitle =>
      'Add a repeating alarm for this class?';

  @override
  String get classAlarmDaySeparator => ', ';

  @override
  String get classAlarmDetailSeparator => '; ';
}
