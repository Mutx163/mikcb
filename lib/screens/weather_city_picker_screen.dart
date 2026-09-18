import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/weather_forecast.dart';
import '../providers/weather_provider.dart';
import '../ui/hyperos/hyperos.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<WeatherProvider?>();

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.weatherCityPickerTitle),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: HyperosTextField(
              controller: _controller,
              hint: l10n.weatherCitySearchHint,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(
            child: _buildResults(context, l10n, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AppLocalizations l10n,
    WeatherProvider? provider,
  ) {
    if (_searching) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    final settledQuery = _settledQuery;
    if (settledQuery == null) {
      return const SizedBox.shrink();
    }

    if (_results.isEmpty) {
      return _buildNotice(context, l10n.weatherCitySearchEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final location = _results[index];
        final selected =
            provider?.location?.isSamePlaceAs(location) ?? false;
        return _WeatherCityOption(
          location: location,
          selected: selected,
          onTap: provider == null
              ? null
              : () => _select(provider, location),
        );
      },
    );
  }

  Widget _buildNotice(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 单个城市候选：城市名 + 行政区（用于区分同名地点）+ 选中标记。
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
    final theme = Theme.of(context);
    final region = location.regionLabel;
    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: HyperosColors.card(context),
      highlightColor: HyperosColors.rowHighlight(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HyperosTypography.listTitle(context),
                  ),
                  if (region.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      region,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 10),
              Icon(
                Icons.check_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
