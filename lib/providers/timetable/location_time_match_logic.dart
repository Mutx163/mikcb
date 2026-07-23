import '../../models/location_time_group.dart';

/// Result of matching a course location against configured place groups.
class LocationTimeMatchResult {
  final String groupId;
  final String groupName;
  final String timeSchemeId;
  final LocationKeyword matchedKeyword;

  const LocationTimeMatchResult({
    required this.groupId,
    required this.groupName,
    required this.timeSchemeId,
    required this.matchedKeyword,
  });
}

class _CandidateKeyword {
  final LocationTimeGroup group;
  final LocationKeyword keyword;

  const _CandidateKeyword({required this.group, required this.keyword});
}

/// Pure location → time-scheme routing helpers.
class LocationTimeMatchLogic {
  LocationTimeMatchLogic._();

  /// Normalizes a location string for matching: trim + case-fold.
  static String normalizeLocation(String? location) {
    return _normalizeForMatch(location);
  }

  /// Normalizes a keyword pattern the same way as locations.
  static String normalizePattern(String pattern) {
    return _normalizeForMatch(pattern);
  }

  /// Shared match-side normalization.
  ///
  /// Must stay compatible with [LocationBuildingClusterLogic] suggestions:
  /// clustering collapses whitespace/fullwidth before extracting building keys
  /// (e.g. `测试教室 01` → key `测试教室`), so matching must also collapse spaces
  /// or auto-imported keywords never hit the original timetable strings.
  static String _normalizeForMatch(String? text) {
    final raw = (text ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final unit in raw.runes) {
      if (unit >= 0xFF01 && unit <= 0xFF5E) {
        // Fullwidth ASCII → halfwidth (same as building cluster).
        buffer.writeCharCode(unit - 0xFEE0);
      } else if (unit == 0x3000) {
        // Fullwidth space.
        continue;
      } else if (unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D) {
        // Collapse all whitespace so "测试教室 01" matches keyword "测试教室".
        continue;
      } else if (unit == 0x00B7 ||
          unit == 0x30FB ||
          unit == 0x2022 ||
          unit == 0x2027 ||
          unit == 0x2219) {
        // Middle dots / bullets (cluster strips these; keep match in sync).
        continue;
      } else if (unit == 0x2014 || unit == 0x2013 || unit == 0xFF0D) {
        // Em/en dash / fullwidth hyphen → ASCII hyphen (cluster maps these).
        buffer.writeCharCode(0x2D);
      } else if (unit == 0xFF0F) {
        // Fullwidth solidus → '/'.
        buffer.writeCharCode(0x2F);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    var normalized = buffer.toString();
    // Align with building-cluster normalization so suggested keywords match.
    normalized = normalized.replaceAllMapped(
      RegExp(r'[（(]([^）)]{1,12})[）)]'),
      (match) => match.group(1) ?? '',
    );
    return normalized.toLowerCase();
  }

  /// Matches [location] against enabled groups.
  ///
  /// Longer keywords win; equal length uses higher [LocationTimeGroup.priority].
  static LocationTimeMatchResult? match(
    String? location,
    List<LocationTimeGroup> groups,
  ) {
    final normalizedLocation = normalizeLocation(location);
    if (normalizedLocation.isEmpty) {
      return null;
    }

    final candidates = <_CandidateKeyword>[];
    for (final group in groups) {
      if (!group.enabled || group.timeSchemeId.isEmpty) {
        continue;
      }
      for (final keyword in group.keywords) {
        final pattern = normalizePattern(keyword.pattern);
        if (pattern.isEmpty) {
          continue;
        }
        candidates.add(_CandidateKeyword(group: group, keyword: keyword));
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((left, right) {
      final leftLength = normalizePattern(left.keyword.pattern).length;
      final rightLength = normalizePattern(right.keyword.pattern).length;
      final lengthCompare = rightLength.compareTo(leftLength);
      if (lengthCompare != 0) {
        return lengthCompare;
      }
      final priorityCompare = right.group.priority.compareTo(
        left.group.priority,
      );
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      // Stable fallback: group name then pattern for deterministic tests.
      final nameCompare = left.group.name.compareTo(right.group.name);
      if (nameCompare != 0) {
        return nameCompare;
      }
      return left.keyword.pattern.compareTo(right.keyword.pattern);
    });

    for (final candidate in candidates) {
      final pattern = normalizePattern(candidate.keyword.pattern);
      if (_matchesMode(
        location: normalizedLocation,
        pattern: pattern,
        mode: candidate.keyword.mode,
      )) {
        return LocationTimeMatchResult(
          groupId: candidate.group.id,
          groupName: candidate.group.name,
          timeSchemeId: candidate.group.timeSchemeId,
          matchedKeyword: candidate.keyword,
        );
      }
    }

    return null;
  }

  static bool _matchesMode({
    required String location,
    required String pattern,
    required LocationKeywordMatchMode mode,
  }) {
    switch (mode) {
      case LocationKeywordMatchMode.exact:
        return location == pattern;
      case LocationKeywordMatchMode.prefix:
        return location.startsWith(pattern);
      case LocationKeywordMatchMode.contains:
        return location.contains(pattern);
    }
  }

  /// Whether any enabled group binds to [schemeId].
  static bool isSchemeBoundByGroups(
    List<LocationTimeGroup> groups,
    String schemeId,
  ) {
    return groups.any(
      (group) => group.enabled && group.timeSchemeId == schemeId,
    );
  }

  /// Whether any group (enabled or not) references [schemeId].
  static bool isSchemeReferencedByGroups(
    List<LocationTimeGroup> groups,
    String schemeId,
  ) {
    return groups.any((group) => group.timeSchemeId == schemeId);
  }

  /// Normalized keyword patterns owned by groups other than [excludingGroupId].
  static Set<String> patternsOwnedByOtherGroups(
    List<LocationTimeGroup> groups, {
    String? excludingGroupId,
  }) {
    final owned = <String>{};
    for (final group in groups) {
      if (excludingGroupId != null && group.id == excludingGroupId) {
        continue;
      }
      for (final keyword in group.keywords) {
        final pattern = normalizePattern(keyword.pattern);
        if (pattern.isNotEmpty) {
          owned.add(pattern);
        }
      }
    }
    return owned;
  }

  /// Name of another group that already owns [pattern], or null if free.
  static String? groupNameOwningPattern(
    List<LocationTimeGroup> groups,
    String pattern, {
    String? excludingGroupId,
  }) {
    final normalized = normalizePattern(pattern);
    if (normalized.isEmpty) {
      return null;
    }
    for (final group in groups) {
      if (excludingGroupId != null && group.id == excludingGroupId) {
        continue;
      }
      for (final keyword in group.keywords) {
        if (normalizePattern(keyword.pattern) == normalized) {
          return group.name;
        }
      }
    }
    return null;
  }

  /// True when [location] already matches a keyword in another group.
  ///
  /// Used to hide classrooms from pickers so the same place cannot be claimed
  /// by two place groups (match engine only returns one winner).
  static bool isLocationClaimedByOtherGroups(
    String? location,
    List<LocationTimeGroup> groups, {
    String? excludingGroupId,
  }) {
    final others = <LocationTimeGroup>[
      for (final group in groups)
        if (excludingGroupId == null || group.id != excludingGroupId) group,
    ];
    return match(location, others) != null;
  }

  /// Keywords from every group except [excludingGroupId] (for coverage UI).
  static List<LocationKeyword> keywordsFromOtherGroups(
    List<LocationTimeGroup> groups, {
    String? excludingGroupId,
  }) {
    final keywords = <LocationKeyword>[];
    for (final group in groups) {
      if (excludingGroupId != null && group.id == excludingGroupId) {
        continue;
      }
      keywords.addAll(group.keywords);
    }
    return keywords;
  }
}
