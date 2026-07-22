import '../../models/location_time_group.dart';

/// Confidence of an automatic building-cluster suggestion.
enum BuildingClusterConfidence { high, medium, low }

/// A group of classroom locations that appear to share the same building.
class BuildingCluster {
  /// Stable key used for dedupe / matching (e.g. `A1`, `A主`, `一教`).
  final String buildingKey;

  /// Human-readable label heuristic (may equal [buildingKey]).
  final String displayName;

  /// Keyword suggested for [LocationTimeGroup] rules.
  final LocationKeyword suggestedKeyword;

  /// Sample locations that fell into this cluster (sorted, unique).
  final List<String> sampleLocations;

  final BuildingClusterConfidence confidence;

  /// Weak campus-gate / zone tags found in the raw strings (e.g. 南门).
  final List<String> gateTags;

  const BuildingCluster({
    required this.buildingKey,
    required this.displayName,
    required this.suggestedKeyword,
    required this.sampleLocations,
    required this.confidence,
    this.gateTags = const [],
  });

  int get locationCount => sampleLocations.length;
}

class _ParsedLocation {
  final String original;
  final String buildingKey;
  final BuildingClusterConfidence confidence;
  final List<String> gateTags;

  const _ParsedLocation({
    required this.original,
    required this.buildingKey,
    required this.confidence,
    required this.gateTags,
  });
}

/// Pure helpers that cluster timetable location strings into buildings.
///
/// Covers common naming worldwide, not only 城科 letter-digit codes:
/// Chinese named buildings (理工楼/逸夫楼/…), ordinal 教学楼, letter blocks,
/// classrooms, virtual platforms, and English Building/Hall labels.
class LocationBuildingClusterLogic {
  LocationBuildingClusterLogic._();

  static final RegExp _whitespace = RegExp(r'\s+');

  /// 一教 / 第六教学楼 / 第3教学楼
  static final RegExp _chineseTeachingBuilding = RegExp(
    r'(?:第)?([一二三四五六七八九十百零〇两\d]{1,3})教(?:学楼)?',
  );
  static final RegExp _mainBuildingChinese = RegExp(r'主教学楼|主教');
  static final RegExp _letterMainBuilding = RegExp(
    r'([A-Za-z]+)主',
    caseSensitive: false,
  );

  /// Letter + Chinese building stem: A综 / B综合楼 / C教学楼…
  static final RegExp _letterChineseBuilding = RegExp(
    r'([A-Za-z]+)(综合楼|教学楼|实验楼|实训楼|科研楼|信息楼|综合|综|实验|实训|楼)',
    caseSensitive: false,
  );

  /// Letter + digits building code: A1, A10, B2…
  static final RegExp _letterDigitPrefix = RegExp(
    r'([A-Za-z]+)(\d+)',
    caseSensitive: false,
  );

  /// Named buildings ending with common facility suffixes, then optional room.
  ///
  /// Examples: 理工楼201、逸夫楼A301、东区实验中心3楼、图书馆报告厅
  static final RegExp _namedFacilityBuilding = RegExp(
    r'([A-Za-z0-9]*[\u4e00-\u9fff]{1,12}(?:'
    r'教学楼|实验楼|实训楼|综合楼|科研楼|行政楼|办公楼|信息楼|工学楼|理学楼|文理楼|'
    r'艺术楼|音乐楼|体育楼|逸夫楼|求是楼|明德楼|博学楼|至善楼|知行楼|致远楼|行健楼|厚德楼|'
    r'理工楼|基础楼|公共楼|图文中心|实验中心|实训中心|活动中心|学生中心|创新中心|'
    r'会议中心|报告厅|阶梯教室|多媒体教室|机房|实验室|图书馆|体育馆|游泳馆|礼堂|'
    r'楼|馆|厅|中心'
    r'))',
  );

  /// Explicit classroom labels: 测试教室、多媒体教室A
  static final RegExp _classroomLabel = RegExp(
    r'([A-Za-z0-9]*[\u4e00-\u9fffA-Za-z0-9]{1,16}教室[A-Za-z0-9]?)',
  );

