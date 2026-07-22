/// Centralized English log message keys for persisted app diagnostics.
/// Categories remain English snake_case for level inference and grep.
/// UI display is localized via [AppLogMessageLocalizer].
abstract final class AppLogMessages {
  static const appLoggerInitialized = 'log_app_logger_initialized';
  static const privacyConsentUpdated = 'log_privacy_consent_updated';
  static const appLogRecordingEnabled = 'log_app_log_recording_enabled';
  static const appLogRecordingRemainsEnabled =
      'log_app_log_recording_remains_enabled';
  static const startupFlowStarted = 'log_startup_flow_started';
  static const startupFlowCompletedNoOnboarding =
      'log_startup_flow_completed_no_onboarding';
  static const startupFlowCompletedAfterGuide =
      'log_startup_flow_completed_after_guide';
  static const startupFlowFailed = 'log_startup_flow_failed';
  static const appLifecycleChanged = 'log_app_lifecycle_changed';
  static const navigatorRouteReplaced = 'log_navigator_route_replaced';
  static const navigatorRouteChanged = 'log_navigator_route_changed';
  static const appLogsDefaultMigrated = 'log_app_logs_default_migrated';
  static const timetableLoadSettingsFailed =
      'log_timetable_load_settings_failed';
  static const timetableLoadCoursesFailed = 'log_timetable_load_courses_failed';
  static const timetableLoadCurrentWeekFailed =
      'log_timetable_load_current_week_failed';
  static const homeWidgetPinSupportFailed =
      'log_home_widget_pin_support_failed';
  static const homeWidgetPinRequestFailed =
      'log_home_widget_pin_request_failed';
  static const homeWidgetSyncFailed = 'log_home_widget_sync_failed';
  static const homeWidgetClearFailed = 'log_home_widget_clear_failed';
  static const homeWidgetScheduleFailed = 'log_home_widget_schedule_failed';
  static const miuiLiveInitializeFailed = 'log_miui_live_initialize_failed';
  static const miuiLiveOpenPromotedSettingsFailed =
      'log_miui_live_open_promoted_settings_failed';
  static const miuiLiveOpenNotificationSettingsFailed =
      'log_miui_live_open_notification_settings_failed';
  static const miuiLiveOpenAutostartSettingsFailed =
      'log_miui_live_open_autostart_settings_failed';
  static const miuiLiveOpenBatterySettingsFailed =
      'log_miui_live_open_battery_settings_failed';
  static const miuiLiveOpenAccessibilitySettingsFailed =
      'log_miui_live_open_accessibility_settings_failed';
  static const miuiLiveHideFromRecentsFailed =
      'log_miui_live_hide_from_recents_failed';
  static const liveUpdateStartFailed = 'log_live_update_start_failed';
  static const liveUpdateStopFailed = 'log_live_update_stop_failed';
  static const liveUpdateDebugStatusFailed =
      'log_live_update_debug_status_failed';
  static const liveUpdateSnapshotSyncFailed =
      'log_live_update_snapshot_sync_failed';
  static const liveUpdateSnapshotClearFailed =
      'log_live_update_snapshot_clear_failed';
  static const liveUpdateSuspendTriggersFailed =
      'log_live_update_suspend_triggers_failed';
  static const lanEditAuthFailed = 'log_lan_edit_auth_failed';
  static const lanEditCourseCreated = 'log_lan_edit_course_created';
  static const lanEditCourseUpdated = 'log_lan_edit_course_updated';
  static const lanEditCourseDeleted = 'log_lan_edit_course_deleted';
  static const lanEditCourseGroupSaved = 'log_lan_edit_course_group_saved';
  static const lanEditMergeImported = 'log_lan_edit_merge_imported';
  static const lanEditCoursesBatchDeleted =
      'log_lan_edit_courses_batch_deleted';
  static const lanEditCurrentWeekSet = 'log_lan_edit_current_week_set';
  static const lanEditProfileSwitched = 'log_lan_edit_profile_switched';
  static const lanEditSpreadsheetImported = 'log_lan_edit_spreadsheet_imported';
  static const lanEditSessionStarted = 'log_lan_edit_session_started';
  static const lanEditSessionStopped = 'log_lan_edit_session_stopped';
  static const liveUpdateTestRequested = 'log_live_update_test_requested';
  static const liveUpdateTestNoSelection = 'log_live_update_test_no_selection';
  static const liveUpdateTestSelectionReady =
      'log_live_update_test_selection_ready';
  static const liveUpdateTestSuspendSync = 'log_live_update_test_suspend_sync';
  static const liveUpdateTestStarting = 'log_live_update_test_starting';
  static const liveUpdateTestStarted = 'log_live_update_test_started';
  static const liveUpdateTestFailed = 'log_live_update_test_failed';
  static const logExportTitle = 'log_export_title';
  static const liveUpdateSettingsSyncedKey = 'log_live_update_settings_synced';

