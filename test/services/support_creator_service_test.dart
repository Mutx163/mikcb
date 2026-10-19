import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_timetable/services/support_creator_service.dart';

void main() {
  test(
    'fetchDonors 配了镜像前缀也不请求镜像：捐赠名单只认官方直连',
    () async {
      // 2026-10-19 信任根收紧：名单是展示型 JSON，没有摘要校验链，镜像能整份
      // 替换它。这里钉的是「镜像即便能返回数据，也不会被请求到」。
      final requestedHosts = <String>[];
      final client = MockClient((request) async {
        requestedHosts.add(request.url.host);
        if (request.url.host == 'mirror.example.com') {
          return http.Response(
            jsonEncode({
              'donors': [
                {'name': 'Mirror Donor'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'donors': [
              {'name': 'Raw Donor'},
            ],
          }),
          200,
        );
      });

      final service = SupportCreatorService(client: client);
      final data = await service.fetchDonors(
        mirrorUrlPrefix: 'https://mirror.example.com/',
      );

      expect(data.donors.single.name, 'Raw Donor');
      expect(requestedHosts, isNot(contains('mirror.example.com')));
    },
  );

  test(
    'fetchDonors 直连全失败时如实失败，不会退到镜像拿一份「能显示」的名单',
    () async {
      final requestedHosts = <String>[];
      final client = MockClient((request) async {
        requestedHosts.add(request.url.host);
        if (request.url.host == 'mirror.example.com') {
          return http.Response(
            jsonEncode({
              'donors': [
                {'name': 'Mirror Donor'},
              ],
            }),
            200,
          );
        }
        return http.Response('unavailable', 503);
      });

      final service = SupportCreatorService(client: client);
      await expectLater(
        service.fetchDonors(mirrorUrlPrefix: 'https://mirror.example.com/'),
        throwsA(isA<Exception>()),
      );
      expect(requestedHosts, isNot(contains('mirror.example.com')));
    },
  );

  test('fetchDonors decodes utf8 donor names correctly', () async {
    final body = utf8.encode(
      jsonEncode({
        'donors': [
          {'name': '小明同学'},
        ],
      }),
    );
    final client = MockClient((request) async {
      return http.Response.bytes(
        body,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = SupportCreatorService(client: client);
    final data = await service.fetchDonors();

    expect(data.donors.single.name, '小明同学');
  });

  test('SupportDonorData.fromJson sorts donors by date descending (newest first)', () {
    final json = {
      'title': '鸣谢名单',
      'donors': [
        {'name': 'Old Donor', 'date': '2026-03-28 10:06:23'},
        {'name': 'Middle Donor', 'date': '2026-05-26 16:17:57'},
        {'name': 'Newest Donor', 'date': '2026-08-20 19:30:23'},
        {'name': 'No Date Donor'},
      ],
    };

    final data = SupportDonorData.fromJson(json);

    expect(
      data.donors.map((e) => e.name).toList(),
      ['Newest Donor', 'Middle Donor', 'Old Donor', 'No Date Donor'],
    );
  });

  test('SupportDonorData.fromJson 解析 subtitleNote 留言格式说明', () {
    final data = SupportDonorData.fromJson({
      'subtitle': '感谢各位朋友的支持！',
      'subtitleNote': '留言请以（昵称：留言）格式填写。',
      'donors': [
        {'name': 'A'},
      ],
    });

    expect(data.subtitle, '感谢各位朋友的支持！');
    expect(data.subtitleNote, '留言请以（昵称：留言）格式填写。');
  });

  test('SupportDonorData.fromJson 兼容无 subtitleNote 的旧 JSON（字段为 null，UI 隐藏提示条）', () {
    final data = SupportDonorData.fromJson({
      'subtitle': '旧版文案',
      'donors': [
        {'name': 'A'},
      ],
    });

    expect(data.subtitleNote, isNull);
  });

  test(
    'fetchDonors 下载渠道选 GitCode（preferGitCode）时优先命中 GitCode contents API（base64 解码）',
    () async {
      final envelope = jsonEncode({
        'encoding': 'base64',
        'content': base64Encode(
          utf8.encode(
            jsonEncode({
              'donors': [
                {'name': 'GitCode Donor'},
              ],
            }),
          ),
        ),
      });
      final requestedHosts = <String>[];
      final client = MockClient((request) async {
        requestedHosts.add(request.url.host);
        if (request.url.host == 'api.gitcode.com') {
          return http.Response(
            envelope,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('unavailable', 503);
      });

      final service = SupportCreatorService(client: client);
      final data = await service.fetchDonors(preferGitCode: true);

      expect(data.donors.single.name, 'GitCode Donor');
      // 主候选先行：GitCode 成功时不应再请求 GitHub raw / 镜像候选。
      expect(requestedHosts, ['api.gitcode.com']);
    },
  );

  test('fetchDonors preferGitCode 时 GitCode 失败自动回退 GitHub raw', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'api.gitcode.com') {
        return http.Response('not found', 404);
      }
      return http.Response(
        jsonEncode({
          'donors': [
            {'name': 'Fallback Donor'},
          ],
        }),
        200,
      );
    });

    final service = SupportCreatorService(client: client);
    final data = await service.fetchDonors(preferGitCode: true);

    expect(data.donors.single.name, 'Fallback Donor');
  });

  test('fetchDonors 未选 preferGitCode 时不会请求 GitCode 候选', () async {
    final requestedHosts = <String>[];
    final client = MockClient((request) async {
      requestedHosts.add(request.url.host);
      if (request.url.host == 'api.gitcode.com') {
        return http.Response(
          jsonEncode({
            'donors': [
              {'name': 'ShouldNotWin'},
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'donors': [
            {'name': 'Plain Donor'},
          ],
        }),
        200,
      );
    });

    final service = SupportCreatorService(client: client);
    final data = await service.fetchDonors();

    expect(data.donors.single.name, 'Plain Donor');
    expect(requestedHosts, isNot(contains('api.gitcode.com')));
  });
}
