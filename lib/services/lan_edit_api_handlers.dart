import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../logging/app_log_messages.dart';
import 'lan_edit_audit_log.dart';
import 'lan_edit_host.dart';
import 'lan_edit_network_utils.dart';
import 'lan_edit_provider_host.dart';
import 'lan_edit_session.dart';
import 'spreadsheet_import_service.dart';
import 'transfer_package.dart';
import 'week_expression_parser.dart';

class LanEditApiHandlers {
  final LanEditHost host;
  final LanEditSession session;

  /// Ceiling on simultaneously-open requests. Every device on the LAN can open
  /// sockets for free, and each one costs a body read plus a JSON decode, so
  /// without this a handful of devices can saturate the phone.
  static const int _maxConcurrentRequests = 16;

  /// Wall-clock budget for reading one request body. A client that trickles
  /// bytes forever would otherwise hold a slot until the socket idle timeout.
  static const Duration _bodyReadBudget = Duration(seconds: 20);

  int _inFlight = 0;

  LanEditApiHandlers({required this.host, required this.session});

  Future<void> handle(HttpRequest request) async {
    // Count from the first line so a slow body cannot dodge the cap by never
    // reaching the route table.
    if (_inFlight >= _maxConcurrentRequests) {
      await _writeError(request, 503, 'too_many_requests', 'Too many requests');
      return;
    }
    _inFlight += 1;
    try {
      await _handleGuarded(request);
    } finally {
      _inFlight -= 1;
    }
  }

  Future<void> _handleGuarded(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        await _writeJson(request, 204, const {});
        return;
      }