  /// 金标联盟公平运行内存（直接中文文案；未进 ARB 时 localizer 原样显示）
  static const fairMemoryTrimHandled = '公平运行内存 TRIM：已清理内存图片缓存（未触碰超级岛/桌面小组件）';
  static const fairMemoryKillHandled = '公平运行内存 KILL：已确认并清理内存缓存（未触碰超级岛/桌面小组件）';

  static String liveUpdateSettingsSynced({
    required bool beforeClass,
    required bool duringClass,
    required bool beforeEnd,
    required bool promote,
    required bool notification,
    required bool countdown,
    required bool courseName,
    required bool location,
  }) =>
      '$liveUpdateSettingsSyncedKey|'
      'beforeClass=$beforeClass|'
      'duringClass=$duringClass|'
      'beforeEnd=$beforeEnd|'
      'promote=$promote|'
      'notification=$notification|'
      'countdown=$countdown|'
      'courseName=$courseName|'
      'location=$location';
}

/// English field keys for structured log viewer display.
const Map<String, String> appLogFieldLabels = {
  'source': 'log_field_source',
  'platform': 'log_field_platform',
  'version': 'log_field_version',
  'buildNumber': 'log_field_build_number',
  'loggingEnabled': 'log_field_logging_enabled',
  'privacyAccepted': 'log_field_privacy_accepted',
  'accepted': 'log_field_accepted',
  'previous': 'log_field_previous',
  'truncated': 'log_field_truncated',
  'truncatedHint': 'log_field_truncated_hint',
  'throwable': 'log_field_throwable',
  'extras': 'log_field_extras',
  'context': 'log_field_context',
  'error': 'log_field_error',
  'brand': 'log_field_brand',
  'manufacturer': 'log_field_manufacturer',
  'model': 'log_field_model',
  'sdkInt': 'log_field_sdk_int',
  'versionName': 'log_field_version_name',
  'channel': 'log_field_channel',
  'hasNotificationPermission': 'log_field_has_notification_permission',
  'hasPromotedPermissionDeclared': 'log_field_has_promoted_permission_declared',
  'canPostPromotedNotifications': 'log_field_can_post_promoted_notifications',
  'ignoringBatteryOptimizations': 'log_field_ignoring_battery_optimizations',
  'keepAliveAccessibilityEnabled': 'log_field_keep_alive_accessibility_enabled',
  'hideFromRecentsEnabled': 'log_field_hide_from_recents_enabled',
  'taskRemovedRecently': 'log_field_task_removed_recently',
  'lastTaskRemovedAt': 'log_field_last_task_removed_at',
  'processImportance': 'log_field_process_importance',
  'autoStartStatus': 'log_field_auto_start_status',
  'liveEnableBeforeClass': 'log_field_live_enable_before_class',
  'liveEnableDuringClass': 'log_field_live_enable_during_class',
  'liveEnableBeforeEnd': 'log_field_live_enable_before_end',
  'livePromoteDuringClass': 'log_field_live_promote_during_class',
  'liveShowDuringClassNotification':
      'log_field_live_show_during_class_notification',
  'liveShowCountdown': 'log_field_live_show_countdown',
  'liveShowStageText': 'log_field_live_show_stage_text',
  'liveShowCourseName': 'log_field_live_show_course_name',
  'liveShowLocation': 'log_field_live_show_location',
  'liveUseShortName': 'log_field_live_use_short_name',
  'liveHidePrefixText': 'log_field_live_hide_prefix_text',
  'liveDuringClassTimeDisplayMode':
      'log_field_live_during_class_time_display_mode',
  'liveEnableMiuiIslandLabelImage':
      'log_field_live_enable_miui_island_label_image',
  'liveMiuiIslandLabelStyle': 'log_field_live_miui_island_label_style',
  'liveMiuiIslandLabelContent': 'log_field_live_miui_island_label_content',
  'liveMiuiIslandLabelFontColor': 'log_field_live_miui_island_label_font_color',
  'liveMiuiIslandLabelFontWeight':
      'log_field_live_miui_island_label_font_weight',
  'liveMiuiIslandLabelRenderQuality':
      'log_field_live_miui_island_label_render_quality',
  'liveMiuiIslandLabelFontSize': 'log_field_live_miui_island_label_font_size',
  'liveMiuiIslandLabelOffsetX': 'log_field_live_miui_island_label_offset_x',
  'liveMiuiIslandLabelOffsetY': 'log_field_live_miui_island_label_offset_y',
  'liveMiuiIslandExpandedIconMode':
      'log_field_live_miui_island_expanded_icon_mode',
  'liveShowBeforeClassMinutes': 'log_field_live_show_before_class_minutes',
  'liveClassReminderStartMinutes':
      'log_field_live_class_reminder_start_minutes',
  'liveEndSecondsCountdownThreshold':
      'log_field_live_end_seconds_countdown_threshold',
  'state': 'log_field_state',
  'route': 'log_field_route',
  'previousRoute': 'log_field_previous_route',
  'profileId': 'log_field_profile_id',
  'reason': 'log_field_reason',
  'clientIp': 'log_field_client_ip',
  'port': 'log_field_port',
  'courseName': 'log_field_course_name',
  'stage': 'log_field_stage',
  'from': 'log_field_from',
  'currentWeek': 'log_field_current_week',
  'weekday': 'log_field_weekday',
  'untilMillis': 'log_field_until_millis',
  'startAtMillis': 'log_field_start_at_millis',
  'mergedCourseCount': 'log_field_merged_course_count',
  'deletedCount': 'log_field_deleted_count',
  'requested': 'log_field_requested',
  'target': 'log_field_target',
  'count': 'log_field_count',
  'value': 'log_field_value',
  'snapshotLength': 'log_field_snapshot_length',
  'storedSnapshotVersion': 'log_field_stored_snapshot_version',
  'intentIsNull': 'log_field_intent_is_null',
  'action': 'log_field_action',
  'step': 'log_field_step',
};

