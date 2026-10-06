import '../models/location_time_group.dart';
import '../models/timetable_settings.dart';

/// 轻屿专属作息数据（`qingyu_only/<学校ID>/time_schemes.json`）里的一套作息。
class QingyuOnlyTimeScheme {
  final String name;
  final List<LocationKeyword> keywords;
  final List<SectionTime> sections;

  /// 套不上任何关键词时使用的兜底作息（keywords 为空即兜底）。
  bool get isFallback => keywords.isEmpty;

  const QingyuOnlyTimeScheme({
    required this.name,
    required this.keywords,
    required this.sections,
  });
}

class QingyuOnlyCampus {
  final String id;
  final String name;
  final List<QingyuOnlyTimeScheme> schemes;

  const QingyuOnlyCampus({
    required this.id,
    required this.name,
    required this.schemes,
  });
}

class QingyuOnlyTimeSchemes {
  final List<QingyuOnlyCampus> campuses;

  const QingyuOnlyTimeSchemes({required this.campuses});

  /// 单校区时无需询问直接用它；多校区交给调用方按脚本的选择反推。
  QingyuOnlyCampus? get soleCampus =>
      campuses.length == 1 ? campuses.first : null;

  /// 用「脚本下发的那套作息」反推用户选的是哪个校区。
  ///
  /// Why this exists: 专属条目复用的是上游标准脚本，而那份脚本本来就会问一句
  /// 「选择学校作息时间表」（四套任选其一）。如果 App 再问一次「你在哪个校区？」，
  /// 用户就要连着回答同一个问题两次 —— 这是本轮方案设计里明确要避开的事。
  ///
  /// 所以这里不新增提问，而是拿脚本给出的节次时间与数据文件里各套解析后的节次
  /// 逐节比对：完全相同的那一套就是答案。它同时是自校验的：数据文件与脚本对不上
  /// 时不会猜，而是返回 null，由调用方退回脚本那套全局作息。
  ///
  /// 命中多套时同样返回 null（此时「用户选了哪套」这个问题本身没有答案）。
  QingyuOnlyCampus? campusForSections(List<SectionTime> sections) {
    if (sections.isEmpty) {
      return null;
    }
    QingyuOnlyCampus? matched;
    for (final campus in campuses) {
      for (final scheme in campus.schemes) {
        if (_sameSections(scheme.sections, sections)) {
          if (matched != null) {
            return null;
          }
          matched = campus;
        }
      }
    }
    return matched;
  }
}

bool _sameSections(List<SectionTime> a, List<SectionTime> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i].startTime != b[i].startTime || a[i].endTime != b[i].endTime) {
      return false;
    }
  }
  return true;
}

/// 纯函数解析器。
///
/// 存在的唯一理由：上游教务协议一次导入只能通过 `savePresetTimeSlots` 存一套
/// 全局作息。学校按校区 / 教学楼类型公布多套作息时（实测 CQCST 有 4 套、13 节，
/// 第 3、4 节差 5~15 分钟），协议表达不了。往协议里加方法是走不通的 —— 那会破坏
/// 「我们的脚本能原样回馈上游」这条原则，所以学校知识放数据文件，脚本保持标准。
///
/// 形状：
/// ```json
/// {
///   "version": 1,
///   "sections": {"1": {"startTime": "08:20", "endTime": "09:05"}, "…": {}},
///   "campuses": [
///     {"id": "yc", "name": "永川校区", "schemes": [
///       {"name": "永川校区 · 其他教学楼"},
///       {"name": "永川校区 · A栋·主教学楼",
///        "keywords": [{"pattern": "A栋", "mode": "prefix"}],
///        "overrides": {"3": {"startTime": "10:30", "endTime": "11:15"}}}
///     ]}
///   ]
/// }
/// ```
///
/// `sections` 是基线（一份完整有效的时间表），`schemes[].overrides` 只写与基线
/// 不同的节次。这样 4 套作息不必各抄 13 个数字，抄错的风险随之消失。
class QingyuOnlyTimeSchemesLogic {
  const QingyuOnlyTimeSchemesLogic._();

  /// 支持的数据版本。将来改格式时旧 App 应当「读不懂就跳过」而不是误读。
  static const int supportedVersion = 1;

