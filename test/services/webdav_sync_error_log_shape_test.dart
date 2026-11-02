import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/webdav_sync_coordinator.dart';

void main() {
  group('describeWebdavSyncErrorForLog（release 取证日志的类型化摘要）', () {
    // `webdav_sync_coordinator` 在 release 取证白名单里（app_debug_log.dart），
    // 这份摘要是同步异常进正式包 logcat 的唯一形态：原文里的 WebDAV 地址 /
    // 用户名必须消失，但「哪类错、哪个码」要留得住（取证能力不降级）。
    test('PlatformException 只留类型与 code，message 原文不出现', () {
      final shape = describeWebdavSyncErrorForLog(
        PlatformException(
          code: 'keystore_read_failed',
          message:
              'GET https://dav.example.com/user/dav/ -> 401 (user=mutx163)',
        ),
      );
      expect(shape, 'PlatformException code=keystore_read_failed');
      expect(shape, isNot(contains('dav.example.com')));
      expect(shape, isNot(contains('mutx163')));
      expect(shape, isNot(contains('401')));
    });

    test('http 栈类异常（SocketException）只留类型名，主机地址不出现', () {
      final shape = describeWebdavSyncErrorForLog(
        const SocketException('Failed host lookup: https://dav.example.com'),
      );
      expect(shape, 'SocketException');
      expect(shape, isNot(contains('dav.example.com')));
    });

    test('任意自定义异常只留类型名，toString 原文不出现', () {
      final shape = describeWebdavSyncErrorForLog(
        _SyncErrorWithSensitiveText(),
      );
      expect(shape, '_SyncErrorWithSensitiveText');
      expect(shape, isNot(contains('webdav.example.cn')));
      expect(shape, isNot(contains('secret')));
    });
  });
}

class _SyncErrorWithSensitiveText implements Exception {
  @override
  String toString() =>
      'Sync failed for https://webdav.example.cn/dav/ (user=secret-name)';
}
