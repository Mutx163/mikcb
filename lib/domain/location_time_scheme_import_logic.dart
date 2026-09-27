import '../models/location_time_group.dart';
import '../models/timetable_settings.dart';

/// One per-teaching-building scheme declared by a 教务 adapter script.
class LocationTimeSchemeImportGroup {
  final String name;
  final List<LocationKeyword> keywords;
  final List<SectionTime> sections;

  const LocationTimeSchemeImportGroup({
    required this.name,
    required this.keywords,
    required this.sections,
  });
}

/// Parsed payload of the `saveLocationTimeSchemes` bridge extension.
///
/// [defaultName] / [defaultSections] describe the fallback scheme used when a
/// classroom matches no [groups] entry.
class LocationTimeSchemeImportSpec {
  final String defaultName;
  final List<SectionTime> defaultSections;
  final List<LocationTimeSchemeImportGroup> groups;

  const LocationTimeSchemeImportSpec({
    required this.defaultName,
    required this.defaultSections,
    required this.groups,
  });
}

/// Pure parser for the `saveLocationTimeSchemes` payload.
///
/// Expected shape (a protocol extension, not upstream v2):
/// ```json
/// {
///   "default": {"name": "…", "sections": [{"startTime": "08:20", "endTime": "09:05"}]},
///   "groups": [
///     {
///       "name": "…",
///       "keywords": [{"pattern": "A主", "mode": "prefix"}],
///       "sections": [{"startTime": "08:20", "endTime": "09:05"}]
///     }
///   ]
/// }
/// ```
///
/// Parsing is deliberately tolerant of individual malformed entries (they are
/// skipped) so one bad classroom cannot void an otherwise good import, but an
/// unusable `default` is fatal because every course depends on it.
class LocationTimeSchemeImportLogic {
  const LocationTimeSchemeImportLogic._();

  /// Throws [FormatException] with a service-message key when the payload
  /// cannot be used at all.
  static LocationTimeSchemeImportSpec parse(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('invalid_location_time_schemes_format');
    }
    final defaultSpec = decoded['default'];
    if (defaultSpec is! Map) {
      throw const FormatException('location_time_schemes_default_required');
    }
    final defaultName = (defaultSpec['name'] as String?)?.trim() ?? '';
    if (defaultName.isEmpty) {
      throw const FormatException(
        'location_time_schemes_default_name_required',
      );
    }
    final defaultSections = parseSections(defaultSpec['sections']);
    if (defaultSections.isEmpty) {
      throw const FormatException('location_time_schemes_default_empty');
    }

    final rawGroups = decoded['groups'] is List
        ? decoded['groups'] as List<dynamic>
        : const <dynamic>[];
    final groups = <LocationTimeSchemeImportGroup>[];
    final seenNames = <String>{};
    for (final item in rawGroups) {
      if (item is! Map) {
        continue;
      }
      final name = (item['name'] as String?)?.trim() ?? '';
      // A duplicate name would make the group ambiguous, so first one wins.
      if (name.isEmpty || !seenNames.add(name)) {
        continue;
      }
      final sections = parseSections(item['sections']);
      final keywords = parseKeywords(item['keywords']);
      // A group without keywords can never win a location match, and one
      // without sections has nothing to route to; skip instead of persisting
      // dead weight.
      if (keywords.isEmpty || sections.isEmpty) {
        continue;
      }
      groups.add(
        LocationTimeSchemeImportGroup(
          name: name,
          keywords: keywords,
          sections: sections,
        ),
      );
    }

    return LocationTimeSchemeImportSpec(
      defaultName: defaultName,
      defaultSections: defaultSections,
      groups: groups,
    );
  }

  /// Reads `[{startTime, endTime}]`, skipping entries missing either clock time.
  ///
  /// The `number` field is intentionally ignored: the host maps sections
  /// positionally, exactly like `savePresetTimeSlots`.
  static List<SectionTime> parseSections(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final sections = <SectionTime>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final startTime = item['startTime']?.toString() ?? '';
      final endTime = item['endTime']?.toString() ?? '';
      if (startTime.isEmpty || endTime.isEmpty) {
        continue;
      }
      sections.add(SectionTime(startTime: startTime, endTime: endTime));
    }
    return sections;
  }

  /// Reads `[{pattern, mode}]`, defaulting unknown modes to `prefix` and
  /// dropping blank patterns.
  static List<LocationKeyword> parseKeywords(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final keywords = <LocationKeyword>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final pattern = (item['pattern'] as String?)?.trim() ?? '';
      if (pattern.isEmpty) {
        continue;
      }
      keywords.add(
        LocationKeyword(
          pattern: pattern,
          mode: LocationKeywordMatchMode.fromValue(item['mode'] as String?),
        ),
      );
    }
    return keywords;
  }
}
