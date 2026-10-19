import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_update_service.dart';

void main() {
  // 期望值是人写下来的契约：这一页/弹窗点「查看 Release」要落在**发布页列表**，
  // 并且主机跟着用户选的渠道走（2026-10-19 真机反馈：原来无论选什么都开
  // gitcode.com/mutx/qingyu/releases/tag/vX）。
  test('GitCode 渠道 → GitCode 发布页列表', () {
    expect(
      AppUpdateService.releaseListUrlFor(AppUpdateDownloadChannel.gitcode),
      'https://gitcode.com/mutx/qingyu/releases',
    );
  });

  test('GitHub 渠道 → GitHub 发布页列表', () {
    expect(
      AppUpdateService.releaseListUrlFor(AppUpdateDownloadChannel.github),
      'https://github.com/Mutx163/mikcb/releases',
    );
  });

  test('蒲公英渠道没有发布页，退回 GitHub 发布页列表', () {
    expect(
      AppUpdateService.releaseListUrlFor(AppUpdateDownloadChannel.pgyer),
      'https://github.com/Mutx163/mikcb/releases',
    );
  });

  test('不带版本号：不是 tag 深链', () {
    for (final channel in AppUpdateDownloadChannel.values) {
      final url = AppUpdateService.releaseListUrlFor(channel);
      expect(url.contains('/tag/'), isFalse, reason: '$channel 给了 tag 深链：$url');
      expect(url.endsWith('/releases'), isTrue, reason: '$channel 不是列表页：$url');
    }
  });
}
