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

  test('sanitizeWebdavErrorMessage maps generic HTTP statuses safely', () {
    expect(
      sanitizeWebdavErrorMessage(const HttpException('statusCode=429')),
      'invalid_response',
    );
    expect(
      sanitizeWebdavErrorMessage(const HttpException('statusCode=500')),
      'invalid_response',
    );
  });

  test('sanitizeWebdavErrorMessage keeps only allowlisted state codes', () {
    for (final code in const [
      'auth_failed',
      'access_denied',
      'certificate_error',
      'connection_timeout',
      'connection_failed',
      'network_error',
      'invalid_response',
      'local_changes_pending_sync',
      'missing_credentials',
      'backup_not_found',
      'missing_backup_snapshot',
      'cannot_delete_current_backup',
      'provider_not_ready',
      'insecure_url_blocked',
      'sync_failed',
    ]) {
      expect(sanitizeWebdavErrorMessage(StateError(code)), code);
    }
  });

  test('sanitizeWebdavErrorMessage rejects arbitrary state error details', () {
    const secret = 'https://dav.example.com/path Authorization=Bearer secret';
    final message = sanitizeWebdavErrorMessage(
      StateError('remote_backup_invalid: $secret\n{"password":"secret"}'),
    );
    expect(message, 'sync_failed');
    expect(message, isNot(contains('dav.example.com')));
    expect(message, isNot(contains('secret')));
  });

  test(
    'sanitizeWebdavErrorMessage uses fixed codes for generic HTTP failures',
    () {
      expect(
        sanitizeWebdavErrorMessage(
          const HttpException('statusCode=429 body=secret'),
        ),
        'invalid_response',
      );
    },
  );
}
