import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../providers/timetable_provider.dart';
import 'couple_webdav_config.dart';
import 'couple_webdav_credentials_store.dart';
import 'data_transfer_service.dart';
import 'partner_timetable_service.dart';
import 'webdav_client_service.dart';

enum CoupleWebdavPullStatus { imported, updated, unchanged, failed }

class CoupleWebdavPullResult {
  final CoupleWebdavPullStatus status;
  final String? errorCode;
  final PartnerImportResultKind? importKind;

  const CoupleWebdavPullResult({
    required this.status,
    this.errorCode,
    this.importKind,
  });
}

class CoupleWebdavService {
  CoupleWebdavService({
    CoupleWebdavConfigStore? configStore,
    CoupleWebdavCredentialsStore? credentialsStore,
    WebdavClientService? clientService,
    DataTransferService? dataTransferService,
  }) : _configStore = configStore ?? const CoupleWebdavConfigStore(),
       _credentialsStore =
           credentialsStore ?? const CoupleWebdavCredentialsStore(),
       _clientService = clientService ?? const WebdavClientService(),
       _dataTransferService = dataTransferService ?? DataTransferService();

  final CoupleWebdavConfigStore _configStore;
  final CoupleWebdavCredentialsStore _credentialsStore;
  final WebdavClientService _clientService;
  final DataTransferService _dataTransferService;

  Future<CoupleWebdavConfig> loadConfig() => _configStore.load();

  Future<void> saveConfig(CoupleWebdavConfig config) =>
      _configStore.save(config);

  Future<bool> hasStoredPassword() async {
    final password = await _credentialsStore.readPassword();
    return password?.trim().isNotEmpty ?? false;
  }

  Future<void> connect({
    required String username,
    required String password,
    int mySlot = 1,
  }) async {
    final config = await loadConfig();
    await testConnection(
      config: config,
      username: username,
      password: password,
    );
    await _credentialsStore.writePassword(password);
    final normalizedSlot = mySlot == 2 ? 2 : 1;
    await saveConfig(
      config.copyWith(username: username.trim(), mySlot: normalizedSlot),
    );
  }

  /// 断开情侣云盘：清配置是主体，删密码尽力而为。
  ///
  /// 原先第一跳就是 `_credentialsStore.deletePassword()`，而 keystore 条目失效时
  /// （换机恢复、系统升级、凭证变化）它抛 `PlatformException`
  /// （`couple_webdav_credentials_store.dart:24-27` 的注释记的就是这个失效面，
  /// 那次只给**读**加了容错，写与删仍把异常交出去）。抛出后用户名没清、
  /// `lastPulledAt` 也没清 → 页面按 `username` 非空判"仍已连接"
  /// （couple_timetable_settings_screen.dart:65-67），而按钮写的是
  /// `onPressed: _disconnectCoupleWebdav`（:240，tear-off 丢掉 Future）——
  /// 用户反复点「断开连接」零反应，异常还没人接。
  ///
  /// 删不掉密码不影响"已断开"的语义：下次保存账号会覆盖它，
  /// 而读密码的地方本来就按"没有密码"处理。
  Future<void> disconnect() async {
    final config = await loadConfig();
    await saveConfig(
      config.copyWith(
        username: '',
        clearLastPulledAt: true,
        clearLastRemoteContentHash: true,
      ),
    );
    try {
      await _credentialsStore.deletePassword();
    } on PlatformException {
      // 密码此刻已经不可操作（连删都删不掉），不因此把用户卡在"已连接"状态。
    }
  }

  Future<void> testConnection({
    CoupleWebdavConfig? config,
    String? username,
    String? password,
  }) async {
    final resolvedConfig = config ?? await loadConfig();
    final resolvedUsername = username?.trim() ?? resolvedConfig.username.trim();
    final resolvedPassword = password ?? await _credentialsStore.readPassword();
    if (resolvedUsername.isEmpty ||
        resolvedPassword == null ||
        resolvedPassword.isEmpty) {
      throw StateError('missing_credentials');
    }
    await _clientService.testConnection(
      WebdavConnectionParams(
        baseUrl: resolvedConfig.baseUrl.trim().isEmpty
            ? CoupleWebdavConfig.defaultJianguoyunBaseUrl
            : resolvedConfig.baseUrl.trim(),
        username: resolvedUsername,
        password: resolvedPassword,
      ),
    );
  }