  /// Virtual / online course places (no physical building).
  static final RegExp _virtualPlatform = RegExp(
    r'([\u4e00-\u9fffA-Za-z0-9]{2,24}(?:'
    r'测评平台|在线平台|学习平台|教学平台|实验平台|慕课|在线课堂|网络课堂|线上教室|'
    r'平台|系统|网站'
    r'))',
  );

  /// English-style: Building A, Science Hall, Lab Building 3
  static final RegExp _englishFacility = RegExp(
    r'((?:[A-Za-z][A-Za-z0-9.\-]{0,20}\s+){0,3}'
    r'(?:Building|Bldg\.?|Hall|Tower|Block|Lab(?:oratory)?|Centre|Center)'
    r'(?:\s+[A-Za-z0-9.\-]{1,12})?)',
    caseSensitive: false,
  );

  /// Chinese (or mixed) stem + trailing room code: 博学B201、东12-305
  static final RegExp _stemThenRoom = RegExp(
    r'^((?:[A-Za-z]{1,4})?[\u4e00-\u9fff]{2,12})'
    r'(?:[-–—·\s]*)'
    r'(?:[A-Za-z]?\d{2,5}[A-Za-z]?|\d{1,2}[-–—]\d{2,4})$',
  );

  /// Pure short Chinese place with no room code (体育馆、操场).
  static final RegExp _shortChinesePlace = RegExp(r'^[\u4e00-\u9fff]{2,12}$');

  static final RegExp _gateTagPattern = RegExp(
    r'南门|北门|东门|西门|正门|侧门|西区|东区|南区|北区|老校区|新校区|虎溪|沙坪坝|大学城|本部|分校',
  );

  /// Optional campus-zone prefix to strip before using a full-string fallback.
  static final RegExp _weakZonePrefix = RegExp(
    r'^(?:西区|东区|南区|北区|老校区|新校区|本部|分校|大学城)',
  );

  /// Trailing room / floor noise to strip from named buildings.
  static final RegExp _trailingRoomNoise = RegExp(
    r'(?:[-–—·\s]*)(?:'
    r'[A-Za-z]?\d{1,5}[A-Za-z]?'
    r'|\d{1,2}[-–—]\d{2,4}'
    // Require at least one digit so bare 楼/层 at the end of 理工楼 is kept.
    r'|[东南西北]?[侧]?(?:楼|层)?\d{1,3}[F层]?'
    r'|第?\d{1,2}(?:楼|层|F)'
    r')$',
  );

  /// Suggests a keyword pattern from a full classroom location string.
  ///
  /// Returns null only for empty input.
  static LocationKeyword? suggestKeywordFromLocation(String? location) {
    final parsed = _parseOne(location);
    if (parsed == null) {
      return null;
    }
    return LocationKeyword(
      pattern: parsed.buildingKey,
      mode: _preferredModeForKey(parsed.buildingKey),
    );
  }

  /// Clusters unique location strings into buildings.
  static List<BuildingCluster> clusterLocations(Iterable<String> locations) {
    final byKey = <String, List<_ParsedLocation>>{};

    for (final raw in locations) {
      final parsed = _parseOne(raw);
      if (parsed == null) {
        continue;
      }
      byKey.putIfAbsent(parsed.buildingKey, () => []).add(parsed);
    }

    final clusters = <BuildingCluster>[];
    for (final entry in byKey.entries) {
      final key = entry.key;
      final members = entry.value;
      final samples = members.map((item) => item.original).toSet().toList()
        ..sort();
      final gateTags = members.expand((item) => item.gateTags).toSet().toList()
        ..sort();
      final confidence = members
          .map((item) => item.confidence)
          .reduce(_maxConfidence);

      clusters.add(
        BuildingCluster(
          buildingKey: key,
          displayName: _displayNameForKey(key),
          suggestedKeyword: LocationKeyword(
            pattern: key,
            mode: _preferredModeForKey(key),
          ),
          sampleLocations: samples,
          confidence: confidence,
          gateTags: gateTags,
        ),
      );
    }

    clusters.sort((left, right) {
      final countCompare = right.locationCount.compareTo(left.locationCount);
      if (countCompare != 0) {
        return countCompare;
      }
      return left.buildingKey.compareTo(right.buildingKey);
    });
    return clusters;
  }

