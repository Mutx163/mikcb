class WarehouseRepositoryException implements Exception {
  final String message;

  const WarehouseRepositoryException(this.message);

  @override
  String toString() => 'WarehouseRepositoryException: $message';
}

class WarehouseRepositorySource {
  final String owner;
  final String repo;
  final String branch;

  const WarehouseRepositorySource({
    required this.owner,
    required this.repo,
    this.branch = 'main',
  });

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
