/// 界面文案风格规则 —— **唯一定义处**。
///
/// 这个文件是「每行字能有多长、什么必须删」的唯一真源。三处消费方：
/// 1. `test/architecture/copy_style_guard_test.dart`：提交时/CI 里跑，超限即红；
/// 2. `dart run tool/copy_style_lint.dart`：改文案前手动自查，只报不拦；
/// 3. AGENTS.md 的 COPY-STYLE 节：写给人和 AI 看的口径，指向本文件。
///
/// 目前守三条：
/// - [findViolations]：行内文案**超宽**（真的折行）；
/// - [findDeadKeys]：ARB 里有、代码从不引用的**死键**；
/// - [findRestatingSubtitles]：说明句**只是在复述标题**（2026-10-25 新增，
///   对应「避免不必要的次要标签和描述，让布局自己说话」）。

///
/// ## 为什么要有这个文件
///
/// 2026-10-20～21 做过一轮文案简洁化（15 个提交、删 104 条改短 53 条），
/// 但口径只写在提交信息和一篇笔记里，**没有任何机器检查**。结果是同一天：
/// `8d1dff31` 立下「灰字 17 字」上限，四小时后的 `1eab2028` 自己写出 25 字；
/// 次日 `f444e9ec` 又加了 23 字的整宽段落（那个位置本来就该多行，不算违规，
/// 但说明「靠人记」这件事不成立）。所以规则必须是**能跑的东西**。
///
/// ## 判据从哪来
///
/// 不是拍脑袋的数字，是 400dp 屏、13sp 灰字实测的折行位置（`bfc6b6bf` 立的）：
/// 开关/选择器行右侧有开关或取值挤压，可用宽度约一个标题 11 字 / 一句说明 17 字。
/// **整宽段落不在此列**——它们本来就该折行（`HyperosSectionDescription`、
/// 对话框正文、引导页段落），拿单行口径去卡它们，会把「写清楚」逼成「写不全」。
library;

import 'dart:convert';
import 'dart:io';

/// 一个语言的文案表（ARB 解码后的 `键 -> 值`；`@` 开头的元数据键已剔除）。
typedef ArbValues = Map<String, String>;

/// 右侧有控件挤压副标题的行控件。**只有这些**按单行口径卡。
///
/// 判据是「副标题右边还有东西占位」：
/// - `HyperosSwitchTile` / `HyperosSliderTile`：右侧开关 / 滑杆；
/// - `HyperosSelectTile` / `HyperosInputTile`：右侧取值或输入框；
/// - `HyperosNavTile` / `HyperosListTile`：右侧箭头（`showChevron`）。
///
/// 反例（**故意不在表里**）：`HyperosControlCard` 的 header 副标题、
/// `HyperosSectionDescription`、裸 `Text` —— 它们 `softWrap: true` 且占满宽度，
/// 折行是预期行为。把这几个算进来会让守卫报出上百条假警报，然后被
/// `--no-verify` 绕过——那是比没有守卫更糟的结局。
const List<String> squeezedRowWidgets = <String>[
  'HyperosSwitchTile',
  'HyperosSliderTile',
  'HyperosSelectTile',
  'HyperosInputTile',
  'HyperosNavTile',
  'HyperosListTile',
];

/// 文案槽位：行控件里承载「说明」的参数名。
const List<String> subtitleArgs = <String>[
  'subtitle',
  'details',
  'hint',
  'caption',
];

/// 文案槽位：行控件里承载「标题」的参数名。
const List<String> titleArgs = <String>['title', 'label'];

/// 单行口径上限（按 [visualWidth] 量，单位≈一个汉字的宽度）。
///
/// - 标题 11：[bfc6b6bf] 实测 400dp 屏、右侧开关挤压后标题可用宽度；
/// - 说明 17：同上，13sp 灰字。**17 是上界不是目标**，能短就短。
const double titleMaxWidth = 11;
const double subtitleMaxWidth = 17;

