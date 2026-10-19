import 'dart:async';
import 'dart:io' show Platform;

/// 格式化当前时间为日志时间戳 `[HH:mm:ss.SSS]`。
String formatLogTimestamp([DateTime? time]) {
  final t = time ?? DateTime.now();
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  final s = t.second.toString().padLeft(2, '0');
  final ms = t.millisecond.toString().padLeft(3, '0');
  return '[$h:$m:$s.$ms]';
}

/// 并行竞争结果。
class RaceResult<T> {
  /// 胜出者，所有候选都返回 null 时为 null。
  final T? winner;

  /// 所有未胜出的 future 的错误或返回 null 时附带的信息。
  final List<Object> errors;

  const RaceResult({required this.winner, required this.errors});
}

/// 让一组 future 并行竞争，返回第一个 [extract] 不为 null 的结果。
///
/// [futures] 中的 future 通过 [extract] 从原始结果中提取有效值；
/// 返回 null 表示该候选不是胜者，继续等待其他候选。
///
/// 任一 future 胜出时立即返回；全部返回 null 或抛异常时，
/// 返回 [RaceResult] 其中 winner 为 null，errors 收集了所有错误。
Future<RaceResult<T>> raceFutures<S, T>(
  Iterable<Future<S>> futures,
  T? Function(S result) extract,
) async {
  final completer = Completer<RaceResult<T>>();
  var completedCount = 0;
  final total = futures.length;
  final errors = <Object>[];
  T? winner;

  for (final future in futures) {
    future
        .then((result) {
          final extracted = extract(result);
          if (extracted != null) {
            winner = extracted;
          }
          completedCount++;
          if (winner != null && !completer.isCompleted) {
            completer.complete(RaceResult(winner: winner, errors: errors));
          } else if (completedCount >= total && !completer.isCompleted) {
            completer.complete(RaceResult(winner: winner, errors: errors));
          }
        })
        .catchError((Object error) {
          errors.add(error);
          completedCount++;
          if (completedCount >= total && !completer.isCompleted) {
            completer.complete(RaceResult(winner: winner, errors: errors));
          }
        });
  }

  return completer.future;
}

/// 所有内置镜像前缀（不含 custom）。
///
/// 安全边界（2026-10-19 信任根收紧）：镜像前缀**只允许用于 APK 字节流**的
/// 候选加速与下载信任判定（isTrustedApkDownloadUrl）。清单（发行版 JSON /
/// Release 页面 HTML 等「决定下载什么、校验什么」的响应）一律禁止走镜像 ——
/// 镜像是 TLS 终止点，可同时替换清单与其声明的摘要（自洽投毒）。
/// 清单来源用 [officialManifestUrlHosts] + [isTrustedManifestUrl] 判定。
const List<String> allBuiltinMirrorUrlPrefixes = [
  'https://ghfast.top/',
  'https://gh.llkk.cc/',
  'https://gh-proxy.com/',
  'https://ghproxy.net/',
];

/// 为 [originalUrl] 构建镜像候选列表。
///
/// [selectedMirrorPrefix] 为用户选择的镜像前缀，会排在最前面；
/// 随后是全部内置镜像；最后是原始 URL。
/// 自动去重。
///
/// ⚠️ 返回值仅可用于 **APK 字节流**的下载候选；清单（JSON/HTML）必须直连，
/// 见 [isTrustedManifestUrl]。历史上本函数曾被用于更新清单竞速 —— 清单与
/// 其声明的摘要可被第三方镜像一同伪造，已收紧（2026-10-19）。
List<String> buildMirrorCandidateUrls(
  String originalUrl, {
  String? selectedMirrorPrefix,
}) {
  final seen = <String>{};
  final candidates = <String>[];

  void addPrefix(String prefix) {
    final normalized = prefix.trim();
    if (normalized.isEmpty) return;
    final separator = normalized.endsWith('/') ? '' : '/';
    final url = '$normalized$separator$originalUrl';
    if (seen.add(url)) candidates.add(url);
  }

  if (selectedMirrorPrefix != null && selectedMirrorPrefix.isNotEmpty) {
    addPrefix(selectedMirrorPrefix);
  }
  for (final prefix in allBuiltinMirrorUrlPrefixes) {
    addPrefix(prefix);
  }
  if (seen.add(originalUrl)) candidates.add(originalUrl);

  return candidates;
}

