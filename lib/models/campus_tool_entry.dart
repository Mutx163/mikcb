/// 默认图标名（注册表见 `widgets/campus_tool_icons.dart`）。
const String kCampusToolDefaultIconName = 'link';

/// 一条直达链接：URI 加上可选的限定目标应用包名。
///
/// 包名不是必填：`cainiao://` 这类私有 scheme 在绝大多数机型上要靠
/// `setPackage` 才不会被别的 App 抢走，但纯 https 兜底链接不需要限定。
/// 两者都保留，是为了照抄 QuickJump 的多级回退口径：同一条链接先按包名
/// 精确投递，失败再原样投递（见 [CampusToolEntry.links] 的顺序）。
class CampusToolLink {
  const CampusToolLink({required this.uri, this.package});

  /// 完整 URI（含 scheme 与 query）。
  final String uri;

  /// 限定投递的目标应用包名；null / 空串表示不限定。
  final String? package;

  /// 编辑框里的单行写法：`包名|链接`；没有限定包名时就是链接本身。
  ///
  /// 用户手改预设时看到的就是这一行，改完保存后仍按同一规则解析回来，
  /// 所以「限定包名」这件事在界面上是可见、可编辑、可去掉的。
  String get editableLine {
    final pkg = package;
    if (pkg == null || pkg.isEmpty) {
      return uri;
    }
    return '$pkg|$uri';
  }

  CampusToolLink copyWith({String? uri, String? package}) {
    return CampusToolLink(uri: uri ?? this.uri, package: package ?? this.package);
  }

  Map<String, Object?> toJson() {
    final pkg = package;
    return <String, Object?>{
      'uri': uri,
      if (pkg != null && pkg.isNotEmpty) 'package': pkg,
    };
  }

  /// 宽松解析：接受字符串（旧格式 / 手写 JSON）或对象；坏条目返回 null
  /// 由调用方丢弃，而不是整份配置判死。
  static CampusToolLink? tryParse(Object? raw) {
    if (raw is String) {
      final uri = raw.trim();
      return uri.isEmpty ? null : CampusToolLink(uri: uri);
    }
    if (raw is Map) {
      String? uri;
      String? pkg;
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! String) {
          continue;
        }
        if (entry.key == 'uri') {
          uri = value.trim();
        } else if (entry.key == 'package') {
          pkg = value.trim();
        }
      }
      if (uri == null || uri.isEmpty) {
        return null;
      }
      return CampusToolLink(
        uri: uri,
        package: pkg == null || pkg.isEmpty ? null : pkg,
      );
    }
    return null;
  }

  @override
  String toString() => 'CampusToolLink($editableLine)';
}

/// 校园小工具里的一条快捷入口。
///
/// 字段口径照搬 QuickJump 的 `Entry`：一串按顺序尝试的直达链接（[links]）、
/// 直达失败时只负责拉起官方 App 的包名（[appPackages]）、最后才是网页兜底
/// （[webUri]）。执行顺序由 `CampusToolRunner` 负责，本类只管数据与序列化。
///
/// [id] 是稳定主键：预设项与 `domain/campus_tool_presets.dart` 的 id 对齐，
/// 用户自建项用 uuid。改名不改 id —— 标题本地化靠 id 反查
/// （见 `l10n/campus_tool_localizer.dart`），改名只影响 [title] 这个覆盖值。
class CampusToolEntry {
  const CampusToolEntry({
    required this.id,
    this.title = '',
    this.icon = kCampusToolDefaultIconName,
    this.links = const <CampusToolLink>[],
    this.appPackages = const <String>[],
    this.webUri,
    this.clearTask = false,
    this.enabled = true,
  });

  final String id;

  /// 用户自定义标题；空串表示「沿用预设标题」（预设改名时才需要写值）。
  final String title;

  /// 图标注册名，未知名字回落默认图标。
  final String icon;

  final List<CampusToolLink> links;
  final List<String> appPackages;

  /// 网页兜底链接（https / http）；null 或空串表示没有兜底。
  final String? webUri;

