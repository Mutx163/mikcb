import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/webdav_client_service.dart';

void main() {
  group('WebdavClientService', () {
    test('default operation timeout is 30 seconds', () {
      expect(
        WebdavClientService.defaultOperationTimeout,
        const Duration(seconds: 30),
      );
    });

    test(
      'classifyGetBytesFailure maps TimeoutException to connection_timeout',
      () {
        final result = WebdavClientService.classifyGetBytesFailure(
          TimeoutException('webdav_operation_timeout'),
        );
        expect(result.isFailed, isTrue);
        expect(result.bytes, isNull);
        expect(result.errorMessage, 'connection_timeout');
      },
    );

    test('classifyGetBytesFailure maps missing-file text to notFound', () {
      final result = WebdavClientService.classifyGetBytesFailure(
        StateError('404 Not Found'),
      );
      expect(result.isFailed, isFalse);
      expect(result.bytes, isNull);
      expect(result.errorMessage, isNull);
    });

    test('classifyGetBytesFailure does not treat embedded 404 as notFound', () {
      for (final message in <String>[
        'request failed for /archives/4040',
        'failed to read lesson-404.json',
      ]) {
        final result = WebdavClientService.classifyGetBytesFailure(
          StateError(message),
        );
        expect(result.isFailed, isTrue, reason: message);
        expect(result.errorMessage, isNot('backup_not_found'), reason: message);
      }
    });

    test('classifyGetBytesFailure maps HTTP status messages safely', () {
      final cases = <String, String>{
        'HTTP 400 Bad Request': 'invalid_response',
        'HTTP 409 Conflict': 'invalid_response',
        'HTTP 429 Too Many Requests': 'invalid_response',
        'HTTP 500 Internal Server Error': 'invalid_response',
        'HTTP/1.1 401 Unauthorized': 'auth_failed',
        'HTTP/2 403 Forbidden': 'access_denied',
      };
      for (final entry in cases.entries) {
        final result = WebdavClientService.classifyGetBytesFailure(
          StateError(entry.key),
        );
        expect(result.isFailed, isTrue, reason: entry.key);
        expect(result.errorMessage, entry.value, reason: entry.key);
      }
    });

    test('classifyGetBytesFailure sanitizes unknown error text', () {
      final result = WebdavClientService.classifyGetBytesFailure(
        StateError('auth_failed_custom'),
      );
      expect(result.isFailed, isTrue);
      expect(result.errorMessage, 'sync_failed');
      expect(result.errorMessage, isNot(contains('auth_failed_custom')));
    });
  });
}