/// 按「渲染宽度」量一段文案，单位≈一个汉字宽。
///
/// 口径与 `bfc6b6bf` 的扫描器一致：汉字/全角 1.0，ASCII 0.55，
/// 占位符按 3 位数字（`000`）估。**不要用 `String.length` 代替**：
/// 「保存」（2 字符）和「OK」（2 字符）在屏幕上宽度差一倍，
/// 而「设置里可以改」和「Settings」也不该用同一个数比。
double visualWidth(String text) {
  final resolved = text.replaceAll(RegExp(r'\{[^}]*\}'), '000');
  var total = 0.0;
  for (final rune in resolved.runes) {
    total += rune > 0x2e80 ? 1.0 : 0.55;
  }
  return total;
}

/// 一处违规。
class CopyViolation {
  const CopyViolation({
    required this.key,
    required this.locale,
    required this.widget,
    required this.arg,
    required this.width,
    required this.limit,
    required this.source,
    required this.line,
    required this.text,
  });

  /// ARB 键名。
  final String key;

  /// 语言代码（zh / en / ja / ko / zh_HK / zh_TW）。
  final String locale;

  /// 渲染它的行控件（如 `HyperosSwitchTile`）。
  final String widget;

  /// 槽位参数名（如 `subtitle`）。
  final String arg;

  /// 实测宽度（[visualWidth] 的返回值）。
  final double width;

  /// 该槽位的上限。
  final double limit;

  /// 源码文件（仓库相对）。
  final String source;

  /// 源码行号。
  final int line;

  /// 文案正文（截断后的预览）。
  final String text;

  String get id => '$locale/$key';

  @override
  String toString() =>
      '$key [$locale] 宽 ${width.toStringAsFixed(1)} > ${limit.toStringAsFixed(0)}'
      '  （$widget.$arg @ $source:$line）\n'
      '    正文：$text';
}

/// 从一处 Dart 源码里抽出「行控件 × 文案键」的绑定关系。
///
/// 做法：找到控件构造调用（`HyperosSwitchTile(`），按括号配对截出它的参数块，
/// 再在块里找 `subtitle: l10n.xxx` 这类绑定。**嵌套控件会被一并扫到**——
/// 外层控件块里含着内层控件的绑定，这是有意的：两者都在行内被挤压，
/// 都该按单行口径卡。重复项由调用方按 `locale/key` 去重。
///
/// [source] 是仓库相对路径，只用于报告定位。
List<CopyBinding> extractBindings(String source, String sourcePath) {
  final bindings = <CopyBinding>[];
  final widgets = squeezedRowWidgets.join('|');
  // 泛型要一起吃进去：`HyperosSelectTile<LiveCountdownTextStyle>(` 这种写法
  // 在仓库里很常见，只匹配 `名字(` 会整类漏掉——漏掉的守卫比没有守卫更糟，
  // 因为它看起来是绿的。（2026-10-21 反向验证时踩到。）
  final ctor = RegExp(
    '\\b($widgets)\\s*(?:<[^<>()]*>)?\\s*\\(',
  );
  // 绑定的两种写法：同行 `subtitle: l10n.x`，或换行后 `subtitle:\n  l10n.x`。
  final args = '${subtitleArgs.join('|')}|${titleArgs.join('|')}';
  final binding = RegExp(
    '\\b($args)\\s*:\\s*\\n?\\s*l10n\\.([A-Za-z0-9_]+)',
  );

  for (final match in ctor.allMatches(source)) {
    final widget = match.group(1)!;
    final start = match.end;
    var index = start;
    var depth = 1;
    while (index < source.length && depth > 0) {
      final char = source[index];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }
      index++;
    }
    if (depth != 0) {
      continue; // 括号不配对的半成品源码（在途改动），跳过而不是炸。
    }
    final body = source.substring(start, index - 1);
    final line = _lineOf(source, match.start);
    for (final argMatch in binding.allMatches(body)) {
      final arg = argMatch.group(1)!;
      final key = argMatch.group(2)!;
      bindings.add(
        CopyBinding(
          widget: widget,
          arg: arg,
          key: key,
          source: sourcePath,
          line: line,
          isTitle: titleArgs.contains(arg),
        ),
      );
    }
  }
  return bindings;
}

int _lineOf(String source, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) {
      line++;
    }
  }
  return line;
}

