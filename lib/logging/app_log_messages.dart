/// Centralized Chinese log messages for persisted app diagnostics.
/// Categories remain English snake_case for level inference and grep.
abstract final class AppLogMessages {
  // App log service
  static const appLoggerInitialized = '应用日志服务已初始化';
  static const privacyConsentUpdated = '隐私协议同意状态已更新';
  static const appLogRecordingEnabled = '应用日志记录已开启';
  static const appLogRecordingRemainsEnabled = '应用日志记录保持开启';

  // Startup & lifecycle
  static const startupFlowStarted = '启动流程处理已开始';
  static const startupFlowCompletedNoOnboarding = '启动流程已完成（无需引导页）';
  static const startupFlowCompletedAfterGuide = '启动流程已完成（经过引导页）';
  static const startupFlowFailed = '启动流程失败，进入降级模式';
  static const appLifecycleChanged = '应用生命周期已变更';
  static const navigatorRouteReplaced = '导航路由已替换';
  static const navigatorRouteChanged = '导航路由已变更';

  // Timetable provider
  static const appLogsDefaultMigrated = '迁移时已默认开启应用日志记录';
  static const timetableLoadSettingsFailed = '加载课表设置失败';
  static const timetableLoadCoursesFailed = '加载课程数据失败';
  static const timetableLoadCurrentWeekFailed = '加载当前周次失败';

  // Home widget
  static const homeWidgetPinSupportFailed = '检查桌面小组件固定支持失败';
  static const homeWidgetPinRequestFailed = '请求固定桌面小组件失败';
  static const homeWidgetSyncFailed = '同步桌面小组件快照失败';
  static const homeWidgetClearFailed = '清空桌面小组件快照失败';
  static const homeWidgetScheduleFailed = '调度桌面小组件刷新失败';

  // MIUI live activities
  static const miuiLiveInitializeFailed = '初始化 MIUI 超级岛通道失败';
  static const miuiLiveOpenPromotedSettingsFailed = '打开超级岛权限设置失败';
  static const miuiLiveOpenNotificationSettingsFailed = '打开通知设置失败';
  static const miuiLiveOpenAutostartSettingsFailed = '打开自启动设置失败';
  static const miuiLiveOpenBatterySettingsFailed = '打开电池优化设置失败';
  static const miuiLiveOpenAccessibilitySettingsFailed = '打开无障碍设置失败';
  static const miuiLiveHideFromRecentsFailed = '更新「从最近任务隐藏」失败';
  static const liveUpdateStartFailed = '从 Flutter 启动超级岛失败';
  static const liveUpdateStopFailed = '从 Flutter 停止超级岛失败';
  static const liveUpdateDebugStatusFailed = '获取原生超级岛调试状态失败';
  static const liveUpdateSnapshotSyncFailed = '同步超级岛课表快照失败';
  static const liveUpdateSnapshotClearFailed = '清空超级岛课表快照失败';

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
      'Flutter 超级岛设置已同步：'
      '课前=$beforeClass，'
      '课中=$duringClass，'
      '下课前=$beforeEnd，'
      '提升=$promote，'
      '通知=$notification，'
      '倒计时=$countdown，'
      '课程名=$courseName，'
      '地点=$location';

  // LAN edit audit
  static const lanEditAuthFailed = '局域网编辑：认证失败';
  static const lanEditCourseCreated = '局域网编辑：已创建课程';
  static const lanEditCourseUpdated = '局域网编辑：已更新课程';
  static const lanEditCourseDeleted = '局域网编辑：已删除课程';
  static const lanEditCourseGroupSaved = '局域网编辑：已保存课程组';
  static const lanEditMergeImported = '局域网编辑：已导入合并备份';
  static const lanEditCoursesBatchDeleted = '局域网编辑：已批量删除课程';
  static const lanEditCurrentWeekSet = '局域网编辑：已设置当前周次';
  static const lanEditSpreadsheetImported = '局域网编辑：已导入表格';
  static const lanEditSessionStarted = '局域网编辑：会话已启动';
  static const lanEditSessionStopped = '局域网编辑：会话已停止';

  // Live update manual test (settings screen)
  static const liveUpdateTestRequested = '用户请求手动超级岛测试通知';
  static const liveUpdateTestNoSelection = '手动超级岛测试：未找到可用课程';
  static const liveUpdateTestSelectionReady = '手动超级岛测试：已解析目标课程';
  static const liveUpdateTestSuspendSync = '手动超级岛测试：已临时暂停定时同步';
  static const liveUpdateTestStarting = '手动超级岛测试：正在启动原生超级岛';
  static const liveUpdateTestStarted = '手动超级岛测试：已成功请求原生超级岛';
  static const liveUpdateTestFailed = '手动超级岛测试：原生超级岛出现前失败';
}

