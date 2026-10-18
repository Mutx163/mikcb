/// 发布说明（`docs/releases/v*.md` / Release 正文）→ 更新弹窗用的「重点摘要」。
///
/// 为什么要有这一层：一个版本的发布说明是**扁平的一长串**条目（实测 v2.1.3.2
/// 有 46 条、正文 90 多行），而弹窗原来只是把正文去掉标题后取前 4 行当作摘要。
/// 那既不是重点（只是文件开头的顺序），一条 60 字的说明又会在第二行中途被截断，
/// 用户看到的永远是「一大串更新内容的顶部」。
///
/// 这里把正文解析成结构化条目，供弹窗只展示「说得清、看得完」的部分：
///
/// - 按「新增 / 优化 / 修复 / 移除」分类 —— 这正是 `docs/RELEASE.md` 强制规定的
///   发布说明写法（英文 New / Improved / Fixed / Removed 一并识别，旧版正文里
///   还有 `-新增`（无空格）这种写法）；
/// - 每条给一个**短标题**：取第一个「：」之前的半句（「新增 弹窗顶部渐变模糊带：
///   材质面板顶部的分段坐到模糊带上…」→「弹窗顶部渐变模糊带」），弹窗的重點行
///   只放短标题，完整句子留在展开列表里；
/// - 产出至多 3 条重点：作者显式声明的优先（正文顶部 `> 本次重点：A、B、C`
///   或 `## 本次重点` 小节），没声明时按 `新增 > 优化 > 移除 > 修复` 的既有
///   优先级取前几条 —— 这条优先级 `docs/RELEASE.md` 里已经写成规范，不是这里新发明的。
///
/// 纯 Dart，不依赖 Flutter，便于在 `test/utils/` 里用真实发布说明做回归。
library;

/// 一条发布说明条目的变更类型。
enum ReleaseChangeKind { added, improved, fixed, removed, other }

/// 解析后的一条变更。
class ReleaseChangeEntry {
  const ReleaseChangeEntry({
    required this.kind,
    required this.text,
    required this.headline,
    this.label = '',
  });

  /// 归一化后的分类（决定重点的挑选顺序）。
  final ReleaseChangeKind kind;

  /// 条目原文（已去掉列表符号与分类前缀），展开列表里显示完整句子。
  final String text;

  /// 短标题：第一个句内分隔符之前的那半句，供重点行使用。
  final String headline;

  /// 正文里作者原本用的分类词（「新增」「Improved」…），空串表示没有分类前缀。
  ///
  /// 分类标签直接用作者自己的词，而不是另立一套翻译：发布说明是中文写、
  /// 应用六种语言都显示同一份正文，标签跟正文保持同一种语言才不会有割裂感；
  /// 将来正文改写成英文，标签也会自动跟着变成英文。
  final String label;

  @override
  String toString() => 'ReleaseChangeEntry($kind, $label, $headline)';
}

/// 一版发布说明的重点摘要。
class ReleaseNotesDigest {
  const ReleaseNotesDigest({
    this.entries = const <ReleaseChangeEntry>[],
    this.highlights = const <ReleaseChangeEntry>[],
    this.highlightsDeclared = false,
  });

  /// 正文里没有任何可用条目的哨兵值。
  static const ReleaseNotesDigest empty = ReleaseNotesDigest();

  /// 全部条目，按正文顺序。
  final List<ReleaseChangeEntry> entries;

  /// 至多 3 条重点，供弹窗顶部展示。
  final List<ReleaseChangeEntry> highlights;

  /// 重点是否由发布说明自己声明（否则是按分类优先级推断的）。
  final bool highlightsDeclared;

  bool get isEmpty => entries.isEmpty && highlights.isEmpty;

  /// 条目总数（展开按钮上的「查看全部 N 项」用它）。
  int get total => entries.length;

  int countOf(ReleaseChangeKind kind) =>
      entries.where((entry) => entry.kind == kind).length;
}

/// 默认展示几条重点。
///
/// 3 是「一屏能扫完、又装得下两个新增加一条优化」的量；再多就退化成
/// 又一份长列表了（这正是要修的问题）。
const int defaultReleaseHighlightCount = 3;

