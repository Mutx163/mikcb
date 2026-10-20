import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/couple_webdav_config.dart';
import 'package:university_timetable/services/couple_webdav_credentials_store.dart';
import 'package:university_timetable/services/couple_webdav_service.dart';
import 'package:university_timetable/services/partner_timetable_service.dart';
import 'package:university_timetable/services/webdav_client_service.dart';
import 'package:webdav_plus/webdav_plus.dart';

/// 情侣云盘服务的宿主端口级行为钉（2026-10-20 泳道 A 第 3 刀补）。
///
/// `couple_webdav_service.dart` 摘除 provider 反向依赖后第一次独立可测。
/// 这里用假宿主 + 假 client（零网络）钉住两条最容易静默漂移的契约：
///
/// 1. **上传路径的读取时序**：凭证检查在前、`initialize` 在前、五个状态
///    字段（activeProfile/courses/scheduleItems/settings/currentWeek）活读
///    在后。这条时序决定「未连接时不得初始化宿主」「读到的必须是初始化后
///    的状态」——服务改为收端口后唯一的等价性风险点。
/// 2. **拉取路径的绑定门**：内容未变时，已绑定 ⇒ `unchanged` 短路、不导入；
///    未绑定 ⇒ 短路不生效、会走到导入（这正是「未绑定不覆盖本地」判定的
///    真实形状：绑定是 unchanged 短路的合取项，不是独立卫语句）。
///
/// 拉取用例的远端载荷必须是**合法 JSON 但不是整包备份**：`isFullBackupJson`
/// 会直接 `jsonDecode`，纯文本会先在「非 JSON」检查处返回，走不到绑定门。

class _RecordingHost implements CoupleWebdavTimetableHost {
  final List<String> calls = [];
  bool bound = true;

  @override
  Future<void> initialize() async {
    calls.add('initialize');
  }

  @override
  bool get hasPartnerBinding {
    calls.add('hasPartnerBinding');
    return bound;
  }

  @override
  Future<PartnerImportResult> importPartnerTimetable(String content) async {
    calls.add('importPartnerTimetable');
    // 假宿主不构造真实档案/绑定：借 pull 既有 catch（FormatException →
    // failed + error.message）把「导入被调用了」变成可断言的错误码。
    throw const FormatException('host-import-not-expected');
  }

  @override
  TimetableProfile? get activeProfile {
    calls.add('activeProfile');
    return null;
  }

  @override
  List<Course> get courses {
    calls.add('courses');
    return const [];
  }

  @override
  List<ScheduleItem> get scheduleItems {
    calls.add('scheduleItems');
    return const [];
  }

  @override
  TimetableSettings get settings {
    calls.add('settings');
    return TimetableSettings.defaults();
  }

  @override
  int get currentWeek {
    calls.add('currentWeek');
    return 1;
  }
}

class _FakeConfigStore implements CoupleWebdavConfigStore {
  const _FakeConfigStore(this.config);

  final CoupleWebdavConfig config;

  @override
  Future<CoupleWebdavConfig> load() async => config;

  @override
  Future<void> save(CoupleWebdavConfig config) async {}
}

class _FakeCredentialsStore implements CoupleWebdavCredentialsStore {
  const _FakeCredentialsStore();

  @override
  Future<String?> readPassword() async => 'secret';

  @override
  Future<void> writePassword(String password) async {}

  @override
  Future<void> deletePassword() async {}
}

class _FakeClientService extends WebdavClientService {
  const _FakeClientService(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> getBytes({
    required WebdavClient client,
    required String remotePath,
    Duration timeout = WebdavClientService.defaultOperationTimeout,
  }) async => bytes;}

void main() {
  test('上传：未连接不初始化宿主；已连接时 initialize 先于五字段活读', () async {
    // 未连接：凭证齐全性检查在 initialize 之前，直接返回错误码。
    final coldService = CoupleWebdavService(
      configStore: const _FakeConfigStore(CoupleWebdavConfig()),
      credentialsStore: const _FakeCredentialsStore(),
    );
    final coldHost = _RecordingHost();
    expect(
      await coldService.uploadMyTimetableForPartner(host: coldHost),
      'couple_webdav_not_connected',
    );
    expect(coldHost.calls, isEmpty, reason: '未连接时不得初始化宿主');

    // 已连接但 baseUrl 非法：五字段在 initialize 之后、建连之前活读，
    // 然后才在建连处返回错误码（零网络）。
    final host = _RecordingHost();
    final service = CoupleWebdavService(
      configStore: const _FakeConfigStore(
        CoupleWebdavConfig(username: 'me', baseUrl: 'not-a-url'),
      ),
      credentialsStore: const _FakeCredentialsStore(),
    );
    expect(
      await service.uploadMyTimetableForPartner(host: host),
      'couple_webdav_invalid_base_url',
    );
    expect(host.calls.first, 'initialize');
    for (final member in [
      'activeProfile',
      'courses',
      'scheduleItems',
      'settings',
      'currentWeek',
    ]) {
      expect(
        host.calls.indexOf('initialize'),
        lessThan(host.calls.indexOf(member)),
        reason: '$member 必须在 initialize 之后读取（保持改前时序）',
      );
    }
  });

  test('拉取：内容未变且已绑定 → unchanged 不导入；未绑定 → 走到导入', () async {
    const content = '{"hello":"world"}';
    final hash = sha256.convert(utf8.encode(content)).toString();
    final config = CoupleWebdavConfig(
      username: 'me',
      lastRemoteContentHash: hash,
    );
    final clientService = _FakeClientService(
      Uint8List.fromList(utf8.encode(content)),
    );

    // 已绑定 + 内容未变：unchanged 短路，绝不调用导入。
    final boundHost = _RecordingHost()..bound = true;
    final boundResult = await CoupleWebdavService(
      configStore: _FakeConfigStore(config),
      credentialsStore: const _FakeCredentialsStore(),
      clientService: clientService,
    ).pullPartnerTimetable(host: boundHost);
    expect(boundResult.status, CoupleWebdavPullStatus.unchanged);
    expect(
      boundHost.calls,
      isNot(contains('importPartnerTimetable')),
      reason: '内容未变且已绑定时不得重新导入（会无谓覆盖本地）',
    );

    // 未绑定 + 内容未变：unchanged 短路的合取项不成立，落到导入。
    // 这是当前契约的真实形状——绑定判定不是独立卫语句。
    final unboundHost = _RecordingHost()..bound = false;
    final unboundResult = await CoupleWebdavService(
      configStore: _FakeConfigStore(config),
      credentialsStore: const _FakeCredentialsStore(),
      clientService: clientService,
    ).pullPartnerTimetable(host: unboundHost);
    expect(unboundHost.calls, contains('importPartnerTimetable'));
    expect(unboundResult.status, CoupleWebdavPullStatus.failed);
    expect(unboundResult.errorCode, 'host-import-not-expected');
  });
}
