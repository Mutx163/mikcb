import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/weather_location_failure_localizer.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/weather_city_picker_screen.dart';
import 'package:university_timetable/services/device_location_service.dart';
import 'package:university_timetable/services/weather_preferences.dart';
import 'package:university_timetable/services/weather_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_location_stub.dart';
import '../helpers_test_app.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

const _hangzhou = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

/// 真实结构的候选列表：搜「杭州」会同时返回浙江杭州与四川甘孜的同名村。
Map<String, dynamic> _geocodingPayload() => {
  'results': [
    {
      'name': '杭州',
      'latitude': 30.29365,
      'longitude': 120.16142,
      'country': '中国',
      'admin1': '浙江',
      'timezone': 'Asia/Shanghai',
    },
    {
      'name': '杭州',
      'latitude': 30.06517,
      'longitude': 102.19527,
      'country': '中国',
      'admin1': '四川',
      'timezone': 'Asia/Shanghai',
    },
  ],
};

/// 记录搜索请求的假服务端；[delay] 用来模拟慢响应以验证乱序保护。
class _SearchServer {
  _SearchServer({this.empty = false, this.delay});

  bool empty;
  Duration? delay;
  final List<String> queries = [];

  WeatherService get service => WeatherService(client: _client);

  late final MockClient _client = MockClient((request) async {
    // 只有地理编码请求算「搜索」；provider 初始化时的预报请求不是本测试关注点，
    // 直接 500，免得把空查询词记进 queries。
    if (request.url.host != 'geocoding-api.open-meteo.com') {
      return http.Response('boom', 500);
    }
    final name = request.url.queryParameters['name'] ?? '';
    queries.add(name);
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    final results = empty
        ? <Map<String, dynamic>>[]
        : (_geocodingPayload()['results']! as List<Map<String, dynamic>>);
    return http.Response(
      jsonEncode({'results': results}),
      200,
      headers: _jsonHeaders,
    );
  });
}

Future<WeatherProvider> _provider(
  WeatherService service, {
  WeatherLocation? current,
  DeviceLocationService? locationService,
}) async {
  if (current != null) {
    await WeatherPreferences.saveLocation(current);
  }
  // 必须 initialize：所选城市是 initialize 从 prefs 读进内存的，
  // 不初始化的话 provider.location 一直是 null。
  final provider = WeatherProvider(
    service: service,
    locationService: locationService,
  );
  await provider.initialize();
  return provider;
}

/// 从另一个页面推入选城市页，这样「定位成功后返回上一页」才有得可返。
class _PickerLauncher extends StatelessWidget {
  const _PickerLauncher();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const WeatherCityPickerScreen(),
          ),
        ),
        child: const Text('open-picker'),
      ),
    );
  }
}