/// 重点的挑选顺序：新增 > 优化 > 移除 > 修复 > 无分类。
///
/// 与 `docs/RELEASE.md` 的「默认优先级：新增 > 优化 > 移除 > 修复细节」一致。
const List<ReleaseChangeKind> _highlightKindPriority = <ReleaseChangeKind>[
  ReleaseChangeKind.added,
  ReleaseChangeKind.improved,
  ReleaseChangeKind.removed,
  ReleaseChangeKind.fixed,
  ReleaseChangeKind.other,
];

/// 分类标签在计数行里的固定顺序（新增 · 优化 · 修复 · 移除）。
const List<ReleaseChangeKind> _countKindOrder = <ReleaseChangeKind>[
  ReleaseChangeKind.added,
  ReleaseChangeKind.improved,
  ReleaseChangeKind.fixed,
  ReleaseChangeKind.removed,
];

const List<(String, ReleaseChangeKind)> _kindPrefixes =
    <(String, ReleaseChangeKind)>[
      ('新增功能', ReleaseChangeKind.added),
      ('新增', ReleaseChangeKind.added),
      ('增加', ReleaseChangeKind.added),
      ('优化', ReleaseChangeKind.improved),
      ('改进', ReleaseChangeKind.improved),
      ('改善', ReleaseChangeKind.improved),
      ('修复', ReleaseChangeKind.fixed),
      ('修正', ReleaseChangeKind.fixed),
      ('移除', ReleaseChangeKind.removed),
      ('删除', ReleaseChangeKind.removed),
      ('下线', ReleaseChangeKind.removed),
    ];

const Map<String, ReleaseChangeKind> _englishKinds = <String, ReleaseChangeKind>{
  'new': ReleaseChangeKind.added,
  'add': ReleaseChangeKind.added,
  'added': ReleaseChangeKind.added,
  'feature': ReleaseChangeKind.added,
  'improve': ReleaseChangeKind.improved,
  'improved': ReleaseChangeKind.improved,
  'enhance': ReleaseChangeKind.improved,
  'enhanced': ReleaseChangeKind.improved,
  'optimize': ReleaseChangeKind.improved,
  'optimized': ReleaseChangeKind.improved,
  'fix': ReleaseChangeKind.fixed,
  'fixed': ReleaseChangeKind.fixed,
  'remove': ReleaseChangeKind.removed,
  'removed': ReleaseChangeKind.removed,
  'deprecate': ReleaseChangeKind.removed,
  'deprecated': ReleaseChangeKind.removed,
};

final RegExp _headingPattern = RegExp(r'^#{1,6}\s+');
final RegExp _bulletPattern = RegExp(r'^(?:[-+*]|\d+[.)])\s*(.+)$');
final RegExp _rulePattern = RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$');
final RegExp _tableRowPattern = RegExp(r'^\|');
final RegExp _imageLinePattern = RegExp(r'^!\[[^\]]*\]\([^)]*\)$');
final RegExp _inlineLinkPattern = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final RegExp _markdownMarkerPattern = RegExp(r'\*\*|__|~~|`');
final RegExp _whitespaceRunPattern = RegExp(r'\s+');
final RegExp _leadingSeparatorPattern = RegExp(r'^[\s:：\-—–~·、,，]+');
final RegExp _headlineStopPattern = RegExp(r'[：:；;。！!？?]');
final RegExp _englishKindPattern = RegExp(
  r'^(new|add|added|feature|improve|improved|enhance|enhanced|optimize|optimized|fix|fixed|remove|removed|deprecate|deprecated)\b',
  caseSensitive: false,
);

/// 正文顶部用来声明重点的引用行，例如 `> 本次重点：A、B、C`。
final RegExp _declaredBlockquotePattern = RegExp(
  r'^(?:本次|这次)?(?:更新|版本)?(?:的)?(?:重点|亮点|看点)\s*[:：]?\s*',
);
final RegExp _declaredBlockquoteEnPattern = RegExp(
  r'^(?:(?:update|release)\s+)?(?:highlights?|key\s*points?)\s*[-:：]?\s*',
  caseSensitive: false,
);

