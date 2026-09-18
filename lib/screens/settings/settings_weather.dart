part of '../timetable_settings_screen.dart';

/// 天气设置：开关、城市、失败重试、覆盖范围说明与数据来源署名。
///
/// 卡片上刻意不显示任何错误态（一屏 5~8 张卡，错误提示会变成视觉灾难），
/// 所以这里是把「为什么没有天气」讲清楚的唯一出口。
///
/// 结构遵循设置页惯例（见 `settings_home_widget.dart` /
/// `settings_home_menu_editor.dart`）：**每个区块 = `HyperosSectionGap` +
/// `HyperosSectionLabel` + 一个 `HyperosListGroup`**，说明文字
/// （`HyperosSectionDescription`）挂在它所属的那个区块之后。裸分组（无标题、
/// 无区块间距）在 IA 规范里是不允许的——区块之间会贴在一起、说明文字没有归属。
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
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.weatherSectionDisplayTitle),
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
          // 「预报只覆盖 16 天」解释的是「为什么有些日子看不到天气」，
          // 属于显示区块的脚注。
          HyperosSectionDescription(text: l10n.weatherCoverageNote),

          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.weatherSectionSourceTitle),
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
              // 取数失败时的重试。放在数据来源区块内，而不是单开一个匿名分组：
              // 它本来就是「这份数据没拿到」的补救动作。
              if (weather?.status == WeatherStatus.failed)
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
          // 数据来源署名是 Open-Meteo 数据许可（CC BY 4.0）的条款要求。
          HyperosSectionDescription(text: l10n.weatherAttribution),
        ],
      ),
    );
  }
}
