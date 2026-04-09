import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/timetable_settings.dart';

class AppLogService {
  AppLogService._internal();

  static final AppLogService instance = AppLogService._internal();

  static const String _acceptedPrivacyPolicyKey =
      'flutter.accepted_privacy_policy';
  static const String _timetableSettingsKey = 'flutter.timetable_settings';
  static const int _maxLogBytes = 512 * 1024;
  static const String _logFileName = 'app_runtime.log';
  static const String _logTitle = '轻屿课表 - 应用日志';

  bool _initialized = false;
  bool _privacyAccepted = false;
  bool _loggingEnabled = false;
  PackageInfo? _packageInfo;
  Future<void> _writeQueue = Future<void>.value();

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
    await info(
      'app_logger_initialized',
      'App log service initialized',
      extras: {
        'platform': defaultTargetPlatform.name,
        'version': _packageInfo?.version ?? '',
        'buildNumber': _packageInfo?.buildNumber ?? '',
        'loggingEnabled': _loggingEnabled,
        'privacyAccepted': _privacyAccepted,
      },
      force: true,
    );
  }

  Future<void> updatePrivacyAccepted(bool value) async {
    _privacyAccepted = value;
    if (value) {
      await info(
        'privacy_consent_updated',
        'Privacy consent updated',
        extras: {'accepted': value},
        force: true,
      );
    }
  }

  Future<void> updateLoggingEnabled(bool value) async {
    final previous = _loggingEnabled;
    _loggingEnabled = value;
    if (value) {
      await info(
        'app_log_recording_enabled',
        previous
            ? 'App log recording remains enabled'
            : 'App log recording enabled',
        extras: {'previous': previous},
        force: true,
      );
    }
  }

  Future<void> verbose(
    String category,
    String message, {
    Map<String, Object?> extras = const {},
    bool force = false,
  }) =>
      log(
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
  }) =>
      log(
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
  }) =>
      log(
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
  }) =>
      log(
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
  }) =>
      log(
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
      } catch (_) {
        // Logging must never break app flow.
      }
    });
    await _writeQueue;
  }

  Future<String> readAppLogsText() async {
    if (!_initialized) {
      await initialize();
    }
    final file = await _resolveLogFile();
    if (!await file.exists()) {
      return _buildHeader();
    }
    final body = (await file.readAsString()).trim();
    final header = _buildHeader();
    if (body.isEmpty) {
      return header;
    }
    return '$header\n$body'.trim();
  }

  Future<String> readMergedLogsText({
    String? nativeRawLog,
  }) async {
    final appText = await readAppLogsText();
    final appBody = _extractBody(appText);
    final nativeBody = _extractBody(nativeRawLog ?? '');

    final sections = <String>[];
    if (appBody.isNotEmpty) {
      sections.add(_injectSourceIntoSections(appBody, source: 'app'));
    }
    if (nativeBody.isNotEmpty) {
      sections.add(_injectSourceIntoSections(nativeBody, source: 'native'));
    }
    final mergedBody =
        sections.where((item) => item.trim().isNotEmpty).join('\n\n').trim();
    final header = _buildHeader();
    if (mergedBody.isEmpty) {
      return header;
    }
    return '$header\n$mergedBody'.trim();
  }

  Future<String?> exportMergedLogsFile({
    String? nativeRawLog,
  }) async {
    final text = await readMergedLogsText(nativeRawLog: nativeRawLog);
    final exportDir = await getTemporaryDirectory();
    final file = File(
      '${exportDir.path}/mikcb-app-logs-${DateTime.now().millisecondsSinceEpoch}.log',
    );
    await file.writeAsString(text, flush: true);
    return file.path;
  }

  Future<bool> clearAppLogs() async {
    try {
      final file = await _resolveLogFile();
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _shouldRecord({required bool force}) {
    return _privacyAccepted && (_loggingEnabled || force);
  }

  bool _readLoggingEnabledFromPrefs(SharedPreferences prefs) {
    final settingsJson = prefs.getString(_timetableSettingsKey);
    if (settingsJson == null || settingsJson.isEmpty) {
      return TimetableSettings.defaults().liveEnableLocalDiagnostics;
    }
    return TimetableSettings.fromJsonString(settingsJson)
        .liveEnableLocalDiagnostics;
  }

  Future<File> _resolveLogFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/logs/$_logFileName');
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

  String _buildHeader() {
    final versionText = _packageInfo == null
        ? ''
        : '${_packageInfo!.version}+${_packageInfo!.buildNumber}';
    return [
      _logTitle,
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
    final parts = normalized
        .split(RegExp(r'\n----\n|\r\n----\r\n|\n----\r\n|\r\n----\n'));
    if (parts.length <= 1) {
      return normalized;
    }
    return parts.sublist(1).join('\n----\n').trim();
  }

  String _injectSourceIntoSections(String body, {required String source}) {
    final sections = body
        .split(RegExp(r'\r?\n\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((section) {
      if (RegExp(r'(^|\n)source=').hasMatch(section)) {
        return section;
      }
      final lines = section.split(RegExp(r'\r?\n'));
      final insertIndex = lines.indexWhere((line) => line.startsWith('time='));
      if (insertIndex != -1) {
        lines.insert(insertIndex + 1, 'source=$source');
        return lines.join('\n');
      }
      return 'source=$source\n$section';
    }).toList(growable: false);
    return sections.join('\n\n');
  }
}