/// 校验 APK 下载 URL 是否来自受信任的来源（GitHub 或已配置镜像）。
///
/// 只做主机级判定，且**仅用于 APK 字节流**：清单来源的信任判定见
/// [isTrustedManifestUrl]。完整性由 AppUpdateService.downloadAndInstallUpdate
/// 的安装闸门强制保证 —— 无官方 SHA-256 拒装、mismatch 拒绝并删除文件，
/// 不存在「可跳过/仅告警」的路径。
bool isTrustedApkDownloadUrl(String url, {String? mirrorUrlPrefix}) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  final host = uri.host.toLowerCase();

  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return uri.scheme == 'http' || uri.scheme == 'https';
    }
  }

  if (uri.scheme != 'https') {
    return false;
  }

  bool hostMatches(String pattern) =>
      host == pattern || host.endsWith('.$pattern');

  if (hostMatches('github.com') || hostMatches('githubusercontent.com')) {
    return true;
  }

  // GitCode 发行版附件（国内直连渠道）。
  if (hostMatches('gitcode.com')) {
    return true;
  }

  bool prefixHostMatches(String? prefix) {
    if (prefix == null || prefix.trim().isEmpty) {
      return false;
    }
    final prefixHost = Uri.tryParse(prefix.trim())?.host.toLowerCase();
    return prefixHost != null && prefixHost.isNotEmpty && host == prefixHost;
  }

  if (prefixHostMatches(mirrorUrlPrefix)) {
    return true;
  }
  for (final prefix in allBuiltinMirrorUrlPrefixes) {
    if (prefixHostMatches(prefix)) {
      return true;
    }
  }
  return false;
}

/// 更新清单（发行版 JSON / Release 页面 HTML）允许的主机后缀。
///
/// 清单「决定下载什么、校验什么」，必须只来自官方直连主机；第三方反代
/// 镜像（allBuiltinMirrorUrlPrefixes）与用户自填前缀都不在此列 —— 它们
/// 对响应有完全控制权，可同时伪造版本与摘要（自洽投毒，2026-10-19）。
const List<String> officialManifestUrlHosts = [
  'github.com',
  'githubusercontent.com',
  'gitcode.com',
];

/// 校验 URL 是否为官方直连主机（GitHub / GitCode，不含任何镜像）。
///
/// 用于「内容会被展示或决定行为」的 JSON：更新清单、捐赠者名单这类数据不该
/// 由镜像回答（镜像对响应有完全控制权，可整份替换）。loopback 测试豁免同样
/// 适用（自动化测试用本地 HTTP 服务当数据源）。
bool isOfficialDirectUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  final host = uri.host.toLowerCase();

  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return uri.scheme == 'http' || uri.scheme == 'https';
    }
  }

  if (uri.scheme != 'https') {
    return false;
  }

  bool hostMatches(String pattern) =>
      host == pattern || host.endsWith('.$pattern');

  for (final pattern in officialManifestUrlHosts) {
    if (hostMatches(pattern)) {
      return true;
    }
  }
  return false;
}

/// 校验更新清单 URL 是否为官方直连主机（不含任何镜像）。
///
/// 与 [isTrustedApkDownloadUrl] 的区别：不接受镜像前缀与用户自填前缀；
/// 语义等价于 [isOfficialDirectUrl]，保留本名是因为调用点都在更新链路里、
/// 读起来更直白。
bool isTrustedManifestUrl(String url) => isOfficialDirectUrl(url);
