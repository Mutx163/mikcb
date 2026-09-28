class WarehouseRepositoryException implements Exception {
  final String message;

  const WarehouseRepositoryException(this.message);

  @override
  String toString() => 'WarehouseRepositoryException: $message';
}

/// 适配仓宿主：GitHub（raw.githubusercontent 直链）或 GitCode（v5 contents API）。
enum WarehouseRepositoryHost { github, gitcode }

/// 轻屿教务适配仓默认源。
/// GitCode 镜像（mutx/qingyu_warehouse）与 GitHub 主仓（Mutx163/qingyu_warehouse）
/// 命名空间不同，gitcodeOwner 需单独指定；更新渠道选 GitCode 时用它直连拉取。
const WarehouseRepositorySource defaultQingyuWarehouseSource =
    WarehouseRepositorySource(
  owner: 'Mutx163',
  repo: 'qingyu_warehouse',
  gitcodeOwner: 'mutx',
);

class WarehouseRepositorySource {
  final String owner;
  final String repo;
  final String branch;
  final WarehouseRepositoryHost host;

  /// GitCode 侧命名空间与 GitHub 不同时的覆盖（如 GitHub Mutx163 → GitCode mutx）。
  /// host 为 gitcode 时优先生效；为空则沿用 owner/repo。
  final String? gitcodeOwner;
  final String? gitcodeRepo;

  const WarehouseRepositorySource({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.host = WarehouseRepositoryHost.github,
    this.gitcodeOwner,
    this.gitcodeRepo,
  });

  String get _gitcodeEffectiveOwner => gitcodeOwner ?? owner;
  String get _gitcodeEffectiveRepo => gitcodeRepo ?? repo;

  /// 返回切换宿主后的源（其余字段保持不变）。
  WarehouseRepositorySource withHost(WarehouseRepositoryHost newHost) {
    if (newHost == host) {
      return this;
    }
    return WarehouseRepositorySource(
      owner: owner,
      repo: repo,
      branch: branch,
      host: newHost,
      gitcodeOwner: gitcodeOwner,
      gitcodeRepo: gitcodeRepo,
    );
  }

  factory WarehouseRepositorySource.fromGitHubUrl(
    String url, {
    String branch = 'main',
    String? gitcodeOwner,
    String? gitcodeRepo,
  }) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) {
      throw const WarehouseRepositoryException('invalid_repository_url');
    }

    if (uri.host == 'github.com') {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      if (segments.length < 2) {
        throw const WarehouseRepositoryException('incomplete_github_repo_url');
      }
      return WarehouseRepositorySource(
        owner: segments[0],
        repo: segments[1],
        branch: branch,
        gitcodeOwner: gitcodeOwner,
        gitcodeRepo: gitcodeRepo,
      );
    }

    if (uri.host == 'raw.githubusercontent.com') {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      if (segments.length < 3) {
        throw const WarehouseRepositoryException('incomplete_raw_github_url');
      }
      return WarehouseRepositorySource(
        owner: segments[0],
        repo: segments[1],
        branch: segments[2],
        gitcodeOwner: gitcodeOwner,
        gitcodeRepo: gitcodeRepo,
      );
    }

    // GitCode 仓库页（国内直连渠道，拉取走 v5 contents API）。
    if (uri.host == 'gitcode.com' || uri.host == 'raw.gitcode.com') {
      final segments = uri.pathSegments
          .where((item) => item.isNotEmpty)
          .toList();
      if (segments.length < 2) {
        throw const WarehouseRepositoryException('incomplete_github_repo_url');
      }
      return WarehouseRepositorySource(
        owner: segments[0],
        repo: segments[1],
        branch: branch,
        host: WarehouseRepositoryHost.gitcode,
      );
    }

    throw const WarehouseRepositoryException('github_only_supported');
  }

  Uri buildRawFileUri(String relativePath) {
    final normalizedPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return Uri.parse(
      'https://raw.githubusercontent.com/$owner/$repo/$branch/$normalizedPath',
    );
  }

  /// GitHub 侧原始文件地址：GitCode 主渠道失败时的回退目标。
  Uri buildGitHubRawFileUri(String relativePath) => buildRawFileUri(relativePath);

  /// GitCode v5 contents API（Gitee 兼容，免令牌可读，返回 base64 JSON）。
  /// GitCode 没有 GitHub 那样的 raw 直链（/raw/ 返回的是网页预览），
  /// 所以文件内容统一从 API 取。
  Uri buildGitCodeContentsUri(String relativePath) {
    final normalizedPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    final encodedPath = normalizedPath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    return Uri.parse(
      'https://api.gitcode.com/api/v5/repos/'
      '$_gitcodeEffectiveOwner/$_gitcodeEffectiveRepo/contents/'
      '$encodedPath?ref=${Uri.encodeQueryComponent(branch)}',
    );
  }

  /// 按宿主返回主拉取地址。
  Uri buildFileUri(String relativePath) => switch (host) {
    WarehouseRepositoryHost.github => buildRawFileUri(relativePath),
    WarehouseRepositoryHost.gitcode => buildGitCodeContentsUri(relativePath),
  };

  String get repositoryUrl => 'https://github.com/$owner/$repo';
}