/// 一处「行控件引用了某个文案键」的绑定。
class CopyBinding {
  const CopyBinding({
    required this.widget,
    required this.arg,
    required this.key,
    required this.source,
    required this.line,
    required this.isTitle,
  });

  final String widget;
  final String arg;
  final String key;
  final String source;
  final int line;

  /// true = 标题槽位（按 [titleMaxWidth] 卡），false = 说明槽位（[subtitleMaxWidth]）。
  final bool isTitle;

  double get limit => isTitle ? titleMaxWidth : subtitleMaxWidth;
}

/// 全仓检查：所有语言 × 所有行控件槽位。
///
/// [sources] 是 `仓库相对路径 -> 源码内容`；[arbByLocale] 是 `语言 -> 文案表`。
/// 同一 `locale/key` 只报一次（取第一处引用位置），避免一个键被十处引用时刷屏。
List<CopyViolation> findViolations({
  required Map<String, String> sources,
  required Map<String, ArbValues> arbByLocale,
}) {
  final bindings = <String, CopyBinding>{};
  for (final entry in sources.entries) {
    for (final binding in extractBindings(entry.value, entry.key)) {
      bindings.putIfAbsent('${binding.key}\u0000${binding.isTitle}', () => binding);
    }
  }

  final violations = <CopyViolation>[];
  final reported = <String>{};
  for (final binding in bindings.values) {
    for (final locale in arbByLocale.keys) {
      final text = arbByLocale[locale]?[binding.key];
      if (text == null) {
        continue; // 键在该语言缺失由 test/l10n 管，不在这里重复报。
      }
      final width = visualWidth(text);
      if (width <= binding.limit) {
        continue;
      }
      final id = '${binding.key}\u0000$locale';
      if (!reported.add(id)) {
        continue;
      }
      violations.add(
        CopyViolation(
          key: binding.key,
          locale: locale,
          widget: binding.widget,
          arg: binding.arg,
          width: width,
          limit: binding.limit,
          source: binding.source,
          line: binding.line,
          text: text.length > 40 ? '${text.substring(0, 40)}…' : text,
        ),
      );
    }
  }
  violations.sort((a, b) => b.width.compareTo(a.width));
  return violations;
}

/// 违规的稳定标识（写进基线文件的那一行）。
String violationId(CopyViolation v) => '${v.locale}/${v.key}';

/// 全仓死键：ARB 里有、但 Dart / 原生代码从不引用的键。
///
/// 这不是「文案风格」问题，是**删文案的收尾**问题：删掉一处渲染却留下键，
/// 下次扫描会把它当成「超长文案」，让人误以为还有活要干；更糟的是它给
/// 后来者一个错误信号——「这个键还在用吧」。
///
/// [codeCorpus] 是除 ARB / 生成物以外的全部源码拼接文本。
Set<String> findDeadKeys({
  required ArbValues template,
  required String codeCorpus,
}) {
  final dead = <String>{};
  for (final key in template.keys) {
    // 词边界用「前后不是标识符字符」判定：`taskNoTasks` 不该被
    // `taskNoTasksForToday` 的引用误判成活键（反之亦然）。
    final pattern = RegExp(
      '(?<![A-Za-z0-9_])${RegExp.escape(key)}(?![A-Za-z0-9_])',
    );
    if (!pattern.hasMatch(codeCorpus)) {
      dead.add(key);
    }
  }
  return dead;
}

// =====================================================================
// 「复述标题」判据：说明句是否只是在用别的词把标题重说一遍。
// =====================================================================

/// 复述判据的残留上限（按 [restatingResidue] 的 token 数计）。
///
/// **这是整条判据唯一的数字**，含义：说明句去掉「行首操作动词」「标题里已有的
/// 词」「纯连接词」之后，还剩几个 token。**0 = 一个都不剩 = 纯复述**。
///
/// 为什么不设成 2（「差不多就行」）：实测过，2 会把真话判成废话。
/// 英文 `Run once now` / `Ignore the schedule` 残留 2 个 token
/// （ignore、schedule），但它讲的是「不等时间窗」——标题给不出这个信息，
/// 删掉用户就不知道为什么要有这个按钮。中文 `登录学校教务系统导入` /
/// `教务系统导入` 同样残留「学校」这层限定。
/// **误删的代价高于漏删**：漏掉一条灰字只是界面不够干净，删错一条会让用户
/// 做错决定。这条口径由本仓库的 COPY-STYLE 纪律决定（「不误删优先」）。
const int restatingResidueMaxTokens = 0;

