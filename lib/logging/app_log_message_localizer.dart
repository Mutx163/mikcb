import '../l10n/app_localizations.dart';
import 'app_log_messages.dart';

/// Maps persisted log message / field / category keys to localized strings.
abstract final class AppLogMessageLocalizer {
  static String localizeMessage(AppLocalizations l10n, String message) {
    if (message.startsWith('${AppLogMessages.liveUpdateSettingsSyncedKey}|')) {
      final params = <String, String>{};
      for (final part in message.split('|').skip(1)) {
        final idx = part.indexOf('=');
        if (idx > 0) {
          params[part.substring(0, idx)] = part.substring(idx + 1);
        }
      }
      return l10n.logLiveUpdateSettingsSynced(
        params['beforeClass'] ?? '',
        params['duringClass'] ?? '',
        params['beforeEnd'] ?? '',
        params['promote'] ?? '',
        params['notification'] ?? '',
        params['countdown'] ?? '',
        params['courseName'] ?? '',
        params['location'] ?? '',
      );
    }
    return switch (message) {
      'log_app_logger_initialized' => l10n.logAppLoggerInitialized,
      'log_privacy_consent_updated' => l10n.logPrivacyConsentUpdated,
      'log_app_log_recording_enabled' => l10n.logAppLogRecordingEnabled,
      'log_app_log_recording_remains_enabled' =>
        l10n.logAppLogRecordingRemainsEnabled,
      'log_startup_flow_started' => l10n.logStartupFlowStarted,
      'log_startup_flow_completed_no_onboarding' =>
        l10n.logStartupFlowCompletedNoOnboarding,
      'log_startup_flow_completed_after_guide' =>
        l10n.logStartupFlowCompletedAfterGuide,
      'log_startup_flow_failed' => l10n.logStartupFlowFailed,
      'log_app_lifecycle_changed' => l10n.logAppLifecycleChanged,
      'log_navigator_route_replaced' => l10n.logNavigatorRouteReplaced,
      'log_navigator_route_changed' => l10n.logNavigatorRouteChanged,
      'log_app_logs_default_migrated' => l10n.logAppLogsDefaultMigrated,
      'log_timetable_load_settings_failed' =>
        l10n.logTimetableLoadSettingsFailed,
      'log_timetable_load_courses_failed' => l10n.logTimetableLoadCoursesFailed,
      'log_timetable_load_current_week_failed' =>
        l10n.logTimetableLoadCurrentWeekFailed,
      'log_home_widget_pin_support_failed' =>
        l10n.logHomeWidgetPinSupportFailed,
      'log_home_widget_pin_request_failed' =>
        l10n.logHomeWidgetPinRequestFailed,
      'log_home_widget_sync_failed' => l10n.logHomeWidgetSyncFailed,
      'log_home_widget_clear_failed' => l10n.logHomeWidgetClearFailed,
      'log_home_widget_schedule_failed' => l10n.logHomeWidgetScheduleFailed,
      'log_home_widget_exact_alarm_check_failed' =>
        l10n.logHomeWidgetExactAlarmCheckFailed,
      'log_home_widget_exact_alarm_request_failed' =>
        l10n.logHomeWidgetExactAlarmRequestFailed,
      'log_miui_live_initialize_failed' => l10n.logMiuiLiveInitializeFailed,
      'log_miui_live_open_promoted_settings_failed' =>
        l10n.logMiuiLiveOpenPromotedSettingsFailed,
      'log_miui_live_open_notification_settings_failed' =>
        l10n.logMiuiLiveOpenNotificationSettingsFailed,
      'log_miui_live_open_autostart_settings_failed' =>
        l10n.logMiuiLiveOpenAutostartSettingsFailed,
      'log_miui_live_open_battery_settings_failed' =>
        l10n.logMiuiLiveOpenBatterySettingsFailed,
      'log_miui_live_open_accessibility_settings_failed' =>
        l10n.logMiuiLiveOpenAccessibilitySettingsFailed,
      'log_miui_live_hide_from_recents_failed' =>
        l10n.logMiuiLiveHideFromRecentsFailed,
      'log_live_update_start_failed' => l10n.logLiveUpdateStartFailed,
      'log_live_update_stop_failed' => l10n.logLiveUpdateStopFailed,
      'log_live_update_debug_status_failed' =>
        l10n.logLiveUpdateDebugStatusFailed,
      'log_live_update_snapshot_sync_failed' =>
        l10n.logLiveUpdateSnapshotSyncFailed,
      'log_live_update_snapshot_clear_failed' =>
        l10n.logLiveUpdateSnapshotClearFailed,
      'log_live_update_suspend_triggers_failed' =>
        l10n.logLiveUpdateSuspendTriggersFailed,
      'log_lan_edit_auth_failed' => l10n.logLanEditAuthFailed,
      'log_lan_edit_course_created' => l10n.logLanEditCourseCreated,
      'log_lan_edit_course_updated' => l10n.logLanEditCourseUpdated,
      'log_lan_edit_course_deleted' => l10n.logLanEditCourseDeleted,
      'log_lan_edit_course_group_saved' => l10n.logLanEditCourseGroupSaved,
      'log_lan_edit_merge_imported' => l10n.logLanEditMergeImported,
      'log_lan_edit_courses_batch_deleted' =>
        l10n.logLanEditCoursesBatchDeleted,
      'log_lan_edit_current_week_set' => l10n.logLanEditCurrentWeekSet,
      'log_lan_edit_profile_switched' => l10n.logLanEditProfileSwitched,
      'log_lan_edit_spreadsheet_imported' => l10n.logLanEditSpreadsheetImported,
      'log_lan_edit_session_started' => l10n.logLanEditSessionStarted,
      'log_lan_edit_session_stopped' => l10n.logLanEditSessionStopped,
      'log_live_update_test_requested' => l10n.logLiveUpdateTestRequested,
      'log_live_update_test_no_selection' => l10n.logLiveUpdateTestNoSelection,
      'log_live_update_test_selection_ready' =>
        l10n.logLiveUpdateTestSelectionReady,
      'log_live_update_test_suspend_sync' => l10n.logLiveUpdateTestSuspendSync,
      'log_live_update_test_starting' => l10n.logLiveUpdateTestStarting,
      'log_live_update_test_started' => l10n.logLiveUpdateTestStarted,
      'log_live_update_test_failed' => l10n.logLiveUpdateTestFailed,
      'log_export_title' => l10n.logExportTitle,
      _ => message,
    };
  }