class WarehouseSchoolEntry {
  final String id;
  final String name;
  final String initial;
  final String resourceFolder;

  const WarehouseSchoolEntry({
    required this.id,
    required this.name,
    required this.initial,
    required this.resourceFolder,
  });
}

class WarehouseRootIndex {
  final List<WarehouseSchoolEntry> schools;

  const WarehouseRootIndex({required this.schools});
}

class WarehouseAdapterEntry {
  final String adapterId;
  final String adapterName;
  final String category;
  final String assetJsPath;
  final String importUrl;
  final String maintainer;
  final String description;

  /// 适配器脚本的 SHA-256（小写十六进制），由仓库 adapters.yaml 声明。
  ///
  /// 为空表示索引未提供校验和，拉取时跳过完整性校验。**实测当前全部为空**：
  /// Mutx163/qingyu_warehouse 的 204 个 adapters.yaml 均无 `sha256` 键，
  /// `scripts/build_data.py` 也不生成，所以这个字段目前不提供任何保护。
  /// 真正补上要靠在 qingyu_warehouse 的构建里输出哈希，见
  /// `WarehouseRepositoryService.fetchAdapterScript` 的说明。
  final String sha256;

  /// 轻屿专属字段（`qingyu_only/<学校ID>/adapters.yaml`），上游 schema 未定义。
  ///
  /// Why it lives here and not in the script: the upstream protocol can only
  /// carry **one** global 作息 per import (`savePresetTimeSlots`), so a school
  /// that publishes different 作息 per campus / teaching building cannot be
  /// expressed by any script. Extending the bridge would have broken the rule
  /// that our scripts stay submittable upstream, so that knowledge moved to a
  /// data file next to the script and the script stayed 100% standard.
  ///
  /// Empty on every `resources/` adapter, and on every App that predates this
  /// field: those Apps never read these keys, so adding them changes nothing
  /// for them.
  ///
  /// 学校作息数据文件名（同目录下），例如 `time_schemes.json`。为空表示这个
  /// 适配器没有专属作息数据。
  final String timeSchemesFile;

  /// 这一条是否来自 `qingyu_only/` 而非 `resources/`。
  ///
  /// 决定脚本的查找顺序：专属条目声明的 `asset_js_path` 通常指向 `resources/` 下
  /// 那份**同一份**上游标准脚本（刻意不另存副本），所以要先在 `qingyu_only/` 本
  /// 目录找、找不到再回落。标准适配器恒为 false，走原来的单路径，行为不变。
  final bool isQingyuOnly;