/// 用来声明重点的小节标题，例如 `## 本次重点`。
final RegExp _declaredSectionPattern = RegExp(
  r'^(?:本次|这次)?(?:更新|版本)?(?:的)?(?:重点|亮点|看点)$',
);
final RegExp _declaredSectionEnPattern = RegExp(
  r'^(?:(?:update|release)\s+)?(?:highlights?|key\s*points?)$',
  caseSensitive: false,
);

/// 把一版发布说明解析成可展示的摘要。
///
/// [maxHighlights] 为要挑出的重点条数，默认 [defaultReleaseHighlightCount]。
ReleaseNotesDigest buildReleaseNotesDigest(
  String body, {
  int maxHighlights = defaultReleaseHighlightCount,
}) {
  final normalized = body
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceFirst('\uFEFF', '');
  if (normalized.trim().isEmpty) {
    return ReleaseNotesDigest.empty;
  }

  final entries = <ReleaseChangeEntry>[];
  final declared = <String>[];
  var insideCodeFence = false;
  var insideDeclaredSection = false;

  for (final rawLine in normalized.split('\n')) {
    // 用没被 trimLeft 的行判断列表符号：发布说明里的二级条目是缩进的，
    // 属于上一条的细节说明，不该被当成独立条目重复计数。
    final line = rawLine.trimRight();
    final trimmed = line.trim();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      insideCodeFence = !insideCodeFence;
      continue;
    }
    if (insideCodeFence || trimmed.isEmpty) {
      continue;
    }
    if (_rulePattern.hasMatch(trimmed) ||
        _tableRowPattern.hasMatch(trimmed) ||
        _imageLinePattern.hasMatch(trimmed)) {
      continue;
    }
    if (_headingPattern.hasMatch(trimmed)) {
      final headingText = trimmed
          .replaceFirst(_headingPattern, '')
          .replaceFirst(RegExp(r'[:：\s]+$'), '');
      insideDeclaredSection =
          _declaredSectionPattern.hasMatch(headingText) ||
          _declaredSectionEnPattern.hasMatch(headingText);
      continue;
    }
    if (trimmed.startsWith('>')) {
      final quoted = trimmed.replaceFirst(RegExp(r'^>+\s*'), '');
      final rest =
          _stripDeclaredLabel(quoted, _declaredBlockquotePattern) ??
          _stripDeclaredLabel(quoted, _declaredBlockquoteEnPattern);
      if (rest != null) {
        declared.addAll(_splitDeclaredItems(rest));
      }
      continue;
    }
    // 正文里的 `SHA-256: ...` 一行（GitCode 发行版正文由 CI 追加）不是条目。
    if (!trimmed.startsWith('-') &&
        !trimmed.startsWith('*') &&
        !trimmed.startsWith('+') &&
        trimmed.toLowerCase().contains('sha-256')) {
      continue;
    }
    final bulletMatch = _bulletPattern.firstMatch(line);
    if (bulletMatch == null) {
      continue;
    }
    final bulletText = _cleanInline(bulletMatch.group(1)!);
    if (bulletText.isEmpty) {
      continue;
    }
    final entry = _entryFromBullet(bulletText);
    if (insideDeclaredSection && entry.kind == ReleaseChangeKind.other) {
      // 「## 本次重点」小节里作者写的是短句（可能不带分类前缀），
      // 整句就是声明本身；同时它也是一条真实变更。
      declared.add(entry.text);
    } else if (insideDeclaredSection) {
      declared.add(entry.headline);
    }
    entries.add(entry);
  }

  final highlights = _selectHighlights(
    entries: entries,
    declared: declared,
    maxHighlights: maxHighlights,
  );

  return ReleaseNotesDigest(
    entries: entries,
    highlights: highlights.items,
    highlightsDeclared: highlights.declared,
  );
}

/// 计数行用的分类标签顺序与文案取自正文本身（见 [ReleaseChangeEntry.label]）。
List<(String, int)> releaseChangeCounts(
  ReleaseNotesDigest digest, {
  List<ReleaseChangeKind> kinds = _countKindOrder,
}) {
  final counts = <(String, int)>[];
  for (final kind in kinds) {
    final count = digest.countOf(kind);
    if (count == 0) {
      continue;
    }
    final label = _labelOfKind(digest.entries, kind);
    if (label.isEmpty) {
      continue;
    }
    counts.add((label, count));
  }
  return counts;
}

