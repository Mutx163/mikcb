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
/// Designed for messy real-world names, not a fixed campus whitelist:
/// letter-digit codes, arbitrary *楼/*馆/*厅/*中心, 号楼/栋/座, 教N,
/// 东/西 + digits, classrooms, online platforms, English halls, etc.
class LocationBuildingClusterLogic {
  LocationBuildingClusterLogic._();

  static final RegExp _whitespace = RegExp(r'\s+');

  /// 一教 / 第六教学楼 / 第3教学楼 / 2教301
  static final RegExp _chineseTeachingBuilding = RegExp(
    r'(?:第)?([一二三四五六七八九十百零〇两\d]{1,3})教(?:学楼)?',
  );

  /// 教1-201 / 教2楼 / 教A301
  static final RegExp _teachThenNumber = RegExp(
    // Letter OR digits/Chinese ordinal only — do not swallow room tails (教A301 → 教A).
    r'教([A-Za-z]|[一二三四五六七八九十]|[0-9]{1,3})(?:号)?(?:教学)?(?:楼|栋)?',
  );

  static final RegExp _mainBuildingChinese = RegExp(r'主教学楼|主教');
  static final RegExp _letterMainBuilding = RegExp(
    r'([A-Za-z]+)主',
    caseSensitive: false,
  );

  static final RegExp _letterChineseBuilding = RegExp(
    r'([A-Za-z]+)(综合楼|教学楼|实验楼|实训楼|科研楼|信息楼|综合|综|实验|实训|楼)',
    caseSensitive: false,
  );

  static final RegExp _letterDigitPrefix = RegExp(
    r'([A-Za-z]+)(\d+)',
    caseSensitive: false,
  );

  /// 1号楼 / 3号教学楼 / 12栋 / 5#楼 / 教学1楼
  static final RegExp _numberedBuilding = RegExp(
    r'(?:教学|实验|实训|综合|公共)?'
    r'(?:第)?'
    r'([一二三四五六七八九十百零〇两\d]{1,3})'
    r'(?:号|#|＃)?'
    r'(?:教学|实验|实训)?'
    r'(楼|栋|幢|座)',
  );

  static final RegExp _seatBlock = RegExp(
    r'([A-Za-z\d一二三四五六七八九十]{1,3})座',
    caseSensitive: false,
  );

  /// 东12 / 西12 / 南教1
  static final RegExp _cardinalGrid = RegExp(
    r'([东西南北])'
    r'(?:教|教学楼|楼)?'
    r'([A-Za-z]?\d{1,3})'
    r'(?:号)?(?:教学)?(?:楼|栋)?',
  );

  static final RegExp _digitBuildingRoom = RegExp(
    r'^([A-Za-z]?\d{1,3}[A-Za-z]?)[-–—/／·.](\d{2,4}[A-Za-z]?)$',
    caseSensitive: false,
  );

  /// Any Chinese stem + facility suffix (not a name whitelist).
  static final RegExp _namedFacilityBuilding = RegExp(
    r'([A-Za-z0-9]*[\u4e00-\u9fff]{1,16}(?:'
    r'教学楼|实验楼|实训楼|综合楼|科研楼|行政楼|办公楼|信息楼|工学楼|理学楼|文理楼|'
    r'艺术楼|音乐楼|体育楼|逸夫楼|求是楼|明德楼|博学楼|至善楼|知行楼|致远楼|行健楼|厚德楼|'
    r'理工楼|基础楼|公共楼|图文中心|实验中心|实训中心|活动中心|学生中心|创新中心|'
    r'会议中心|学术中心|报告厅|阶梯教室|多媒体教室|语音室|机房|实验室|'
    r'图书馆|体育馆|游泳馆|礼堂|大礼堂|音乐厅|美术馆|博物馆|科技馆|'
    r'楼|馆|厅|中心|栋|幢|院|所'
    r'))',
  );