/// Chinese display labels for log field keys in the structured viewer.
const Map<String, String> appLogFieldLabels = {
  // Header / meta
  'source': '来源',
  'platform': '平台',
  'version': '版本',
  'buildNumber': '构建号',
  'loggingEnabled': '日志记录',
  'privacyAccepted': '隐私协议',
  'accepted': '已同意',
  'previous': '先前状态',
  'truncated': '已截断',
  'truncatedHint': '截断提示',
  'throwable': '异常',
  'extras': '附加信息',
  'context': '设备上下文',
  'error': '错误',
  // Device context
  'brand': '品牌',
  'manufacturer': '制造商',
  'model': '型号',
  'sdkInt': 'SDK 版本',
  'versionName': '版本名',
  'channel': '渠道',
  'hasNotificationPermission': '通知权限',
  'hasPromotedPermissionDeclared': '已声明提升通知权限',
  'canPostPromotedNotifications': '可发布提升通知',
  'ignoringBatteryOptimizations': '忽略电池优化',
  'keepAliveAccessibilityEnabled': '无障碍保活已启用',
  'hideFromRecentsEnabled': '从最近任务隐藏',
  'taskRemovedRecently': '近期任务被移除',
  'lastTaskRemovedAt': '上次任务移除时间',
  'processImportance': '进程重要性',
  'autoStartStatus': '自启动状态',
  // Live update settings
  'liveEnableBeforeClass': '课前超级岛',
  'liveEnableDuringClass': '课中超级岛',
  'liveEnableBeforeEnd': '下课前超级岛',
  'livePromoteDuringClass': '课中提升通知',
  'liveShowDuringClassNotification': '课中状态栏通知',
  'liveShowCountdown': '显示倒计时',
  'liveShowStageText': '显示阶段文字',
  'liveShowCourseName': '显示课程名',
  'liveShowLocation': '显示地点',
  'liveUseShortName': '使用简称',
  'liveHidePrefixText': '隐藏前缀文字',
  'liveDuringClassTimeDisplayMode': '课中时间显示模式',
  'liveEnableMiuiIslandLabelImage': '岛标签图片',
  'liveMiuiIslandLabelStyle': '岛标签样式',
  'liveMiuiIslandLabelContent': '岛标签内容',
  'liveMiuiIslandLabelFontColor': '岛标签字体颜色',
  'liveMiuiIslandLabelFontWeight': '岛标签字重',
  'liveMiuiIslandLabelRenderQuality': '岛标签渲染质量',
  'liveMiuiIslandLabelFontSize': '岛标签字号',
  'liveMiuiIslandLabelOffsetX': '岛标签 X 偏移',
  'liveMiuiIslandLabelOffsetY': '岛标签 Y 偏移',
  'liveMiuiIslandExpandedIconMode': '展开图标模式',
  'liveShowBeforeClassMinutes': '课前显示分钟数',
  'liveClassReminderStartMinutes': '上课提醒开始分钟',
  'liveEndSecondsCountdownThreshold': '下课秒倒计时阈值',
  // Common extras
  'state': '状态',
  'route': '路由',
  'previousRoute': '先前路由',
  'profileId': '课表配置 ID',
  'reason': '原因',
  'clientIp': '客户端 IP',
  'port': '端口',
  'courseName': '课程名',
  'stage': '阶段',
  'from': '来源页面',
  'currentWeek': '当前周次',
  'weekday': '星期',
  'untilMillis': '暂停截止时间',
  'startAtMillis': '开始时间',
  'mergedCourseCount': '合并课程数',
  'deletedCount': '删除数量',
  'requested': '请求数量',
  'target': '目标',
  'count': '数量',
  'value': '值',
  'snapshotLength': '快照长度',
  'storedSnapshotVersion': '存储快照版本',
  'intentIsNull': 'Intent 为空',
  'action': '操作',
  'step': '步骤',
};

String categoryDisplayLabel(String category) =>
    appLogCategoryLabels[category] ?? category;

String fieldDisplayLabel(String key) => appLogFieldLabels[key] ?? key;

