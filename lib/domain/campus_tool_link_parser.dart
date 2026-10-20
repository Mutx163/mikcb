import '../models/campus_tool_entry.dart';

/// 一个 URI 允许的最大长度（与 Kotlin 侧 `CampusToolLauncher` 同值）。
const int kCampusToolMaxUriLength = 4096;

/// 明确拒绝的 scheme：它们会打开本机文件 / 注入脚本 / 反向跳转 intent，
/// 与「打开取件身份码」这件正事无关，用户手滑粘进来也不该被执行。
const Set<String> kCampusToolBlockedSchemes = <String>{
  'file',
  'content',
  'javascript',
  'data',
  'intent',
  'blob',
  'vbscript',
  'about',
  'chrome',
  'android-app',
};

final RegExp _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*$');
final RegExp _packagePattern = RegExp(
  r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$',
);

/// 链接编辑框的解析错误类型。
enum CampusToolLinkParseError {
  none,

  /// 不是 `scheme://...` 形状（或 scheme 被禁）。
  uri,

  /// `包名|链接` 里的包名不合法。
  package,
}

/// 解析结果：成功给链接表，失败给「第几行 + 哪种错」，由界面翻译成人话。
class CampusToolLinkParseResult {
  const CampusToolLinkParseResult.success(this.links)
    : error = CampusToolLinkParseError.none,
      lineNumber = 0;

  const CampusToolLinkParseResult.failure(this.error, this.lineNumber)
    : links = const <CampusToolLink>[];

  final List<CampusToolLink> links;
  final CampusToolLinkParseError error;

  /// 1 基行号（与编辑框里数行一致）；成功时为 0。
  final int lineNumber;

  bool get ok => error == CampusToolLinkParseError.none;
}

/// 包名列表的解析结果（与链接结果分开：两者的「成功」载荷不是一个东西，
/// 硬塞进同一个类会让调用方要对 links 的含义做二次解释）。
class CampusToolPackageParseResult {
  const CampusToolPackageParseResult.success(this.packages) : badLineNumber = 0;

  const CampusToolPackageParseResult.failure(this.badLineNumber)
    : packages = const <String>[];

  final List<String> packages;

  /// 第一个坏行号（1 基）；成功时为 0。
  final int badLineNumber;

  bool get ok => badLineNumber == 0;
}

/// 解析「直达链接」多行文本。
///
/// 行格式两种：
/// - `scheme://...`：不限定目标应用；
/// - `包名|scheme://...`：只投递给该应用（QuickJump 的 `setPackage` 口径）。
///
/// 含 `|` 但左侧不是合法包名时，整行按 URI 解析 —— 有些查询串里本来就有
/// `|`，不能因为「看起来像包名分隔符」就把合法链接判死。
CampusToolLinkParseResult parseCampusToolLinks(String text) {
  final links = <CampusToolLink>[];
  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) {
      continue;
    }
    final separator = line.indexOf('|');
    if (separator > 0) {
      final package = line.substring(0, separator).trim();
      final uri = line.substring(separator + 1).trim();
      if (isValidCampusToolPackage(package)) {
        if (!isValidCampusToolUri(uri)) {
          return CampusToolLinkParseResult.failure(
            CampusToolLinkParseError.uri,
            index + 1,
          );
        }
        links.add(CampusToolLink(uri: uri, package: package));
        continue;
      }
      // 左侧不像包名：整行当 URI 处理（见上面的注释）。
    }
    if (!isValidCampusToolUri(line)) {
      return CampusToolLinkParseResult.failure(
        CampusToolLinkParseError.uri,
        index + 1,
      );
    }
    links.add(CampusToolLink(uri: line));
  }
  return CampusToolLinkParseResult.success(links);
}

/// 解析「兜底应用包名」多行文本：每行一个包名，空行跳过，重复去重。
CampusToolPackageParseResult parseCampusToolPackages(String text) {
  final packages = <String>[];
  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) {
      continue;
    }
    if (!isValidCampusToolPackage(line)) {
      return CampusToolPackageParseResult.failure(index + 1);
    }
    if (!packages.contains(line)) {
      packages.add(line);
    }
  }
  return CampusToolPackageParseResult.success(packages);
}

bool isValidCampusToolPackage(String value) {
  return _packagePattern.hasMatch(value);
}

/// `scheme://rest` 形状校验；同时挡住危险 scheme 与超长串。
bool isValidCampusToolUri(String value) {
  final uri = value.trim();
  if (uri.isEmpty || uri.length > kCampusToolMaxUriLength) {
    return false;
  }
  final separator = uri.indexOf('://');
  if (separator <= 0) {
    return false;
  }
  final scheme = uri.substring(0, separator);
  if (!_schemePattern.hasMatch(scheme)) {
    return false;
  }
  return !kCampusToolBlockedSchemes.contains(scheme.toLowerCase());
}

/// 网页兜底链接只接受 http(s)：其余 scheme 一律按「不是网址」处理。
bool isValidCampusToolWebUri(String value) {
  final uri = value.trim();
  if (uri.isEmpty || uri.length > kCampusToolMaxUriLength) {
    return false;
  }
  final lower = uri.toLowerCase();
  if (lower.startsWith('https://')) {
    return uri.length > 8;
  }
  if (lower.startsWith('http://')) {
    return uri.length > 7;
  }
  return false;
}
