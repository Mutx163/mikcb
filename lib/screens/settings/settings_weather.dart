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
              // 一键定位放在城市行之前：它比「手动搜索」更常用，也是「我不想挑
              // 城市，直接用我在的地方」的默认路径。
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  // 城市行用的是 location，这里换 pin 避免两个同形图标。
                  MiuixIcons.extended.byName('pin')!,
                  HyperosIconColors.blue,
                ),
                title: l10n.weatherUseCurrentLocation,
                endActions: [
                  if (weather?.isLocating ?? false)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
                // 定位中整行禁用：系统级动作会弹权限框、要十几秒，防重复触发。
                // provider 侧还有单飞兜底，两道都在。
                onClick: (weather == null || weather.isLocating)
                    ? null
                    : () => unawaited(_locateWeather(context, weather)),
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('location')!,
                  HyperosIconColors.teal,
                ),
                title: l10n.weatherCityLabel,
                endActions: [
                  Text(
                    // displayName 而不是 name：定位来的地点带区级，显示「杭州市 ·
                    // 拱墅区」；手动搜索的没有区级，就只显示市名。
                    weather?.location?.displayName ?? l10n.weatherCityNotSet,
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

/// 一键定位。成功后**留在原地**——那一行的尾随值已经变成新地点，本身就是反馈，
/// 再弹一次是噪音；失败才提示。
Future<void> _locateWeather(BuildContext context, WeatherProvider weather) async {
  // l10n 必须在 await 之前取：await 之后 context 可能已失效。
  final l10n = AppLocalizations.of(context)!;
  final failure = await weather.locateCurrentPosition();
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    showAppToast(
      context,
      message: WeatherLocationFailureLocalizer.message(l10n, failure),
      kind: AppToastKind.warning,
    );
    return;
  }
  // 按网络 IP 估算出来的位置要如实标注：它可能指到运营商网关所在城市，
  // 不能让它冒充真实定位。
  if (weather.lastLocateWasEstimated) {
    showAppToast(context, message: l10n.weatherLocationEstimated);
  }
}
