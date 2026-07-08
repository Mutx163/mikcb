import '../models/warehouse_repository_models.dart';
import 'app_localizations.dart';

const String serviceMessagePayloadSeparator = '|';

/// Encodes a service message [code] with optional [args] for throws/returns.
String encodeServiceMessage(String code, [Map<String, Object?> args = const {}]) {
  if (args.isEmpty) {
    return code;
  }
  final parts = <String>[
    code,
    for (final entry in args.entries) '${entry.key}=${entry.value}',
  ];
  return parts.join(serviceMessagePayloadSeparator);
}

/// Parses a payload produced by [encodeServiceMessage].
({String code, Map<String, Object?> args}) parseServiceMessage(String payload) {
  final parts = payload.split(serviceMessagePayloadSeparator);
  final code = parts.first;
  final args = <String, Object?>{};
  for (final part in parts.skip(1)) {
    final separatorIndex = part.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }
    args[part.substring(0, separatorIndex)] = part.substring(separatorIndex + 1);
  }
  return (code: code, args: args);
}

/// Encodes a spreadsheet / import row warning for later UI localization.
String encodeServiceRowWarning(
  int rowNumber,
  String code, {
  Map<String, Object?> args = const {},
}) {
  return encodeServiceMessage(
    'spreadsheet_row_warning',
    {'rowNumber': rowNumber, 'inner': encodeServiceMessage(code, args)},
  );
}

