import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/about_screen.dart';
import 'package:university_timetable/services/app_update_service.dart';

void main() {
  test('mirror source on Android uses in-app download', () {
    expect(
      resolveAboutUpdatePrimaryAction(
        isAndroid: true,
        downloadUrl: 'https://example.com/app.apk',
        channel: AppUpdateDownloadChannel.github,
      ),
      AboutUpdatePrimaryAction.downloadInApp,
    );
  });

  test('original source on Android also uses in-app download', () {
    expect(
      resolveAboutUpdatePrimaryAction(
        isAndroid: true,
        downloadUrl: 'https://github.com/example/app.apk',
        channel: AppUpdateDownloadChannel.github,
      ),
      AboutUpdatePrimaryAction.downloadInApp,
    );
  });

  test('non-Android still opens the direct download link', () {
    expect(
      resolveAboutUpdatePrimaryAction(
        isAndroid: false,
        downloadUrl: 'https://github.com/example/app.apk',
        channel: AppUpdateDownloadChannel.github,
      ),
      AboutUpdatePrimaryAction.openDownloadLink,
    );
  });

  test('missing asset link falls back to release page', () {
    expect(
      resolveAboutUpdatePrimaryAction(
        isAndroid: true,
        downloadUrl: null,
        channel: AppUpdateDownloadChannel.github,
      ),
      AboutUpdatePrimaryAction.openReleasePage,
    );
  });

  test('pgyer channel always opens download link in browser', () {
    expect(
      resolveAboutUpdatePrimaryAction(
        isAndroid: true,
        downloadUrl: 'https://www.pgyer.com/app',
        channel: AppUpdateDownloadChannel.pgyer,
      ),
      AboutUpdatePrimaryAction.openDownloadLink,
    );
  });

  test('recommend mirror picks the fastest reachable preset', () {
    final recommended = resolveRecommendedMirrorPreset({
      AppUpdateMirrorPreset.ghfast: const AppUpdateDownloadProbeResult(
        isSuccess: true,
        elapsed: Duration(milliseconds: 180),
      ),
      AppUpdateMirrorPreset.ghproxyCn: const AppUpdateDownloadProbeResult(
        isSuccess: true,
        elapsed: Duration(milliseconds: 90),
      ),
      AppUpdateMirrorPreset.ghLlkk: const AppUpdateDownloadProbeResult(
        isSuccess: false,
        elapsed: Duration(milliseconds: 40),
        message: 'HTTP 502',
      ),
    });

    expect(recommended, AppUpdateMirrorPreset.ghproxyCn);
  });

  test('fallback mirror skips the current preset', () {
    final fallback = resolveMirrorFallbackPreset(
      currentPreset: AppUpdateMirrorPreset.ghproxyCn,
      availablePresets: const [
        AppUpdateMirrorPreset.ghproxyCn,
        AppUpdateMirrorPreset.ghfast,
        AppUpdateMirrorPreset.ghLlkk,
      ],
    );

    expect(fallback, AppUpdateMirrorPreset.ghfast);
  });
}
