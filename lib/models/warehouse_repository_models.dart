class WarehouseRepositoryException implements Exception {
  final String message;

  const WarehouseRepositoryException(this.message);

  @override
  String toString() => 'WarehouseRepositoryException: $message';
}

/// 适配仓宿主：GitHub（raw.githubusercontent 直链）或 GitCode（v5 contents API）。
enum WarehouseRepositoryHost { github, gitcode }

class WarehouseRepositorySource {
  final String owner;
  final String repo;
  final String branch;
  final WarehouseRepositoryHost host;

  const WarehouseRepositorySource({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.host = WarehouseRepositoryHost.github,
  });

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
    );
  }

  factory WarehouseRepositorySource.fromGitHubUrl(
    String url, {
    String branch = 'main',
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
      'https://api.gitcode.com/api/v5/repos/$owner/$repo/contents/'
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
  /// 为空表示索引未提供校验和（旧版索引），拉取时跳过完整性校验。
  final String sha256;

  const WarehouseAdapterEntry({
    required this.adapterId,
    required this.adapterName,
    required this.category,
    required this.assetJsPath,
    required this.importUrl,
    required this.maintainer,
    required this.description,
    this.sha256 = '',
  });
}

class WarehouseAdaptersIndex {
  final List<WarehouseAdapterEntry> adapters;

  const WarehouseAdaptersIndex({required this.adapters});
}