  /// 仅当同一所学校有多套作息时才需要：导入前问用户「你在哪个校区？」。
  /// 为空则直接用唯一那套。
  final String campusPrompt;

  const WarehouseAdapterEntry({
    required this.adapterId,
    required this.adapterName,
    required this.category,
    required this.assetJsPath,
    required this.importUrl,
    required this.maintainer,
    required this.description,
    this.sha256 = '',
    this.timeSchemesFile = '',
    this.campusPrompt = '',
    this.isQingyuOnly = false,
  });
}

class WarehouseAdaptersIndex {
  final List<WarehouseAdapterEntry> adapters;

  const WarehouseAdaptersIndex({required this.adapters});
}

/// 教务导入「按适配器（脚本）名称搜索」全局索引的适配器条目。
/// 仅含搜索所需的 ID 与名称，来自 index/search_index.yaml（仓库
/// scripts/build_search_index.py 聚合全部学校的 adapters.yaml 生成）。
class WarehouseSearchAdapterEntry {
  final String adapterId;
  final String adapterName;

  const WarehouseSearchAdapterEntry({
    required this.adapterId,
    required this.adapterName,
  });
}

/// 搜索索引中一所学校的适配器清单。
class WarehouseSearchSchoolEntry {
  final String id;
  final List<WarehouseSearchAdapterEntry> adapters;

  const WarehouseSearchSchoolEntry({required this.id, required this.adapters});

  /// 关键词命中的适配器显示名（保持索引顺序；名称为空时回退用 ID 展示），
  /// 大小写不敏感。适配器 ID（如 WakeUp）与名称（如 WakeUp课程表分享口令导入）
  /// 都参与匹配。
  List<String> matchedAdapterNames(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    final names = <String>[];
    for (final adapter in adapters) {
      final displayName = adapter.adapterName.isNotEmpty
          ? adapter.adapterName
          : adapter.adapterId;
      if (displayName.toLowerCase().contains(normalized) ||
          adapter.adapterId.toLowerCase().contains(normalized)) {
        names.add(displayName);
      }
    }
    return List.unmodifiable(names);
  }
}

/// index/search_index.yaml 的解析结果。
class WarehouseSearchIndex {
  final String versionId;
  final List<WarehouseSearchSchoolEntry> schools;

  const WarehouseSearchIndex({required this.versionId, required this.schools});

  /// 关键词命中的适配器显示名，按学校 id 分组（仅含非空命中）。
  /// 教务导入搜索用它把「按脚本名命中」的学校也带出来，并回显命中的脚本名。
  Map<String, List<String>> matchedAdapterNamesBySchool(String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return const {};
    }
    final matches = <String, List<String>>{};
    for (final school in schools) {
      final names = school.matchedAdapterNames(normalized);
      if (names.isNotEmpty) {
        matches[school.id] = names;
      }
    }
    return Map.unmodifiable(matches);
  }
}

/// 教务导入学校搜索：命中学校名称/ID/首字母/资源目录，或搜索索引中任一
/// 适配器名称/ID。[adapterMatches] 是
/// WarehouseSearchIndex.matchedAdapterNamesBySchool 的结果；传空表（旧版
/// 适配仓没有全局搜索索引时）行为与仅按学校字段搜索完全一致。
List<WarehouseSchoolEntry> filterWarehouseSchools(
  List<WarehouseSchoolEntry> schools,
  String query, {
  Map<String, List<String>> adapterMatches = const {},
}) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) {
    return schools;
  }
  return schools
      .where((school) {
        final bool fieldMatch =
            school.name.toLowerCase().contains(keyword) ||
            school.id.toLowerCase().contains(keyword) ||
            school.initial.toLowerCase().contains(keyword) ||
            school.resourceFolder.toLowerCase().contains(keyword);
        if (fieldMatch) {
          return true;
        }
        return adapterMatches[school.id]?.isNotEmpty ?? false;
      })
      .toList(growable: false);
}
