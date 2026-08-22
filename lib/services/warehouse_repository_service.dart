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

  const WarehouseFetchOptions({
    required this.downloadSource,
    required this.mirrorPreset,
    required this.customMirrorUrlPrefix,
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
      source.buildRawFileUri('index/root_index.yaml'),
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
      source.buildRawFileUri(path),
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

  Future<String> fetchAdapterScript(
    WarehouseRepositorySource source, {
    required WarehouseSchoolEntry school,
    required WarehouseAdapterEntry adapter,
    WarehouseFetchOptions? options,
  }) async {
    final path = 'resources/${school.resourceFolder}/${adapter.assetJsPath}';
    final bytes = await _fetchBytes(source.buildRawFileUri(path), options: options);
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

  Future<String> _fetchText(Uri uri, {WarehouseFetchOptions? options}) async {
    return utf8.decode(await _fetchBytes(uri, options: options));
  }

  Future<List<int>> _fetchBytes(
    Uri uri, {
    WarehouseFetchOptions? options,
  }) async {
    final effectiveOptions =
        options ??
        const WarehouseFetchOptions(
          downloadSource: AppUpdateDownloadSource.mirror,
          mirrorPreset: AppUpdateMirrorPreset.ghfast,
          customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
        );
    final candidates = _buildCandidateUris(uri, effectiveOptions);
    _log('请求 $uri,候选 ${candidates.length} 个');

    // Prefer the official raw URL first so a poisoned mirror cannot win a race.
    // Fall back to remaining candidates only when the primary fetch fails.
    final orderedCandidates = <Uri>[
      uri,
      ...candidates.where((candidate) => candidate != uri),
    ];
    Object? lastError;
    for (final candidate in orderedCandidates) {
      try {
        final response = await _client.get(
          candidate,
          headers: const {
            'Accept': 'text/plain, */*',
            'User-Agent': 'mikcb-warehouse-client',
          },
        );
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
        lastError = StateError('http_${response.statusCode}');
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
