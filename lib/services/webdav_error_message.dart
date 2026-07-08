import 'dart:io';

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
  if (error is StateError) {
    return error.message;
  }

  final lower = error.toString().toLowerCase();
  if (lower.contains('401')) {
    return 'auth_failed';
  }
  if (lower.contains('403')) {
    return 'access_denied';
  }
  if (lower.contains('certificate') || lower.contains('handshake')) {
    return 'certificate_error';
  }
  if (lower.contains('timeout')) {
    return 'connection_timeout';
  }
  if (lower.contains('connection')) {
    return 'connection_failed';
  }

  return 'sync_failed';
}
