import 'dart:io';

/// 守卫数据源解析：守卫测的是「这次提交的内容」，不是磁盘上的工作区。
///
/// 默认（CI / 本地直接 `flutter test`）：[resolve] 原样返回仓库相对路径 ——
/// 守卫读工作区，行为与 2026-10-20 之前完全一致。
///
/// pre-commit 钩子会先把**本次提交的快照**物化到临时目录
/// （`git checkout-index -a --prefix=<快照>/`：普通提交物化共享索引、
/// 路径限定提交物化 git 传入的临时索引 `next-index-*.lock`，两者都精确等于
/// 「这个提交里有什么」），再通过环境变量 `MIKCB_GUARD_SNAPSHOT` 把快照根
/// 交给守卫。此时 [resolve] 把仓库相对路径映射进快照 —— 工作区里别人的
/// 在途改动、未跟踪文件天然不在快照里，既不会误伤也不会被当成自己的。
///
/// 规则：
/// - 守卫里所有 `File(...)` / `Directory(...)` 的路径都必须经 [resolve]
///   （`guard_source_test.dart` 有纪律扫描盯着这条）；
/// - [resolve] 对**绝对路径**原样返回：`listSync` 产出的路径已经落在
///   正确的根下（工作区模式=仓库根相对、快照模式=快照根），不需要二次解析；
/// - 把 listSync 产出的路径与**仓库相对字面量做比较**时，必须先过
///   [repoRelative] 归一（快照模式下它们是绝对路径，直接比较会全错，
///   `frozen_test_dirs_guard` / `liquid_glass_single_entry_guard` 是先例）。
class GuardSource {
  static String? get _snapshotRoot {
    final raw = Platform.environment['MIKCB_GUARD_SNAPSHOT']?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw.endsWith('/') || raw.endsWith('\\') ? raw : '$raw/';
  }

  static bool _isAbsolute(String p) =>
      p.startsWith('/') ||
      p.startsWith('\\') ||
      RegExp(r'^[A-Za-z]:[/\\]').hasMatch(p);

  /// 把「仓库相对路径或 listSync 产出的路径」解析成实际可读路径。
  static String resolve(String repoPath) {
    if (_isAbsolute(repoPath)) {
      return repoPath;
    }
    final root = _snapshotRoot;
    return root == null ? repoPath : '$root$repoPath';
  }

  /// 把任意来源的路径归一成**仓库相对**的 POSIX 形式（比较 / 汇报用）。
  static String repoRelative(String anyPath) {
    final normalized = anyPath.replaceAll('\\', '/');
    final root = _snapshotRoot?.replaceAll('\\', '/');
    if (root != null && normalized.startsWith(root)) {
      return normalized.substring(root.length);
    }
    final cwd = Directory.current.path.replaceAll('\\', '/');
    final cwdPrefix = cwd.endsWith('/') ? cwd : '$cwd/';
    if (normalized.startsWith(cwdPrefix)) {
      return normalized.substring(cwdPrefix.length);
    }
    return normalized;
  }
}
