import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/weather_logic.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/services/weather_preferences.dart';
import 'package:university_timetable/services/weather_service.dart';
import 'package:university_timetable/widgets/course_weather_display.dart';
import 'package:university_timetable/widgets/day_agenda_info_row.dart';
import 'package:university_timetable/widgets/day_course_weather_row.dart';

import '../helpers_test_app.dart';
import '../helpers_weather.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

const _hangzhou = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

/// 造一份窗口覆盖「今天 0 点起 96 小时」的响应。
///
/// 逐小时天气码固定为 61（小雨）、概率固定 60，所以断言可以写死期望文案。
Map<String, dynamic> _payload() {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  String two(int value) => value.toString().padLeft(2, '0');
  return {
    'latitude': _hangzhou.latitude,
    'longitude': _hangzhou.longitude,
    'timezone': 'Asia/Shanghai',
    'hourly': {
      'time': [
        for (var hour = 0; hour < 96; hour++)
          () {
            final time = start.add(Duration(hours: hour));
            return '${time.year}-${two(time.month)}-${two(time.day)}'
                'T${two(time.hour)}:00';
          }(),
      ],
      'temperature_2m': [for (var i = 0; i < 96; i++) 23.0],
      'precipitation_probability': [for (var i = 0; i < 96; i++) 60],
      'precipitation': [for (var i = 0; i < 96; i++) 0.5],
      'snowfall': [for (var i = 0; i < 96; i++) 0.0],
      'weather_code': [for (var i = 0; i < 96; i++) 61],
    },
  };
}

/// 拉起一个已经拿到预报的 provider（HTTP 与 prefs 都要跳出 FakeAsync）。
Future<WeatherProvider> _readyProvider(
  WidgetTester tester, {
  bool enabled = true,
}) async {
  late WeatherProvider provider;
  await tester.runAsync(() async {
    await WeatherPreferences.setEnabled(enabled);
    await WeatherPreferences.saveLocation(_hangzhou);
    provider = WeatherProvider(
      service: WeatherService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(_payload()), 200, headers: _jsonHeaders),
        ),
      ),
    );
    await provider.initialize();
    await provider.ensureFresh();
  });
  return provider;
}

DateTime get _today => DateTime.now();

String _hhmm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

Widget _wrap(
  WeatherProvider provider, {
  DateTime? date,
  bool visible = true,
  bool showPhenomenon = true,
  bool showTemperature = true,
  bool showProbability = false,
}) {
  return TestApp(
    home: ChangeNotifierProvider<WeatherProvider>.value(
      value: provider,
      child: DayCourseWeatherRow(
        date: date ?? _today,
        startTime: _hhmm(8, 0),
        endTime: _hhmm(9, 35),
        ink: Colors.white,
        visible: visible,
        showPhenomenon: showPhenomenon,
        showTemperature: showTemperature,
        showProbability: showProbability,
      ),
    ),
  );
}