  static final RegExp _classroomLabel = RegExp(
    // Do NOT glue trailing room digits onto the label: "测试教室01" must yield
    // "测试教室" so match-side contains/prefix can still hit "测试教室 01".
    r'([A-Za-z0-9]*[\u4e00-\u9fffA-Za-z0-9]{1,20}'
    r'(?:教室|阶教|阶梯教室|语音室|机房|实验室))',
  );

  static final RegExp _sportsPlace = RegExp(
    r'([\u4e00-\u9fffA-Za-z0-9]{0,12}(?:'
    r'操场|田径场|足球场|篮球场|排球场|网球场|羽毛球场|乒乓球场|'
    r'游泳馆|体育馆|运动场|风雨操场|体育场'
    r'))',
  );

  static final RegExp _virtualPlatform = RegExp(
    r'([\u4e00-\u9fffA-Za-z0-9]{0,24}(?:'
    r'测评平台|在线平台|学习平台|教学平台|实验平台|慕课|在线课堂|网络课堂|'
    r'线上教室|线上|网上|网课|腾讯会议|钉钉|飞书|Zoom|Teams|ClassIn|'
    r'平台|系统|网站|直播'
    r'))',
    caseSensitive: false,
  );

  static final RegExp _englishFacility = RegExp(
    r'((?:[A-Za-z][A-Za-z0-9.\-]{0,20}\s+){0,4}'
    r'(?:Building|Bldg\.?|Hall|Tower|Block|Wing|Lab(?:oratory)?|'
    r'Centre|Center|Room|Rm\.?)'
    r'(?:\s+[A-Za-z0-9.\-]{1,12})?)',
    caseSensitive: false,
  );

  static final RegExp _stemThenRoom = RegExp(
    r'^((?:[A-Za-z]{1,4})?[\u4e00-\u9fff]{2,16})'
    r'(?:[-–—·./／\s]*)'
    r'(?:[A-Za-z]?\d{2,5}[A-Za-z]?|\d{1,2}[-–—]\d{2,4})$',
  );

  static final RegExp _shortChinesePlace = RegExp(r'^[\u4e00-\u9fff]{2,16}$');

  static final RegExp _gateTagPattern = RegExp(
    r'南门|北门|东门|西门|正门|侧门|西区|东区|南区|北区|老校区|新校区|'
    r'虎溪|沙坪坝|大学城|本部|分校|主校区|南校区|北校区|中心校区',
  );

  static final RegExp _weakZonePrefix = RegExp(
    r'^(?:西区|东区|南区|北区|老校区|新校区|本部|分校|大学城|'
    r'主校区|南校区|北校区|中心校区|虎溪校区|沙坪坝校区)',
  );

  static final RegExp _weakSchoolPrefix = RegExp(
    r'^[\u4e00-\u9fffA-Za-z0-9]{2,20}(?:大学|学院|校区)',
  );