/// 纯连接词 / 语气词 / 虚词：剥掉它们不影响「这句话有没有新信息」。
const Set<String> _copyStopWords = <String>{
  // 中文虚词与连接词
  '的', '了', '吗', '呢', '吧', '啊', '着', '过', '们', '你', '我', '他', '它',
  '这', '那', '其', '之', '而', '且', '然', '后', '即', '可', '以', '及', '和',
  '与', '或', '就', '在', '把', '被', '给', '为', '是', '一', '个', '都', '也',
  '能', '会', '将', '要', '需', '还', '从', '对', '等', '地', '该', '本', '此',
  '请', '再', '并', '由', '向', '于', '按', '如', '若',
  // 英文冠词 / 介词 / 系动词
  'the', 'a', 'an', 'of', 'to', 'in', 'on', 'at', 'for', 'with', 'and', 'or',
  'is', 'are', 'be', 'you', 'your', 'it', 'this', 'that', 'will', 'can',
};

/// 行首操作动词：真正的「怎么做」该由界面表达，不该写进灰字。
///
/// 只剥**行首**一个：句中出现动词（「关闭后不再获取天气数据」）不算，
/// 那种句子讲的是后果，要留。
const List<String> _leadingActionVerbs = <String>[
  '登录', '选择', '查看', '进入', '打开', '点按', '点击', '填写', '切换',
  '设置', '添加', '长按', '滑动', '选中',
  'select', 'view', 'open', 'enter', 'tap', 'click', 'choose', 'fill',
  'switch', 'add', 'longpress',
];

bool _isCjkRune(int rune) => rune > 0x2e80;

/// 把一段文案切成 token：汉字一字一个，拉丁字母/数字连续成词，其余是分隔。
///
/// 不用 `split(' ')`：中文没有空格，按词切会把整句当成一个 token，
/// 判据就永远命中不了。
///
/// **注意这里只做「字」级切分，行首动词另由 [stripLeadingActionVerb] 处理**：
/// 中文词没有分隔符，`「选择课表」` 切成单字后行首动词 `选择` 永远匹配不上，
/// 会漏掉最典型的复述——这是 2026-10-25 反向验证时抓到的 bug。
List<String> copyTokens(String text) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString().toLowerCase());
      buffer.clear();
    }
  }

  for (final rune in text.runes) {
    if (_isCjkRune(rune)) {
      flush();
      tokens.add(String.fromCharCode(rune));
    } else if (RegExp(r'[A-Za-z0-9]').hasMatch(String.fromCharCode(rune))) {
      buffer.write(String.fromCharCode(rune));
    } else {
      flush();
    }
  }
  flush();
  return tokens;
}

/// 剥掉句子开头那一个「操作动词」（`选择课表` → `课表`）。
///
/// 必须在**原字符串**上按词剥，而不是在切好的单字 token 上剥：
/// 中文动词是两个汉字，单字 token 里没有任何一项等于 `选择`。
///
/// 只剥行首一个：「关闭后不再获取天气数据」这类句子里虽然也有动词，
/// 但它讲的是后果，整句要留。
String stripLeadingActionVerb(String text) {
  final trimmed = text.trimLeft();
  for (final verb in _leadingActionVerbs) {
    if (trimmed.toLowerCase().startsWith(verb)) {
      return trimmed.substring(verb.length).trimLeft();
    }
  }
  return trimmed;
}

/// 说明句在标题之外还剩多少 token；0 表示纯复述。
///
/// 步骤：先剥行首操作动词（在字符串上做，见 [stripLeadingActionVerb]），
/// 再切 token，最后去掉标题里已有的、以及 [copyStopWords]。
int restatingResidue(String subtitle, String title) {
  final tokens = copyTokens(stripLeadingActionVerb(subtitle));
  final titleTokens = copyTokens(title).toSet();
  var residue = 0;
  for (final token in tokens) {
    if (titleTokens.contains(token) || _copyStopWords.contains(token)) {
      continue;
    }
    residue++;
  }
  return residue;
}

