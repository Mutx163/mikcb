import 'dart:async';
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

  /// 轻屿专属目录探测的超时。
  ///
  /// 它是锦上添花：探测失败只是少一个额外条目，不该拖慢主路径，更不该挂住。
  /// `http.Client` 默认**没有**超时，所以一个半死的镜像能把这次等待拖成永远 ——
  /// 上一版就是因此让学校页一直转圈圈。
  static const Duration qingyuOnlyProbeTimeout = Duration(seconds: 6);

  /// 只打一次主地址、且自带超时的探测读取。
  ///
  /// Why 不用 [_fetchText]：那条路会按「主地址 + 4 个镜像候选」依次试。`qingyu_only/`
  /// 对绝大多数学校**不存在**（222 所里目前只有 1 所），走完整候选链等于每次开学校
  /// 页都为一次必然的 404 花掉 5 个来回。主地址能读到就够了：读不到就当这所学校
  /// 没有专属条目，下次还会再试。
  Future<String> _fetchProbeText(
    WarehouseRepositorySource source,
    String relativePath,
  ) async {
    final effectiveSource = source;
    final uri = effectiveSource.buildFileUri(relativePath);
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': uri.host == 'api.gitcode.com'
                ? 'application/json'
                : 'text/plain, */*',
            'User-Agent': 'mikcb-warehouse-client',
          },
        )
        .timeout(qingyuOnlyProbeTimeout);
    if (response.statusCode != 200) {
      throw const WarehouseRepositoryException('qingyu_only_probe_miss');
    }
    return utf8.decode(_decodeCandidateBytes(uri, response.bodyBytes));
  }

  /// 拉取轻屿专属适配条目（`qingyu_only/<目录>/adapters.yaml`）。
  ///
  /// 这个目录是本仓自有的，永不参与上游同步、也永不打进任何索引
  /// （`build_search_index.py` 只聚合 `resources/*/adapters.yaml`）。因此：
  ///
  /// - **旧版 App 完全不受影响** —— 它从不请求这个路径，只看 `resources/`，看到的
  ///   仍是一切如常的标准适配器。
  /// - 新版 App 对没有该目录的仓库（任何镜像的旧快照、上游仓、他人 fork）会拿到
  ///   404，这里**降级为「没有专属适配」**而不是报错。
  ///
  /// 逐个学校按需探测（1 次请求），不引入新的全局索引 —— 多一个索引就多一件要维护
  /// 且要防同步的东西，而学校数量有界。
  ///
  /// 调用方**不得**把这个 Future 挂在页面渲染的关键路径上：它对绝大多数学校都是
  /// 一次必然的 404，挂在关键路径上会让整个学校页陪着它一起等。
  Future<List<WarehouseAdapterEntry>> fetchQingyuOnlyAdapters(
    WarehouseRepositorySource source,
    WarehouseSchoolEntry school,
  ) async {
    final path = 'qingyu_only/${school.resourceFolder}/adapters.yaml';
    String content;
    try {
      content = await _fetchProbeText(source, path);
    } on WarehouseRepositoryException {
      // 绝大多数学校没有这个目录，属正常情况。
      return const [];
    } on TimeoutException {
      return const [];
    }
    return _parseQingyuOnlyAdapterEntries(content);
  }

  /// 拉取 `qingyu_only/<目录>/` 下的一个文件（作息数据、或专属脚本副本）。
  ///
  /// 404 / 解析失败一律抛出 [WarehouseRepositoryException]，由调用方决定降级方式；
  /// 「取不到就按标准流程继续」这个决定不应该藏在拉取层。
  Future<String> fetchQingyuOnlyText(
    WarehouseRepositorySource source,
    WarehouseSchoolEntry school,
    String relativeName, {
    WarehouseFetchOptions? options,
  }) async {
    // 目录穿越：仓库内容是远端数据，文件名必须限制在同目录内。
    if (relativeName.isEmpty ||
        relativeName.contains('/') ||
        relativeName.contains('\\') ||
        relativeName.contains('..')) {
      throw const WarehouseRepositoryException('qingyu_only_bad_relative_name');
    }
    return _fetchText(
      source,
      'qingyu_only/${school.resourceFolder}/$relativeName',
      options: options,
    );
  }

  List<WarehouseAdapterEntry> _parseQingyuOnlyAdapterEntries(String content) {
    final maps = _parseYamlListMaps(content, topLevelKey: 'adapters');
    return maps
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
            timeSchemesFile: item['time_schemes_file'] ?? '',
            campusPrompt: item['campus_prompt'] ?? '',
            isQingyuOnly: true,
          ),
        )
        .where((item) => item.adapterId.isNotEmpty && item.assetJsPath.isNotEmpty)
        .toList(growable: false);
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
    bool preferQingyuOnlyAsset = false,
  }) async {
    // 轻屿专属条目声明的 `asset_js_path` 通常指向 `resources/` 下那份**同一份**
    // 上游标准脚本（刻意不另存副本，避免两份解析逻辑漂移）。所以顺序是：先在
    // `qingyu_only/` 本目录找，找不到回落 `resources/`。标准适配器完全不受影响。
    final candidates = preferQingyuOnlyAsset || adapter.isQingyuOnly
        ? <String>[
            'qingyu_only/${school.resourceFolder}/${adapter.assetJsPath}',
            'resources/${school.resourceFolder}/${adapter.assetJsPath}',
          ]
        : <String>['resources/${school.resourceFolder}/${adapter.assetJsPath}'];

    List<int> bytes;
    if (candidates.length == 1) {
      bytes = await _fetchBytes(source, candidates.single, options: options);
    } else {
      // 本目录找不到就回落 `resources/` 下那份同一脚本。全部候选都失败时以最后一次
      // 的错误为准——那才是用户真正会看到的那个 host 的失败原因。
      List<int>? resolved;
      WarehouseRepositoryException? lastError;
      for (final path in candidates) {
        try {
          resolved = await _fetchBytes(source, path, options: options);
          break;
        } on WarehouseRepositoryException catch (error) {
          lastError = error;
        }
      }
      if (resolved == null) {
        throw lastError ??
            const WarehouseRepositoryException('warehouse_script_fetch_failed');
      }
      bytes = resolved;
    }
    // Integrity gate: when the index declares a SHA-256 for the script, the
    // fetched bytes must match before the script is ever handed to WebView.
    //
    // IMPORTANT: this gate is currently INERT in production. As of 2026-09-26
    // none of the 204 adapters.yaml files in Mutx163/qingyu_warehouse contain a
    // `sha256` key, and scripts/build_data.py does not emit one either, so
    // `declared` is empty for every school and no script is ever verified.
    // Turning this into a hard failure (fail-closed) would brick 教务 import for
    // every user until the upstream index starts publishing hashes, so the
    // permissive branch stays deliberately. Closing this properly means adding
    // hash emission to the qingyu_warehouse build, not changing this check.
    //
    // Even once hashes exist they only bind script-to-index: the index itself is
    // still fetched unverified, so an attacker who can poison adapters.yaml can
    // replace the hash too. The index needs its own integrity story.
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