  /// Clusters not yet covered by any keyword in [existingKeywords].
  static List<BuildingCluster> uncoveredClusters({
    required Iterable<String> locations,
    required Iterable<LocationKeyword> existingKeywords,
  }) {
    final existingPatterns = existingKeywords
        .map((keyword) => keyword.pattern.trim().toLowerCase())
        .where((pattern) => pattern.isNotEmpty)
        .toSet();
    return clusterLocations(locations)
        .where(
          (cluster) =>
              !existingPatterns.contains(cluster.buildingKey.toLowerCase()),
        )
        .toList();
  }

  static _ParsedLocation? _parseOne(String? location) {
    final original = (location ?? '').trim();
    if (original.isEmpty) {
      return null;
    }

    final normalized = original.replaceAll(_whitespace, '');
    final gateTags = _extractGateTags(normalized);
    final withoutZone = normalized.replaceFirst(_weakZonePrefix, '');
    final parseSource = withoutZone.isEmpty ? normalized : withoutZone;

    // 1) Virtual / online places first (avoid treating 平台 as room noise).
    final virtual = _virtualPlatform.firstMatch(parseSource);
    if (virtual != null) {
      final key = (virtual.group(1) ?? parseSource).trim();
      if (key.length >= 2) {
        return _ParsedLocation(
          original: original,
          buildingKey: key,
          confidence: BuildingClusterConfidence.high,
          gateTags: gateTags,
        );
      }
    }

    // 2) Chinese main building.
    if (_mainBuildingChinese.hasMatch(normalized)) {
      return _ParsedLocation(
        original: original,
        buildingKey: '主教',
        confidence: BuildingClusterConfidence.high,
        gateTags: gateTags,
      );
    }

    // 3) Chinese teaching-building ordinal: 一教 / 第六教学楼.
    // More specific than bare 综合楼 when both appear (综合楼一教301 → 一教).
    final chineseMatch = _chineseTeachingBuilding.firstMatch(normalized);
    if (chineseMatch != null) {
      final ordinal = chineseMatch.group(1) ?? '';
      return _ParsedLocation(
        original: original,
        buildingKey: '$ordinal教',
        confidence: BuildingClusterConfidence.high,
        gateTags: gateTags,
      );
    }

    // 4) Letter + 主 (e.g. A主201)
    final letterMain = _letterMainBuilding.firstMatch(normalized);
    if (letterMain != null) {
      final letter = (letterMain.group(1) ?? '').toUpperCase();
      if (letter.isNotEmpty) {
        return _ParsedLocation(
          original: original,
          buildingKey: '$letter主',
          confidence: BuildingClusterConfidence.high,
          gateTags: gateTags,
        );
      }
    }

    // 5) Letter + Chinese building stem (A综D101 → A综, not D1)
    final letterChinese = _letterChineseBuilding.firstMatch(normalized);
    if (letterChinese != null) {
      final letter = (letterChinese.group(1) ?? '').toUpperCase();
      final stem = letterChinese.group(2) ?? '';
      if (letter.isNotEmpty && stem.isNotEmpty) {
        return _ParsedLocation(
          original: original,
          buildingKey: _normalizeLetterChineseKey(letter, stem),
          confidence: BuildingClusterConfidence.high,
          gateTags: gateTags,
        );
      }
    }

    // 6) Named Chinese facilities: 理工楼201、逸夫楼、实验中心…
    final named = _bestNamedFacility(parseSource);
    if (named != null) {
      return _ParsedLocation(
        original: original,
        buildingKey: named,
        confidence: BuildingClusterConfidence.high,
        gateTags: gateTags,
      );
    }

    // 7) Explicit classroom labels: 测试教室
    final classroom = _classroomLabel.firstMatch(parseSource);
    if (classroom != null) {
      final key = (classroom.group(1) ?? '').trim();
      if (key.length >= 2) {
        return _ParsedLocation(
          original: original,
          buildingKey: key,
          confidence: BuildingClusterConfidence.high,
          gateTags: gateTags,
        );
      }
    }

    // 8) Letter + digit building code (A1062 → A1, A6106 → A6)
    // Use zone-stripped source so 西区A1062 still yields A1.
    final letterDigit = _bestLetterDigitMatch(parseSource);
    if (letterDigit != null) {
      return _ParsedLocation(
        original: original,
        buildingKey: letterDigit.buildingKey,
        confidence: letterDigit.confidence,
        gateTags: gateTags,
      );
    }

    // 9) English Building / Hall / Lab labels
    final english =
        _englishFacility.firstMatch(original) ??
        _englishFacility.firstMatch(parseSource);
    if (english != null) {
      final rawEnglish = _collapseSpaces(english.group(1) ?? '');
      final key = rawEnglish
          .replaceFirst(RegExp(r'\s+[A-Za-z]?\d{1,5}[A-Za-z]?$'), '')
          .trim();
      if (key.length >= 3) {
        return _ParsedLocation(
          original: original,
          buildingKey: key,
          confidence: BuildingClusterConfidence.medium,
          gateTags: gateTags,
        );
      }
    }

    // 10) Generic stem + room: 博学B201
    final stemRoom = _stemThenRoom.firstMatch(parseSource);
    if (stemRoom != null) {
      final key = (stemRoom.group(1) ?? '').trim();
      if (key.length >= 2) {
        return _ParsedLocation(
          original: original,
          buildingKey: key,
          confidence: BuildingClusterConfidence.medium,
          gateTags: gateTags,
        );
      }
    }

    // 11) Short pure-Chinese place (体育馆、操场、报告厅)
    if (_shortChinesePlace.hasMatch(parseSource)) {
      return _ParsedLocation(
        original: original,
        buildingKey: parseSource,
        confidence: BuildingClusterConfidence.medium,
        gateTags: gateTags,
      );
    }

    // 12) Fallback: cleaned full string so every timetable location can become
    // a keyword (never silently drop 劳动测评平台 / odd custom rooms).
    final fallback = _fallbackKeyword(parseSource);
    if (fallback != null) {
      return _ParsedLocation(
        original: original,
        buildingKey: fallback,
        confidence: BuildingClusterConfidence.low,
        gateTags: gateTags,
      );
    }

    return null;
  }

