import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/warehouse_repository_models.dart';
import '../models/timetable_settings.dart';

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
      : _client = client ?? http.Client();

  Future<WarehouseRootIndex> fetchRootIndex(
    WarehouseRepositorySource source, {
    WarehouseFetchOptions? options,
  }) async {
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
      throw const WarehouseRepositoryException('未读取到任何学校或工具索引');
    }
    return WarehouseRootIndex(schools: schools);
  }

  Future<WarehouseAdaptersIndex> fetchAdaptersIndex(
    WarehouseRepositorySource source,
    WarehouseSchoolEntry school, {
    WarehouseFetchOptions? options,
  }) async {
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
          ),
        )
        .where((item) => item.adapterId.isNotEmpty && item.assetJsPath.isNotEmpty)
        .toList(growable: false);
    if (adapters.isEmpty) {
      throw WarehouseRepositoryException('未读取到 ${school.name} 的适配器信息');
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
    return _fetchText(
      source.buildRawFileUri(path),
      options: options,
    );
  }

  Future<String> _fetchText(
    Uri uri, {
    WarehouseFetchOptions? options,
  }) async {
    final candidates = _buildCandidateUris(
      uri,
      options ??
          const WarehouseFetchOptions(
            downloadSource: AppUpdateDownloadSource.mirror,
            mirrorPreset: AppUpdateMirrorPreset.ghfast,
            customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
          ),
    );

    Object? lastError;
    for (final candidate in candidates) {
      try {
        final response = await _client.get(
          candidate,
          headers: const {
            'Accept': 'text/plain, */*',
            'User-Agent': 'mikcb-warehouse-client',
          },
        );
        if (response.statusCode == 200) {
          return utf8.decode(response.bodyBytes);
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
    }

    final usingMirror =
        (options ?? const WarehouseFetchOptions(
              downloadSource: AppUpdateDownloadSource.mirror,
              mirrorPreset: AppUpdateMirrorPreset.ghfast,
              customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
            ))
            .downloadSource ==
            AppUpdateDownloadSource.mirror;
    throw WarehouseRepositoryException(
      usingMirror
          ? '暂时无法读取适配仓。当前已按“版本更新”里的国内镜像线路尝试读取，请检查网络，或切到其他镜像线路后重试。'
              '${lastError == null ? "" : " 原始错误：$lastError"}'
          : '暂时无法读取适配仓。当前正在使用 GitHub 原始线路，请检查网络，或在“版本更新”里切到国内镜像后重试。'
              '${lastError == null ? "" : " 原始错误：$lastError"}',
    );
  }

  List<Uri> _buildCandidateUris(
    Uri originalUri,
    WarehouseFetchOptions options,
  ) {
    if (options.downloadSource != AppUpdateDownloadSource.mirror) {
      return [originalUri];
    }

    final orderedPresets = <AppUpdateMirrorPreset>[
      options.mirrorPreset,
      AppUpdateMirrorPreset.ghfast,
      AppUpdateMirrorPreset.ghproxyCn,
      AppUpdateMirrorPreset.ghLlkk,
      if (options.customMirrorUrlPrefix.trim().isNotEmpty)
        AppUpdateMirrorPreset.custom,
    ];
    final seen = <String>{};
    final uris = <Uri>[];
    for (final preset in orderedPresets) {
      final prefix = resolveAppUpdateMirrorUrlPrefix(
        preset: preset,
        customUrlPrefix: options.customMirrorUrlPrefix,
      );
      final separator = prefix.endsWith('/') ? '' : '/';
      final candidate = Uri.parse('$prefix$separator$originalUri');
      final key = candidate.toString();
      if (seen.add(key)) {
        uris.add(candidate);
      }
    }
    return uris;
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