/// 一处「说明句复述标题」。
class RestatingSubtitle {
  const RestatingSubtitle({
    required this.titleKey,
    required this.subtitleKey,
    required this.locale,
    required this.widget,
    required this.residue,
    required this.source,
    required this.line,
    required this.titleText,
    required this.subtitleText,
  });

  final String titleKey;
  final String subtitleKey;
  final String locale;
  final String widget;

  /// 残留 token 数（0 = 纯复述）。
  final int residue;
  final String source;
  final int line;
  final String titleText;
  final String subtitleText;

  String get id => '$locale/$subtitleKey';

  @override
  String toString() =>
      '$subtitleKey [$locale] 残留 $residue token'
      '（标题「$titleText」/ 说明「$subtitleText」，$widget @ $source:$line）';
}

/// 一处「同一行控件里的标题键 + 说明键」配对。
///
/// 单独抽出来是因为复述判据必须**成对**看：说明句有没有新信息，
/// 只取决于它和同一行的标题比。单看说明句无从判断。
class RowCopyPair {
  const RowCopyPair({
    required this.widget,
    required this.titleKey,
    required this.subtitleKey,
    required this.source,
    required this.line,
  });

  final String widget;
  final String titleKey;
  final String subtitleKey;
  final String source;
  final int line;
}

/// 从一处源码里抽出「标题键 + 说明键」配对。
///
/// 只认 `subtitle`：`details` / `hint` / `caption` 在仓库里含义不同——
/// `details` 是行的**右侧取值**（如「已启用 3/6 个」），不是次要说明，
/// 把它算进来会误伤真实数据。这一点与 [extractBindings] 的口径有意不同：
/// 那里判「宽不宽」，两个槽位都受挤压；这里判「要不要存在」，只针对说明。
///
/// 同一控件块里第一个 title / subtitle 生效（与手工阅读一致）；
/// 缺标题的配对跳过——没有标题就没有「复述」这回事。
List<RowCopyPair> extractRowCopyPairs(String source, String sourcePath) {
  final pairs = <RowCopyPair>[];
  final widgets = squeezedRowWidgets.join('|');
  final ctor = RegExp('\\b($widgets)\\s*(?:<[^<>()]*>)?\\s*\\(');
  final titleRe = RegExp(
    '\\b(title|label)\\s*:\\s*\\n?\\s*l10n\\.([A-Za-z0-9_]+)',
  );
  final subtitleRe = RegExp('\\bsubtitle\\s*:\\s*\\n?\\s*l10n\\.([A-Za-z0-9_]+)');

  for (final match in ctor.allMatches(source)) {
    final start = match.end;
    var index = start;
    var depth = 1;
    while (index < source.length && depth > 0) {
      final char = source[index];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }
      index++;
    }
    if (depth != 0) {
      continue; // 括号不配对的在途改动，跳过而不是炸。
    }
    final body = source.substring(start, index - 1);
    final subtitleMatch = subtitleRe.firstMatch(body);
    if (subtitleMatch == null) {
      continue;
    }
    final titleMatch = titleRe.firstMatch(body);
    if (titleMatch == null) {
      continue; // 无标题：说明句是这行唯一的标签，不是「复述」。
    }
    pairs.add(
      RowCopyPair(
        widget: match.group(1)!,
        titleKey: titleMatch.group(2)!,
        subtitleKey: subtitleMatch.group(1)!,
        source: sourcePath,
        line: _lineOf(source, match.start),
      ),
    );
  }
  return pairs;
}