  static String localizeField(AppLocalizations l10n, String key) {
    final mapped = appLogFieldLabels[key];
    if (mapped == null) return key;
    return switch (mapped) {
      'log_field_source' => l10n.logFieldSource,
      'log_field_platform' => l10n.logFieldPlatform,
      'log_field_version' => l10n.logFieldVersion,
      'log_field_build_number' => l10n.logFieldBuildNumber,
      'log_field_logging_enabled' => l10n.logFieldLoggingEnabled,
      'log_field_privacy_accepted' => l10n.logFieldPrivacyAccepted,
      'log_field_accepted' => l10n.logFieldAccepted,
      'log_field_previous' => l10n.logFieldPrevious,
      'log_field_truncated' => l10n.logFieldTruncated,
      'log_field_truncated_hint' => l10n.logFieldTruncatedHint,
      'log_field_throwable' => l10n.logFieldThrowable,
      'log_field_extras' => l10n.logFieldExtras,
      'log_field_context' => l10n.logFieldContext,
      'log_field_error' => l10n.logFieldError,
      'log_field_brand' => l10n.logFieldBrand,
      'log_field_manufacturer' => l10n.logFieldManufacturer,
      'log_field_model' => l10n.logFieldModel,
      'log_field_sdk_int' => l10n.logFieldSdkInt,
      'log_field_version_name' => l10n.logFieldVersionName,
      'log_field_channel' => l10n.logFieldChannel,
      'log_field_has_notification_permission' =>
        l10n.logFieldHasNotificationPermission,
      'log_field_has_promoted_permission_declared' =>
        l10n.logFieldHasPromotedPermissionDeclared,
      'log_field_can_post_promoted_notifications' =>
        l10n.logFieldCanPostPromotedNotifications,
      'log_field_ignoring_battery_optimizations' =>
        l10n.logFieldIgnoringBatteryOptimizations,
      'log_field_keep_alive_accessibility_enabled' =>
        l10n.logFieldKeepAliveAccessibilityEnabled,
      'log_field_hide_from_recents_enabled' =>
        l10n.logFieldHideFromRecentsEnabled,
      'log_field_task_removed_recently' => l10n.logFieldTaskRemovedRecently,
      'log_field_last_task_removed_at' => l10n.logFieldLastTaskRemovedAt,
      'log_field_process_importance' => l10n.logFieldProcessImportance,
      'log_field_auto_start_status' => l10n.logFieldAutoStartStatus,
      'log_field_live_enable_before_class' =>
        l10n.logFieldLiveEnableBeforeClass,
      'log_field_live_enable_during_class' =>
        l10n.logFieldLiveEnableDuringClass,
      'log_field_live_enable_before_end' => l10n.logFieldLiveEnableBeforeEnd,
      'log_field_live_promote_during_class' =>
        l10n.logFieldLivePromoteDuringClass,
      'log_field_live_show_during_class_notification' =>
        l10n.logFieldLiveShowDuringClassNotification,
      'log_field_live_show_countdown' => l10n.logFieldLiveShowCountdown,
      'log_field_live_show_stage_text' => l10n.logFieldLiveShowStageText,
      'log_field_live_show_course_name' => l10n.logFieldLiveShowCourseName,
      'log_field_live_show_location' => l10n.logFieldLiveShowLocation,
      'log_field_live_use_short_name' => l10n.logFieldLiveUseShortName,
      'log_field_live_hide_prefix_text' => l10n.logFieldLiveHidePrefixText,
      'log_field_live_during_class_time_display_mode' =>
        l10n.logFieldLiveDuringClassTimeDisplayMode,
      'log_field_live_enable_miui_island_label_image' =>
        l10n.logFieldLiveEnableMiuiIslandLabelImage,
      'log_field_live_miui_island_label_style' =>
        l10n.logFieldLiveMiuiIslandLabelStyle,
      'log_field_live_miui_island_label_content' =>
        l10n.logFieldLiveMiuiIslandLabelContent,
      'log_field_live_miui_island_label_font_color' =>
        l10n.logFieldLiveMiuiIslandLabelFontColor,
      'log_field_live_miui_island_label_font_weight' =>
        l10n.logFieldLiveMiuiIslandLabelFontWeight,
      'log_field_live_miui_island_label_render_quality' =>
        l10n.logFieldLiveMiuiIslandLabelRenderQuality,
      'log_field_live_miui_island_label_font_size' =>
        l10n.logFieldLiveMiuiIslandLabelFontSize,
      'log_field_live_miui_island_label_offset_x' =>
        l10n.logFieldLiveMiuiIslandLabelOffsetX,
      'log_field_live_miui_island_label_offset_y' =>
        l10n.logFieldLiveMiuiIslandLabelOffsetY,
      'log_field_live_miui_island_expanded_icon_mode' =>
        l10n.logFieldLiveMiuiIslandExpandedIconMode,
      'log_field_live_show_before_class_minutes' =>
        l10n.logFieldLiveShowBeforeClassMinutes,
      'log_field_live_class_reminder_start_minutes' =>
        l10n.logFieldLiveClassReminderStartMinutes,
      'log_field_live_end_seconds_countdown_threshold' =>
        l10n.logFieldLiveEndSecondsCountdownThreshold,
      'log_field_state' => l10n.logFieldState,
      'log_field_route' => l10n.logFieldRoute,
      'log_field_previous_route' => l10n.logFieldPreviousRoute,
      'log_field_profile_id' => l10n.logFieldProfileId,
      'log_field_reason' => l10n.logFieldReason,
      'log_field_client_ip' => l10n.logFieldClientIp,
      'log_field_port' => l10n.logFieldPort,
      'log_field_course_name' => l10n.logFieldCourseName,
      'log_field_stage' => l10n.logFieldStage,
      'log_field_from' => l10n.logFieldFrom,
      'log_field_current_week' => l10n.logFieldCurrentWeek,
      'log_field_weekday' => l10n.logFieldWeekday,
      'log_field_until_millis' => l10n.logFieldUntilMillis,
      'log_field_start_at_millis' => l10n.logFieldStartAtMillis,
      'log_field_merged_course_count' => l10n.logFieldMergedCourseCount,
      'log_field_deleted_count' => l10n.logFieldDeletedCount,
      'log_field_requested' => l10n.logFieldRequested,
      'log_field_target' => l10n.logFieldTarget,
      'log_field_count' => l10n.logFieldCount,
      'log_field_value' => l10n.logFieldValue,
      'log_field_snapshot_length' => l10n.logFieldSnapshotLength,
      'log_field_stored_snapshot_version' => l10n.logFieldStoredSnapshotVersion,
      'log_field_intent_is_null' => l10n.logFieldIntentIsNull,
      'log_field_action' => l10n.logFieldAction,
      'log_field_step' => l10n.logFieldStep,
      _ => key,
    };
  }

