import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/webdav_error_message.dart';

void main() {
  test('sanitizeWebdavErrorMessage maps auth failures without leaking url', () {
    final message = sanitizeWebdavErrorMessage(
      const HttpException('GET https://dav.example.com/secret failed: 401'),
    );
    expect(message, 'auth_failed');
    expect(message.contains('dav.example.com'), isFalse);
  });

  test('sanitizeWebdavErrorMessage maps socket and certificate errors', () {
    expect(
      sanitizeWebdavErrorMessage(const SocketException('Failed host lookup')),
      'connection_failed',
    );
    expect(
      sanitizeWebdavErrorMessage(const HandshakeException('CERT_INVALID')),
      'certificate_error',
    );
  });

  test('sanitizeWebdavErrorMessage maps generic HTTP statuses', () {
    expect(
      sanitizeWebdavErrorMessage(const HttpException('statusCode=429')),
      'http_429',
    );
    expect(
      sanitizeWebdavErrorMessage(const HttpException('statusCode=500')),
      'invalid_response',
    );
  });

  test('sanitizeWebdavErrorMessage keeps state error message', () {
    expect(
      sanitizeWebdavErrorMessage(StateError('backup_not_found')),
      'backup_not_found',
    );
  });
}