  /// Picks the longest named-facility match and strips trailing room codes.
  static String? _bestNamedFacility(String text) {
    final matches = _namedFacilityBuilding.allMatches(text).toList();
    if (matches.isEmpty) {
      return null;
    }

    Match? best;
    for (final match in matches) {
      final candidate = match.group(1) ?? '';
      if (candidate.length < 2) {
        continue;
      }
      if (best == null || candidate.length > (best.group(1)?.length ?? 0)) {
        best = match;
      }
    }
    if (best == null) {
      return null;
    }

    var key = best.group(1)!.trim();
    if (key.length == 1) {
      return null;
    }
    key = key.replaceFirst(_trailingRoomNoise, '');
    if (key.length < 2) {
      return null;
    }
    return key;
  }

  static String? _fallbackKeyword(String normalized) {
    var value = normalized.replaceFirst(_trailingRoomNoise, '');
    value = value.trim();
    if (value.length < 2) {
      return null;
    }
    if (value.length > 24) {
      value = value.substring(0, 24);
    }
    return value;
  }

  static String _collapseSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Collapses A综合楼 / A综合 / A综 → stable key `A综`.
  static String _normalizeLetterChineseKey(String letter, String stem) {
    final upperLetter = letter.toUpperCase();
    if (stem.startsWith('综')) {
      return '$upperLetter综';
    }
    if (stem.startsWith('教学')) {
      return '$upperLetter教学楼';
    }
    if (stem.startsWith('实验')) {
      return '$upperLetter实验楼';
    }
    if (stem.startsWith('实训')) {
      return '$upperLetter实训楼';
    }
    if (stem == '楼') {
      return '$upperLetter楼';
    }
    return '$upperLetter$stem';
  }