/// 这一行（含自带的上间距）的布局高度。
///
/// 量的是根部那个 `Padding`：它是 `SingleChildRenderObjectWidget`，所以量到的
/// 就是这一行自己的高度（`Padding` 是普通的 `EdgeInsets`，行高由里面的图标与文字
/// 撑开）。`Visibility(maintainSize)` 不改布局，所以预留位与真天气行量出来的数
/// 应当完全相等——不相等就意味着数据到达时卡片还会顶一下。
double _rowHeight(WidgetTester tester) => tester
    .getSize(
      find.descendant(
        of: find.byType(DayCourseWeatherRow),
        matching: find.byType(Padding),
      ),
    )
    .height;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('没挂 WeatherProvider 时不抛异常且不渲染', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: DayCourseWeatherRow(
          date: _today,
          startTime: '08:00',
          endTime: '09:35',
          ink: Colors.white,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(DayAgendaInfoRow), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('visible 为 false 时不渲染', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(_wrap(provider, visible: false));
    await tester.pump();

    expect(find.byType(DayAgendaInfoRow), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('date 为 null 时不渲染', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider<WeatherProvider>.value(
          value: provider,
          child: const DayCourseWeatherRow(
            date: null,
            startTime: '08:00',
            endTime: '09:35',
            ink: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DayAgendaInfoRow), findsNothing);
  });

  testWidgets('有数据时渲染「现象 · 温度」（默认内容组合）', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('小雨 · 23°'), findsOneWidget);
    expect(find.byType(DayAgendaInfoRow), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('勾上降水概率才出现百分号', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(_wrap(provider, showProbability: true));
    await tester.pump();

    expect(find.text('小雨 · 23° · 60%'), findsOneWidget);
  });

  testWidgets('关掉现象只剩温度：文字只剩温度，图标换成温度计', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(_wrap(provider, showPhenomenon: false));
    await tester.pump();

    expect(find.text('23°'), findsOneWidget);
    // 图标由「第一个勾上的项目」（这里是温度）认领，不再是现象那一族的雨滴。
    expect(find.byIcon(Icons.thermostat), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
  });

  testWidgets('三个内容项全关时整行消失（不留半格空隙）', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(
      _wrap(
        provider,
        showPhenomenon: false,
        showTemperature: false,
      ),
    );
    await tester.pump();

    expect(find.byType(DayAgendaInfoRow), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DayCourseWeatherRow),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
  });

  testWidgets('图标与该时段的现象对应', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, weatherIconFor(WeatherCategory.lightRain));
    expect(icon.icon, Icons.water_drop_outlined);
  });

  testWidgets('自带的上间距与课卡其他信息行一致', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    final padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(DayCourseWeatherRow),
        matching: find.byType(Padding),
      ),
    );
    expect(padding.padding, const EdgeInsets.only(top: 5.5));
  });

  testWidgets('概率偏低时不渲染百分号', (tester) async {
    late WeatherProvider provider;
    await tester.runAsync(() async {
      await WeatherPreferences.setEnabled(true);
      await WeatherPreferences.saveLocation(_hangzhou);
      final payload = _payload();
      (payload['hourly']! as Map<String, dynamic>)['precipitation_probability'] =
          [for (var i = 0; i < 96; i++) 20];
      provider = WeatherProvider(
        service: WeatherService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(payload),
              200,
              headers: _jsonHeaders,
            ),
          ),
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();
    });

    await tester.pumpWidget(_wrap(provider, showProbability: true));
    await tester.pump();

    expect(find.text('小雨 · 23°'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('预报窗口之外的日子不渲染', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(
      _wrap(provider, date: _today.add(const Duration(days: 40))),
    );
    await tester.pump();

    expect(find.byType(DayAgendaInfoRow), findsNothing);
  });

  testWidgets('开关关闭时不渲染', (tester) async {
    final provider = await _readyProvider(tester, enabled: false);
    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.byType(DayAgendaInfoRow), findsNothing);
  });

  testWidgets('时间串畸形时不渲染', (tester) async {
    final provider = await _readyProvider(tester);
    await tester.pumpWidget(
      TestApp(
        home: ChangeNotifierProvider<WeatherProvider>.value(
          value: provider,
          child: DayCourseWeatherRow(
            date: _today,
            startTime: 'oops',
            endTime: '09:35',
            ink: Colors.white,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DayAgendaInfoRow), findsNothing);
  });

  testWidgets('无数据时不留半格空隙（自身完全消失）', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: DayCourseWeatherRow(
          date: null,
          startTime: '08:00',
          endTime: '09:35',
          ink: Colors.white,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(DayCourseWeatherRow),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('预报没到时先留一行的空位：高度不变、什么都不画', (tester) async {
    // 用户反馈的那个窗口：刚进 App，预报还在路上。数据到达时卡片**不能**长高一格
    // 把下方的课卡顶一下（那就是「闪一下」）。所以留位必须在，且必须与真天气行等高。
    final pending = await pendingWeatherProvider(tester);

    await tester.pumpWidget(_wrap(pending.provider));
    await tester.pump();

    // 位置留住了：一个 Padding 顶着（连自带的上间距一起）。
    final reserved = _rowHeight(tester);
    expect(reserved, greaterThan(0));
    // 但什么都不画：只有占位图标，没有「现象 · 温度」这样的文字。
    expect(find.byIcon(weatherPlaceholderIcon), findsOneWidget);
    expect(find.textContaining('°'), findsNothing);

    await pending.awaitArrival(tester);
    expect(find.text('小雨 · 23°'), findsOneWidget);
    // 这条就是本次改动的全部意义：内容换了几何没动。
    expect(_rowHeight(tester), reserved);
  });

  testWidgets('天气没开 / 失败退避中不留位（空位会变成永久空行）', (tester) async {
    final pending = await pendingWeatherProvider(tester, enabled: false);

    await tester.pumpWidget(_wrap(pending.provider));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(DayCourseWeatherRow),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
    // 天气总开关关着 → provider 压根不发请求，没有「等它到货」这回事。
  });
}
