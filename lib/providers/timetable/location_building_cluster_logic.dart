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
class LocationBuildingClusterLogic {
  LocationBuildingClusterLogic._();

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _chineseTeachingBuilding = RegExp(
    r'(?:第)?([一二三四五六七八九十百零〇两\d]{1,3})教(?:学楼)?',
  );
  static final RegExp _mainBuildingChinese = RegExp(r'主教学楼|主教');
  static final RegExp _letterMainBuilding = RegExp(
    r'([A-Za-z]+)主',
    caseSensitive: false,
  );

  /// Letter + Chinese building stem: A综 / B综合楼 / C教学楼…
  /// Must run before bare letter+digit so "A综D101" becomes A综, not D1.
  static final RegExp _letterChineseBuilding = RegExp(
    r'([A-Za-z]+)(综合楼|教学楼|实验楼|综合|综|实验|楼)',
    caseSensitive: false,
  );
  // Letter + digits building code anywhere: A1, A10, B2…
  static final RegExp _letterDigitPrefix = RegExp(
    r'([A-Za-z]+)(\d+)',
    caseSensitive: false,
  );
  static final RegExp _gateTagPattern = RegExp(
    r'南门|北门|东门|西门|正门|侧门|西区|东区|南区|北区|老校区|新校区|虎溪|沙坪坝',
  );

  /// Suggests a keyword pattern from a full classroom location string.
  ///
  /// Returns null when nothing reliable can be extracted.
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
  ///
  /// Longer building keys are preferred when one location could match several.
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

    // 1) Chinese main building.
    if (_mainBuildingChinese.hasMatch(normalized)) {
      return _ParsedLocation(
        original: original,
        buildingKey: '主教',
        confidence: BuildingClusterConfidence.high,
        gateTags: gateTags,
      );
    }

    // 2) Chinese teaching-building ordinal: 一教 / 第六教学楼
    final chineseMatch = _chineseTeachingBuilding.firstMatch(normalized);
    if (chineseMatch != null) {
      final ordinal = chineseMatch.group(1) ?? '';
      final key = '$ordinal教';
      return _ParsedLocation(
        original: original,
        buildingKey: key,
        confidence: BuildingClusterConfidence.high,
        gateTags: gateTags,
      );
    }

    // 3) Letter + 主 (e.g. A主201)
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

    // 4) Letter + Chinese building stem (A综D101 → A综, not D1)
    final letterChinese = _letterChineseBuilding.firstMatch(normalized);
    if (letterChinese != null) {
      final letter = (letterChinese.group(1) ?? '').toUpperCase();
      final stem = letterChinese.group(2) ?? '';
      if (letter.isNotEmpty && stem.isNotEmpty) {
        final key = _normalizeLetterChineseKey(letter, stem);
        return _ParsedLocation(
          original: original,
          buildingKey: key,
          confidence: BuildingClusterConfidence.high,
          gateTags: gateTags,
        );
      }
    }

    // 5) Letter + digit building code (A1062 → A1, A6106 → A6)
    // Prefer the left-most match that looks like a building, not a trailing room
    // code after Chinese text (handled above) or after another letter block.
    final letterDigit = _bestLetterDigitMatch(normalized);
    if (letterDigit != null) {
      return _ParsedLocation(
        original: original,
        buildingKey: letterDigit.buildingKey,
        confidence: letterDigit.confidence,
        gateTags: gateTags,
      );
    }

    return null;
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

    // Returns the left-most letter+digit run. Trailing room codes that follow
    // Chinese building stems (e.g. A综D101) are already handled by earlier
    // matchers; this helper does not skip mid-string room tails itself.
    for (final match in matches) {
      final letter = (match.group(1) ?? '').toUpperCase();
      final digits = match.group(2) ?? '';
      if (letter.isEmpty || digits.isEmpty) {
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
  /// Heuristic: when total digits >= 3, keep 1 digit as building number if
  /// the remainder looks like a room (3–4 digits), otherwise keep 2.
  /// Examples: `1062` → `1`, `6106` → `6`, `101` → `1`, `10` → `10`.
  static String _splitBuildingDigits(String digits) {
    if (digits.length <= 2) {
      return digits;
    }
    // Prefer 1-digit building when remaining is 3–4 (typical room).
    final oneDigitRoom = digits.substring(1);
    if (oneDigitRoom.length >= 3 && oneDigitRoom.length <= 4) {
      return digits.substring(0, 1);
    }
    // Prefer 2-digit building when remaining is 3–4.
    if (digits.length >= 5) {
      final twoDigitRoom = digits.substring(2);
      if (twoDigitRoom.length >= 3 && twoDigitRoom.length <= 4) {
        return digits.substring(0, 2);
      }
    }
    // Fallback: first digit only for long runs.
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
    // Pure Chinese labels work better with contains (may appear mid-string).
    final hasLetterOrDigit = RegExp(r'[A-Za-z0-9]').hasMatch(key);
    if (!hasLetterOrDigit) {
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
