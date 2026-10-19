import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/about_screen.dart';
import 'package:university_timetable/services/app_update_service.dart';

/// 期望值是人推出来的：`hasRelease` 管「有没有版本信息可展示」，`hasUpdate`
/// 管「要不要让人下载」。2026-10-19 修掉的 bug 就是这两者被混用（按钮只看
/// hasRelease，「已是最新」下面挂着可点的「立即下载」）。
AppUpdateCheckResult _result({
  required bool hasRelease,
  required bool hasUpdate,
}) {
  return AppUpdateCheckResult(
    hasRelease: hasRelease,
    hasUpdate: hasUpdate,
    currentVersion: '2.1.3.4',
  );
}

void main() {
  test('没拿到 release 一律按检查失败处理，不冒充已是最新', () {
    expect(
      resolveAboutUpdateCardState(
        _result(hasRelease: false, hasUpdate: false),
      ),
      AboutUpdateCardState.checkFailed,
    );
  });

  test('上游给出自相矛盾的结果（无 release 却说有更新）也按失败处理', () {
    expect(
      resolveAboutUpdateCardState(
        _result(hasRelease: false, hasUpdate: true),
      ),
      AboutUpdateCardState.checkFailed,
    );
  });

  test('拿到 release 但版本不比当前高 → 已是最新（不给下载入口）', () {
    expect(
      resolveAboutUpdateCardState(
        _result(hasRelease: true, hasUpdate: false),
      ),
      AboutUpdateCardState.alreadyLatest,
    );
  });

  test('拿到 release 且版本更高 → 发现新版本（给下载入口）', () {
    expect(
      resolveAboutUpdateCardState(
        _result(hasRelease: true, hasUpdate: true),
      ),
      AboutUpdateCardState.updateAvailable,
    );
  });
}
