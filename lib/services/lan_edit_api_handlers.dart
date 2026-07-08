import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../logging/app_log_messages.dart';
import 'lan_edit_audit_log.dart';
import 'lan_edit_host.dart';
import 'lan_edit_network_utils.dart';
import 'lan_edit_provider_host.dart';
import 'lan_edit_session.dart';
import 'spreadsheet_import_service.dart';
import 'week_expression_parser.dart';

class LanEditApiHandlers {
  final LanEditHost host;
  final LanEditSession session;

  LanEditApiHandlers({required this.host, required this.session});

  Future<void> handle(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        await _writeJson(request, 204, const {});
        return;
      }

      final path = request.uri.path;
      if (path == '/api/v1/health') {
        await _writeJson(request, 200, {
          'ok': true,
          'serverTime': DateTime.now().toIso8601String(),
        });
        return;
      }

      if (path == '/api/v1/auth/verify' && request.method == 'POST') {
        await _handleVerify(request);
        return;
      }

      if (!await _authorize(request)) {
        return;
      }

      if (path == '/api/v1/session' && request.method == 'GET') {
        await host.ensureInitialized();
        await _writeJson(request, 200, {
          'profileName': host.activeProfileName,
          'activeWeek': host.currentWeek,
          'semesterWeekCount': host.semesterWeekCount,
          'serverTime': DateTime.now().toIso8601String(),
          'expiresAt': session.expiresAt.toIso8601String(),
        });
        return;
      }

      if (path == '/api/v1/session' && request.method == 'PATCH') {
        await _handlePatchSession(request);
        return;
      }

      if (path == '/api/v1/import/spreadsheet' && request.method == 'POST') {
        await _handleSpreadsheetImport(request);
        return;
      }

      if (path == '/api/v1/import/merge' && request.method == 'POST') {
        await _handleMergeImport(request);
        return;
      }

      if (path == '/api/v1/courses/batch-delete' && request.method == 'POST') {
        await _handleBatchDeleteCourses(request);
        return;
      }

      if (path == '/api/v1/week-expression/parse' && request.method == 'POST') {
        await _handleParseWeekExpression(request);
        return;
      }

      if (path == '/api/v1/meta' && request.method == 'GET') {
        await host.ensureInitialized();
        await _writeJson(request, 200, host.buildMetaJson());
        return;
      }

      if (path == '/api/v1/profile/active' && request.method == 'GET') {
        await host.ensureInitialized();
        await _writeJson(
          request,
          200,
          jsonDecode(host.buildProfileBackupJson()) as Map<String, dynamic>,
        );
        return;
      }

      if (path == '/api/v1/profile/active' && request.method == 'PUT') {
        await _handleImportProfile(request);
        return;
      }

      if (path == '/api/v1/courses' && request.method == 'GET') {
        await host.ensureInitialized();
        await _writeJson(request, 200, {
          'courses': host.courses.map((course) => course.toJson()).toList(),
        });
        return;
      }

      if (path == '/api/v1/courses' && request.method == 'POST') {
        await _handleCreateCourse(request);
        return;
      }

      if (path == '/api/v1/courses/group' && request.method == 'PUT') {
        await _handleReplaceCourseGroup(request);
        return;
      }

      final courseMatch = RegExp(r'^/api/v1/courses/([^/]+)$').firstMatch(path);
      if (courseMatch != null) {
        final courseId = Uri.decodeComponent(courseMatch.group(1)!);
        if (request.method == 'GET') {
          await _handleGetCourse(request, courseId);
          return;
        }
        if (request.method == 'PATCH') {
          await _handlePatchCourse(request, courseId);
          return;
        }
        if (request.method == 'DELETE') {
          await _handleDeleteCourse(request, courseId);
          return;
        }
      }

