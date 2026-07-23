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

    test('classifyGetBytesFailure keeps other errors as failed message', () {
      final result = WebdavClientService.classifyGetBytesFailure(
        StateError('auth_failed_custom'),
      );
      expect(result.isFailed, isTrue);
      expect(result.errorMessage, contains('auth_failed_custom'));
    });
  });
}
