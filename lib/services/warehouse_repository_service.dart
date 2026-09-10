import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import '../models/warehouse_repository_models.dart';
import '../models/timetable_settings.dart';
import '../utils/async_utils.dart';
import 'app_http_client.dart';

class WarehouseFetchOptions {
  final AppUpdateDownloadSource downloadSource;
  final AppUpdateMirrorPreset mirrorPreset;
  final String customMirrorUrlPrefix;

  /// 更新界面下载渠道是否选择了国内源（GitCode 直连或蒲公英）。
  /// 为 true 时教务适配仓的拉取同步走 GitCode（v5 contents API，国内直连，
  /// 无需镜像前缀），失败时自动回退 GitHub raw 与镜像候选。
  final bool preferGitCode;

  const WarehouseFetchOptions({
    required this.downloadSource,
    required this.mirrorPreset,
    required this.customMirrorUrlPrefix,
    this.preferGitCode = false,
  });

  factory WarehouseFetchOptions.fromSettings(TimetableSettings settings) {
    return WarehouseFetchOptions(
      downloadSource: AppUpdateDownloadSourceX.fromValue(
        settings.appUpdateDownloadSource,
      ),
      mirrorPreset: AppUpdateMirrorPresetX.fromValue(
        settings.appUpdateMirrorPreset,
      ),
      customMirrorUrlPrefix: settings.appUpdateMirrorUrlPrefix,
      preferGitCode: AppUpdateDownloadChannelX.fromValue(
        settings.appUpdateDownloadChannel,
      ).preferGitCodeSync,
    );
  }
}

class WarehouseRepositoryService {
  final http.Client _client;

  WarehouseRepositoryService({http.Client? client})
    : _client = client ?? createAppHttpClient();

  static void _log(String message) {
    appDebugLog('WarehouseService', '${formatLogTimestamp()} $message');
  }

