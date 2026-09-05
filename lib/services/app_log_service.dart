import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_log_messages.dart';
import '../logging/diagnostics_log_parser.dart';
import '../models/timetable_settings.dart';

// 合并热路径的正则提为常量：watchMergedLogsText 的轮询/写入触发会对全量
// 日志文本反复跑这些正则，几千条日志时在循环里 new RegExp 是秒级开销。
final RegExp _logSectionSplitRegex = RegExp(r'\r?\n\r?\n');
final RegExp _logSourceMarkerRegex = RegExp(r'(^|\n)source=');
final RegExp _logLineSplitRegex = RegExp(r'\r?\n');

class AppLogService {
  AppLogService._internal();

  static final AppLogService instance = AppLogService._internal();

  // 注意：shared_preferences 在 Android 侧会自动叠加 'flutter.' 前缀，这里必须写
  // 裸 key，与 StorageService 的写入 key 同源；手写 'flutter.' 会变成
  // flutter.flutter.* 双前缀，永远读不到数据（历史 bug，2026-09 修复）。
  static const String _acceptedPrivacyPolicyKey = 'accepted_privacy_policy';
  static const String _timetableSettingsKey = 'timetable_settings';
  static const String _profilesKey = 'timetable_profiles';
  static const String _activeProfileIdKey = 'active_timetable_profile_id';
  static const int _maxLogBytes = 512 * 1024;
  static const String _logFileName = 'app_runtime.log';
  static const String _logTitleKey = AppLogMessages.logExportTitle;