  static final RegExp _trailingRoomNoise = RegExp(
    r'(?:[-–—·./／\s()（）]*)(?:'
    r'[A-Za-z]?\d{1,5}[A-Za-z]?'
    r'|\d{1,2}[-–—]\d{2,4}'
    r'|[东南西北]?[侧]?(?:楼|层)?\d{1,3}[F层]?'
    r'|第?\d{1,2}(?:楼|层|F|f)'
    r'|\d{1,2}F'
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

    final normalized = _normalizeLocationText(original);
    final gateTags = _extractGateTags(normalized);

    var parseSource = normalized;
    parseSource = parseSource.replaceFirst(_weakZonePrefix, '');
    if (parseSource.length >= 4) {
      final withoutSchool = parseSource.replaceFirst(_weakSchoolPrefix, '');
      if (withoutSchool.length >= 2) {
        parseSource = withoutSchool;
      }
    }
    if (parseSource.isEmpty) {
      parseSource = normalized;
    }

    final virtual = _virtualPlatform.firstMatch(parseSource);
    if (virtual != null) {
      final key = (virtual.group(1) ?? parseSource).trim();
      if (key.length >= 2) {
        return _hit(original, key, BuildingClusterConfidence.high, gateTags);
      }
    }

    if (_mainBuildingChinese.hasMatch(normalized)) {
      return _hit(original, '主教', BuildingClusterConfidence.high, gateTags);
    }

    final chineseMatch = _chineseTeachingBuilding.firstMatch(parseSource);
    if (chineseMatch != null) {
      final ordinal = chineseMatch.group(1) ?? '';
      return _hit(
        original,
        '$ordinal教',
        BuildingClusterConfidence.high,
        gateTags,
      );
    }

    final teachNum = _teachThenNumber.firstMatch(parseSource);
    if (teachNum != null) {
      final ordinal = (teachNum.group(1) ?? '').toUpperCase();
      if (ordinal.isNotEmpty) {
        return _hit(
          original,
          '教$ordinal',
          BuildingClusterConfidence.high,
          gateTags,
        );
      }
    }

    final letterMain = _letterMainBuilding.firstMatch(parseSource);
    if (letterMain != null) {
      final letter = (letterMain.group(1) ?? '').toUpperCase();
      if (letter.isNotEmpty && letter.length <= 2) {
        return _hit(
          original,
          '$letter主',
          BuildingClusterConfidence.high,
          gateTags,
        );
      }
    }

    final letterChinese = _letterChineseBuilding.firstMatch(parseSource);
    if (letterChinese != null) {
      final letter = (letterChinese.group(1) ?? '').toUpperCase();
      final stem = letterChinese.group(2) ?? '';
      if (letter.isNotEmpty && letter.length <= 2 && stem.isNotEmpty) {
        return _hit(
          original,
          _normalizeLetterChineseKey(letter, stem),
          BuildingClusterConfidence.high,
          gateTags,
        );
      }
    }

    final named = _bestNamedFacility(parseSource);
    if (named != null) {
      return _hit(original, named, BuildingClusterConfidence.high, gateTags);
    }

    // Cardinal grid before numbered 楼/栋 so 西3楼 → 西3, not 3楼.
    final cardinal = _cardinalGrid.firstMatch(parseSource);
    if (cardinal != null) {
      final dir = cardinal.group(1) ?? '';
      final code = (cardinal.group(2) ?? '').toUpperCase();
      if (dir.isNotEmpty && code.isNotEmpty) {
        return _hit(
          original,
          '$dir$code',
          BuildingClusterConfidence.high,
          gateTags,
        );
      }
    }

    final numbered = _numberedBuilding.firstMatch(parseSource);
    if (numbered != null) {
      final ordinal = numbered.group(1) ?? '';
      final unit = numbered.group(2) ?? '楼';
      if (ordinal.isNotEmpty) {
        return _hit(
          original,
          '$ordinal$unit',
          BuildingClusterConfidence.high,
          gateTags,
        );
      }
    }

    final seat = _seatBlock.firstMatch(parseSource);
    if (seat != null) {
      final block = (seat.group(1) ?? '').toUpperCase();
      if (block.isNotEmpty) {
        return _hit(
          original,
          '$block座',
          BuildingClusterConfidence.high,
          gateTags,
        );
      }
    }

    final classroom = _classroomLabel.firstMatch(parseSource);
    if (classroom != null) {
      final key = (classroom.group(1) ?? '').trim();
      if (key.length >= 2) {
        return _hit(original, key, BuildingClusterConfidence.high, gateTags);
      }
    }

    final sports = _sportsPlace.firstMatch(parseSource);
    if (sports != null) {
      final key = (sports.group(1) ?? '').trim();
      if (key.length >= 2) {
        return _hit(original, key, BuildingClusterConfidence.high, gateTags);
      }
    }

    final letterDigit = _bestLetterDigitMatch(parseSource);
    if (letterDigit != null) {
      return _hit(
        original,
        letterDigit.buildingKey,
        letterDigit.confidence,
        gateTags,
      );
    }

    final digitRoom = _digitBuildingRoom.firstMatch(parseSource);
    if (digitRoom != null) {
      final building = (digitRoom.group(1) ?? '').toUpperCase();
      if (building.isNotEmpty) {
        return _hit(
          original,
          building,
          BuildingClusterConfidence.medium,
          gateTags,
        );
      }
    }

    final english =
        _englishFacility.firstMatch(original) ??
        _englishFacility.firstMatch(parseSource);
    if (english != null) {
      final rawEnglish = _collapseSpaces(english.group(1) ?? '');
      final key = rawEnglish
          .replaceFirst(RegExp(r'\s+[A-Za-z]?\d{1,5}[A-Za-z]?$'), '')
          .trim();
      if (key.length >= 3) {
        return _hit(original, key, BuildingClusterConfidence.medium, gateTags);
      }
    }

    final stemRoom = _stemThenRoom.firstMatch(parseSource);
    if (stemRoom != null) {
      final key = (stemRoom.group(1) ?? '').trim();
      if (key.length >= 2) {
        return _hit(original, key, BuildingClusterConfidence.medium, gateTags);
      }
    }

    if (_shortChinesePlace.hasMatch(parseSource)) {
      return _hit(
        original,
        parseSource,
        BuildingClusterConfidence.medium,
        gateTags,
      );
    }

    final fallback = _fallbackKeyword(parseSource);
    if (fallback != null) {
      return _hit(original, fallback, BuildingClusterConfidence.low, gateTags);
    }

    return null;
  }