  /// 是否强制新开目标页（FLAG_ACTIVITY_CLEAR_TASK）。
  ///
  /// QuickJump 用它修复「淘宝在后台时跳不动」的机型；默认关闭。
  final bool clearTask;

  /// 是否出现在快捷按钮区；关掉只是隐藏，不删数据。
  final bool enabled;

  /// 至少有一个可尝试的目标（链接 / 应用 / 网页）才算配置完整。
  bool get hasTarget =>
      links.isNotEmpty ||
      appPackages.isNotEmpty ||
      (webUri != null && webUri!.trim().isNotEmpty);

  /// 尝试顺序里的目标总数，用于列表行副标题。
  int get targetCount =>
      links.length +
      appPackages.length +
      ((webUri != null && webUri!.trim().isNotEmpty) ? 1 : 0);

  CampusToolEntry copyWith({
    String? title,
    String? icon,
    List<CampusToolLink>? links,
    List<String>? appPackages,
    String? webUri,
    bool? clearTask,
    bool? enabled,
  }) {
    return CampusToolEntry(
      id: id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      links: links ?? this.links,
      appPackages: appPackages ?? this.appPackages,
      webUri: webUri ?? this.webUri,
      clearTask: clearTask ?? this.clearTask,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() {
    final web = webUri;
    return <String, Object?>{
      'id': id,
      if (title.trim().isNotEmpty) 'title': title,
      'icon': icon,
      'links': <Object?>[for (final link in links) link.toJson()],
      'appPackages': appPackages,
      if (web != null && web.trim().isNotEmpty) 'webUri': web,
      if (clearTask) 'clearTask': true,
      if (!enabled) 'enabled': false,
    };
  }

  /// 宽松解析：缺 id 或链接全部坏掉时返回 null（整条丢弃，而不是整份判死）。
  static CampusToolEntry? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    String? id;
    String title = '';
    String icon = kCampusToolDefaultIconName;
    String? webUri;
    var clearTask = false;
    var enabled = true;
    final links = <CampusToolLink>[];
    final appPackages = <String>[];
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      switch (key) {
        case 'id':
          if (value is String) {
            id = value.trim();
          }
        case 'title':
          if (value is String) {
            title = value.trim();
          }
        case 'icon':
          if (value is String && value.trim().isNotEmpty) {
            icon = value.trim();
          }
        case 'links':
          if (value is List) {
            for (final item in value) {
              final link = CampusToolLink.tryParse(item);
              if (link != null) {
                links.add(link);
              }
            }
          }
        case 'appPackages':
          if (value is List) {
            for (final item in value) {
              if (item is String) {
                final pkg = item.trim();
                if (pkg.isNotEmpty && !appPackages.contains(pkg)) {
                  appPackages.add(pkg);
                }
              }
            }
          }
        case 'webUri':
          if (value is String && value.trim().isNotEmpty) {
            webUri = value.trim();
          }
        case 'clearTask':
          clearTask = value == true;
        case 'enabled':
          enabled = value != false;
      }
    }
    if (id == null || id.isEmpty) {
      return null;
    }
    return CampusToolEntry(
      id: id,
      title: title,
      icon: icon,
      links: List<CampusToolLink>.unmodifiable(links),
      appPackages: List<String>.unmodifiable(appPackages),
      webUri: webUri,
      clearTask: clearTask,
      enabled: enabled,
    );
  }

  /// 把持久化里的一坨（List 或 `{entries: [...]}` 里的那个 List）规整成条目：
  /// 丢坏项、去重复 id、保持顺序。
  static List<CampusToolEntry> normalizeList(Object? raw) {
    if (raw is! List) {
      return const <CampusToolEntry>[];
    }
    final result = <CampusToolEntry>[];
    final seen = <String>{};
    for (final item in raw) {
      final entry = tryParse(item);
      if (entry == null || !seen.add(entry.id)) {
        continue;
      }
      result.add(entry);
    }
    return List<CampusToolEntry>.unmodifiable(result);
  }

  @override
  String toString() => 'CampusToolEntry($id, links=${links.length})';
}
