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
    return (location ?? '').trim().toLowerCase();
  }

  /// Normalizes a keyword pattern the same way as locations.
  static String normalizePattern(String pattern) {
    return pattern.trim().toLowerCase();
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
}