/// Chinese display labels for log categories in the structured viewer.
const Map<String, String> appLogCategoryLabels = {
  'app_logger_initialized': '应用日志：初始化',
  'privacy_consent_updated': '应用日志：隐私协议',
  'app_log_recording_enabled': '应用日志：记录开关',
  'startup_flow_started': '启动流程：开始',
  'startup_flow_completed': '启动流程：完成',
  'startup_flow_failed': '启动流程：失败',
  'app_lifecycle_state_changed': '应用生命周期',
  'route_pushed': '路由：入栈',
  'route_popped': '路由：出栈',
  'route_replaced': '路由：替换',
  'flutter_framework_error': 'Flutter 框架错误',
  'flutter_platform_error': 'Flutter 平台错误',
  'flutter_zone_error': 'Flutter Zone 错误',
  'app_logs_default_migrated': '应用日志：迁移',
  'timetable_load_settings_failed': '课表：加载设置失败',
  'timetable_load_courses_failed': '课表：加载课程失败',
  'timetable_load_current_week_failed': '课表：加载周次失败',
  'home_widget_pin_support_failed': '桌面小组件：检查固定支持',
  'home_widget_pin_request_failed': '桌面小组件：请求固定',
  'home_widget_sync_failed': '桌面小组件：同步失败',
  'home_widget_clear_failed': '桌面小组件：清空失败',
  'home_widget_schedule_failed': '桌面小组件：调度刷新',
  'miui_live_initialize_failed': '超级岛：初始化失败',
  'miui_live_open_promoted_settings_failed': '超级岛：打开权限设置',
  'miui_live_open_notification_settings_failed': '超级岛：打开通知设置',
  'miui_live_open_autostart_settings_failed': '超级岛：打开自启动设置',
  'miui_live_open_battery_settings_failed': '超级岛：打开电池优化',
  'miui_live_open_accessibility_settings_failed': '超级岛：打开无障碍设置',
  'miui_live_hide_from_recents_failed': '超级岛：隐藏最近任务',
  'live_update_flutter_initialize_failed': '超级岛：Flutter 初始化失败',
  'live_update_start_failed': '超级岛：启动失败',
  'live_update_stop_failed': '超级岛：停止失败',
  'live_update_debug_status_failed': '超级岛：调试状态失败',
  'live_update_settings_synced': '超级岛：设置已同步',
  'live_update_snapshot_sync_failed': '超级岛：快照同步失败',
  'live_update_snapshot_clear_failed': '超级岛：快照清空失败',
  'lan_edit_auth_failed': '局域网编辑：认证',
  'lan_edit_course_created': '局域网编辑：创建课程',
  'lan_edit_course_updated': '局域网编辑：更新课程',
  'lan_edit_course_deleted': '局域网编辑：删除课程',
  'lan_edit_course_group_saved': '局域网编辑：保存课程组',
  'lan_edit_merge_imported': '局域网编辑：合并导入',
  'lan_edit_courses_batch_deleted': '局域网编辑：批量删除',
  'lan_edit_current_week_set': '局域网编辑：设置周次',
  'lan_edit_spreadsheet_imported': '局域网编辑：表格导入',
  'lan_edit_session_started': '局域网编辑：会话启动',
  'lan_edit_session_stopped': '局域网编辑：会话停止',
  'live_update_test_requested': '超级岛测试：请求',
  'live_update_test_no_selection': '超级岛测试：无课程',
  'live_update_test_selection_ready': '超级岛测试：已选课程',
  'live_update_test_suspend_sync': '超级岛测试：暂停同步',
  'live_update_test_starting': '超级岛测试：启动中',
  'live_update_test_started': '超级岛测试：已启动',
  'live_update_test_failed': '超级岛测试：失败',
  'live_update_snapshot_settings': '超级岛：快照设置',
  'live_update_snapshot_synced': '超级岛：快照已同步',
  'live_update_snapshot_cleared': '超级岛：快照已清空',
  'live_update_alarm_triggered': '超级岛：闹钟触发',
  'live_update_scheduler_resume': '超级岛：调度恢复',
  'live_update_reschedule_holiday': '超级岛：节假日跳过',
  'live_update_reschedule_active': '超级岛：立即启动',
  'live_update_reschedule_scheduled': '超级岛：已调度',
  'live_update_snapshot_parse_failed': '超级岛：快照解析失败',
  'live_update_snapshot_invalidated_after_upgrade': '超级岛：升级后快照失效',
  'live_update_payload_selected': '超级岛：已选负载',
  'live_update_scheduler_start_failed': '超级岛：调度启动失败',
  'live_update_start_requested': '超级岛：请求启动',
  'live_update_stop_requested': '超级岛：请求停止',
  'live_update_service_missing_payload': '超级岛：服务缺少负载',
  'live_update_service_started': '超级岛：服务已启动',
  'live_update_service_start_failed': '超级岛：服务启动失败',
  'live_update_task_removed': '超级岛：任务被移除',
  'live_update_task_removed_resumed': '超级岛：任务移除后恢复',
  'live_update_before_class_quick_action': '超级岛：课前快捷操作',
  'live_update_before_class_quick_action_restored': '超级岛：课前快捷操作已恢复',
  'live_update_status_bar_dismissed': '超级岛：状态栏通知已关闭',
  'live_update_not_promoted': '超级岛：未提升通知',
  'live_update_promoted_not_shown': '超级岛：提升未显示',
  'live_update_service_stopped': '超级岛：服务已停止',
  'keep_alive_accessibility_connected': '保活：无障碍已连接',
  'diagnostics_enabled': '诊断：已开启',
  'diagnostics_cleared': '诊断：已清空',
  'diagnostics_bootstrap': '诊断：引导',
  'flutter_diagnostic': 'Flutter 诊断',
  'flutter_diagnostic_event': 'Flutter 诊断事件',
  'render_failed': '渲染失败',
  'debug_snapshot': '调试快照',
};
