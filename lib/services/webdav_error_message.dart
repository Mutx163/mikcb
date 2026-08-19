import 'dart:async';
import 'dart:io';

import 'package:webdav_plus/webdav_plus.dart';

/// 将 WebDAV / 网络异常转为可安全展示给用户的简短文案（不含 URL / 凭据）。
String sanitizeWebdavErrorMessage(Object error) {
  if (error is SocketException) {
    return 'connection_failed';
  }
  if (error is HandshakeException) {
    return 'certificate_error';
  }
  if (error is FormatException) {
    return 'invalid_response';
  }
  if (error is TimeoutException) {
    return 'connection_timeout';
  }
  if (error is StateError) {
    return error.message;
  }

  // WebDAVException carries a statusCode — use it for precise mapping.
  if (error is WebDAVException) {
    final statusCode = error.statusCode;
    if (statusCode == 401) {
      return 'auth_failed';
    }
    if (statusCode == 403) {
      return 'access_denied';
    }
    if (statusCode == 404) {
      return 'backup_not_found';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'invalid_response';
    }
    if (statusCode != null) {
      return 'http_$statusCode';
    }
  }

  final lower = error.toString().toLowerCase();
  final statusMatch = RegExp(
    r'\b(?:http\s+|status(?:code)?[=: ]+)(\d{3})\b',
  ).firstMatch(lower);
  final textualStatusCode =
      statusMatch == null ? null : int.tryParse(statusMatch.group(1)!);
  if (textualStatusCode == 401) {
    return 'auth_failed';
  }
  if (textualStatusCode == 403) {
    return 'access_denied';
  }
  if (textualStatusCode == 404) {
    return 'backup_not_found';
  }
  if (textualStatusCode != null && textualStatusCode >= 500) {
    return 'invalid_response';
  }
  if (textualStatusCode != null && textualStatusCode >= 400) {
    return 'http_$textualStatusCode';
  }
  if (lower.contains('401')) {
    return 'auth_failed';
  }
  if (lower.contains('403')) {
    return 'access_denied';
  }
  if (lower.contains('404')) {
    return 'backup_not_found';
  }
  if (lower.contains('certificate') || lower.contains('handshake')) {
    return 'certificate_error';
  }
  if (lower.contains('timeout')) {
    return 'connection_timeout';
  }
  if (lower.contains('connection') ||
      lower.contains('socket') ||
      lower.contains('network')) {
    return 'connection_failed';
  }

  return 'sync_failed';
}
