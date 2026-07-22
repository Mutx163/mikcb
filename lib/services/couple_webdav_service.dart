import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

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

  Future<void> disconnect() async {
    await _credentialsStore.deletePassword();
    final config = await loadConfig();
    await saveConfig(
      config.copyWith(
        username: '',
        clearLastPulledAt: true,
        clearLastRemoteContentHash: true,
      ),
    );
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

    final content = utf8.decode(resolvedBytes);
    if (_dataTransferService.isFullBackupJson(content)) {
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