String _labelOfKind(List<ReleaseChangeEntry> entries, ReleaseChangeKind kind) {
  for (final entry in entries) {
    if (entry.kind == kind && entry.label.isNotEmpty) {
      return entry.label;
    }
  }
  return '';
}

({List<ReleaseChangeEntry> items, bool declared}) _selectHighlights({
  required List<ReleaseChangeEntry> entries,
  required List<String> declared,
  required int maxHighlights,
}) {
  if (maxHighlights <= 0) {
    return (items: const <ReleaseChangeEntry>[], declared: false);
  }

  final resolved = <ReleaseChangeEntry>[];
  final seen = <String>{};
  for (final wanted in declared) {
    if (resolved.length >= maxHighlights) {
      break;
    }
    final matched = _matchDeclared(entries, wanted);
    final item = ReleaseChangeEntry(
      kind: matched?.kind ?? ReleaseChangeKind.other,
      text: matched?.text ?? wanted,
      headline: wanted,
      label: matched?.label ?? '',
    );
    if (seen.add(item.headline)) {
      resolved.add(item);
    }
  }
  if (resolved.isNotEmpty) {
    return (items: resolved, declared: true);
  }

  final fallback = <ReleaseChangeEntry>[];
  for (final kind in _highlightKindPriority) {
    for (final entry in entries) {
      if (entry.kind != kind) {
        continue;
      }
      fallback.add(entry);
      if (fallback.length >= maxHighlights) {
        break;
      }
    }
    if (fallback.length >= maxHighlights) {
      break;
    }
  }
  return (items: fallback, declared: false);
}

/// 声明的简写要认回正文里的那条条目，靠两步：
/// 先看是否互相包含（「Bing 每日壁纸库」是原文子串），再按相似度兜底。
///
/// 兜底不是锦上添花：作者声明时写的是给人看的简写（「十档玻璃滑杆」），
/// 正文那条是（「液态玻璃的档位改成一根 10 格节点滑杆」），两者**字面上不互为
/// 子串**。没有这一层，声明的重点就会整条对不上分类，标签只能显示成「其他」。
ReleaseChangeEntry? _matchDeclared(
  List<ReleaseChangeEntry> entries,
  String wanted,
) {
  final key = _normalizeForMatch(wanted);
  if (key.isEmpty) {
    return null;
  }
  for (final entry in entries) {
    if (_normalizeForMatch(entry.text).contains(key)) {
      return entry;
    }
  }
  for (final entry in entries) {
    if (_normalizeForMatch(entry.headline).contains(key)) {
      return entry;
    }
  }
  for (final entry in entries) {
    final headlineKey = _normalizeForMatch(entry.headline);
    if (headlineKey.isNotEmpty && key.contains(headlineKey)) {
      return entry;
    }
  }

  ReleaseChangeEntry? best;
  var bestScore = 0.0;
  for (final entry in entries) {
    final score = _similarity(key, _normalizeForMatch(entry.text));
    final headlineScore = _similarity(key, _normalizeForMatch(entry.headline));
    final resolved = score > headlineScore ? score : headlineScore;
    if (resolved > bestScore) {
      bestScore = resolved;
      best = entry;
    }
  }
  return bestScore >= _declaredMatchThreshold ? best : null;
}

/// 相似度阈值：中文按二字组重合率算，40% 上下足够认出简写与正文的同一件事，
/// 又不会把两条无关的变更凑到一起。
const double _declaredMatchThreshold = 0.34;

final RegExp _asciiWordPattern = RegExp(r'^[a-z0-9 ]+$');
final RegExp _tokenSeparatorPattern = RegExp(r'\s+');

double _similarity(String key, String candidate) {
  if (key.isEmpty || candidate.isEmpty) {
    return 0;
  }
  if (_asciiWordPattern.hasMatch(key) && _asciiWordPattern.hasMatch(candidate)) {
    return _tokenOverlap(key, candidate);
  }
  final keyBigrams = _bigrams(key);
  if (keyBigrams.isEmpty) {
    return candidate.contains(key) ? 1 : 0;
  }
  final candidateBigrams = _bigrams(candidate);
  var overlap = 0;
  for (final gram in keyBigrams) {
    if (candidateBigrams.contains(gram)) {
      overlap++;
    }
  }
  return overlap / keyBigrams.length;
}

