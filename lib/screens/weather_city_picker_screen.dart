import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/weather_location_failure_localizer.dart';
import '../models/weather_forecast.dart';
import '../providers/weather_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

/// 选城市页：搜索 + 结果列表。
///
/// Open-Meteo 的地理编码接口会为「杭州」同时返回浙江杭州与四川甘孜的同名村，
/// 所以每一行都必须带行政区（[WeatherLocation.regionLabel]），只显示城市名
/// 会让用户没法区分。
class WeatherCityPickerScreen extends StatefulWidget {
  const WeatherCityPickerScreen({super.key});

  @override
  State<WeatherCityPickerScreen> createState() =>
      _WeatherCityPickerScreenState();
}

class _WeatherCityPickerScreenState extends State<WeatherCityPickerScreen> {
  /// 输入防抖：每敲一个字就发一次请求会浪费免费额度，也容易让结果乱序。
  static const Duration _debounceDelay = Duration(milliseconds: 400);

  /// 少于两个字符时接口只会返回空结果，直接不发。
  static const int _minQueryLength = 2;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<WeatherLocation> _results = const <WeatherLocation>[];
  bool _searching = false;

  /// 已发出且已返回的查询词；用来区分「还没搜」与「搜了但没结果」。
  String? _settledQuery;

  /// 请求序号：慢的旧请求回来时不能覆盖新请求的结果。
  int _requestSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < _minQueryLength) {
      setState(() {
        _results = const <WeatherLocation>[];
        _settledQuery = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(_debounceDelay, () => _search(trimmed));
  }

  Future<void> _search(String query) async {
    final seq = ++_requestSeq;
    final provider = context.read<WeatherProvider?>();
    final results = provider == null
        ? const <WeatherLocation>[]
        : await provider.searchLocations(query);
    if (!mounted || seq != _requestSeq) {
      return;
    }
    setState(() {
      _results = results;
      _settledQuery = query;
      _searching = false;
    });
  }

  void _select(WeatherProvider provider, WeatherLocation location) {
    unawaited(provider.setLocation(location));
    Navigator.pop(context);
  }

  /// 一键定位。成功后**返回上一页**——与「点选一个城市」一致，回到设置页那一行
  /// 已经显示新地点了，留在搜索页没有意义。
  Future<void> _locate(WeatherProvider provider) async {
    // l10n 必须在 await 之前取：await 之后 context 可能已失效。
    final l10n = AppLocalizations.of(context)!;
    final failure = await provider.locateCurrentPosition();
    if (!mounted) {
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
    // 不能让它冒充真实定位。标注之后照常返回上一页——它仍然是可用结果。
    if (provider.lastLocateWasEstimated) {
      showAppToast(context, message: l10n.weatherLocationEstimated);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<WeatherProvider?>();
    final locating = provider?.isLocating ?? false;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.weatherCityPickerTitle),
      // 键盘弹出时把内容顶上去，否则搜索结果会被输入法盖住。
      resizeToAvoidBottomInset: true,
      child: HyperosListView(
        pageStorageKey: const PageStorageKey<String>('weather-city-picker'),
        children: [
          // 定位入口排在搜索之前：它是「我不挑，就用我在的地方」那条更短的路。
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.weatherSectionCurrentLocation),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.my_location_rounded,
                title: l10n.weatherUseCurrentLocation,
                subtitle: locating
                    ? l10n.weatherLocating
                    : provider?.location?.displayName,
                // 定位中禁用（onTap 为 null 时该行变灰且不画箭头）。
                onTap: provider == null || locating
                    ? null
                    : () => unawaited(_locate(provider)),
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.weatherSectionSearchCity),
          HyperosTextField(
            controller: _controller,
            hint: l10n.weatherCitySearchHint,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
          ),
          ..._buildResults(l10n, provider),
        ],
      ),
    );
  }

  /// 结果区。
  ///
  /// 必须走 `HyperosSubpage` + [HyperosListView] 这一套，不能用裸 `Column`：
  /// 顶栏是**悬浮**在内容之上的，只有 [HyperosListView] 会把顶栏占用的高度算成
  /// 顶部内边距（`HyperosBlurredHeaderScope.insetOf`），裸 Column 的内容会被
  /// 顶栏整块盖住——表现就是「页面只有标题、正文空白」。
  /// 同理不能用惰性 `ListView.builder`：那会在滚动时回收输入框。
  List<Widget> _buildResults(
    AppLocalizations l10n,
    WeatherProvider? provider,
  ) {
    if (_searching) {
      return const [
        SizedBox(height: 28),
        Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      ];
    }

    // 还没搜过：不显示任何提示，等着用户输入。
    if (_settledQuery == null) {
      return const [];
    }

    if (_results.isEmpty) {
      return [HyperosSectionDescription(text: l10n.weatherCitySearchEmpty)];
    }

    return [
      const SizedBox(height: 4),
      HyperosListGroup(
        children: [
          for (final location in _results)
            _WeatherCityOption(
              location: location,
              selected: provider?.location?.isSamePlaceAs(location) ?? false,
              onTap: provider == null
                  ? null
                  : () => _select(provider, location),
            ),
        ],
      ),
    ];
  }
}

/// 单个城市候选：城市名 + 行政区（用于区分同名地点）+ 选中标记。
///
/// 用与设置行同一套行壳，保证行高与左右内边距跟其他列表行对齐。
class _WeatherCityOption extends StatelessWidget {
  const _WeatherCityOption({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final WeatherLocation location;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final region = location.regionLabel;
    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: HyperosColors.card(context),
      highlightColor: HyperosColors.rowHighlight(context),
      child: hyperosListRowShell(
        padding: hyperosRowPadding(context),
        minHeight: HyperosTokens.listRowTwoLineMinHeight,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HyperosTypography.listTitle(context),
                  ),
                  const SizedBox(height: HyperosTokens.titleCaptionGap),
                  Text(
                    region,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 10),
              Icon(
                Icons.check_rounded,
                size: 20,
                color: HyperosColors.primary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
