import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/weather_location_failure_localizer.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/screens/weather_city_picker_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/device_location_service.dart';
import 'package:university_timetable/services/weather_preferences.dart';
import 'package:university_timetable/services/weather_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_location_stub.dart';
import '../helpers_test_app.dart';

const _hangzhou = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

/// 设置首页要能滚到天气入口、点开子页。这里只需要 provider 挂上，不关心预报内容。
WeatherProvider _weatherProvider({DeviceLocationService? locationService}) {
  return WeatherProvider(
    service: WeatherService(
      client: MockClient((_) async => http.Response('boom', 500)),
    ),
    locationService: locationService,
  );
}

void _seedPrefs({bool withCity = true, bool enabled = true}) {
  final now = DateTime(2026, 4, 12);
  final settings = TimetableSettings.defaults();
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: settings,
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
    WeatherPreferences.enabledKey: enabled,
    if (withCity) WeatherPreferences.locationKey: _hangzhou.toJsonString(),
  });
}

Future<void> _pumpUntilSettled(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// 设置首页很长，天气入口在「显示与外观」组里，先滚到它。
Future<void> scrollToWeatherEntry(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final homeList = find.byType(HyperosListView).first;
  await tester.scrollUntilVisible(
    find.text(l10n.weatherSettingsEntryTitle),
    200,
    scrollable: find
        .descendant(of: homeList, matching: find.byType(Scrollable))
        .first,
  );
}

/// 滚到入口并点进天气子页。
Future<void> openWeatherSubpage(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await scrollToWeatherEntry(tester, l10n);
  await tester.tap(find.text(l10n.weatherSettingsEntryTitle));
  await _pumpUntilSettled(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/live');

  setUp(() {
    StorageService().resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, null);
  });

  Future<WeatherProvider> pumpSettings(
    WidgetTester tester, {
    bool withCity = true,
    bool enabled = true,
    DeviceLocationService? locationService,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    _seedPrefs(withCity: withCity, enabled: enabled);
    final timetable = await createInitializedTestProvider(tester);
    final weather = _weatherProvider(locationService: locationService);
    await tester.runAsync(weather.initialize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: timetable),
          ChangeNotifierProvider.value(value: weather),
        ],
        child: const TestApp(home: TimetableSettingsScreen()),
      ),
    );
    await _pumpUntilSettled(tester);
    return weather;
  }

  testWidgets('设置首页「显示与外观」里有天气入口，并显示当前城市', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester);

    await scrollToWeatherEntry(tester, l10n);

    expect(find.text(l10n.weatherSettingsEntryTitle), findsOneWidget);
    expect(find.text('杭州'), findsOneWidget);
  });

  testWidgets('未设城市时入口显示「未设置」', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester, withCity: false);

    await scrollToWeatherEntry(tester, l10n);

    expect(find.text(l10n.weatherCityNotSet), findsOneWidget);
  });

  testWidgets('点开天气子页：开关、城市行、覆盖范围与数据来源都在', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester);

    await openWeatherSubpage(tester, l10n);

    // 标题在磨砂栏与大标题各渲染一次，故用 findsWidgets。
    expect(find.text(l10n.weatherSettingsTitle), findsWidgets);
    expect(find.text(l10n.weatherEnableTitle), findsOneWidget);
    expect(find.text(l10n.weatherEnableSubtitle), findsOneWidget);
    expect(find.text(l10n.weatherCityLabel), findsOneWidget);
    expect(find.text('杭州'), findsOneWidget);
    expect(find.text(l10n.weatherCoverageNote), findsOneWidget);
    expect(find.text(l10n.weatherAttribution), findsOneWidget);
    // 开关初始为开。
    final switchTile = tester.widget<HyperosSwitchTile>(
      find.byType(HyperosSwitchTile),
    );
    expect(switchTile.value, isTrue);
  });

  testWidgets('子页内容不会被悬浮顶栏盖住', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester);

    await openWeatherSubpage(tester, l10n);

    // 与选城市页同一条防线：只断言 find.text 命中是不够的，正文被悬浮顶栏
    // 整块盖住时那些断言依然会通过。这里比几何位置。
    final switchRect = tester.getRect(find.byType(HyperosSwitchTile));
    expect(switchRect.width, greaterThan(0));
    expect(switchRect.height, greaterThan(0));

    final titleFinder = find.text(l10n.weatherSettingsTitle);
    var lowestTitleBottom = 0.0;
    for (var i = 0; i < titleFinder.evaluate().length; i++) {
      final bottom = tester.getRect(titleFinder.at(i)).bottom;
      if (bottom > lowestTitleBottom) {
        lowestTitleBottom = bottom;
      }
    }
    expect(lowestTitleBottom, greaterThan(0));
    expect(switchRect.top, greaterThanOrEqualTo(lowestTitleBottom - 1));
  });

  testWidgets('两个区块各有区块标题，且之间留出区块间距', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester);

    await openWeatherSubpage(tester, l10n);

    // IA 规范不许无名分组：每个区块都要有自己的标题。
    expect(find.text(l10n.weatherSectionDisplayTitle), findsOneWidget);
    expect(find.text(l10n.weatherSectionSourceTitle), findsOneWidget);

    // 只断言「标题存在」还不够——当初两块卡片就是贴在一起的。这里量间距：
    // 相邻两组之间必须留出至少一个 HyperosSectionGap。
    final subpageList = find.byType(HyperosListView).last;
    final groups = find
        .descendant(of: subpageList, matching: find.byType(HyperosListGroup))
        .evaluate()
        .toList();
    expect(groups.length, 2, reason: '显示 / 数据来源 两个区块');
    final firstBottom = tester
        .getRect(
          find
              .descendant(
                of: subpageList,
                matching: find.byType(HyperosListGroup),
              )
              .at(0),
        )
        .bottom;
    final secondTop = tester
        .getRect(
          find
              .descendant(
                of: subpageList,
                matching: find.byType(HyperosListGroup),
              )
              .at(1),
        )
        .top;
    expect(
      secondTop - firstBottom,
      greaterThanOrEqualTo(HyperosTokens.sectionGap - 1),
    );
  });

  testWidgets('说明文字挂在所属区块之后（覆盖范围在显示组下、署名在数据来源组下）', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester);

    await openWeatherSubpage(tester, l10n);

    final coverageY = tester.getRect(find.text(l10n.weatherCoverageNote)).top;
    final sourceLabelY = tester
        .getRect(find.text(l10n.weatherSectionSourceTitle))
        .top;
    final attributionY = tester.getRect(find.text(l10n.weatherAttribution)).top;

    // 覆盖范围说明在「显示」组与「数据来源」组标题之间。
    expect(coverageY, lessThan(sourceLabelY));
    // 署名在「数据来源」组标题之后。
    expect(attributionY, greaterThan(sourceLabelY));
  });

  testWidgets('子页里拨动开关会写进 WeatherProvider', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final weather = await pumpSettings(tester);

    await openWeatherSubpage(tester, l10n);

    expect(weather.enabled, isTrue);
    await tester.tap(find.byType(HyperosSwitchTile));
    await _pumpUntilSettled(tester);

    expect(weather.enabled, isFalse);
    expect(await WeatherPreferences.isEnabled(), isFalse);
  });

  testWidgets('点城市行打开选城市页', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester);

    await openWeatherSubpage(tester, l10n);

    await tester.tap(find.text(l10n.weatherCityLabel));
    await _pumpUntilSettled(tester);

    expect(find.byType(WeatherCityPickerScreen), findsOneWidget);
    expect(find.text(l10n.weatherCityPickerTitle), findsWidgets);
  });

  testWidgets('「数据来源」区块里「使用当前位置」排在城市行之前', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    await pumpSettings(tester);
    await openWeatherSubpage(tester, l10n);

    // 只断言文字存在不够——顺序错了照样命中。这里比纵向次序：
    // 区块标题 → 使用当前位置 → 城市。
    final sourceLabel = tester.getRect(
      find.text(l10n.weatherSectionSourceTitle),
    );
    final useCurrent = tester.getRect(
      find.text(l10n.weatherUseCurrentLocation),
    );
    final city = tester.getRect(find.text(l10n.weatherCityLabel));

    expect(useCurrent.top, greaterThan(sourceLabel.bottom - 1));
    expect(useCurrent.top, lessThan(city.top));
  });

  testWidgets('点「使用当前位置」→ 成功，城市行变成「市 · 区」', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final weather = await pumpSettings(
      tester,
      locationService: stubLocationService(),
    );
    await openWeatherSubpage(tester, l10n);
    expect(find.text('杭州'), findsOneWidget);

    await tester.tap(find.text(l10n.weatherUseCurrentLocation));
    await _pumpUntilSettled(tester);

    expect(weather.location!.displayName, '杭州市 · 拱墅区');
    expect(find.text('杭州市 · 拱墅区'), findsOneWidget);
    expect(weather.lastLocateFailure, isNull);
  });

  testWidgets('定位失败 → 弹提示，且原城市不动', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final weather = await pumpSettings(
      tester,
      // resolvesTo 为 null 模拟「定到了坐标但解析不出地名」。
      locationService: stubLocationService(resolvesTo: null),
    );
    await openWeatherSubpage(tester, l10n);

    await tester.tap(find.text(l10n.weatherUseCurrentLocation));
    await _pumpUntilSettled(tester);

    expect(weather.lastLocateFailure, DeviceLocationFailure.addressUnavailable);
    expect(weather.location!.name, '杭州');
    expect(
      find.text(
        WeatherLocationFailureLocalizer.message(
          l10n,
          DeviceLocationFailure.addressUnavailable,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('定位中该行禁用并显示进度，期间再点不会发第二次', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final source = StubDeviceLocationSource(delay: const Duration(seconds: 2));
    final weather = await pumpSettings(
      tester,
      locationService: stubLocationService(source: source),
    );
    await openWeatherSubpage(tester, l10n);

    await tester.tap(find.text(l10n.weatherUseCurrentLocation));
    await tester.pump();

    expect(weather.isLocating, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 定位中再点一次：入口已禁用，不该再发一次定位。
    await tester.tap(
      find.text(l10n.weatherUseCurrentLocation),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(source.positionCalls, 1);

    await tester.pump(const Duration(seconds: 3));
    await _pumpUntilSettled(tester);
    expect(weather.isLocating, isFalse);
    expect(weather.location!.displayName, '杭州市 · 拱墅区');
  });
}
