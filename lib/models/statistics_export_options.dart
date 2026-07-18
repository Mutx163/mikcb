/// Modules that can be included when exporting course statistics.
enum StatisticsExportModule {
  overview,
  achievements,
  stories,
  dailyDistribution,
  natureRatio,
  ranking,
}

/// User choices from the statistics export sheet (image only).
class StatisticsExportOptions {
  const StatisticsExportOptions({required this.modules});

  final Set<StatisticsExportModule> modules;

  /// All modules available for export.
  static const Set<StatisticsExportModule> allModules =
      <StatisticsExportModule>{
        StatisticsExportModule.overview,
        StatisticsExportModule.achievements,
        StatisticsExportModule.stories,
        StatisticsExportModule.dailyDistribution,
        StatisticsExportModule.natureRatio,
        StatisticsExportModule.ranking,
      };

  /// Default selection: everything except course ranking (long and optional).
  static const Set<StatisticsExportModule> defaultModules =
      <StatisticsExportModule>{
        StatisticsExportModule.overview,
        StatisticsExportModule.achievements,
        StatisticsExportModule.stories,
        StatisticsExportModule.dailyDistribution,
        StatisticsExportModule.natureRatio,
      };

  static StatisticsExportOptions defaults() {
    return const StatisticsExportOptions(modules: defaultModules);
  }

  bool get hasModules => modules.isNotEmpty;

  StatisticsExportOptions copyWith({Set<StatisticsExportModule>? modules}) {
    return StatisticsExportOptions(modules: modules ?? this.modules);
  }
}

/// Brand URLs shown on the export-only header / footer.
abstract final class StatisticsExportBrand {
  static const websiteUrl = 'https://mutx.ccwu.cc/';
  static const websiteDisplay = 'mutx.ccwu.cc';
  static const githubUrl = 'https://github.com/Mutx163/mikcb';
  static const githubDisplay = 'github.com/Mutx163/mikcb';
}