  /// 解析 [decoded]。整体不可用时抛 [FormatException]（消息是服务消息码）；
  /// 单条脏数据只丢自己那一条，不废掉整份。
  ///
  /// **不信任仓库里的数据**：镜像可能被投毒、仓库可能回退到没有这个目录的旧版本，
  /// 所以每一条规则都在这里再校验一遍。校验项与仓库侧
  /// `scripts/validate_qingyu_only.py` 一致 —— 同一份数据被两处消费，仓库侧拦 CI，
  /// App 侧拦线上。
  static QingyuOnlyTimeSchemes parse(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('qingyu_only_time_schemes_format');
    }
    final version = decoded['version'];
    if (version is! int || version != supportedVersion) {
      throw const FormatException('qingyu_only_time_schemes_version');
    }

    final baseline = _parseSectionMap(decoded['sections']);
    if (baseline == null) {
      throw const FormatException('qingyu_only_time_schemes_baseline_missing');
    }

    final rawCampuses = decoded['campuses'];
    if (rawCampuses is! List || rawCampuses.isEmpty) {
      throw const FormatException('qingyu_only_time_schemes_campuses_missing');
    }

    final campuses = <QingyuOnlyCampus>[];
    final seenCampusIds = <String>{};
    for (final raw in rawCampuses) {
      if (raw is! Map) {
        continue;
      }
      final name = _text(raw['name']);
      if (name.isEmpty) {
        continue;
      }
      // id 只用于去重与日志；为空时用名字兜底，避免整校区被误判成重复。
      final rawId = _text(raw['id']);
      final key = rawId.isEmpty ? name : rawId;
      if (!seenCampusIds.add(key)) {
        continue;
      }
      final schemes = _parseSchemes(raw['schemes'], baseline);
      if (schemes.isEmpty) {
        continue;
      }
      // 兜底作息必须恰好一套：没有它则课程时间无处可落，多于一套则「默认用哪套」
      // 没有答案（仓库侧校验器同样卡这一条）。
      if (schemes.where((scheme) => scheme.isFallback).length != 1) {
        continue;
      }
      campuses.add(QingyuOnlyCampus(id: key, name: name, schemes: schemes));
    }