  static _ParsedLocation _hit(
    String original,
    String buildingKey,
    BuildingClusterConfidence confidence,
    List<String> gateTags,
  ) {
    return _ParsedLocation(
      original: original,
      buildingKey: buildingKey,
      confidence: confidence,
      gateTags: gateTags,
    );
  }

  /// Fullwidth -> halfwidth, unify dashes/slashes, unwrap short parentheses.
  static String _normalizeLocationText(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      if (unit >= 0xFF01 && unit <= 0xFF5E) {
        buffer.writeCharCode(unit - 0xFEE0);
      } else if (unit == 0x3000) {
        buffer.writeCharCode(0x20);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    var text = buffer.toString();
    text = text.replaceAll(_whitespace, '');
    text = text.replaceAll('－', '-');
    text = text.replaceAll('—', '-');
    text = text.replaceAll('–', '-');
    text = text.replaceAll('／', '/');
    text = text.replaceAll('·', '');
    text = text.replaceAll('•', '');
    text = text.replaceAllMapped(
      RegExp(r'[（(]([^）)]{1,12})[）)]'),
      (match) => match.group(1) ?? '',
    );
    return text;
  }

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
    if (key.length < 2) {
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
      if (normalized.length >= 2) {
        return normalized.length > 24
            ? normalized.substring(0, 24)
            : normalized;
      }
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
      if (letter.isEmpty || digits.isEmpty || letter.length > 2) {
        continue;
      }
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
    final hasLetterOrDigit = RegExp(r'[A-Za-z0-9]').hasMatch(key);
    if (!hasLetterOrDigit) {
      return LocationKeywordMatchMode.contains;
    }
    if (key.contains(' ') ||
        key.contains('平台') ||
        key.contains('系统') ||
        key.contains('教室') ||
        key.contains('会议') ||
        key.toLowerCase().contains('zoom') ||
        key.toLowerCase().contains('teams')) {
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
    final teachNum = RegExp(r'^教([A-Za-z\d]+)$').firstMatch(key);
    if (teachNum != null) {
      return '教${teachNum.group(1)}';
    }
    final letterMain = RegExp(r'^([A-Za-z]+)主$').firstMatch(key);
    if (letterMain != null) {
      return '${letterMain.group(1)!.toUpperCase()}主教学楼';
    }
    final letterDigit = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(key);
    if (letterDigit != null) {
      return '${letterDigit.group(1)!.toUpperCase()}${letterDigit.group(2)}栋';
    }
    final numbered = RegExp(
      r'^([一二三四五六七八九十百零〇两\d]+)(楼|栋|幢|座)$',
    ).firstMatch(key);
    if (numbered != null) {
      return '${numbered.group(1)}号${numbered.group(2)}';
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
