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

  static const String _acceptedPrivacyPolicyKey =
      'flutter.accepted_privacy_policy';
  static const String _timetableSettingsKey = 'flutter.timetable_settings';
  static const String _profilesKey = 'flutter.timetable_profiles';
  static const String _activeProfileIdKey = 'flutter.active_timetable_profile_id';
  static const int _maxLogBytes = 512 * 1024;
  static const String _logFileName = 'app_runtime.log';
  static const String _logTitleKey = AppLogMessages.logExportTitle;

  bool _initialized = false;
  bool _privacyAccepted = false;
  bool _loggingEnabled = false;
  PackageInfo? _packageInfo;
  Future<void> _writeQueue = Future<void>.value();
  final StreamController<void> _logChangeController =
      StreamController<void>.broadcast();

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _privacyAccepted = prefs.getBool(_acceptedPrivacyPolicyKey) ?? false;
    _loggingEnabled = _readLoggingEnabledFromPrefs(prefs);
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      _packageInfo = null;
    }
    _initialized = true;
    if (_loggingEnabled) {
      await info(
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
    if (!value) {
      return;
    }
    await info(
      'app_log_recording_enabled',
      previous
          ? AppLogMessages.appLogRecordingRemainsEnabled
          : AppLogMessages.appLogRecordingEnabled,
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
    Map<String, Object?> extras = const {},
    bool force = false,
  }) => log(
    level: 'warn',
    category: category,
    message: message,
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
        _notifyLogChanged();
      } catch (_) {
        // Logging must never break app flow.
      }
    });
    await _writeQueue;
  }

  Future<String> readAppLogsText({bool forExport = false}) async {
    if (!_initialized) {
      await initialize();
    }
    final file = await _resolveLogFile();
    if (!await file.exists()) {
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
        if (await file.exists()) {
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
      final stat = await file.stat();
      return '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _trimIfNeeded(File file) async {
    if (!await file.exists()) {
      return;
    }
    final length = await file.length();
    if (length <= _maxLogBytes) {
      return;
    }
    final text = await file.readAsString();
    final retainLength = _maxLogBytes ~/ 2;
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