      // A browser page on the same Wi-Fi can reach this API from the user's
      // phone. Reject cross-origin requests so visiting an arbitrary site
      // cannot burn the owner's PIN attempts or drive the API. Requests with no
      // Origin come from the native client, which never sends one.
      if (!await _isSameOrigin(request)) {
        await _writeError(request, 403, 'cross_origin_forbidden', 'Forbidden');
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
        session.boundProfileId ??= host.activeProfileId;
        await _writeJson(request, 200, {
          'profileId': host.activeProfileId,
          'profileName': host.activeProfileName,
          'profiles': host.listProfilesSummary(),
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

      if (path == '/api/v1/profiles' && request.method == 'GET') {
        await host.ensureInitialized();
        await _writeJson(request, 200, {
          'activeProfileId': host.activeProfileId,
          'profiles': host.listProfilesSummary(),
        });
        return;
      }

      if (path == '/api/v1/profiles/switch' && request.method == 'POST') {
        await _handleSwitchProfile(request);
        return;
      }

      if (path == '/api/v1/import/spreadsheet' && request.method == 'POST') {
        await _handleSpreadsheetImport(request);
        return;
      }

      if (path == '/api/v1/import/preview' && request.method == 'POST') {
        await _handleTransferPreview(request);
        return;
      }

      if (path == '/api/v1/import/apply' && request.method == 'POST') {
        await _handleTransferApply(request);
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
    } on FormatException catch (error) {
      // A malformed body is the caller's problem, not a server fault. These used
      // to fall through to the generic handler below and answer 500 while
      // echoing the raw Dart message back to whoever sent the request.
      await _writeError(
        request,
        _statusForBodyFormatError(error.message),
        'invalid_request',
        error.message,
      );
    } catch (_) {
      // 未鉴权路径上的兜底分支也会走到这里：Dart 异常原文（类型名、provider 内部
      // 结构、偶发的绝对路径）不能回给同网段的任意请求方，那等于一台没配对成功
      // 的设备也能拿本 App 做指纹。对端只需要知道「服务端出错」，细节留在本机日志。
      await _writeError(request, 500, 'internal_error', 'internal_error');
    }
  }

  static int _statusForBodyFormatError(String message) {
    if (message == 'request_body_too_large') {
      return 413;
    }
    if (message == 'request_body_timeout') {
      return 408;
    }
    return 400;
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
      if (!await _ensureWriteProfileTarget(request, body: body)) {
        return;
      }
      final context = _courseContext();
      final draft = LanEditProviderHost.courseFromApiJson(
        body,
        sections: context.sections,
        semesterWeekCount: context.semesterWeekCount,
      );
      if (draft.name.trim().isEmpty) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'course_name_required',
        );
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
        (error.message as Object?)?.toString() ?? '$error',
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
      if (!await _ensureWriteProfileTarget(request, body: patch)) {
        return;
      }
      final context = _courseContext();
      final updated = LanEditProviderHost.mergeCoursePatch(
        existing,
        patch,
        sections: context.sections,
        semesterWeekCount: context.semesterWeekCount,
      );
      if (updated.name.trim().isEmpty) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'course_name_required',
        );
        return;
      }
      await host.updateCourse(updated);
      lanEditAuditInfo(
        'lan_edit_course_updated',
        AppLogMessages.lanEditCourseUpdated,
        extras: {'courseId': updated.id, 'courseName': updated.name},
      );
      await _writeJson(request, 200, updated.toJson());
    } on StateError catch (error) {
      // 预检（existing == null → 404）之后到真正写入之间课程被删掉时，
      // provider 是静默 return 的；host.updateCourse 用事后置条件补上这个信号，
      // 这里把它落成 404，而不是继续回 200 让浏览器显示"已保存"。
      if (error.message != 'course_not_found') {
        rethrow;
      }
      await _writeError(request, 404, 'not_found', 'Course not found');
    } on ArgumentError catch (error) {
      await _writeError(
        request,
        400,
        'invalid_request',
        (error.message as Object?)?.toString() ?? '$error',
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleDeleteCourse(HttpRequest request, String courseId) async {
    try {
      await host.ensureInitialized();
      if (!await _ensureWriteProfileTarget(request)) {
        return;
      }
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
        (error.message as Object?)?.toString() ?? '$error',
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleReplaceCourseGroup(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      if (!await _ensureWriteProfileTarget(request, body: body)) {
        return;
      }
      final originalName = body['originalName']?.toString();
      final rawSlots = body['slots'];
      if (rawSlots is! List || rawSlots.isEmpty) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'at_least_one_schedule_slot',
        );
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
        await _writeError(
          request,
          400,
          'invalid_request',
          'course_name_required',
        );
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
        (error.message as Object?)?.toString() ?? '$error',
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleImportProfile(HttpRequest request) async {
    // The real provider host implements the migration capability. Keep the
    // legacy endpoint only for lightweight test/legacy hosts; the live LAN UI
    // always uses preview + apply below.
    if (host is LanTransferHost) {
      await _handleLegacyImportRejected(request);
      return;
    }
    await host.ensureInitialized();
    if (!await _ensureWriteProfileTarget(request)) {
      return;
    }
    final body = await _readBody(request);
    await host.importProfileBackupJson(body);
    await _writeJson(request, 200, {'imported': true});
  }

  Future<void> _handleMergeImport(HttpRequest request) async {
    if (host is LanTransferHost) {
      await _handleLegacyImportRejected(request);
      return;
    }
    try {
      await host.ensureInitialized();
      if (!await _ensureWriteProfileTarget(request)) {
        return;
      }
      final body = await _readBody(request);
      if (body.trim().isEmpty) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'backup_content_required',
        );
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

  Future<void> _handleTransferPreview(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      if (!await _ensureWriteProfileTarget(request)) {
        return;
      }
      final content = await _readBody(request);
      if (content.trim().isEmpty) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'backup_content_required',
        );
        return;
      }
      final transferHost = host is LanTransferHost
          ? host as LanTransferHost
          : null;
      final preview = transferHost?.previewTransferJson(content);
      if (preview == null) {
        await _writeError(
          request,
          501,
          'transfer_preview_not_supported',
          'transfer_preview_not_supported',
        );
        return;
      }
      await _writeJson(request, 200, preview.toJson());
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    } on UnsupportedError catch (error) {
      await _writeError(
        request,
        501,
        'transfer_preview_not_supported',
        error.message ?? 'transfer_preview_not_supported',
      );
    }
  }

  Future<void> _handleTransferApply(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      if (!await _ensureWriteProfileTarget(request, body: body)) {
        return;
      }
      final content = body['content']?.toString() ?? '';
      final mode = switch (body['mode']?.toString()) {
        'merge' => TransferApplyMode.merge,
        'overwrite' => TransferApplyMode.overwrite,
        _ => null,
      };
      if (content.trim().isEmpty || mode == null) {
        await _writeError(
          request,
          400,
          'invalid_request',
          'transfer_content_and_mode_required',
        );
        return;
      }
      final transferHost = host is LanTransferHost
          ? host as LanTransferHost
          : null;
      if (transferHost == null) {
        await _writeError(
          request,
          501,
          'transfer_apply_not_supported',
          'transfer_apply_not_supported',
        );
        return;
      }
      final result = await transferHost.applyTransferJson(content, mode: mode);
      await _writeJson(request, 200, {
        'applied': result.applied,
        'mode': mode.name,
        'transferId': result.undoToken?.id,
        'diff': result.preview.toJson(),
        if (result.error != null) 'error': result.error,
      });
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    } on UnsupportedError catch (error) {
      await _writeError(
        request,
        501,
        'transfer_apply_not_supported',
        error.message ?? 'transfer_apply_not_supported',
      );
    }
  }

  Future<void> _handleLegacyImportRejected(HttpRequest request) async {
    await _writeError(
      request,
      409,
      'transfer_preview_required',
      'Use /api/v1/import/preview then /api/v1/import/apply with an explicit mode',
    );
  }

  Future<void> _handleBatchDeleteCourses(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      if (!await _ensureWriteProfileTarget(request, body: body)) {
        return;
      }
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
        (error.message as Object?)?.toString() ?? '$error',
      );
    }
  }

  Future<void> _handlePatchSession(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      if (!await _ensureWriteProfileTarget(request, body: body)) {
        return;
      }
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

  Future<void> _handleSwitchProfile(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      final profileId = body['profileId']?.toString().trim() ?? '';
      if (profileId.isEmpty) {
        await _writeError(request, 400, 'invalid_request', 'profileId 不能为空');
        return;
      }
      await host.switchProfile(profileId);
      session.boundProfileId = host.activeProfileId;
      lanEditAuditInfo(
        'lan_edit_profile_switched',
        AppLogMessages.lanEditProfileSwitched,
        extras: {
          'profileId': host.activeProfileId,
          'profileName': host.activeProfileName,
        },
      );
      await _writeJson(request, 200, {
        'profileId': host.activeProfileId,
        'profileName': host.activeProfileName,
        'profiles': host.listProfilesSummary(),
        'meta': host.buildMetaJson(),
      });
    } on ArgumentError catch (error) {
      final message = error.message?.toString() ?? '$error';
      final notFound =
          message.contains('profile_not_found') ||
          message.contains('profile_switch_failed');
      await _writeError(
        request,
        notFound ? 404 : 400,
        notFound ? 'not_found' : 'invalid_request',
        message,
      );
    } on FormatException catch (error) {
      await _writeError(request, 400, 'invalid_request', error.message);
    }
  }

  Future<void> _handleSpreadsheetImport(HttpRequest request) async {
    try {
      await host.ensureInitialized();
      final body = await _readJsonBody(request);
      if (!await _ensureWriteProfileTarget(request, body: body)) {
        return;
      }
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

  /// Treats a request as same-origin when its `Origin` host matches the `Host`
  /// it was addressed to. The server binds every interface, so the phone can be
  /// reached as 192.168.x.x, 10.x.x.x or an hotspot address; comparing against
  /// the request's own Host accepts whichever one the client legitimately used
  /// while still rejecting a page served from any other site.
  Future<bool> _isSameOrigin(HttpRequest request) async {
    final origin = request.headers.value('origin');
    if (origin == null || origin.isEmpty || origin == 'null') {
      return true;
    }
    final originUri = Uri.tryParse(origin);
    final originHost = originUri?.host.trim().toLowerCase() ?? '';
    if (originHost.isEmpty) {
      return false;
    }
    final requestHost =
        Uri.tryParse(
          'http://${request.headers.value(HttpHeaders.hostHeader) ?? ''}',
        )?.host.trim().toLowerCase() ??
        '';
    if (requestHost.isEmpty) {
      return false;
    }
    return originHost == requestHost;
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

  /// Ensures write targets the session-bound / request profile and current active.
  ///
  /// Returns false after writing 400/409 when the write must be rejected.
  Future<bool> _ensureWriteProfileTarget(
    HttpRequest request, {
    Map<String, dynamic>? body,
  }) async {
    await host.ensureInitialized();
    session.boundProfileId ??= host.activeProfileId;

    final fromBody = body?['profileId']?.toString().trim();
    final fromQuery = request.uri.queryParameters['profileId']?.trim();
    final fromHeader = request.headers.value('x-profile-id')?.trim();
    final requested = (fromBody != null && fromBody.isNotEmpty)
        ? fromBody
        : (fromQuery != null && fromQuery.isNotEmpty)
        ? fromQuery
        : (fromHeader != null && fromHeader.isNotEmpty)
        ? fromHeader
        : session.boundProfileId?.trim();

    if (requested == null || requested.isEmpty) {
      await _writeError(
        request,
        400,
        'profile_id_required',
        'profileId is required for write operations',
      );
      return false;
    }

    final bound = session.boundProfileId?.trim();
    if (bound != null && bound.isNotEmpty && bound != requested) {
      await _writeError(
        request,
        400,
        'profile_id_mismatch',
        'profileId does not match session-bound profile',
      );
      return false;
    }

    final active = host.activeProfileId;
    if (active != null && active != requested) {
      await _writeJson(request, 409, {
        'error': 'profile_mismatch',
        'message': 'Active profile changed; refresh or switch profile',
        'activeProfileId': active,
        'requestedProfileId': requested,
        'boundProfileId': bound,
      });
      return false;
    }

    session.boundProfileId = requested;
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
    _requireJsonContentType(request);
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

  /// Without this a cross-origin HTML form can post `text/plain` bodies to this
  /// API: the body is read as JSON regardless of the declared type, so the
  /// browser's CORS preflight is skipped and the request still lands.
  void _requireJsonContentType(HttpRequest request) {
    final raw = request.headers.contentType;
    final mime = raw?.mimeType.trim().toLowerCase() ?? '';
    if (mime == 'application/json') {
      return;
    }
    throw const FormatException('unsupported_content_type');
  }

  static const int _maxRequestBodyBytes = 5 * 1024 * 1024;

  Future<String> _readBody(HttpRequest request) async {
    final contentLength = request.contentLength;
    if (contentLength > _maxRequestBodyBytes) {
      throw const FormatException('request_body_too_large');
    }
    final builder = BytesBuilder(copy: false);
    final deadline = DateTime.now().add(_bodyReadBudget);
    await for (final chunk in request) {
      // A slow trickle can keep a socket alive indefinitely, so budget the whole
      // read rather than trusting the per-chunk size cap below.
      if (DateTime.now().isAfter(deadline)) {
        throw const FormatException('request_body_timeout');
      }
      builder.add(chunk);
      if (builder.length > _maxRequestBodyBytes) {
        throw const FormatException('request_body_too_large');
      }
    }
    return utf8.decode(builder.takeBytes());
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