/// Localizes a service-layer message [code] with optional [args].
///
/// [code] may be a bare code or an [encodeServiceMessage] payload.
String localizeServiceMessage(
  AppLocalizations l10n,
  String code, {
  Map<String, Object?> args = const {},
}) {
  final parsed = parseServiceMessage(code);
  final resolvedCode = parsed.code;
  final resolvedArgs = {...parsed.args, ...args};

  switch (resolvedCode) {
    case 'spreadsheet_row_warning':
      final rowNumber = _intArg(resolvedArgs, 'rowNumber') ?? 0;
      final inner = resolvedArgs['inner']?.toString() ?? '';
      return l10n.serviceMsgSpreadsheetRowWarning(
        rowNumber,
        localizeServiceMessage(l10n, inner),
      );

    // Import / backup
    case 'import_file_unrecognized':
      return l10n.serviceMsgImportFileUnrecognized;
    case 'import_use_overwrite_for_full_backup':
      return l10n.serviceMsgImportUseOverwriteForFullBackup;
    case 'import_no_profiles_in_backup':
      return l10n.serviceMsgImportNoProfilesInBackup;
    case 'unrecognized_mikcb_data_file':
      return l10n.serviceMsgUnrecognizedMikcbDataFile;
    case 'partner_import_requires_single_profile':
      return l10n.partnerImportRequiresSingleProfile;
    case 'missing_settings_data':
      return l10n.serviceMsgMissingSettingsData;
    case 'unrecognized_mikcb_full_backup':
      return l10n.serviceMsgUnrecognizedMikcbFullBackup;
    case 'missing_full_backup_data':
      return l10n.serviceMsgMissingFullBackupData;
    case 'use_profile_backup_not_full':
      return l10n.serviceMsgUseProfileBackupNotFull;

    // Cloud sync snapshot
    case 'unrecognized_sync_snapshot':
      return l10n.serviceMsgUnrecognizedSyncSnapshot;
    case 'missing_sync_timetable_data':
      return l10n.serviceMsgMissingSyncTimetableData;
    case 'sync_snapshot_checksum_failed':
      return l10n.serviceMsgSyncSnapshotChecksumFailed;
    case 'sync_snapshot_no_profiles':
      return l10n.serviceMsgSyncSnapshotNoProfiles;
    case 'sync_snapshot_unrecognized':
      return l10n.serviceMsgSyncSnapshotUnrecognized;

    // Time scheme
    case 'time_scheme_not_found':
      return l10n.serviceMsgTimeSchemeNotFound;
    case 'time_scheme_config_unavailable':
      return l10n.serviceMsgTimeSchemeConfigUnavailable;
    case 'time_scheme_not_found_selected':
      return l10n.serviceMsgTimeSchemeNotFoundSelected;
    case 'time_scheme_sections_insufficient':
      return l10n.serviceMsgTimeSchemeSectionsInsufficient(
        _intArg(resolvedArgs, 'startSection') ?? 0,
        _intArg(resolvedArgs, 'endSection') ?? 0,
      );
    case 'section_count_below_usage':
      return l10n.serviceMsgSectionCountBelowUsage(
        _intArg(resolvedArgs, 'requiredMaxSection') ?? 0,
      );
    case 'section_count_below_usage_detail':
      final usageType = resolvedArgs['usageType']?.toString() ?? '';
      return l10n.serviceMsgSectionCountBelowUsageDetail(
        _intArg(resolvedArgs, 'requiredMaxSection') ?? 0,
        resolvedArgs['profileName']?.toString() ?? '',
        resolvedArgs['courseName']?.toString() ?? '',
        _intArg(resolvedArgs, 'dayOfWeek') ?? 0,
        _intArg(resolvedArgs, 'startSection') ?? 0,
        _intArg(resolvedArgs, 'endSection') ?? 0,
        usageType.isEmpty ? '' : localizeServiceMessage(l10n, usageType),
      );
    case 'at_least_one_section_required':
      return l10n.serviceMsgAtLeastOneSectionRequired;
    case 'section_end_must_after_start':
      return l10n.serviceMsgSectionEndMustAfterStart(
        _intArg(resolvedArgs, 'sectionNumber') ?? 0,
      );
    case 'section_start_before_previous_end':
      return l10n.serviceMsgSectionStartBeforePreviousEnd(
        _intArg(resolvedArgs, 'sectionNumber') ?? 0,
      );
    case 'period_start_time_required':
      return l10n.serviceMsgPeriodStartTimeRequired;
    case 'section_crosses_midnight':
      return l10n.serviceMsgSectionCrossesMidnight(
        _intArg(resolvedArgs, 'sectionNumber') ?? 0,
      );
    case 'class_duration_must_positive':
      return l10n.serviceMsgClassDurationMustPositive;
    case 'break_duration_must_non_negative':
      return l10n.serviceMsgBreakDurationMustNonNegative;
    case 'at_least_one_period_section':
      return l10n.serviceMsgAtLeastOnePeriodSection;
    case 'invalid_time_format':
      return l10n.serviceMsgInvalidTimeFormat;

    // Timetable provider
    case 'linked_course_not_found':
      return l10n.serviceMsgLinkedCourseNotFound;
    case 'course_not_found_for_delete':
      return l10n.serviceMsgCourseNotFoundForDelete;
    case 'course_not_scheduled_week':
      return l10n.serviceMsgCourseNotScheduledWeek(
        _intArg(resolvedArgs, 'sourceWeek') ?? 0,
      );
    case 'course_not_found_for_reschedule':
      return l10n.serviceMsgCourseNotFoundForReschedule;
    case 'target_week_out_of_range':
      return l10n.serviceMsgTargetWeekOutOfRange;
    case 'at_least_one_schedule_slot':
      return l10n.serviceMsgAtLeastOneScheduleSlot;
    case 'course_name_required':
      return l10n.serviceMsgCourseNameRequired;
    case 'backup_content_required':
      return l10n.serviceMsgBackupContentRequired;

    // Spreadsheet import
    case 'spreadsheet_format_unrecognized':
      return l10n.spreadsheetFormatUnrecognized;
    case 'spreadsheet_format_or_encoding_unrecognized':
      return l10n.serviceMsgSpreadsheetFormatOrEncodingUnrecognized;
    case 'spreadsheet_xlsx_parse_failed':
      return l10n.serviceMsgSpreadsheetXlsxParseFailed(
        resolvedArgs['error']?.toString() ?? '',
      );
    case 'spreadsheet_wakeup_insufficient_columns':
      return l10n.serviceMsgSpreadsheetWakeupInsufficientColumns(
        _intArg(resolvedArgs, 'rowNumber') ?? 0,
        _intArg(resolvedArgs, 'columnCount') ?? 0,
      );
    case 'weekday_must_be_1_to_7':
      return l10n.serviceMsgWeekdayMustBe1To7;
    case 'custom_weeks_required':
      return l10n.serviceMsgCustomWeeksRequired;
    case 'class_weeks_required':
      return l10n.serviceMsgClassWeeksRequired;
    case 'start_week_must_be_at_least_1':
      return l10n.serviceMsgStartWeekMustBeAtLeast1;
    case 'start_week_exceeds_semester':
      return l10n.serviceMsgStartWeekExceedsSemester(
        _intArg(resolvedArgs, 'startWeek') ?? 0,
        _intArg(resolvedArgs, 'semesterWeekCount') ?? 0,
      );
    case 'end_week_before_start_week':
      return l10n.serviceMsgEndWeekBeforeStartWeek;
    case 'weeks_range_required':
      return l10n.serviceMsgWeeksRangeRequired;
    case 'field_must_be_at_least_1':
      return l10n.serviceMsgFieldMustBeAtLeast1(
        _localizeFieldName(l10n, resolvedArgs['field']?.toString()),
      );
    case 'field_cannot_be_less_than':
      return l10n.serviceMsgFieldCannotBeLessThan(
        _localizeFieldName(l10n, resolvedArgs['startField']?.toString()),
        _localizeFieldName(l10n, resolvedArgs['endField']?.toString()),
      );
    case 'section_out_of_range':
      return l10n.serviceMsgSectionOutOfRange(
        _intArg(resolvedArgs, 'section') ?? 0,
        _intArg(resolvedArgs, 'maxSection') ?? 0,
      );
    case 'field_must_be_integer':
      return l10n.serviceMsgFieldMustBeInteger(
        _localizeFieldName(l10n, resolvedArgs['field']?.toString()),
      );
    case 'field_cannot_be_empty':
      return l10n.serviceMsgFieldCannotBeEmpty(
        _localizeFieldName(l10n, resolvedArgs['field']?.toString()),
      );
    case 'spreadsheet_end_week_clamped':
      return l10n.serviceMsgSpreadsheetEndWeekClamped(
        _intArg(resolvedArgs, 'rowNumber') ?? 0,
        _intArg(resolvedArgs, 'endWeek') ?? 0,
        _intArg(resolvedArgs, 'semesterWeekCount') ?? 0,
      );
    case 'spreadsheet_odd_even_both':
      return l10n.serviceMsgSpreadsheetOddEvenBoth(
        _intArg(resolvedArgs, 'rowNumber') ?? 0,
      );

    // Week expression
    case 'week_start_invalid':
      return l10n.serviceMsgWeekStartInvalid(
        resolvedArgs['itemName']?.toString() ?? '',
      );
    case 'week_range_invalid':
      return l10n.serviceMsgWeekRangeInvalid(
        resolvedArgs['itemName']?.toString() ?? '',
      );
    case 'week_range_too_large':
      return l10n.serviceMsgWeekRangeTooLarge(
        resolvedArgs['itemName']?.toString() ?? '',
      );
    case 'week_token_unrecognized':
      return l10n.serviceMsgWeekTokenUnrecognized(
        resolvedArgs['itemName']?.toString() ?? '',
        resolvedArgs['token']?.toString() ?? '',
      );
    case 'weeks_exceed_semester_clamped':
      return l10n.serviceMsgWeeksExceedSemesterClamped(
        resolvedArgs['itemName']?.toString() ?? '',
        _intArg(resolvedArgs, 'semesterWeekCount') ?? 0,
        resolvedArgs['weeks']?.toString() ?? '',
      );

    // AI import
    case 'ai_result_not_object':
      return l10n.serviceMsgAiResultNotObject;
    case 'ai_schema_must_be':
      return l10n.serviceMsgAiSchemaMustBe(
        resolvedArgs['schema']?.toString() ?? '',
      );
    case 'ai_courses_must_be_array':
      return l10n.serviceMsgAiCoursesMustBeArray;
    case 'ai_warnings_must_be_array':
      return l10n.serviceMsgAiWarningsMustBeArray;
    case 'ai_warning_item_must_be_string':
      return l10n.serviceMsgAiWarningItemMustBeString;
    case 'ai_course_not_object':
      return l10n.serviceMsgAiCourseNotObject(
        _intArg(resolvedArgs, 'index') ?? 0,
      );
    case 'ai_course_name_empty':
      return l10n.serviceMsgAiCourseNameEmpty(
        _intArg(resolvedArgs, 'index') ?? 0,
      );
    case 'ai_course_day_of_week_invalid':
      return l10n.serviceMsgAiCourseDayOfWeekInvalid(
        _intArg(resolvedArgs, 'index') ?? 0,
      );
    case 'ai_course_start_section_invalid':
      return l10n.serviceMsgAiCourseStartSectionInvalid(
        _intArg(resolvedArgs, 'index') ?? 0,
      );
    case 'ai_course_end_section_invalid':
      return l10n.serviceMsgAiCourseEndSectionInvalid(
        _intArg(resolvedArgs, 'index') ?? 0,
      );
    case 'ai_course_custom_weeks_empty':
      return l10n.serviceMsgAiCourseCustomWeeksEmpty(
        _intArg(resolvedArgs, 'index') ?? 0,
      );
    case 'ai_course_nature_invalid':
      return l10n.serviceMsgAiCourseNatureInvalid(
        _intArg(resolvedArgs, 'index') ?? 0,
      );
    case 'ai_unknown_fields':
      return l10n.serviceMsgAiUnknownFields(
        resolvedArgs['targetName']?.toString() ?? '',
        resolvedArgs['fields']?.toString() ?? '',
      );
    case 'ai_field_must_be_string':
      return l10n.serviceMsgAiFieldMustBeString(
        resolvedArgs['field']?.toString() ?? '',
      );
    case 'ai_field_must_be_integer':
      return l10n.serviceMsgAiFieldMustBeInteger(
        resolvedArgs['field']?.toString() ?? '',
      );
    case 'ai_week_list_invalid':
      return l10n.serviceMsgAiWeekListInvalid(
        resolvedArgs['itemName']?.toString() ?? '',
      );
    case 'ai_week_list_type_invalid':
      return l10n.serviceMsgAiWeekListTypeInvalid(
        resolvedArgs['field']?.toString() ?? '',
      );

    // App update
    case 'download_cancelled':
      return l10n.aboutDownloadCancelled;
    case 'no_release_available':
      return l10n.serviceMsgNoReleaseAvailable;
    case 'no_release_with_prerelease':
      return l10n.serviceMsgNoReleaseWithPrerelease;
    case 'update_check_http_failed':
      return l10n.serviceMsgUpdateCheckHttpFailed(
        _intArg(resolvedArgs, 'statusCode') ?? 0,
      );
    case 'update_check_network_failed':
      return l10n.serviceMsgUpdateCheckNetworkFailed;
    case 'update_download_url_untrusted':
      return l10n.serviceMsgUpdateDownloadUrlUntrusted;
    case 'update_download_http_failed':
      return l10n.serviceMsgUpdateDownloadHttpFailed(
        _intArg(resolvedArgs, 'statusCode') ?? 0,
      );
    case 'update_open_installer_failed':
      return l10n.serviceMsgUpdateOpenInstallerFailed(
        resolvedArgs['detail']?.toString() ?? '',
      );
    case 'update_download_install_error':
      return l10n.serviceMsgUpdateDownloadInstallError(
        resolvedArgs['detail']?.toString() ?? '',
      );
    case 'invalid_url':
      return l10n.serviceMsgInvalidUrl;
    case 'update_available_prerelease':
      return l10n.serviceMsgUpdateAvailablePrerelease;
    case 'update_available':
      return l10n.serviceMsgUpdateAvailable;
    case 'already_latest':
      return l10n.serviceMsgAlreadyLatest;

    // Share export
    case 'share_backup_text':
      return l10n.serviceMsgShareBackupText;
    case 'share_backup_subject':
      return l10n.serviceMsgShareBackupSubject;
    case 'share_backup_subject_named':
      return l10n.serviceMsgShareBackupSubjectNamed(
        resolvedArgs['profileName']?.toString() ?? '',
      );
    case 'share_full_backup_text':
      return l10n.serviceMsgShareFullBackupText;
    case 'share_full_backup_subject':
      return l10n.serviceMsgShareFullBackupSubject;

    // Warehouse repository
    case 'invalid_repository_url':
      return l10n.serviceMsgInvalidRepositoryUrl;
    case 'incomplete_github_repo_url':
      return l10n.serviceMsgIncompleteGithubRepoUrl;
    case 'incomplete_raw_github_url':
      return l10n.serviceMsgIncompleteRawGithubUrl;
    case 'github_only_supported':
      return l10n.serviceMsgGithubOnlySupported;
    case 'warehouse_no_schools_index':
      return l10n.serviceMsgWarehouseNoSchoolsIndex;
    case 'warehouse_no_adapters':
      return l10n.serviceMsgWarehouseNoAdapters(
        resolvedArgs['schoolName']?.toString() ?? '',
      );
    case 'warehouse_fetch_failed_mirror':
      return l10n.serviceMsgWarehouseFetchFailedMirror(
        _intArg(resolvedArgs, 'candidatesCount') ?? 0,
      );
    case 'warehouse_fetch_failed_github':
      return l10n.serviceMsgWarehouseFetchFailedGithub;

    // Warehouse macro
    case 'manual_input_captcha':
      return l10n.serviceMsgManualInputCaptcha;
    case 'manual_input_password':
      return l10n.serviceMsgManualInputPassword;
    case 'macro_no_steps':
      return l10n.serviceMsgMacroNoSteps;
    case 'macro_user_cancelled':
      return l10n.serviceMsgMacroUserCancelled;
    case 'macro_step_failed':
      final detail = resolvedArgs['detail']?.toString() ?? '';
      return l10n.serviceMsgMacroStepFailed(
        _intArg(resolvedArgs, 'stepIndex') ?? 0,
        _intArg(resolvedArgs, 'totalSteps') ?? 0,
        detail.isEmpty ? '' : localizeServiceMessage(l10n, detail),
      );
    case 'macro_navigate_url_empty':
      return l10n.serviceMsgMacroNavigateUrlEmpty;
    case 'macro_navigate_url_invalid':
      return l10n.serviceMsgMacroNavigateUrlInvalid(
        resolvedArgs['url']?.toString() ?? '',
      );
    case 'macro_fill_selector_empty':
      return l10n.serviceMsgMacroFillSelectorEmpty;
    case 'macro_element_not_found':
      return l10n.serviceMsgMacroElementNotFound(
        resolvedArgs['selector']?.toString() ?? '',
      );
    case 'macro_click_selector_empty':
      return l10n.serviceMsgMacroClickSelectorEmpty;
    case 'macro_url_pattern_empty':
      return l10n.serviceMsgMacroUrlPatternEmpty;
    case 'macro_wait_selector_empty':
      return l10n.serviceMsgMacroWaitSelectorEmpty;
    case 'macro_manual_input_default':
      return l10n.serviceMsgMacroManualInputDefault;
    case 'macro_poll_timeout':
      return l10n.serviceMsgMacroPollTimeout(
        resolvedArgs['stepLabel']?.toString() ?? '',
        _intArg(resolvedArgs, 'timeoutSeconds') ?? 0,
        resolvedArgs['lastError']?.toString() ?? '',
      );
    case 'macro_replay_navigate':
      return l10n.serviceMsgMacroReplayNavigate;
    case 'macro_replay_fill_field':
      return l10n.serviceMsgMacroReplayFillField;
    case 'macro_replay_click':
      return l10n.serviceMsgMacroReplayClick;
    case 'macro_replay_wait_url':
      return l10n.serviceMsgMacroReplayWaitUrl;
    case 'macro_replay_wait_selector':
      return l10n.serviceMsgMacroReplayWaitSelector;
    case 'macro_replay_wait_manual':
      return l10n.serviceMsgMacroReplayWaitManual;
    case 'macro_replay_execute_script':
      return l10n.serviceMsgMacroReplayExecuteScript;
    case 'macro_replay_delay':
      return l10n.serviceMsgMacroReplayDelay;
    case 'macro_replay_failed':
      return l10n.serviceMsgMacroReplayFailed(
        resolvedArgs['detail']?.toString() ?? '',
      );
    case 'macro_replay_paused':
      return l10n.serviceMsgMacroReplayPaused(
        resolvedArgs['reason']?.toString() ?? '',
      );

    // Support / statistics
    case 'support_donors_load_failed':
      return l10n.serviceMsgSupportDonorsLoadFailed(
        resolvedArgs['detail']?.toString() ?? '',
      );
    case 'statistics_share_failed':
      return l10n.serviceMsgStatisticsShareFailed(
        resolvedArgs['detail']?.toString() ?? '',
      );

    // WebDAV / sync (shared with sanitizeWebdavErrorMessage)
    case 'auth_failed':
      return l10n.serviceMsgAuthFailed;
    case 'access_denied':
      return l10n.serviceMsgAccessDenied;
    case 'certificate_error':
      return l10n.serviceMsgCertificateError;
    case 'connection_timeout':
      return l10n.serviceMsgConnectionTimeout;
    case 'connection_failed':
      return l10n.serviceMsgConnectionFailed;
    case 'invalid_response':
      return l10n.serviceMsgInvalidResponse;
    case 'sync_failed':
      return l10n.serviceMsgSyncFailed;

    // Usage type labels for time scheme detail
    case 'usage_type_override':
      return l10n.serviceMsgUsageTypeOverride;
    case 'usage_type_profile':
      return l10n.serviceMsgUsageTypeProfile;

    default:
      return resolvedCode;
  }
}