  Future<WarehouseRootIndex> fetchRootIndex(
    WarehouseRepositorySource source, {
    WarehouseFetchOptions? options,
  }) async {
    _log('获取学校列表...');
    final content = await _fetchText(
      source,
      'index/root_index.yaml',
      options: options,
    );
    final maps = _parseYamlListMaps(content, topLevelKey: 'schools');
    final schools = maps
        .map(
          (item) => WarehouseSchoolEntry(
            id: item['id'] ?? '',
            name: item['name'] ?? '',
            initial: item['initial'] ?? '',
            resourceFolder: item['resource_folder'] ?? '',
          ),
        )
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.name.isNotEmpty &&
              item.resourceFolder.isNotEmpty,
        )
        .toList(growable: false);
    if (schools.isEmpty) {
      throw const WarehouseRepositoryException('warehouse_no_schools_index');
    }
    return WarehouseRootIndex(schools: schools);
  }

  Future<WarehouseAdaptersIndex> fetchAdaptersIndex(
    WarehouseRepositorySource source,
    WarehouseSchoolEntry school, {
    WarehouseFetchOptions? options,
  }) async {
    _log('获取 ${school.name} 适配器列表...');
    final path = 'resources/${school.resourceFolder}/adapters.yaml';
    final content = await _fetchText(
      source,
      path,
      options: options,
    );
    final maps = _parseYamlListMaps(content, topLevelKey: 'adapters');
    final adapters = maps
      .map(
        (item) => WarehouseAdapterEntry(
          adapterId: item['adapter_id'] ?? '',
          adapterName: item['adapter_name'] ?? '',
          category: item['category'] ?? '',
          assetJsPath: item['asset_js_path'] ?? '',
          importUrl: item['import_url'] ?? '',
          maintainer: item['maintainer'] ?? '',
          description: item['description'] ?? '',
          sha256: item['sha256'] ?? '',
        ),
      )
      .where(
        (item) => item.adapterId.isNotEmpty && item.assetJsPath.isNotEmpty,
      )
      .toList(growable: false);
    if (adapters.isEmpty) {
      throw WarehouseRepositoryException(
        encodeServiceMessage('warehouse_no_adapters', {
          'schoolName': school.name,
        }),
      );
    }
    return WarehouseAdaptersIndex(adapters: adapters);
  }

  /// 拉取教务导入「按适配器（脚本）名称搜索」的全局索引。
  /// 旧版适配仓没有该文件（404）或网络失败时抛 WarehouseRepositoryException，
  /// 调用方捕获后降级为仅按学校字段搜索，不影响正常流程。
  Future<WarehouseSearchIndex> fetchSearchIndex(
    WarehouseRepositorySource source, {
    WarehouseFetchOptions? options,
  }) async {
    _log('fetching adapter search index...');
    final content = await _fetchText(
      source,
      'index/search_index.yaml',
      options: options,
    );
    return parseWarehouseSearchIndexYaml(content);
  }

  Future<String> fetchAdapterScript(
    WarehouseRepositorySource source, {
    required WarehouseSchoolEntry school,
    required WarehouseAdapterEntry adapter,
    WarehouseFetchOptions? options,
  }) async {
    final path = 'resources/${school.resourceFolder}/${adapter.assetJsPath}';
    final bytes = await _fetchBytes(source, path, options: options);
    // Integrity gate: when the index declares a SHA-256 for the script, the
    // fetched bytes must match before the script is ever handed to WebView.
    // This closes the mirror-fallback / custom-prefix supply chain where a
    // poisoned mirror can otherwise serve arbitrary JS into the bridge session.
    // Legacy indexes without sha256 keep working unchanged (no verification).
    final declared = adapter.sha256.trim().toLowerCase();
    if (declared.isNotEmpty) {
      final actual = sha256.convert(bytes).toString();
      if (actual != declared) {
        _log('脚本 SHA-256 校验失败：声明 $declared，实际 $actual');
        throw const WarehouseRepositoryException(
          'warehouse_script_checksum_failed',
        );
      }
    }
    return utf8.decode(bytes);
  }

  Future<String> _fetchText(
    WarehouseRepositorySource source,
    String relativePath, {
    WarehouseFetchOptions? options,
  }) async {
    return utf8.decode(
      await _fetchBytes(source, relativePath, options: options),
    );
  }

  Future<List<int>> _fetchBytes(
    WarehouseRepositorySource source,
    String relativePath, {
    WarehouseFetchOptions? options,
  }) async {
    final effectiveOptions =
        options ??
        const WarehouseFetchOptions(
          downloadSource: AppUpdateDownloadSource.mirror,
          mirrorPreset: AppUpdateMirrorPreset.ghfast,
          customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
        );
    final effectiveSource = effectiveOptions.preferGitCode
        ? source.withHost(WarehouseRepositoryHost.gitcode)
        : source;
    final primaryUri = effectiveSource.buildFileUri(relativePath);
    final orderedCandidates = <Uri>[
      primaryUri,
      ..._buildFallbackUris(
        effectiveSource,
        relativePath,
        effectiveOptions,
        primaryUri,
      ),
    ];
    _log('请求 $primaryUri,候选 ${orderedCandidates.length} 个');

    // Prefer the primary URL first so a poisoned mirror cannot win a race.
    // Fall back to remaining candidates only when the primary fetch fails.
    Object? lastError;
    for (final candidate in orderedCandidates) {
      try {
        final response = await _client.get(
          candidate,
          headers: {
            'Accept': candidate.host == 'api.gitcode.com'
                ? 'application/json'
                : 'text/plain, */*',
            'User-Agent': 'mikcb-warehouse-client',
          },
        );
        if (response.statusCode == 200) {
          try {
            return _decodeCandidateBytes(candidate, response.bodyBytes);
          } catch (error) {
            lastError = error;
          }
        } else {
          lastError = StateError('http_${response.statusCode}');
        }
      } catch (error) {
        lastError = error;
      }
    }

    final candidatesCount = orderedCandidates.length;
    throw _buildFetchError(
      effectiveOptions,
      lastError,
      candidatesCount: candidatesCount,
    );
  }

  /// GitCode contents API 返回 base64 JSON；其余候选直接就是文件字节。
  List<int> _decodeCandidateBytes(Uri uri, List<int> bodyBytes) {
    if (uri.host != 'api.gitcode.com') {
      return bodyBytes;
    }
    final Object? decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('gitcode_contents_invalid_payload');
    }
    final base64Content = decoded['content'];
    if (base64Content is! String || base64Content.isEmpty) {
      throw StateError('gitcode_contents_missing_content');
    }
    return base64Decode(base64Content.replaceAll(RegExp(r'\s'), ''));
  }

  /// 主地址之外的候选：GitCode 失败时回退 GitHub raw（含镜像前缀加速）。
  List<Uri> _buildFallbackUris(
    WarehouseRepositorySource source,
    String relativePath,
    WarehouseFetchOptions options,
    Uri primaryUri,
  ) {
    final fallbacks = <Uri>[];
    void addUnique(Uri uri) {
      if (uri != primaryUri && !fallbacks.contains(uri)) {
        fallbacks.add(uri);
      }
    }

    final githubRawUri = source.buildGitHubRawFileUri(relativePath);
    if (source.host == WarehouseRepositoryHost.gitcode) {
      addUnique(githubRawUri);
    }
    for (final uri in _buildCandidateUris(githubRawUri, options)) {
      addUnique(uri);
    }
    return fallbacks;
  }

  WarehouseRepositoryException _buildFetchError(
    WarehouseFetchOptions options,
    Object? lastError, {
    int candidatesCount = 0,
  }) {
    final usingMirror =
        options.downloadSource == AppUpdateDownloadSource.mirror;
    final code = usingMirror
        ? 'warehouse_fetch_failed_mirror'
        : 'warehouse_fetch_failed_github';
    return WarehouseRepositoryException(
      encodeServiceMessage(
        code,
        usingMirror ? {'candidatesCount': '$candidatesCount'} : const {},
      ),
    );
  }

  List<Uri> _buildCandidateUris(
    Uri originalUri,
    WarehouseFetchOptions options,
  ) {
    if (options.downloadSource != AppUpdateDownloadSource.mirror) {
      return [originalUri];
    }

    final selectedPrefix = resolveAppUpdateMirrorUrlPrefix(
      preset: options.mirrorPreset,
      customUrlPrefix: options.customMirrorUrlPrefix,
    );
    final urls = buildMirrorCandidateUrls(
      originalUri.toString(),
      selectedMirrorPrefix: selectedPrefix,
    );
    return urls.map(Uri.parse).toList();
  }
}

