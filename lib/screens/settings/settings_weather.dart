part of '../timetable_settings_screen.dart';

/// 天气设置：开关、城市、失败重试、覆盖范围说明与数据来源署名。
///
/// 卡片上刻意不显示任何错误态（一屏 5~8 张卡，错误提示会变成视觉灾难），
/// 所以这里是把「为什么没有天气」讲清楚的唯一出口。
class _WeatherSettingsScreen extends StatelessWidget {
  const _WeatherSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weather = context.watch<WeatherProvider?>();

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.weatherSettingsTitle),
      child: HyperosListView(
        pageStorageKey: const PageStorageKey<String>('settings-weather'),
        children: [
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.weatherEnableTitle,
                subtitle: l10n.weatherEnableSubtitle,
                value: weather?.enabled ?? false,
                onChanged: weather == null
                    ? null
                    : (value) => unawaited(weather.setEnabled(value)),
              ),
            ],
          ),
          HyperosListGroup(
            children: [
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('location')!,
                  HyperosIconColors.teal,
                ),
                title: l10n.weatherCityLabel,
                endActions: [
                  Text(
                    weather?.location?.name ?? l10n.weatherCityNotSet,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
                onClick: weather == null
                    ? null
                    : () => HyperosNavigation.push(
                        context,
                        settings: const RouteSettings(
                          name: '/settings/weather/city',
                        ),
                        builder: (_) => const WeatherCityPickerScreen(),
                      ),
              ),
            ],
          ),
          if (weather?.status == WeatherStatus.failed)
            HyperosListGroup(
              children: [
                _MiuixSettingsPreference(
                  startAction: _settingsIconBadge(
                    MiuixIcons.extended.byName('refresh')!,
                    HyperosIconColors.orange,
                  ),
                  title: l10n.weatherStatusFailed,
                  endActions: [
                    Text(
                      l10n.weatherRetryAction,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                  onClick: () => unawaited(weather!.retry()),
                ),
              ],
            ),
          HyperosSectionDescription(text: l10n.weatherCoverageNote),
          HyperosSectionDescription(text: l10n.weatherAttribution),
        ],
      ),
    );
  }
}