    if (campuses.isEmpty) {
      throw const FormatException('qingyu_only_time_schemes_campuses_empty');
    }
    return QingyuOnlyTimeSchemes(campuses: campuses);
  }

  static List<QingyuOnlyTimeScheme> _parseSchemes(
    Object? raw,
    Map<int, SectionTime> baseline,
  ) {
    if (raw is! List) {
      return const [];
    }
    final schemes = <QingyuOnlyTimeScheme>[];
    final seenNames = <String>{};
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final name = _text(item['name']);
      // 重名会让「兜底是哪一套」变歧义，先到先得。
      if (name.isEmpty || !seenNames.add(name)) {
        continue;
      }
      final sections = _resolveSchemeSections(item['overrides'], baseline);
      if (sections == null) {
        continue;
      }
      schemes.add(
        QingyuOnlyTimeScheme(
          name: name,
          keywords: _parseKeywords(item['keywords']),
          sections: sections,
        ),
      );
    }
    return schemes;
  }

  /// 基线 + 该套的覆盖 → 完整时间表。覆盖只允许改时间，不允许增删节次。
  ///
  /// 返回 null 表示这套数据不可用，调用方丢掉这一套即可（同校区其余套仍可用）。
  static List<SectionTime>? _resolveSchemeSections(
    Object? rawOverrides,
    Map<int, SectionTime> baseline,
  ) {
    // 覆盖表天生稀疏 ——「只写与基线不同的节次」正是这个格式存在的理由 ——
    // 所以绝不能拿「必须是 1..N 连续」去要求它。（第一版就踩了这个坑，把
    // CQCST 两个校区各砍掉一套，测试对着真实数据文件才暴露出来。）
    //
    // 空对象按「没有覆盖」处理：写了 overrides 却什么都没改，不算数据写错。
    final hasOverrides = rawOverrides is Map && rawOverrides.isNotEmpty;
    final overrides = hasOverrides
        ? _parseSectionMap(rawOverrides, requireContiguousFromOne: false)
        : null;
    // 显式写了覆盖却读不出内容（节次越界、时钟倒退）＝ 数据写错。
    if (hasOverrides && overrides == null) {
      return null;
    }
    // 覆盖了基线里没有的节次 = 数据写错：照抄会造出一份对不上的时间表。
    if (overrides != null) {
      for (final index in overrides.keys) {
        if (!baseline.containsKey(index)) {
          return null;
        }
      }
    }
    final sections = <SectionTime>[];
    for (var index = 1; index <= baseline.length; index++) {
      final section = overrides?[index] ?? baseline[index]!;
      if (sections.isNotEmpty) {
        // 覆盖后仍要求每一节不早于上一节的结束 —— 这是 App 建模板时的硬性要求，
        // 仓库侧校验器也卡同一条，两边规则一致才不会互相打脸。
        final previousEnd = _clockMinutes(sections.last.endTime);
        final start = _clockMinutes(section.startTime);
        if (previousEnd == null || start == null || previousEnd > start) {
          return null;
        }
      }
      sections.add(section);
    }
    return List<SectionTime>.unmodifiable(sections);
  }

  /// 把 `{"3": {startTime, endTime}}` 读成节次序号 → 时间。
  ///
  /// 返回 null 表示这份数据不可用：序号不是正整数、时钟格式不对、或某一节结束不
  /// 晚于开始。最后一种是真实存在的错误 —— 仓库侧校验器第一次运行就抓到了它
  /// （CQCST 基线曾把第 3 节照抄成第 1 节的占位值），而那份表 App 建不出来。
  ///
  /// [requireContiguousFromOne] 只对**基线**为真；覆盖表是稀疏的，不受此限。
  static Map<int, SectionTime>? _parseSectionMap(
    Object? raw, {
    bool requireContiguousFromOne = true,
  }) {
    if (raw is! Map) {
      return null;
    }
    final byIndex = <int, SectionTime>{};
    for (final entry in raw.entries) {
      final index = int.tryParse(_text(entry.key));
      final value = entry.value;
      if (index == null || index <= 0 || value is! Map) {
        return null;
      }
      final start = _text(value['startTime']);
      final end = _text(value['endTime']);
      final startMinutes = _clockMinutes(start);
      final endMinutes = _clockMinutes(end);
      if (startMinutes == null ||
          endMinutes == null ||
          endMinutes <= startMinutes) {
        return null;
      }
      byIndex[index] = SectionTime(startTime: start, endTime: end);
    }
    if (byIndex.isEmpty) {
      return null;
    }
    if (requireContiguousFromOne) {
      final ordered = byIndex.keys.toList()..sort();
      // 节次按位置对齐，缺一节会让「第 3 节」指向错误的时间。
      for (var i = 0; i < ordered.length; i++) {
        if (ordered[i] != i + 1) {
          return null;
        }
      }
    }
    return byIndex;
  }

  static List<LocationKeyword> _parseKeywords(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final keywords = <LocationKeyword>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final pattern = _text(item['pattern']);
      if (pattern.isEmpty) {
        continue;
      }
      keywords.add(
        LocationKeyword(
          pattern: pattern,
          mode: LocationKeywordMatchMode.fromValue(_text(item['mode'])),
        ),
      );
    }
    return keywords;
  }

  static String _text(Object? raw) => raw?.toString().trim() ?? '';

  static int? _clockMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour > 23 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }
}

/// 导入一套专属作息时，现有地点分组与新分组怎么合。
///
/// 三条规则，优先级从高到低：
///
/// 1. **同名替换**：脚本/数据文件提到的组名直接顶掉旧组——重复导入不攒重名组。
/// 2. **他校自动组清除**：来源标记是**别的学校**的自动分组（教学楼名跨校撞车
///    太常见，「A栋」谁家都有），留着只会把新校教室错分到旧校的作息上。
/// 3. **其余一律保留**：用户手建的组（无来源标记）与本校旧组。手建组不属于
///    任何一次导入的清理范围；本校旧组随后会被同名替换或继续生效。
///
/// 抽成纯函数的原因与 `_parseSectionMap` 等一致：合并策略是「清错一组比少清
/// 一组更糟」的判断，必须能直接单测，不该埋在屏幕的 async 流程里。
List<LocationTimeGroup> mergeLocationTimeGroupsForImport({
  required List<LocationTimeGroup> existing,
  required List<LocationTimeGroup> incoming,
  required String schoolId,
}) {
  final replacedNames = incoming.map((group) => group.name).toSet();
  return [
    for (final group in existing)
      if (!replacedNames.contains(group.name) &&
          (group.sourceSchoolId == null || group.sourceSchoolId == schoolId))
        group,
    ...incoming,
  ];
}