/// Localizes any service-layer warning string (row warnings, week clamps, etc.).
String localizeServiceWarning(AppLocalizations l10n, String warning) {
  return localizeServiceMessage(l10n, warning);
}

/// Localizes errors thrown from service/provider layers.
String localizeServiceError(AppLocalizations l10n, Object error) {
  if (error is FormatException) {
    return localizeServiceMessage(l10n, error.message);
  }
  if (error is ArgumentError) {
    final message = error.message?.toString();
    if (message != null && message.isNotEmpty) {
      return localizeServiceMessage(l10n, message);
    }
  }
  if (error is WarehouseRepositoryException) {
    return localizeServiceMessage(l10n, error.message);
  }
  if (error is Exception) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return localizeServiceMessage(l10n, text.substring('Exception: '.length));
    }
  }
  return error.toString();
}

String _localizeFieldName(AppLocalizations l10n, String? fieldCode) {
  switch (fieldCode) {
    case 'course_name':
      return l10n.serviceMsgFieldCourseName;
    case 'weekday':
      return l10n.serviceMsgFieldWeekday;
    case 'start_section':
      return l10n.serviceMsgFieldStartSection;
    case 'end_section':
      return l10n.serviceMsgFieldEndSection;
    case 'custom_weeks':
      return l10n.serviceMsgFieldCustomWeeks;
    case 'class_weeks':
      return l10n.serviceMsgFieldClassWeeks;
    case 'start_week':
      return l10n.serviceMsgFieldStartWeek;
    case 'end_week':
      return l10n.serviceMsgFieldEndWeek;
    default:
      return fieldCode ?? '';
  }
}

int? _intArg(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