      await _writeError(request, 404, 'not_found', 'Resource not found');
    } catch (error) {
      await _writeError(
        request,
        500,
        'internal_error',
        error is ArgumentError ? error.message ?? '$error' : '$error',
      );
    }
  }

  Future<void> _handleVerify(HttpRequest request) async {
    final clientIp = clientIpFromRequest(request);
    if (session.isExpired) {
      lanEditAuditInfo(
        'lan_edit_auth_failed',
        AppLogMessages.lanEditAuthFailed,
        extras: {'reason': 'session_expired', 'clientIp': clientIp},
      );
      await _writeError(request, 401, 'session_expired', 'Session expired');
      return;
    }
    if (session.isPinRateLimited(clientIp)) {
      lanEditAuditInfo(
        'lan_edit_auth_failed',
        AppLogMessages.lanEditAuthFailed,
        extras: {'reason': 'rate_limited', 'clientIp': clientIp},
      );
      await _writeError(request, 429, 'rate_limited', 'Too many PIN attempts');
      return;
    }

    final body = await _readJsonBody(request);
    final pin = body['pin']?.toString() ?? '';
    if (!session.verifyPin(pin, clientIp)) {
      lanEditAuditInfo(
        'lan_edit_auth_failed',
        AppLogMessages.lanEditAuthFailed,
        extras: {'reason': 'invalid_pin', 'clientIp': clientIp},
      );
      await _writeError(request, 401, 'invalid_pin', 'Invalid PIN');
      return;
    }

    await _writeJson(request, 200, {
      'token': session.token,
      'expiresAt': session.expiresAt.toIso8601String(),
    });
  }

  Future<void> _handleCreateCourse(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      final context = _courseContext();
      final draft = LanEditProviderHost.courseFromApiJson(
        body,
        sections: context.sections,
        semesterWeekCount: context.semesterWeekCount,
      );
      if (draft.name.trim().isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'course_name_required');
        return;
      }
      final created = await host.createCourse(draft);
      lanEditAuditInfo(
        'lan_edit_course_created',
        AppLogMessages.lanEditCourseCreated,
        extras: {'courseId': created.id, 'courseName': created.name},
      );
      await _writeJson(request, 201, created.toJson());
    } on ArgumentError catch (error) {
      await _writeError(
        request,
        400,
        'invalid_request',
        error.message ?? '$error',
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleGetCourse(HttpRequest request, String courseId) async {
    await host.ensureInitialized();
    final course = host.findCourse(courseId);
    if (course == null) {
      await _writeError(request, 404, 'not_found', 'Course not found');
      return;
    }
    await _writeJson(request, 200, course.toJson());
  }

  Future<void> _handlePatchCourse(HttpRequest request, String courseId) async {
    try {
      await host.ensureInitialized();
      final existing = host.findCourse(courseId);
      if (existing == null) {
        await _writeError(request, 404, 'not_found', 'Course not found');
        return;
      }
      final patch = await _readJsonBody(request);
      final context = _courseContext();
      final updated = LanEditProviderHost.mergeCoursePatch(
        existing,
        patch,
        sections: context.sections,
        semesterWeekCount: context.semesterWeekCount,
      );
      if (updated.name.trim().isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'course_name_required');
        return;
      }
      await host.updateCourse(updated);
      lanEditAuditInfo(
        'lan_edit_course_updated',
        AppLogMessages.lanEditCourseUpdated,
        extras: {'courseId': updated.id, 'courseName': updated.name},
      );
      await _writeJson(request, 200, updated.toJson());
    } on ArgumentError catch (error) {
      await _writeError(
        request,
        400,
        'invalid_request',
        error.message ?? '$error',
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleDeleteCourse(HttpRequest request, String courseId) async {
    try {
      await host.ensureInitialized();
      final existing = host.findCourse(courseId);
      if (existing == null) {
        await _writeError(request, 404, 'not_found', 'Course not found');
        return;
      }
      await host.deleteCourse(courseId);
      lanEditAuditInfo(
        'lan_edit_course_deleted',
        AppLogMessages.lanEditCourseDeleted,
        extras: {'courseId': courseId, 'courseName': existing.name},
      );
      await _writeJson(request, 200, {'deleted': true, 'id': courseId});
    } on ArgumentError catch (error) {
      await _writeError(
        request,
        400,
        'invalid_request',
        error.message ?? '$error',
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleReplaceCourseGroup(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      final originalName = body['originalName']?.toString();
      final rawSlots = body['slots'];
      if (rawSlots is! List || rawSlots.isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'at_least_one_schedule_slot');
        return;
      }

      final context = _courseContext();
      final slots = <Course>[];
      for (final item in rawSlots) {
        if (item is! Map) {
          await _writeError(
            request,
            400,
            'invalid_request',
            'Invalid slot entry',
          );
          return;
        }
        final slotMap = Map<String, dynamic>.from(item);
        final courseName =
            (slotMap['name'] as String?)?.trim() ??
            originalName?.trim() ??
            '课程';
        LanEditProviderHost.applyWeekExpressionFields(
          slotMap,
          courseName: courseName,
          semesterWeekCount: context.semesterWeekCount,
        );
        slots.add(
          LanEditProviderHost.courseFromApiJson(
            slotMap,
            sections: context.sections,
            semesterWeekCount: context.semesterWeekCount,
            existingId: slotMap['id'] as String?,
          ),
        );
      }

      if (slots.first.name.trim().isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'course_name_required');
        return;
      }

      final saved = await host.replaceCourseGroup(
        originalName: originalName,
        slots: slots,
      );
      lanEditAuditInfo(
        'lan_edit_course_group_saved',
        AppLogMessages.lanEditCourseGroupSaved,
        extras: {
          'originalName': originalName,
          'courseName': saved.first.name,
          'scheduleCount': saved.length,
        },
      );
      await _writeJson(request, 200, {
        'courses': saved.map((course) => course.toJson()).toList(),
      });
    } on ArgumentError catch (error) {
      await _writeError(
        request,
        400,
        'invalid_request',
        error.message ?? '$error',
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleImportProfile(HttpRequest request) async {
    await host.ensureInitialized();
    final body = await _readBody(request);
    await host.importProfileBackupJson(body);
    await _writeJson(request, 200, {'imported': true});
  }

  Future<void> _handleMergeImport(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readBody(request);
      if (body.trim().isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'backup_content_required');
        return;
      }
      final count = await host.importMergeBackupJson(body);
      lanEditAuditInfo(
        'lan_edit_merge_imported',
        AppLogMessages.lanEditMergeImported,
        extras: {'mergedCourseCount': count},
      );
      await _writeJson(request, 200, {'mergedCount': count});
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleBatchDeleteCourses(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      final rawIds = body['ids'];
      if (rawIds is! List || rawIds.isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'ids 不能为空');
        return;
      }
      final ids = rawIds.map((item) => item.toString()).toList();
      final deletedCount = await host.deleteCoursesBatch(ids);
      lanEditAuditInfo(
        'lan_edit_courses_batch_deleted',
        AppLogMessages.lanEditCoursesBatchDeleted,
        extras: {'deletedCount': deletedCount, 'requested': ids.length},
      );
      await _writeJson(request, 200, {'deletedCount': deletedCount});
    } on ArgumentError catch (error) {
      await _writeError(
        request,
        400,
        'invalid_request',
        error.message ?? '$error',
      );
    }
  }

  Future<void> _handlePatchSession(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      final week = (body['currentWeek'] as num?)?.toInt();
      if (week == null || week < 1) {
        await _writeError(request, 400, 'invalid_request', 'currentWeek 无效');
        return;
      }
      if (week > host.semesterWeekCount) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'currentWeek 不能超过学期周数 ${host.semesterWeekCount}',
        );
        return;
      }
      await host.setCurrentWeek(week);
      lanEditAuditInfo(
        'lan_edit_current_week_set',
        AppLogMessages.lanEditCurrentWeekSet,
        extras: {'currentWeek': week},
      );
      await _writeJson(request, 200, {'currentWeek': host.currentWeek});
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleSpreadsheetImport(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      final fileName = body['fileName']?.toString() ?? 'import.csv';
      final encoded = body['contentBase64']?.toString() ?? '';
      if (encoded.trim().isEmpty) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'contentBase64 不能为空',
        );
        return;
      }
      final replaceExisting = body['replaceExisting'] == true;
      late final List<int> bytes;
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        await _writeError(request, 400, 'invalid_request', 'contentBase64 无效');
        return;
      }
      final service = SpreadsheetImportService();
      final result = service.parseBytes(
        bytes,
        fileName: fileName,
        settings: host.timetableSettings,
      );
      if (result.courses.isEmpty) {
        await _writeJson(request, 200, {
          'importedCount': 0,
          'warnings': result.warnings,
          'format': result.format,
        });
        return;
      }
      final count = await host.importSpreadsheetCourses(
        result,
        replaceExisting: replaceExisting,
      );
      lanEditAuditInfo(
        'lan_edit_spreadsheet_imported',
        AppLogMessages.lanEditSpreadsheetImported,
        extras: {
          'importedCount': count,
          'replaceExisting': replaceExisting,
          'format': result.format,
        },
      );
      await _writeJson(request, 200, {
        'importedCount': count,
        'warnings': result.warnings,
        'format': result.format,
      });
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleParseWeekExpression(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      final expression = body['expression']?.toString().trim() ?? '';
      if (expression.isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'expression 不能为空');
        return;
      }
      final itemName = body['itemName']?.toString().trim() ?? '课程';
      final warnings = <String>[];
      final weeks = WeekExpressionParser.parse(
        expression,
        itemName: itemName,
        semesterWeekCount: host.semesterWeekCount,
        warnings: warnings,
      );
      await _writeJson(request, 200, {'weeks': weeks, 'warnings': warnings});
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<bool> _authorize(HttpRequest request) async {
    final clientIp = clientIpFromRequest(request);
    if (session.isExpired) {
      lanEditAuditInfo(
        'lan_edit_auth_failed',
        AppLogMessages.lanEditAuthFailed,
        extras: {'reason': 'session_expired', 'clientIp': clientIp},
      );
      await _writeError(request, 401, 'session_expired', 'Session expired');
      return false;
    }
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    final token = _extractBearerToken(header);
    if (!session.verifyTokenForRequest(token, clientIp)) {
      lanEditAuditInfo(
        'lan_edit_auth_failed',
        AppLogMessages.lanEditAuthFailed,
        extras: {
          'reason': token == null || token.isEmpty
              ? 'missing_token'
              : 'invalid_token',
          'clientIp': clientIp,
        },
      );
      await _writeError(request, 401, 'unauthorized', 'Unauthorized');
      return false;
    }
    return true;
  }

  String? _extractBearerToken(String? header) {
    if (header == null) {
      return null;
    }
    const prefix = 'Bearer ';
    if (!header.startsWith(prefix)) {
      return null;
    }
    return header.substring(prefix.length).trim();
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final raw = await _readBody(request);
    if (raw.trim().isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  }

  Future<String> _readBody(HttpRequest request) async {
    return utf8.decodeStream(request);
  }

  Future<void> _writeJson(
    HttpRequest request,
    int statusCode,
    Object body,
  ) async {
    try {
      request.response.statusCode = statusCode;
      if (statusCode != 204) {
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set('Cache-Control', 'no-store');
        request.response.write(jsonEncode(body));
      }
      await request.response.close();
    } catch (_) {
      // Client disconnected; ignore to avoid crashing the LAN server.
    }
  }

  Future<void> _writeError(
    HttpRequest request,
    int statusCode,
    String error,
    String message,
  ) async {
    await _writeJson(request, statusCode, {'error': error, 'message': message});
  }

  _CourseBuildContext _courseContext() {
    if (host is LanEditProviderHost) {
      final providerHost = host as LanEditProviderHost;
      return _CourseBuildContext(
        sections: providerHost.sections,
        semesterWeekCount: providerHost.semesterWeekCountValue,
      );
    }
    final meta = host.buildMetaJson();
    final rawSections = meta['sections'] as List<dynamic>? ?? const [];
    return _CourseBuildContext(
      sections: rawSections
          .map(
            (item) =>
                SectionTime.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      semesterWeekCount: meta['semesterWeekCount'] as int? ?? 20,
    );
  }
}

class _CourseBuildContext {
  final List<SectionTime> sections;
  final int semesterWeekCount;

  const _CourseBuildContext({
    required this.sections,
    required this.semesterWeekCount,
  });
}