const Map<String, String> appLogCategoryLabels = {
  'app_logger_initialized': 'log_cat_app_logger_initialized',
  'privacy_consent_updated': 'log_cat_privacy_consent_updated',
  'app_log_recording_enabled': 'log_cat_app_log_recording_enabled',
  'startup_flow_started': 'log_cat_startup_flow_started',
  'startup_flow_completed': 'log_cat_startup_flow_completed',
  'startup_flow_failed': 'log_cat_startup_flow_failed',
  'app_lifecycle_state_changed': 'log_cat_app_lifecycle_state_changed',
  'route_pushed': 'log_cat_route_pushed',
  'route_popped': 'log_cat_route_popped',
  'route_replaced': 'log_cat_route_replaced',
  'flutter_framework_error': 'log_cat_flutter_framework_error',
  'flutter_platform_error': 'log_cat_flutter_platform_error',
  'flutter_zone_error': 'log_cat_flutter_zone_error',
  'app_logs_default_migrated': 'log_cat_app_logs_default_migrated',
  'timetable_load_settings_failed': 'log_cat_timetable_load_settings_failed',
  'timetable_load_courses_failed': 'log_cat_timetable_load_courses_failed',
  'timetable_load_current_week_failed':
      'log_cat_timetable_load_current_week_failed',
  'home_widget_pin_support_failed': 'log_cat_home_widget_pin_support_failed',
  'home_widget_pin_request_failed': 'log_cat_home_widget_pin_request_failed',
  'home_widget_sync_failed': 'log_cat_home_widget_sync_failed',
  'home_widget_clear_failed': 'log_cat_home_widget_clear_failed',
  'home_widget_schedule_failed': 'log_cat_home_widget_schedule_failed',
  'miui_live_initialize_failed': 'log_cat_miui_live_initialize_failed',
  'miui_live_open_promoted_settings_failed':
      'log_cat_miui_live_open_promoted_settings_failed',
  'miui_live_open_notification_settings_failed':
      'log_cat_miui_live_open_notification_settings_failed',
  'miui_live_open_autostart_settings_failed':
      'log_cat_miui_live_open_autostart_settings_failed',
  'miui_live_open_battery_settings_failed':
      'log_cat_miui_live_open_battery_settings_failed',
  'miui_live_open_accessibility_settings_failed':
      'log_cat_miui_live_open_accessibility_settings_failed',
  'miui_live_hide_from_recents_failed':
      'log_cat_miui_live_hide_from_recents_failed',
  'live_update_flutter_initialize_failed':
      'log_cat_live_update_flutter_initialize_failed',
  'live_update_start_failed': 'log_cat_live_update_start_failed',
  'live_update_stop_failed': 'log_cat_live_update_stop_failed',
  'live_update_debug_status_failed': 'log_cat_live_update_debug_status_failed',
  'live_update_settings_synced': 'log_cat_live_update_settings_synced',
  'live_update_snapshot_sync_failed':
      'log_cat_live_update_snapshot_sync_failed',
  'live_update_snapshot_clear_failed':
      'log_cat_live_update_snapshot_clear_failed',
  'lan_edit_auth_failed': 'log_cat_lan_edit_auth_failed',
  'lan_edit_course_created': 'log_cat_lan_edit_course_created',
  'lan_edit_course_updated': 'log_cat_lan_edit_course_updated',
  'lan_edit_course_deleted': 'log_cat_lan_edit_course_deleted',
  'lan_edit_course_group_saved': 'log_cat_lan_edit_course_group_saved',
  'lan_edit_merge_imported': 'log_cat_lan_edit_merge_imported',
  'lan_edit_courses_batch_deleted': 'log_cat_lan_edit_courses_batch_deleted',
  'lan_edit_current_week_set': 'log_cat_lan_edit_current_week_set',
  'lan_edit_spreadsheet_imported': 'log_cat_lan_edit_spreadsheet_imported',
  'lan_edit_session_started': 'log_cat_lan_edit_session_started',
  'lan_edit_session_stopped': 'log_cat_lan_edit_session_stopped',
  'live_update_test_requested': 'log_cat_live_update_test_requested',
  'live_update_test_no_selection': 'log_cat_live_update_test_no_selection',
  'live_update_test_selection_ready':
      'log_cat_live_update_test_selection_ready',
  'live_update_test_suspend_sync': 'log_cat_live_update_test_suspend_sync',
  'live_update_test_starting': 'log_cat_live_update_test_starting',
  'live_update_test_started': 'log_cat_live_update_test_started',
  'live_update_test_failed': 'log_cat_live_update_test_failed',
  'live_update_snapshot_settings': 'log_cat_live_update_snapshot_settings',
  'live_update_snapshot_synced': 'log_cat_live_update_snapshot_synced',
  'live_update_snapshot_cleared': 'log_cat_live_update_snapshot_cleared',
  'live_update_alarm_triggered': 'log_cat_live_update_alarm_triggered',
  'live_update_scheduler_resume': 'log_cat_live_update_scheduler_resume',
  'live_update_reschedule_holiday': 'log_cat_live_update_reschedule_holiday',
  'live_update_reschedule_active': 'log_cat_live_update_reschedule_active',
  'live_update_reschedule_scheduled':
      'log_cat_live_update_reschedule_scheduled',
  'live_update_snapshot_parse_failed':
      'log_cat_live_update_snapshot_parse_failed',
  'live_update_snapshot_invalidated_after_upgrade':
      'log_cat_live_update_snapshot_invalidated_after_upgrade',
  'live_update_payload_selected': 'log_cat_live_update_payload_selected',
  'live_update_scheduler_start_failed':
      'log_cat_live_update_scheduler_start_failed',
  'live_update_start_requested': 'log_cat_live_update_start_requested',
  'live_update_stop_requested': 'log_cat_live_update_stop_requested',
  'live_update_service_missing_payload':
      'log_cat_live_update_service_missing_payload',
  'live_update_service_started': 'log_cat_live_update_service_started',
  'live_update_service_start_failed':
      'log_cat_live_update_service_start_failed',
  'live_update_task_removed': 'log_cat_live_update_task_removed',
  'live_update_task_removed_resumed':
      'log_cat_live_update_task_removed_resumed',
  'live_update_before_class_quick_action':
      'log_cat_live_update_before_class_quick_action',
  'live_update_before_class_quick_action_restored':
      'log_cat_live_update_before_class_quick_action_restored',
  'live_update_status_bar_dismissed':
      'log_cat_live_update_status_bar_dismissed',
  'live_update_not_promoted': 'log_cat_live_update_not_promoted',
  'live_update_promoted_not_shown': 'log_cat_live_update_promoted_not_shown',
  'live_update_service_stopped': 'log_cat_live_update_service_stopped',
  'keep_alive_accessibility_connected':
      'log_cat_keep_alive_accessibility_connected',
  'diagnostics_enabled': 'log_cat_diagnostics_enabled',
  'diagnostics_cleared': 'log_cat_diagnostics_cleared',
  'diagnostics_bootstrap': 'log_cat_diagnostics_bootstrap',
  'flutter_diagnostic': 'log_cat_flutter_diagnostic',
  'flutter_diagnostic_event': 'log_cat_flutter_diagnostic_event',
  'render_failed': 'log_cat_render_failed',
  'debug_snapshot': 'log_cat_debug_snapshot',
};