/// 全仓检查：所有语言 × 所有「标题 + 说明」配对，找出复述标题的说明句。
///
/// 同一 `locale/说明键` 只报一次（取第一处引用），与 [findViolations] 一致。
List<RestatingSubtitle> findRestatingSubtitles({
  required Map<String, String> sources,
  required Map<String, ArbValues> arbByLocale,
}) {
  final pairs = <String, RowCopyPair>{};
  for (final entry in sources.entries) {
    for (final pair in extractRowCopyPairs(entry.value, entry.key)) {
      pairs.putIfAbsent(
        '${pair.titleKey}\u0000${pair.subtitleKey}',
        () => pair,
      );
    }
  }

  final found = <RestatingSubtitle>[];
  final reported = <String>{};
  for (final pair in pairs.values) {
    for (final locale in arbByLocale.keys) {
      final arb = arbByLocale[locale];
      final title = arb?[pair.titleKey];
      final subtitle = arb?[pair.subtitleKey];
      if (title == null || subtitle == null) {
        continue; // 缺译由 test/l10n 管。
      }
      final residue = restatingResidue(subtitle, title);
      if (residue > restatingResidueMaxTokens) {
        continue;
      }
      final id = '$locale\u0000${pair.subtitleKey}';
      if (!reported.add(id)) {
        continue;
      }
      found.add(
        RestatingSubtitle(
          titleKey: pair.titleKey,
          subtitleKey: pair.subtitleKey,
          locale: locale,
          widget: pair.widget,
          residue: residue,
          source: pair.source,
          line: pair.line,
          titleText: title,
          subtitleText: subtitle,
        ),
      );
    }
  }
  found.sort((a, b) => a.id.compareTo(b.id));
  return found;
}

/// 复述违规的稳定标识（写进基线文件的那一行）。
String restatingId(RestatingSubtitle v) => v.id;

/// 六种语言的 ARB 文件名（`lib/l10n/app_<locale>.arb`）。
const List<String> appLocales = <String>[
  'zh',
  'en',
  'ja',
  'ko',
  'zh_HK',
  'zh_TW',
];

/// 读六份 ARB。键顺序无关，`@` 元数据剔除，非字符串值跳过。
///
/// [resolve] 负责把仓库相对路径映射成实际可读路径——守卫要传
/// `GuardSource.resolve`（读提交快照），CLI 传恒等函数（读工作区）。
Map<String, ArbValues> loadArbs(String Function(String) resolve) {
  final result = <String, ArbValues>{};
  for (final locale in appLocales) {
    final path = resolve('lib/l10n/app_$locale.arb');
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('缺语言文件：$path');
    }
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    result[locale] = <String, String>{
      for (final entry in raw.entries)
        if (!entry.key.startsWith('@') && entry.value is String)
          entry.key: entry.value as String,
    };
  }
  return result;
}

/// 读 `lib/` 下的 Dart 源码，**排除生成的 `app_localizations*.dart`**。
///
/// 生成物里每个键都有一个 getter，不排除的话死键永远查不出来
/// （每个键都能「引用」到生成物自己身上），宽度检查也会被生成物的
/// 注释行污染。返回 `仓库相对路径 -> 内容`。
Map<String, String> loadSources(String Function(String) resolve) {
  final sources = <String, String>{};
  // 目录本身也要经 resolve：快照模式下工作区的 lib/ 不是提交内容。
  final root = Directory(resolve('lib'));
  if (!root.existsSync()) {
    throw StateError('找不到 lib/：${root.path}');
  }
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final rel = entity.path.replaceAll(r'\', '/');
    if (rel.contains('/l10n/app_localizations')) {
      continue;
    }
    // listSync 在快照模式给绝对路径，rebase 回仓库相对：调用方（基线比较）
    // 一律用仓库相对路径，否则两种模式下的集合比较不成立。
    sources[_repoRelative(rel, resolve)] = entity.readAsStringSync();
  }
  return sources;
}

/// 把 listSync 产出的路径折算成 `lib/...` 形式的仓库相对路径。
String _repoRelative(String anyPath, String Function(String) resolve) {
  final normalized = anyPath.replaceAll(r'\', '/');
  final probe = resolve('lib').replaceAll(r'\', '/');
  final index = normalized.indexOf('/lib/');
  if (index >= 0) {
    return normalized.substring(index + 1);
  }
  final libIndex = probe.endsWith('/lib') ? probe.length - 4 : probe.length;
  return normalized.length > libIndex
      ? 'lib${normalized.substring(libIndex)}'
      : normalized;
}
