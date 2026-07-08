import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/async_utils.dart';

void main() {
  group('isTrustedApkDownloadUrl', () {
    test('allows github release assets', () {
      expect(
        isTrustedApkDownloadUrl(
          'https://github.com/Mutx163/mikcb/releases/download/v2.0.0/app.apk',
        ),
        isTrue,
      );
      expect(
        isTrustedApkDownloadUrl(
          'https://objects.githubusercontent.com/github-production-release-asset/1.apk',
        ),
        isTrue,
      );
    });

    test('allows builtin mirror hosts', () {
      expect(
        isTrustedApkDownloadUrl(
          'https://ghfast.top/github.com/Mutx163/mikcb/releases/download/v2/app.apk',
        ),
        isTrue,
      );
    });

    test('rejects untrusted hosts and non-https urls', () {
      expect(
        isTrustedApkDownloadUrl('http://github.com/Mutx163/mikcb/app.apk'),
        isFalse,
      );
      expect(
        isTrustedApkDownloadUrl('https://evil.example.com/app.apk'),
        isFalse,
      );
      expect(isTrustedApkDownloadUrl('not-a-url'), isFalse);
    });

    test('allows loopback urls only under flutter test', () {
      expect(
        isTrustedApkDownloadUrl('http://127.0.0.1:1234/app.apk'),
        isTrue,
      );
    });

    test('allows user-selected mirror prefix host', () {
      expect(
        isTrustedApkDownloadUrl(
          'https://mirror.example.com/Mutx163/mikcb/app.apk',
          mirrorUrlPrefix: 'https://mirror.example.com/',
        ),
        isTrue,
      );
    });
  });
}