/// 解析 index/search_index.yaml（scripts/build_search_index.py 的确定性输出）。
/// 宽松解析：跳过注释/空行与不完整条目；version_id 缺失记空串，
/// 手工编辑或旧格式文件也能尽量可用。
WarehouseSearchIndex parseWarehouseSearchIndexYaml(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  var versionId = '';
  final schools = <WarehouseSearchSchoolEntry>[];
  var inSchools = false;
  WarehouseSearchSchoolEntry? currentSchool;
  var inAdapters = false;
  WarehouseSearchAdapterEntry? currentAdapter;

  void flushAdapter() {
    final adapter = currentAdapter;
    final school = currentSchool;
    if (adapter != null && adapter.adapterId.isNotEmpty && school != null) {
      school.adapters.add(adapter);
    }
    currentAdapter = null;
  }

  void flushSchool() {
    flushAdapter();
    final school = currentSchool;
    if (school != null &&
        school.id.isNotEmpty &&
        school.adapters.isNotEmpty) {
      schools.add(
        WarehouseSearchSchoolEntry(id: school.id, adapters: school.adapters),
      );
    }
    currentSchool = null;
    inAdapters = false;
  }

  for (final rawLine in lines) {
    final normalizedLine = rawLine.replaceAll('\t', '  ');
    final trimmed = normalizedLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final indent = normalizedLine.length - normalizedLine.trimLeft().length;

    if (indent == 0) {
      final entry = _parseYamlPair(trimmed);
      if (entry != null && entry.key == 'version_id') {
        versionId = entry.value;
        continue;
      }
      if (trimmed == 'schools:') {
        inSchools = true;
      } else if (inSchools) {
        // 下一个顶层键：schools 列表结束
        flushSchool();
        inSchools = false;
      }
      continue;
    }
    if (!inSchools) {
      continue;
    }

    if (indent == 2 && trimmed.startsWith('- ')) {
      flushSchool();
      final entry = _parseYamlPair(trimmed.substring(2).trim());
      final id = entry != null && entry.key == 'id' ? entry.value : '';
      currentSchool = WarehouseSearchSchoolEntry(id: id, adapters: []);
      continue;
    }
    final school = currentSchool;
    if (school == null) {
      continue;
    }

    if (trimmed == 'adapters:') {
      inAdapters = true;
      continue;
    }
    if (!inAdapters) {
      continue;
    }

    if (trimmed.startsWith('- ')) {
      flushAdapter();
      final entry = _parseYamlPair(trimmed.substring(2).trim());
      if (entry != null && entry.key == 'adapter_id') {
        currentAdapter = WarehouseSearchAdapterEntry(
          adapterId: entry.value,
          adapterName: '',
        );
      }
      continue;
    }
    final entry = _parseYamlPair(trimmed);
    final adapter = currentAdapter;
    if (entry != null && entry.key == 'adapter_name' && adapter != null) {
      currentAdapter = WarehouseSearchAdapterEntry(
        adapterId: adapter.adapterId,
        adapterName: entry.value,
      );
    }
  }
  flushSchool();
  return WarehouseSearchIndex(versionId: versionId, schools: schools);
}