double _tokenOverlap(String key, String candidate) {
  final keyTokens = key.split(_tokenSeparatorPattern).where((t) => t.isNotEmpty);
  if (keyTokens.isEmpty) {
    return 0;
  }
  final candidateTokens = candidate
      .split(_tokenSeparatorPattern)
      .where((t) => t.isNotEmpty)
      .toSet();
  var overlap = 0;
  for (final token in keyTokens) {
    if (token.length >= 2 && candidateTokens.contains(token)) {
      overlap++;
    }
  }
  return overlap / keyTokens.length;
}

Set<String> _bigrams(String value) {
  final runes = value.runes.toList(growable: false);
  final grams = <String>{};
  for (var index = 0; index + 1 < runes.length; index++) {
    grams.add(String.fromCharCodes(<int>[runes[index], runes[index + 1]]));
  }
  return grams;
}

String _normalizeForMatch(String value) => value.toLowerCase().replaceAll(
  RegExp(r'[\s，。、；：:;,\.\-—…「」『』（）()《》\[\]"“”\x27]'),
  '',
);

String? _stripDeclaredLabel(String value, RegExp pattern) {
  final match = pattern.firstMatch(value);
  if (match == null) {
    return null;
  }
  return value.substring(match.end);
}

List<String> _splitDeclaredItems(String value) => value
    .split(RegExp(r'[、,，;；|/]'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList(growable: false);

ReleaseChangeEntry _entryFromBullet(String bullet) {
  var kind = ReleaseChangeKind.other;
  var label = '';
  var rest = bullet;

  for (final prefix in _kindPrefixes) {
    final keyword = prefix.$1;
    if (rest.startsWith(keyword) && rest.length > keyword.length) {
      kind = prefix.$2;
      label = keyword;
      rest = rest.substring(keyword.length);
      break;
    }
  }
  if (kind == ReleaseChangeKind.other) {
    final match = _englishKindPattern.firstMatch(rest);
    if (match != null && rest.length > match.end) {
      final keyword = match.group(1)!;
      kind = _englishKinds[keyword.toLowerCase()]!;
      label = _titleCaseLabel(keyword, bullet);
      rest = rest.substring(match.end);
    }
  }

  final text = _stripLeadingSeparators(rest);
  final resolved = text.isEmpty ? bullet : text;
  return ReleaseChangeEntry(
    kind: kind,
    text: resolved,
    headline: _headlineOf(resolved),
    label: label,
  );
}

/// 英文分类词按作者原本的大小写展示（`New` / `NEW` 各自保持），
/// 这样标签不会和正文里那一行看起来是两种写法。
String _titleCaseLabel(String keyword, String source) {
  final start = source.toLowerCase().indexOf(keyword.toLowerCase());
  if (start < 0) {
    return keyword;
  }
  return source.substring(start, start + keyword.length);
}

String _stripLeadingSeparators(String value) =>
    value.replaceFirst(_leadingSeparatorPattern, '').trim();

String _cleanInline(String raw) {
  var text = raw.replaceAllMapped(
    _inlineLinkPattern,
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAll(_markdownMarkerPattern, '');
  return text.replaceAll(_whitespaceRunPattern, ' ').trim();
}

/// 短标题的长度上限。
///
/// 弹窗里重点行按 14sp、两行收住，窄屏每行约 18～20 个汉字，40 字是
/// 「两行刚好、再多就靠省略号」的尺度。
const int _headlineMaxRunes = 40;

String _headlineOf(String text) {
  final match = _headlineStopPattern.firstMatch(text);
  var headline = match == null ? text : text.substring(0, match.start);
  headline = headline.trim();
  if (headline.isEmpty) {
    headline = text.trim();
  }
  if (headline.runes.length > _headlineMaxRunes) {
    headline =
        '${String.fromCharCodes(headline.runes.take(_headlineMaxRunes))}…';
  }
  return headline;
}