  static String localizeCategory(AppLocalizations l10n, String category) {
    final mapped = appLogCategoryLabels[category];
    if (mapped == null) return category;
    return switch (mapped) {
      'log_cat_app_logger_initialized' => l10n.logCatAppLoggerInitialized,
      'log_cat_privacy_consent_updated' => l10n.logCatPrivacyConsentUpdated,
      'log_cat_app_log_recording_enabled' => l10n.logCatAppLogRecordingEnabled,
      'log_cat_startup_flow_started' => l10n.logCatStartupFlowStarted,
      'log_cat_startup_flow_completed' => l10n.logCatStartupFlowCompleted,
      'log_cat_startup_flow_failed' => l10n.logCatStartupFlowFailed,
      'log_cat_app_lifecycle_state_changed' =>
        l10n.logCatAppLifecycleStateChanged,
      'log_cat_route_pushed' => l10n.logCatRoutePushed,
      'log_cat_route_popped' => l10n.logCatRoutePopped,
      'log_cat_route_replaced' => l10n.logCatRouteReplaced,
      'log_cat_flutter_framework_error' => l10n.logCatFlutterFrameworkError,
      'log_cat_flutter_platform_error' => l10n.logCatFlutterPlatformError,
      'log_cat_flutter_zone_error' => l10n.logCatFlutterZoneError,
      'log_cat_app_logs_default_migrated' => l10n.logCatAppLogsDefaultMigrated,
      'log_cat_timetable_load_settings_failed' =>
        l10n.logCatTimetableLoadSettingsFailed,
      'log_cat_timetable_load_courses_failed' =>
        l10n.logCatTimetableLoadCoursesFailed,
      'log_cat_timetable_load_current_week_failed' =>
        l10n.logCatTimetableLoadCurrentWeekFailed,
      'log_cat_home_widget_pin_support_failed' =>
        l10n.logCatHomeWidgetPinSupportFailed,
      'log_cat_home_widget_pin_request_failed' =>
        l10n.logCatHomeWidgetPinRequestFailed,
      'log_cat_home_widget_sync_failed' => l10n.logCatHomeWidgetSyncFailed,
      'log_cat_home_widget_clear_failed' => l10n.logCatHomeWidgetClearFailed,
      'log_cat_home_widget_schedule_failed' =>
        l10n.logCatHomeWidgetScheduleFailed,
      'log_cat_miui_live_initialize_failed' =>
        l10n.logCatMiuiLiveInitializeFailed,
      'log_cat_miui_live_open_promoted_settings_failed' =>
        l10n.logCatMiuiLiveOpenPromotedSettingsFailed,
      'log_cat_miui_live_open_notification_settings_failed' =>
        l10n.logCatMiuiLiveOpenNotificationSettingsFailed,
      'log_cat_miui_live_open_autostart_settings_failed' =>
        l10n.logCatMiuiLiveOpenAutostartSettingsFailed,
      'log_cat_miui_live_open_battery_settings_failed' =>
        l10n.logCatMiuiLiveOpenBatterySettingsFailed,
      'log_cat_miui_live_open_accessibility_settings_failed' =>
        l10n.logCatMiuiLiveOpenAccessibilitySettingsFailed,
      'log_cat_miui_live_hide_from_recents_failed' =>
        l10n.logCatMiuiLiveHideFromRecentsFailed,
      'log_cat_live_update_flutter_initialize_failed' =>
        l10n.logCatLiveUpdateFlutterInitializeFailed,
      'log_cat_live_update_start_failed' => l10n.logCatLiveUpdateStartFailed,
      'log_cat_live_update_stop_failed' => l10n.logCatLiveUpdateStopFailed,
      'log_cat_live_update_debug_status_failed' =>
        l10n.logCatLiveUpdateDebugStatusFailed,
      'log_cat_live_update_settings_synced' =>
        l10n.logCatLiveUpdateSettingsSynced,
      'log_cat_live_update_snapshot_sync_failed' =>
        l10n.logCatLiveUpdateSnapshotSyncFailed,
      'log_cat_live_update_snapshot_clear_failed' =>
        l10n.logCatLiveUpdateSnapshotClearFailed,
      'log_cat_lan_edit_auth_failed' => l10n.logCatLanEditAuthFailed,
      'log_cat_lan_edit_course_created' => l10n.logCatLanEditCourseCreated,
      'log_cat_lan_edit_course_updated' => l10n.logCatLanEditCourseUpdated,
      'log_cat_lan_edit_course_deleted' => l10n.logCatLanEditCourseDeleted,
      'log_cat_lan_edit_course_group_saved' =>
        l10n.logCatLanEditCourseGroupSaved,
      'log_cat_lan_edit_merge_imported' => l10n.logCatLanEditMergeImported,
      'log_cat_lan_edit_courses_batch_deleted' =>
        l10n.logCatLanEditCoursesBatchDeleted,
      'log_cat_lan_edit_current_week_set' => l10n.logCatLanEditCurrentWeekSet,
      'log_cat_lan_edit_spreadsheet_imported' =>
        l10n.logCatLanEditSpreadsheetImported,
      'log_cat_lan_edit_session_started' => l10n.logCatLanEditSessionStarted,
      'log_cat_lan_edit_session_stopped' => l10n.logCatLanEditSessionStopped,
      'log_cat_live_update_test_requested' =>
        l10n.logCatLiveUpdateTestRequested,
      'log_cat_live_update_test_no_selection' =>
        l10n.logCatLiveUpdateTestNoSelection,
      'log_cat_live_update_test_selection_ready' =>
        l10n.logCatLiveUpdateTestSelectionReady,
      'log_cat_live_update_test_suspend_sync' =>
        l10n.logCatLiveUpdateTestSuspendSync,
      'log_cat_live_update_test_starting' => l10n.logCatLiveUpdateTestStarting,
      'log_cat_live_update_test_started' => l10n.logCatLiveUpdateTestStarted,
      'log_cat_live_update_test_failed' => l10n.logCatLiveUpdateTestFailed,
      'log_cat_live_update_snapshot_settings' =>
        l10n.logCatLiveUpdateSnapshotSettings,
      'log_cat_live_update_snapshot_synced' =>
        l10n.logCatLiveUpdateSnapshotSynced,
      'log_cat_live_update_snapshot_cleared' =>
        l10n.logCatLiveUpdateSnapshotCleared,
      'log_cat_live_update_alarm_triggered' =>
        l10n.logCatLiveUpdateAlarmTriggered,
      'log_cat_live_update_scheduler_resume' =>
        l10n.logCatLiveUpdateSchedulerResume,
      'log_cat_live_update_reschedule_holiday' =>
        l10n.logCatLiveUpdateRescheduleHoliday,
      'log_cat_live_update_reschedule_active' =>
        l10n.logCatLiveUpdateRescheduleActive,
      'log_cat_live_update_reschedule_scheduled' =>
        l10n.logCatLiveUpdateRescheduleScheduled,
      'log_cat_live_update_snapshot_parse_failed' =>
        l10n.logCatLiveUpdateSnapshotParseFailed,
      'log_cat_live_update_snapshot_invalidated_after_upgrade' =>
        l10n.logCatLiveUpdateSnapshotInvalidatedAfterUpgrade,
      'log_cat_live_update_payload_selected' =>
        l10n.logCatLiveUpdatePayloadSelected,
      'log_cat_live_update_scheduler_start_failed' =>
        l10n.logCatLiveUpdateSchedulerStartFailed,
      'log_cat_live_update_start_requested' =>
        l10n.logCatLiveUpdateStartRequested,
      'log_cat_live_update_stop_requested' =>
        l10n.logCatLiveUpdateStopRequested,
      'log_cat_live_update_service_missing_payload' =>
        l10n.logCatLiveUpdateServiceMissingPayload,
      'log_cat_live_update_service_started' =>
        l10n.logCatLiveUpdateServiceStarted,
      'log_cat_live_update_service_start_failed' =>
        l10n.logCatLiveUpdateServiceStartFailed,
      'log_cat_live_update_task_removed' => l10n.logCatLiveUpdateTaskRemoved,
      'log_cat_live_update_task_removed_resumed' =>
        l10n.logCatLiveUpdateTaskRemovedResumed,
      'log_cat_live_update_before_class_quick_action' =>
        l10n.logCatLiveUpdateBeforeClassQuickAction,
      'log_cat_live_update_before_class_quick_action_restored' =>
        l10n.logCatLiveUpdateBeforeClassQuickActionRestored,
      'log_cat_live_update_status_bar_dismissed' =>
        l10n.logCatLiveUpdateStatusBarDismissed,
      'log_cat_live_update_not_promoted' => l10n.logCatLiveUpdateNotPromoted,
      'log_cat_live_update_promoted_not_shown' =>
        l10n.logCatLiveUpdatePromotedNotShown,
      'log_cat_live_update_service_stopped' =>
        l10n.logCatLiveUpdateServiceStopped,
      'log_cat_keep_alive_accessibility_connected' =>
        l10n.logCatKeepAliveAccessibilityConnected,
      'log_cat_diagnostics_enabled' => l10n.logCatDiagnosticsEnabled,
      'log_cat_diagnostics_cleared' => l10n.logCatDiagnosticsCleared,
      'log_cat_diagnostics_bootstrap' => l10n.logCatDiagnosticsBootstrap,
      'log_cat_flutter_diagnostic' => l10n.logCatFlutterDiagnostic,
      'log_cat_flutter_diagnostic_event' => l10n.logCatFlutterDiagnosticEvent,
      'log_cat_render_failed' => l10n.logCatRenderFailed,
      'log_cat_debug_snapshot' => l10n.logCatDebugSnapshot,
      _ => category,
    };
  }

  static String localizeExportTitle(AppLocalizations l10n) =>
      l10n.logExportTitle;
}

String categoryDisplayLabel(String category, AppLocalizations l10n) =>
    AppLogMessageLocalizer.localizeCategory(l10n, category);

String fieldDisplayLabel(String key, AppLocalizations l10n) =>
    AppLogMessageLocalizer.localizeField(l10n, key);