List<Map<String, String>> _parseYamlListMaps(
  String content, {
  required String topLevelKey,
}) {
  final lines = content.split(RegExp(r'\r?\n'));
  final items = <Map<String, String>>[];
  var inTargetSection = false;
  Map<String, String>? current;

  for (final rawLine in lines) {
    final normalizedLine = rawLine.replaceAll('\t', '  ');
    final trimmed = normalizedLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }

    if (!inTargetSection) {
      if (trimmed == '$topLevelKey:') {
        inTargetSection = true;
      }
      continue;
    }

    final indent = normalizedLine.length - normalizedLine.trimLeft().length;
    if (indent == 0 && trimmed.endsWith(':')) {
      break;
    }

    if (indent == 2 && trimmed.startsWith('- ')) {
      if (current != null && current.isNotEmpty) {
        items.add(current);
      }
      current = <String, String>{};
      final pair = trimmed.substring(2).trim();
      if (pair.isNotEmpty) {
        final entry = _parseYamlPair(pair);
        if (entry != null) {
          current[entry.key] = entry.value;
        }
      }
      continue;
    }

    if (indent >= 4 && current != null) {
      final entry = _parseYamlPair(trimmed);
      if (entry != null) {
        current[entry.key] = entry.value;
      }
    }
  }

  if (current != null && current.isNotEmpty) {
    items.add(current);
  }

  return items;
}

MapEntry<String, String>? _parseYamlPair(String line) {
  final separatorIndex = line.indexOf(': ');
  if (separatorIndex <= 0) {
    return null;
  }
  final key = line.substring(0, separatorIndex).trim();
  var value = line.substring(separatorIndex + 2).trim();
  value = _stripInlineComment(value);
  if ((value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))) {
    value = value.substring(1, value.length - 1);
  }
  return MapEntry(key, _decodeEscapedYamlText(value.trim()));
}

String _stripInlineComment(String value) {
  if (value.isEmpty || !value.contains('#')) {
    return value;
  }
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
    } else if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
    }
    if (char == '#' && !inSingleQuote && !inDoubleQuote) {
      break;
    }
    buffer.write(char);
  }
  return buffer.toString().trimRight();
}

String _decodeEscapedYamlText(String value) {
  return value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t');
}