Future<void> _pumpPicker(WidgetTester tester, WeatherProvider provider) async {
  await tester.pumpWidget(
    TestApp(
      home: ChangeNotifierProvider<WeatherProvider>.value(
        value: provider,
        child: const WeatherCityPickerScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 输入关键字并跨过 400ms 防抖。
Future<void> _type(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('内容不会被悬浮顶栏盖住，且输入框真实占到尺寸', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    // 这条是回归防线：裸 Column 当正文时，内容会被悬浮顶栏整块盖住——页面看起来
    // 「只有标题、正文空白」。只断言 find.text 命中的话那种坏布局也会通过，
    // 所以必须比几何位置：输入框要落在标题下方，且自身有非零尺寸。
    final fieldRect = tester.getRect(find.byType(HyperosTextField));
    expect(fieldRect.width, greaterThan(0));
    expect(fieldRect.height, greaterThan(0));

    final titleFinder = find.text(l10n.weatherCityPickerTitle);
    var lowestTitleBottom = 0.0;
    for (var i = 0; i < titleFinder.evaluate().length; i++) {
      final bottom = tester.getRect(titleFinder.at(i)).bottom;
      if (bottom > lowestTitleBottom) {
        lowestTitleBottom = bottom;
      }
    }
    expect(lowestTitleBottom, greaterThan(0));
    expect(fieldRect.top, greaterThanOrEqualTo(lowestTitleBottom - 1));
  });

  testWidgets('对照：裸 Column 当正文确实会被顶栏盖住（证明上一条断言有牙）', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    // 故意还原出问题的那种写法（正文是裸 Column，不走 HyperosListView）：
    // 顶栏是悬浮的，不会给正文让位，所以输入框顶边落在标题底边之上。
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          title: Text(l10n.weatherCityPickerTitle),
          child: Column(
            children: [
              HyperosTextField(hint: l10n.weatherCitySearchHint),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fieldRect = tester.getRect(find.byType(HyperosTextField));
    final titleFinder = find.text(l10n.weatherCityPickerTitle);
    var lowestTitleBottom = 0.0;
    for (var i = 0; i < titleFinder.evaluate().length; i++) {
      final bottom = tester.getRect(titleFinder.at(i)).bottom;
      if (bottom > lowestTitleBottom) {
        lowestTitleBottom = bottom;
      }
    }

    expect(fieldRect.top, lessThan(lowestTitleBottom));
  });

  testWidgets('初始状态不发请求、不显示空结果提示', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    expect(server.queries, isEmpty);
    expect(find.text('没有找到匹配的城市'), findsNothing);
  });

  testWidgets('关键字不足两个字符不发请求', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    await _type(tester, '杭');
    expect(server.queries, isEmpty);

    await _type(tester, ' ');
    expect(server.queries, isEmpty);
  });

  testWidgets('跨过防抖后发一次请求，结果带行政区以便区分同名地点', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    await _type(tester, '杭州');

    expect(server.queries, ['杭州']);
    // 两行同名城市，靠行政区区分（find.text('杭州') 还会命中搜索框里的文字，
    // 所以用行政区这一对唯一副标题来断言行数）。
    expect(find.text('浙江 · 中国'), findsOneWidget);
    expect(find.text('四川 · 中国'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('防抖期内连续输入只发最后一次', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    await tester.enterText(find.byType(TextField), '杭');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '杭州');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '杭州市');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(server.queries, ['杭州市']);
  });

  testWidgets('搜到空结果时给出提示', (tester) async {
    final server = _SearchServer(empty: true);
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    await _type(tester, '不存在的城市');

    expect(server.queries, ['不存在的城市']);
    expect(find.text('没有找到匹配的城市'), findsOneWidget);
  });

  testWidgets('慢的旧请求不会覆盖新请求的结果', (tester) async {
    final server = _SearchServer(delay: const Duration(milliseconds: 600));
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    // 第一次搜索发出后不等它回来，立刻改关键字发出第二次。
    await tester.enterText(find.byType(TextField), '杭州');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(find.byType(TextField), '成都');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 两次都发出了，但最终界面必须对应最后一次查询。
    expect(server.queries, ['杭州', '成都']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('点击候选会写入所选城市并返回', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    await _type(tester, '杭州');
    expect(provider.location, isNull);

    await tester.tap(find.text('四川 · 中国'));
    await tester.pumpAndSettle();

    expect(provider.location, isNotNull);
    expect(provider.location!.admin1, '四川');
    expect(provider.location!.latitude, closeTo(30.06517, 1e-6));
  });

  testWidgets('当前城市带选中标记', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(server.service, current: _hangzhou);
    await _pumpPicker(tester, provider);

    await _type(tester, '杭州');

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('候选里没有当前城市时不显示选中标记', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(
      server.service,
      current: const WeatherLocation(
        name: '成都',
        latitude: 30.5728,
        longitude: 104.0668,
      ),
    );
    await _pumpPicker(tester, provider);

    await _type(tester, '杭州');

    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('清空关键字会清掉已有结果', (tester) async {
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    await _type(tester, '杭州');
    expect(find.text('浙江 · 中国'), findsOneWidget);

    await _type(tester, '');
    expect(find.text('浙江 · 中国'), findsNothing);
  });

  testWidgets('没挂 WeatherProvider 时不抛异常', (tester) async {
    await tester.pumpWidget(const TestApp(home: WeatherCityPickerScreen()));
    await tester.pumpAndSettle();
    await _type(tester, '杭州');

    expect(tester.takeException(), isNull);
  });

  testWidgets('顶部有「当前位置」区块，且定位行落在页面标题下方', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    expect(find.text(l10n.weatherSectionCurrentLocation), findsOneWidget);
    expect(find.text(l10n.weatherSectionSearchCity), findsOneWidget);
    expect(find.text(l10n.weatherUseCurrentLocation), findsOneWidget);

    // 与设置子页同一条防线：只断言 find.text 命中抓不到「被悬浮顶栏盖住」，
    // 必须比几何位置。
    final locateRect = tester.getRect(
      find.text(l10n.weatherUseCurrentLocation),
    );
    expect(locateRect.width, greaterThan(0));
    expect(locateRect.height, greaterThan(0));

    final titleFinder = find.text(l10n.weatherCityPickerTitle);
    var lowestTitleBottom = 0.0;
    for (var i = 0; i < titleFinder.evaluate().length; i++) {
      final bottom = tester.getRect(titleFinder.at(i)).bottom;
      if (bottom > lowestTitleBottom) {
        lowestTitleBottom = bottom;
      }
    }
    expect(lowestTitleBottom, greaterThan(0));
    expect(locateRect.top, greaterThanOrEqualTo(lowestTitleBottom - 1));
  });

  testWidgets('定位行排在搜索框上方', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final server = _SearchServer();
    final provider = await _provider(server.service);
    await _pumpPicker(tester, provider);

    final locateTop = tester
        .getRect(find.text(l10n.weatherUseCurrentLocation))
        .top;
    final fieldTop = tester.getRect(find.byType(HyperosTextField)).top;
    expect(locateTop, lessThan(fieldTop));
  });

  testWidgets('点定位行 → 成功 → 返回上一页并换城市', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final server = _SearchServer();
    final provider = await _provider(
      server.service,
      locationService: stubLocationService(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<WeatherProvider>.value(
        value: provider,
        child: const TestApp(home: _PickerLauncher()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-picker'));
    await tester.pumpAndSettle();
    expect(find.byType(WeatherCityPickerScreen), findsOneWidget);

    await tester.tap(find.text(l10n.weatherUseCurrentLocation));
    await tester.pumpAndSettle();

    expect(find.byType(WeatherCityPickerScreen), findsNothing);
    expect(provider.location!.displayName, '杭州市 · 拱墅区');
  });

  testWidgets('定位失败 → 弹提示且留在本页', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final server = _SearchServer();
    final provider = await _provider(
      server.service,
      locationService: stubLocationService(resolvesTo: null),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<WeatherProvider>.value(
        value: provider,
        child: const TestApp(home: _PickerLauncher()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.weatherUseCurrentLocation));
    await tester.pumpAndSettle();

    expect(find.byType(WeatherCityPickerScreen), findsOneWidget);
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

  testWidgets('定位中禁用定位行，期间再点不会发第二次', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final server = _SearchServer();
    final source = StubDeviceLocationSource(delay: const Duration(seconds: 2));
    final provider = await _provider(
      server.service,
      locationService: stubLocationService(source: source),
    );
    await _pumpPicker(tester, provider);

    await tester.tap(find.text(l10n.weatherUseCurrentLocation));
    await tester.pump();
    expect(provider.isLocating, isTrue);
    // 定位中副标题换成「正在定位…」。
    expect(find.text(l10n.weatherLocating), findsOneWidget);

    await tester.tap(
      find.text(l10n.weatherUseCurrentLocation),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(source.positionCalls, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(provider.isLocating, isFalse);
  });
}