  static ({String buildingKey, BuildingClusterConfidence confidence})?
  _bestLetterDigitMatch(String normalized) {
    final matches = _letterDigitPrefix.allMatches(normalized).toList();
    if (matches.isEmpty) {
      return null;
    }

    for (final match in matches) {
      final letter = (match.group(1) ?? '').toUpperCase();
      final digits = match.group(2) ?? '';
      // Campus letter blocks are almost always 1–2 letters (A1, AB10).
      // Longer letter runs are English words (ScienceHall201) — skip here.
      if (letter.isEmpty || digits.isEmpty || letter.length > 2) {
        continue;
      }
      // Skip letter+digit that is only a room tail after a Chinese stem
      // (e.g. 理工楼A201 → room A201 should not become building A2).
      final prefix = normalized.substring(0, match.start);
      if (RegExp(r'[\u4e00-\u9fff]$').hasMatch(prefix)) {
        continue;
      }
      final buildingDigits = _splitBuildingDigits(digits);
      final key = '$letter$buildingDigits';
      final confidence = digits.length >= 3
          ? BuildingClusterConfidence.high
          : BuildingClusterConfidence.medium;
      return (buildingKey: key, confidence: confidence);
    }
    return null;
  }

  /// Splits a digit run into building number vs room number.
  ///
  /// Examples: `1062` → `1`, `6106` → `6`, `101` → `1`, `10` → `10`.
  static String _splitBuildingDigits(String digits) {
    if (digits.length <= 2) {
      return digits;
    }
    final oneDigitRoom = digits.substring(1);
    if (oneDigitRoom.length >= 3 && oneDigitRoom.length <= 4) {
      return digits.substring(0, 1);
    }
    if (digits.length >= 5) {
      final twoDigitRoom = digits.substring(2);
      if (twoDigitRoom.length >= 3 && twoDigitRoom.length <= 4) {
        return digits.substring(0, 2);
      }
    }
    return digits.substring(0, 1);
  }

  static List<String> _extractGateTags(String normalized) {
    return _gateTagPattern
        .allMatches(normalized)
        .map((match) => match.group(0)!)
        .toSet()
        .toList()
      ..sort();
  }

  static LocationKeywordMatchMode _preferredModeForKey(String key) {
    // Pure Chinese / mixed labels often appear mid-string → contains.
    final hasLetterOrDigit = RegExp(r'[A-Za-z0-9]').hasMatch(key);
    if (!hasLetterOrDigit) {
      return LocationKeywordMatchMode.contains;
    }
    // Virtual platforms and multi-word English labels also use contains.
    if (key.contains(' ') ||
        key.contains('平台') ||
        key.contains('系统') ||
        key.contains('教室')) {
      return LocationKeywordMatchMode.contains;
    }
    return LocationKeywordMatchMode.prefix;
  }

  static String _displayNameForKey(String key) {
    if (key == '主教') {
      return '主教学楼';
    }
    final letterZong = RegExp(r'^([A-Za-z]+)综$').firstMatch(key);
    if (letterZong != null) {
      return '${letterZong.group(1)!.toUpperCase()}综合楼';
    }
    final chineseOrdinal = RegExp(r'^([一二三四五六七八九十百零〇两\d]+)教$').firstMatch(key);
    if (chineseOrdinal != null) {
      return '第${chineseOrdinal.group(1)}教学楼';
    }
    final letterMain = RegExp(r'^([A-Za-z]+)主$').firstMatch(key);
    if (letterMain != null) {
      return '${letterMain.group(1)!.toUpperCase()}主教学楼';
    }
    final letterDigit = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(key);
    if (letterDigit != null) {
      return '${letterDigit.group(1)!.toUpperCase()}${letterDigit.group(2)}栋';
    }
    return key;
  }

  static BuildingClusterConfidence _maxConfidence(
    BuildingClusterConfidence left,
    BuildingClusterConfidence right,
  ) {
    const order = {
      BuildingClusterConfidence.low: 0,
      BuildingClusterConfidence.medium: 1,
      BuildingClusterConfidence.high: 2,
    };
    return (order[left]! >= order[right]!) ? left : right;
  }
}