  bool _initialized = false;
  bool _privacyAccepted = false;
  bool _loggingEnabled = false;
  // 连续写失败计数：日志写失败本身被本类的 catch 吞掉（日志不能破坏
  // 业务流），若磁盘满等故障持续，所有下游静默失败将同时失去观测手段。
  // 连续失败达到阈值时用 debugPrint 突破自吞兜底打一条，提示排查。
  int _consecutiveWriteFailures = 0;
  static const int _writeFailureAlertThreshold = 5;
  PackageInfo? _packageInfo;
  Future<void> _writeQueue = Future<void>.value();
  final StreamController<void> _logChangeController =
      StreamController<void>.broadcast();

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    // 同步置位防并发重入：启动期多个 info() 调用会各自触发 initialize，
    // 若等 await 完成后再置位，同一冷启动会记出多条 app_logger_initialized
    // （2026-09 日志卫生审计：一次冷启动 ×3）。
    _initialized = true;
    // 初始化必须吞掉自身异常：log()/warn() 在未初始化时会先走这里，而调用方
    // 常以 unawaited 方式触发（如 HomeWidgetBindingService 的失败留痕）。测试
    // 环境无 shared_preferences/path_provider 插件时 getInstance 会抛
    // MissingPluginException——若不在此捕获，异步异常会沿 unawaited 链路逃逸，
    // 打挂"当前正在跑"的任意一个测试（表现为 flaky，失败文件随机）。与类
    // 注释的兜底原则一致：日志系统故障不能破坏业务流，最坏情况只是失去观测。
    try {
      final prefs = await SharedPreferences.getInstance();
      _privacyAccepted = prefs.getBool(_acceptedPrivacyPolicyKey) ?? false;
      _loggingEnabled = _readLoggingEnabledFromPrefs(prefs);
    } catch (_) {
      // 保持默认值（privacy=false、logging=false），后续 log() 会被
      // _shouldRecord 直接过滤，不会产生新的写入路径。
    }
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      _packageInfo = null;
    }
    if (_loggingEnabled) {
      // 工程自证事件，debug 档即可：每个 engine 初始化各记一条，不该占 info。
      await debug(
        'app_logger_initialized',
        AppLogMessages.appLoggerInitialized,
        extras: {
          'platform': defaultTargetPlatform.name,
          'version': _packageInfo?.version ?? '',
          'buildNumber': _packageInfo?.buildNumber ?? '',
          'loggingEnabled': _loggingEnabled,
          'privacyAccepted': _privacyAccepted,
        },
      );
    }
  }

  Future<void> updatePrivacyAccepted(bool value) async {
    _privacyAccepted = value;
    if (value && _loggingEnabled) {
      await info(
        'privacy_consent_updated',
        AppLogMessages.privacyConsentUpdated,
        extras: {'accepted': value},
      );
    }
  }

  Future<void> updateLoggingEnabled(bool value) async {
    final previous = _loggingEnabled;
    _loggingEnabled = value;
    if (!value || previous) {
      // 关闭无迁移可记；状态未变化时 RemainsEnabled 无信息量
      // （2026-09 日志卫生审计：每次冷启动重复 ×2）。
      return;
    }
    await info(
      'app_log_recording_enabled',
      AppLogMessages.appLogRecordingEnabled,
      extras: {'previous': previous},
    );
  }

  Future<void> verbose(
    String category,
    String message, {
    Map<String, Object?> extras = const {},
    bool force = false,
  }) => log(
    level: 'verbose',
    category: category,
    message: message,
    extras: extras,
    force: force,
  );

  Future<void> debug(
    String category,
    String message, {
    Map<String, Object?> extras = const {},
    bool force = false,
  }) => log(
    level: 'debug',
    category: category,
    message: message,
    extras: extras,
    force: force,
  );

  Future<void> info(
    String category,
    String message, {
    Map<String, Object?> extras = const {},
    bool force = false,
  }) => log(
    level: 'info',
    category: category,
    message: message,
    extras: extras,
    force: force,
  );

  Future<void> warn(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extras = const {},
    bool force = false,
  }) => log(
    level: 'warn',
    category: category,
    message: message,
    error: error,
    stackTrace: stackTrace,
    extras: extras,
    force: force,
  );

  Future<void> error(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extras = const {},
    bool force = false,
  }) => log(
    level: 'error',
    category: category,
    message: message,
    error: error,
    stackTrace: stackTrace,
    extras: extras,
    force: force,
  );

  Future<void> log({
    required String level,
    required String category,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extras = const {},
    bool force = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_shouldRecord(force: force)) {
      return;
    }

    final normalizedLevel = _normalizeLevel(level);
    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _resolveLogFile();
        await _trimIfNeeded(file);
        final payload = _buildEntryPayload(
          level: normalizedLevel,
          category: category,
          message: message,
          error: error,
          stackTrace: stackTrace,
          extras: extras,
        );
        await file.parent.create(recursive: true);
        await file.writeAsString(payload, mode: FileMode.append, flush: true);
        _consecutiveWriteFailures = 0;
        _notifyLogChanged();
      } catch (e) {
        // Logging must never break app flow.
        _consecutiveWriteFailures++;
        // 取模节流：长磁盘满故障下每 N 次告警一次，而非只在第 5 次打一条
        // 后永久静默。不清零、不递归调用 log()。debugPrint 必须放在 assert
        // 之外：连续写失败往往意味着磁盘满，release 包恰恰最需要这条可见
        // 痕迹，包在 assert 里会被整体剥离，只剩 debug 可见，与本类兜底
        // 目标相反。
        if (_consecutiveWriteFailures % _writeFailureAlertThreshold == 0) {
          debugPrint(
            '[AppLogService] log write failed $_consecutiveWriteFailures '
            'times in a row: $e',
          );
        }
      }
    });
    await _writeQueue;
  }

  Future<String> readAppLogsText({bool forExport = false}) async {
    if (!_initialized) {
      await initialize();
    }
    final file = await _resolveLogFile();
    if (!file.existsSync()) {
      return _buildHeader(includeExportTime: forExport);
    }
    final body = (await file.readAsString()).trim();
    final header = _buildHeader(includeExportTime: forExport);
    if (body.isEmpty) {
      return header;
    }
    return '$header\n$body'.trim();
  }

  Future<String> readMergedLogsText({
    String? nativeRawLog,
    bool forExport = false,
  }) async {
    final appText = await readAppLogsText(forExport: forExport);
    final appBody = _extractBody(appText);
    final nativeBody = _extractBody(nativeRawLog ?? '');

    final sections = <String>[];
    if (appBody.isNotEmpty) {
      sections.add(_injectSourceIntoSections(appBody, source: 'app'));
    }
    if (nativeBody.isNotEmpty) {
      sections.add(_injectSourceIntoSections(nativeBody, source: 'native'));
    }
    final mergedBody = sections
        .where((item) => item.trim().isNotEmpty)
        .join('\n\n')
        .trim();
    final header = _buildHeader(includeExportTime: forExport);
    if (mergedBody.isEmpty) {
      return header;
    }
    return '$header\n$mergedBody'.trim();
  }

  Stream<String> watchMergedLogsText({
    Future<String?> Function()? loadNativeRawLog,
    Duration nativePollInterval = const Duration(seconds: 1),
  }) {
    late final StreamController<String> controller;
    Timer? nativePollTimer;
    Timer? debounceTimer;
    StreamSubscription<void>? logChangeSub;
    var closed = false;
    String? lastEmittedBody;
    // 轮询去重指纹：日志文件（size+mtime）和原生日志文本都没变时跳过整条
    // 重读+重合并管线。没有它，每秒一次的轮询即便日志零新增也会在主
    // isolate 上全量跑一遍读取/切分/注入，日志页因此被自己拖死。
    String? lastAppLogFingerprint = '';
    String? lastNativeRawLog;

    Future<void> emit() async {
      if (closed) {
        return;
      }
      try {
        final nativeRaw = loadNativeRawLog != null
            ? await loadNativeRawLog()
            : null;
        final appFingerprint = await _logFileFingerprint();
        if (appFingerprint == lastAppLogFingerprint &&
            nativeRaw == lastNativeRawLog) {
          return;
        }
        lastAppLogFingerprint = appFingerprint;
        lastNativeRawLog = nativeRaw;
        final text = await readMergedLogsText(nativeRawLog: nativeRaw);
        final body = extractDiagnosticsLogBody(text);
        if (closed || body == lastEmittedBody) {
          return;
        }
        lastEmittedBody = body;
        controller.add(text);
      } catch (error, stackTrace) {
        if (!closed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    void scheduleEmit() {
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 150), emit);
    }

    controller = StreamController<String>(
      onListen: () {
        scheduleEmit();
        logChangeSub = _logChangeController.stream.listen((_) => scheduleEmit());
        if (loadNativeRawLog != null) {
          nativePollTimer = Timer.periodic(
            nativePollInterval,
            (_) => scheduleEmit(),
          );
        }
      },
      onCancel: () {
        closed = true;
        debounceTimer?.cancel();
        nativePollTimer?.cancel();
        logChangeSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<String?> exportMergedLogsFile({String? nativeRawLog}) async {
    final text = await readMergedLogsText(
      nativeRawLog: nativeRawLog,
      forExport: true,
    );
    final exportDir = await getTemporaryDirectory();
    final file = File(
      '${exportDir.path}/mikcb-app-logs-${DateTime.now().millisecondsSinceEpoch}.log',
    );
    await file.writeAsString(text, flush: true);
    return file.path;
  }

  Future<bool> clearAppLogs() async {
    var cleared = false;
    _writeQueue = _writeQueue.then((_) async {
      try {
        final file = await _resolveLogFile();
        if (file.existsSync()) {
          await file.delete();
        }
        cleared = true;
      } catch (_) {
        cleared = false;
      }
    });
    await _writeQueue;
    _notifyLogChanged();
    return cleared;
  }

  void _notifyLogChanged() {
    if (!_logChangeController.isClosed) {
      _logChangeController.add(null);
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _privacyAccepted = false;
    _loggingEnabled = false;
    _packageInfo = null;
    _writeQueue = Future<void>.value();
    _consecutiveWriteFailures = 0;
  }

  @visibleForTesting
  void notifyLogChangedForTesting() => _notifyLogChanged();

  bool _shouldRecord({required bool force}) {
    if (force && !_loggingEnabled) {
      return false;
    }
    return _privacyAccepted && _loggingEnabled;
  }

  bool _readLoggingEnabledFromPrefs(SharedPreferences prefs) {
    final fromProfiles = _readLoggingEnabledFromProfiles(prefs);
    if (fromProfiles != null) {
      return fromProfiles;
    }

    final settingsJson = prefs.getString(_timetableSettingsKey);
    if (settingsJson == null || settingsJson.isEmpty) {
      return TimetableSettings.defaults().liveEnableLocalDiagnostics;
    }
    try {
      return TimetableSettings.fromJsonString(
        settingsJson,
      ).liveEnableLocalDiagnostics;
    } catch (_) {
      return TimetableSettings.defaults().liveEnableLocalDiagnostics;
    }
  }

  bool? _readLoggingEnabledFromProfiles(SharedPreferences prefs) {
    final profilesJson = prefs.getString(_profilesKey);
    if (profilesJson == null || profilesJson.isEmpty) {
      return null;
    }
    try {
      final profiles = jsonDecode(profilesJson) as List<dynamic>;
      if (profiles.isEmpty) {
        return null;
      }
      final activeProfileId = prefs.getString(_activeProfileIdKey);
      Map<String, dynamic>? profile;
      if (activeProfileId != null && activeProfileId.isNotEmpty) {
        for (final item in profiles) {
          final candidate = Map<String, dynamic>.from(item as Map);
          if (candidate['id'] == activeProfileId) {
            profile = candidate;
            break;
          }
        }
      }
      profile ??= Map<String, dynamic>.from(profiles.first as Map);
      final settings = profile['settings'];
      if (settings is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(
        settings,
      )['liveEnableLocalDiagnostics'] as bool?;
    } catch (_) {
      return null;
    }
  }

  Future<File> _resolveLogFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/logs/$_logFileName');
  }

  /// 日志文件的轻量变更指纹（size+mtime 毫秒），文件不存在返回 null。
  /// 只做一次 stat，不读内容，供轮询判断「是否有新东西可合并」。
  Future<String?> _logFileFingerprint() async {
    try {
      final file = await _resolveLogFile();
      final stat = file.statSync();
      return '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _trimIfNeeded(File file) async {
    if (!file.existsSync()) {
      return;
    }
    final length = await file.length();
    if (length <= _maxLogBytes) {
      return;
    }
    final text = await file.readAsString();
    const retainLength = _maxLogBytes ~/ 2;
    final retained = text.length <= retainLength
        ? text
        : text.substring(text.length - retainLength);
    await file.writeAsString(retained.trimLeft(), flush: true);
  }

  String _buildHeader({bool includeExportTime = false}) {
    final versionText = _packageInfo == null
        ? ''
        : '${_packageInfo!.version}+${_packageInfo!.buildNumber}';
    return [
      _logTitleKey,
      if (includeExportTime)
        'exportedAt=${DateTime.now().millisecondsSinceEpoch}',
      'platform=${defaultTargetPlatform.name}',
      if (versionText.isNotEmpty) 'version=$versionText',
      '----',
    ].join('\n');
  }

  String _buildEntryPayload({
    required String level,
    required String category,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extras = const {},
  }) {
    final buffer = StringBuffer()
      ..writeln('time=${DateTime.now().millisecondsSinceEpoch}')
      ..writeln('level=$level')
      ..writeln('source=app')
      ..writeln('category=$category')
      ..writeln('message=$message');

    if (extras.isNotEmpty) {
      buffer.writeln('extras=');
      extras.forEach((key, value) {
        buffer.writeln('  $key=${value ?? 'null'}');
      });
    }
    if (error != null) {
      buffer.writeln('error=$error');
    }
    if (stackTrace != null) {
      buffer.writeln('stackTrace=');
      buffer.writeln(stackTrace.toString().trimRight());
    }
    buffer.writeln();
    return buffer.toString();
  }

  String _normalizeLevel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'error':
      case 'warn':
      case 'info':
      case 'debug':
      case 'verbose':
        return raw.trim().toLowerCase();
      default:
        return 'info';
    }
  }

  String _extractBody(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final parts = normalized.split(diagnosticsBodySeparatorRegex);
    if (parts.length <= 1) {
      return normalized;
    }
    return parts.sublist(1).join('\n----\n').trim();
  }

  String _injectSourceIntoSections(String body, {required String source}) {
    final sections = body
        .split(_logSectionSplitRegex)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((section) {
          if (_logSourceMarkerRegex.hasMatch(section)) {
            return section;
          }
          final lines = section.split(_logLineSplitRegex);
          final insertIndex = lines.indexWhere(
            (line) => line.startsWith('time='),
          );
          if (insertIndex != -1) {
            lines.insert(insertIndex + 1, 'source=$source');
            return lines.join('\n');
          }
          return 'source=$source\n$section';
        })
        .toList(growable: false);
    return sections.join('\n\n');
  }
}