  Future<CoupleWebdavPullResult> pullPartnerTimetable({
    required TimetableProvider provider,
    bool force = false,
  }) async {
    final config = await loadConfig();
    final password = await _credentialsStore.readPassword();
    if (config.username.trim().isEmpty ||
        password == null ||
        password.trim().isEmpty) {
      return const CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.failed,
        errorCode: 'couple_webdav_not_connected',
      );
    }

    final client = _clientService.createClient(
      WebdavConnectionParams(
        baseUrl: config.baseUrl.trim().isEmpty
            ? CoupleWebdavConfig.defaultJianguoyunBaseUrl
            : config.baseUrl.trim(),
        username: config.username.trim(),
        password: password,
      ),
    );
    final bytes = await _clientService.getBytes(
      client: client,
      remotePath: config.partnerTimetableRemotePath,
    );
    // Dual-slot is authoritative. Do not fall back to the legacy single file:
    // both devices used to write/read the same path and import "self as partner".
    final resolvedBytes = bytes;
    if (resolvedBytes == null || resolvedBytes.isEmpty) {
      return const CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.failed,
        errorCode: 'couple_webdav_partner_file_missing',
      );
    }

    // 解码与「是不是完整备份」判定此前在 try 之外：远端 slot 文件被塞进非 UTF-8
    // 字节、HTML 错误页或截断 JSON 时（本服务的载荷没有任何完整性保护，见
    // CODE_REVIEW 2026-10-01），FormatException/ArgumentError 会一路冒出这个
    // 设计上「只返回错误码、从不抛」的方法，再冒出 UI 调用方（那边只有
    // try/finally，没有 catch），落到 zone 的未处理异步异常 —— 用户表现为点了
    // 「拉取」毫无反应。
    final String content;
    try {
      content = utf8.decode(resolvedBytes);
    } catch (_) {
      return const CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.failed,
        errorCode: 'couple_webdav_partner_file_not_utf8',
      );
    }

    final bool isFullBackup;
    try {
      isFullBackup = _dataTransferService.isFullBackupJson(content);
    } catch (_) {
      return const CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.failed,
        errorCode: 'couple_webdav_partner_file_not_json',
      );
    }
    if (isFullBackup) {
      return const CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.failed,
        errorCode: 'partner_import_requires_single_profile',
      );
    }

    final contentHash = sha256.convert(utf8.encode(content)).toString();
    if (!force &&
        config.lastRemoteContentHash == contentHash &&
        provider.hasPartnerBinding) {
      return const CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.unchanged,
      );
    }

    try {
      final importResult = await provider.importPartnerTimetable(content);
      await saveConfig(
        config.copyWith(
          lastPulledAt: DateTime.now(),
          lastRemoteContentHash: contentHash,
        ),
      );
      return CoupleWebdavPullResult(
        status: importResult.kind == PartnerImportResultKind.created
            ? CoupleWebdavPullStatus.imported
            : CoupleWebdavPullStatus.updated,
        importKind: importResult.kind,
      );
    } on FormatException catch (error) {
      return CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.failed,
        errorCode: error.message,
      );
    } catch (_) {
      return const CoupleWebdavPullResult(
        status: CoupleWebdavPullStatus.failed,
        errorCode: 'couple_webdav_pull_failed',
      );
    }
  }

  Future<String?> uploadMyTimetableForPartner({
    required TimetableProvider provider,
  }) async {
    final config = await loadConfig();
    final password = await _credentialsStore.readPassword();
    if (config.username.trim().isEmpty ||
        password == null ||
        password.trim().isEmpty) {
      return 'couple_webdav_not_connected';
    }

    await provider.initialize();
    final content = _dataTransferService.buildBackupJson(
      profileName: provider.activeProfile?.name,
      courses: provider.courses,
      scheduleItems: provider.scheduleItems,
      settings: provider.settings,
      currentWeek: provider.currentWeek,
    );

    final client = _clientService.createClient(
      WebdavConnectionParams(
        baseUrl: config.baseUrl.trim().isEmpty
            ? CoupleWebdavConfig.defaultJianguoyunBaseUrl
            : config.baseUrl.trim(),
        username: config.username.trim(),
        password: password,
      ),
    );
    await _clientService.ensureRemoteFolder(
      client: client,
      remoteFolder: config.normalizedRemoteFolder,
    );
    await _clientService.putBytes(
      client: client,
      remotePath: config.mineTimetableRemotePath,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    return null;
  }
}
