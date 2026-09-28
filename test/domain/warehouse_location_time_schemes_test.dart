import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_location_time_schemes.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 真实数据：CQCST 的作息文件与适配脚本里的四套作息必须一致，否则 App 侧
/// 「用脚本选中的那套反推校区」就永远判不出来。
///
/// 用真文件而不是抄一份进测试，是因为这个一致性正是要守住的东西 —— 抄一份的
/// 测试只会验证自己。仓不在本机时（App 的 CI）整组跳过；权威检查放在仓库侧
/// `tests/test_qingyu_only_isolation.py`，那里 CI 一定会跑。
const String _repoPath = r'C:\cursor\qingyu_warehouse';

File? _repoFile(String relative) {
  final file = File('$_repoPath\\$relative');
  return file.existsSync() ? file : null;
}

Map<String, dynamic> _loadCqcstSchemes() =>
    jsonDecode(
          _repoFile('qingyu_only\\CQCST\\time_schemes.json')!.readAsStringSync(),
        )
        as Map<String, dynamic>;

/// 数据文件的基线 = 唯一没有覆盖、也就是兜底的那一套的节次。
QingyuOnlyTimeScheme _baselineOf(QingyuOnlyTimeSchemes parsed) {
  for (final campus in parsed.campuses) {
    for (final scheme in campus.schemes) {
      if (scheme.isFallback) {
        return scheme;
      }
    }
  }
  throw StateError('数据文件里没有兜底作息，解析器本该报错');
}

void main() {
  final dataFile = _repoFile('qingyu_only\\CQCST\\time_schemes.json');
  final scriptFile = _repoFile('resources\\CQCST\\cqcst_01.js');
  final skipWithoutRepo = dataFile == null || scriptFile == null
      ? '教务适配仓不在本机；该一致性由仓库侧 tests/ 守住'
      : null;

  group('真实数据', () {
    test('CQCST 的作息文件能被解析出两校区各两套', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse(_loadCqcstSchemes());
      expect(parsed.campuses, hasLength(2));
      for (final campus in parsed.campuses) {
        expect(campus.schemes, hasLength(2));
        expect(
          campus.schemes.where((scheme) => scheme.isFallback),
          hasLength(1),
          reason: '${campus.id} 必须恰好一套兜底作息',
        );
        // 13 节，全部有效且不倒挂。
        for (final scheme in campus.schemes) {
          expect(scheme.sections, hasLength(13));
        }
      }
    }, skip: skipWithoutRepo);

    test('四套作息互不相同（否则分流毫无意义）', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse(_loadCqcstSchemes());
      final fingerprints = <String>{};
      for (final campus in parsed.campuses) {
        for (final scheme in campus.schemes) {
          fingerprints.add(
            scheme.sections.map((s) => '${s.startTime}-${s.endTime}').join(','),
          );
        }
      }
      expect(fingerprints, hasLength(4), reason: '四套应当两两不同');
    }, skip: skipWithoutRepo);

    test('数据文件与脚本必须对得上，否则「不额外问用户」整个设计失效', () {
      // 这是「不额外问用户」的地基：App 靠逐节比对脚本下发的节次时间反推校区。
      // 两边一旦漂移，用户在专属条目里选了作息却判不出校区，功能静默退回脚本
      // 那套全局作息，界面上看不出任何异常。
      //
      // 脚本的形状是「13 节公共表（第 3、4 节留 null）+ 每套只写第 3、4 节」，
      // 所以这里分别核对两半，而不是把脚本的拼装逻辑在 Dart 里重写一遍
      //（重写等于把要抓的漂移也抄一份）。
      final source = scriptFile!.readAsStringSync();
      final parsed = QingyuOnlyTimeSchemesLogic.parse(_loadCqcstSchemes());
      final baseline = _baselineOf(parsed)
          .sections
          .map((s) => '${s.startTime}-${s.endTime}')
          .toList();

      const tableStart = 'const SCHOOL_COMMON_TIME_SLOTS = [';
      final tableFrom = source.indexOf(tableStart) + tableStart.length;
      final tableBody = source.substring(
        tableFrom,
        source.indexOf('];', tableFrom),
      );
      final entries = <String?>[];
      for (final m in RegExp(
        r'\["(\d{1,2}:\d{2})",\s*"(\d{1,2}:\d{2})"\]|\bnull\b',
      ).allMatches(tableBody)) {
        entries.add(m.group(1) == null ? null : '${m.group(1)}-${m.group(2)}');
      }
      expect(entries, hasLength(13));
      // 第 3、4 节刻意留空，由每套自己给 —— 这也正是数据文件用 overrides 表达
      // 它们的原因。若脚本改成写死第 3、4 节，这条会红，提示两边的表达方式要
      // 一起改。
      expect(entries[2], isNull);
      expect(entries[3], isNull);
      for (var i = 0; i < entries.length; i++) {
        final fromScript = entries[i];
        if (fromScript == null) {
          continue;
        }
        expect(
          baseline[i],
          fromScript,
          reason: '第 ${i + 1} 节与脚本不一致',
        );
      }

      final scriptPairs = RegExp(
        r'third:\s*\["(\d{1,2}:\d{2})",\s*"(\d{1,2}:\d{2})"\],'
        r'\s*fourth:\s*\["(\d{1,2}:\d{2})",\s*"(\d{1,2}:\d{2})"\]',
      )
          .allMatches(source)
          .map(
            (m) => '${m.group(1)}-${m.group(2)}|${m.group(3)}-${m.group(4)}',
          )
          .toSet();
      expect(scriptPairs, hasLength(4));
      final dataPairs = <String>{};
      for (final campus in parsed.campuses) {
        for (final scheme in campus.schemes) {
          dataPairs.add(
            '${scheme.sections[2].startTime}-${scheme.sections[2].endTime}|'
            '${scheme.sections[3].startTime}-${scheme.sections[3].endTime}',
          );
        }
      }
      expect(dataPairs, scriptPairs);
    }, skip: skipWithoutRepo);

    test('用脚本那一套反推，能拿回正确的校区', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse(_loadCqcstSchemes());
      for (final campus in parsed.campuses) {
        for (final scheme in campus.schemes) {
          expect(
            parsed.campusForSections(scheme.sections)?.id,
            campus.id,
            reason: '用「${scheme.name}」反推应拿回 ${campus.id}',
          );
        }
      }
    }, skip: skipWithoutRepo);
  });

  group('campusForSections', () {
    Map<String, dynamic> twoCampuses() => {
          'version': 1,
          'sections': {
            '1': {'startTime': '08:20', 'endTime': '09:05'},
            '2': {'startTime': '09:15', 'endTime': '10:00'},
          },
          'campuses': [
            {
              'id': 'a',
              'name': 'A 校区',
              'schemes': [
                {'name': 'A · 其他'},
                {
                  'name': 'A · 主楼',
                  'keywords': [
                    {'pattern': 'A', 'mode': 'prefix'}
                  ],
                  'overrides': {
                    '2': {'startTime': '09:20', 'endTime': '10:05'}
                  },
                },
              ],
            },
            {
              'id': 'b',
              'name': 'B 校区',
              'schemes': [
                {
                  'name': 'B · 其他',
                  'overrides': {
                    '2': {'startTime': '09:25', 'endTime': '10:10'}
                  },
                }
              ],
            },
          ],
        };

    test('逐节完全相同才算命中', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse(twoCampuses());
      // A·其他 的节次就是基线。
      expect(
        parsed.campusForSections([
          const SectionTime(startTime: '08:20', endTime: '09:05'),
          const SectionTime(startTime: '09:15', endTime: '10:00'),
        ])?.id,
        'a',
      );
      // 只差一节就对不上，不猜。
      expect(
        parsed.campusForSections([
          const SectionTime(startTime: '08:20', endTime: '09:05'),
          const SectionTime(startTime: '09:16', endTime: '10:00'),
        ]),
        isNull,
      );
      // 节数不同也对不上。
      expect(
        parsed.campusForSections([
          const SectionTime(startTime: '08:20', endTime: '09:05'),
        ]),
        isNull,
      );
      expect(parsed.campusForSections(const []), isNull);
    });

    test('判不出时返回 null，不替用户猜', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse(twoCampuses());
      expect(
        parsed.campusForSections([
          const SectionTime(startTime: '07:30', endTime: '08:05'),
        ]),
        isNull,
      );
    });

    test('两套作息完全相同时判为「无法判定」而不是随便挑一个', () {
      // 数据写错时会出现这种形状：两个校区各自的兜底作息一模一样。此时
      // 「用户选了哪套」这个问题本身没有答案，必须报「判不出」。
      final parsed = QingyuOnlyTimeSchemesLogic.parse({
        'version': 1,
        'sections': {
          '1': {'startTime': '08:20', 'endTime': '09:05'},
        },
        'campuses': [
          {
            'id': 'a',
            'name': 'A',
            'schemes': [
              {'name': 'A · 其他'}
            ],
          },
          {
            'id': 'b',
            'name': 'B',
            'schemes': [
              {'name': 'B · 其他'}
            ],
          },
        ],
      });
      expect(
        parsed.campusForSections([
          const SectionTime(startTime: '08:20', endTime: '09:05'),
        ]),
        isNull,
      );
    });
  });

  group('parse 的校验', () {
    List<SectionTime> sectionsOf(QingyuOnlyTimeSchemes parsed, int index) =>
        parsed.campuses[index].schemes.first.sections;

    test('版本不认识就当没有，绝不用未来的格式硬套现在的时间表', () {
      expect(
        () => QingyuOnlyTimeSchemesLogic.parse({
          'version': 2,
          'sections': {
            '1': {'startTime': '08:20', 'endTime': '09:05'},
          },
          'campuses': [
            {
              'id': 'a',
              'name': 'A',
              'schemes': [
                {'name': 'A'}
              ],
            }
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('基线某节时间倒退 → 整份不可用（校验器第一次跑就抓到的真实错误）', () {
      expect(
        () => QingyuOnlyTimeSchemesLogic.parse({
          'version': 1,
          'sections': {
            '1': {'startTime': '08:20', 'endTime': '09:05'},
            '2': {'startTime': '09:15', 'endTime': '10:00'},
          },
          'campuses': [
            {
              'id': 'a',
              'name': 'A',
              'schemes': [
                {'name': 'A'}
              ],
            }
          ],
        }),
        returnsNormally,
      );
      // 第 2 节结束早于第 1 节结束，这份时间表 App 建不出来。
      expect(
        () => QingyuOnlyTimeSchemesLogic.parse({
          'version': 1,
          'sections': {
            '1': {'startTime': '08:20', 'endTime': '09:05'},
            '2': {'startTime': '07:15', 'endTime': '08:00'},
          },
          'campuses': [
            {
              'id': 'a',
              'name': 'A',
              'schemes': [
                {'name': 'A'}
              ],
            }
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('覆盖造成时间倒退 → 丢掉这一套，同校区其余套仍可用', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse({
        'version': 1,
        'sections': {
          '1': {'startTime': '08:20', 'endTime': '09:05'},
          '2': {'startTime': '09:15', 'endTime': '10:00'},
          '3': {'startTime': '10:10', 'endTime': '10:55'},
        },
        'campuses': [
          {
            'id': 'a',
            'name': 'A',
            'schemes': [
              {
                'name': '坏的',
                'overrides': {
                  '2': {'startTime': '08:00', 'endTime': '08:30'}
                },
              },
              {'name': '好的'},
            ],
          },
        ],
      });
      expect(parsed.campuses.single.schemes, hasLength(1));
      expect(parsed.campuses.single.schemes.single.name, '好的');
    });

    test('覆盖不存在的节次 → 丢掉这一套', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse({
        'version': 1,
        'sections': {
          '1': {'startTime': '08:20', 'endTime': '09:05'},
        },
        'campuses': [
          {
            'id': 'a',
            'name': 'A',
            'schemes': [
              {
                'name': '越界',
                'overrides': {
                  '7': {'startTime': '20:00', 'endTime': '20:45'}
                },
              },
              {'name': '好的'},
            ],
          },
        ],
      });
      expect(parsed.campuses.single.schemes.single.name, '好的');
    });

    test('节次不连续（缺一节）→ 整份不可用', () {
      // 节次按位置对齐，缺一节会让「第 3 节」指向错误的时间。
      expect(
        () => QingyuOnlyTimeSchemesLogic.parse({
          'version': 1,
          'sections': {
            '1': {'startTime': '08:20', 'endTime': '09:05'},
            '3': {'startTime': '10:10', 'endTime': '10:55'},
          },
          'campuses': [
            {
              'id': 'a',
              'name': 'A',
              'schemes': [
                {'name': 'A'}
              ],
            }
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('覆盖表稀疏是合法的 —— 这是格式本身要求的', () {
      // 「只写与基线不同的节次」正是 overrides 存在的理由。拿「必须是 1..N 连续」
      // 去要求它，会把所有带覆盖的作息全部误杀（第一版就踩了这个坑，对着真实
      // 数据文件才暴露出来：CQCST 两校区各被砍掉一套）。
      final parsed = QingyuOnlyTimeSchemesLogic.parse({
        'version': 1,
        'sections': {
          '1': {'startTime': '08:20', 'endTime': '09:05'},
          '2': {'startTime': '09:15', 'endTime': '10:00'},
          '3': {'startTime': '10:10', 'endTime': '10:55'},
        },
        'campuses': [
          {
            'id': 'a',
            'name': 'A',
            'schemes': [
              {
                'name': 'A · 主楼',
                'keywords': [
                  {'pattern': 'A', 'mode': 'prefix'}
                ],
                'overrides': {
                  '3': {'startTime': '10:30', 'endTime': '11:15'}
                },
              },
              {'name': 'A · 其他'},
            ],
          },
        ],
      });
      expect(parsed.campuses.single.schemes, hasLength(2));
      final withKeywords = parsed.campuses.single.schemes.first;
      expect(withKeywords.sections[2].startTime, '10:30');
      expect(withKeywords.sections[2].endTime, '11:15');
      expect(withKeywords.sections[0].startTime, '08:20');
    });

    test('兜底作息不是恰好一套 → 整个校区作废 → 整份不可用', () {
      // 没有兜底：课程时间无处可落。多于一套：「默认用哪套」没有答案。
      for (final schemes in [
        [
          {
            'name': '有词',
            'keywords': [
              {'pattern': 'A', 'mode': 'prefix'}
            ],
          },
        ],
        [
          {'name': '兜底一'},
          {'name': '兜底二'},
        ],
      ]) {
        expect(
          () => QingyuOnlyTimeSchemesLogic.parse({
            'version': 1,
            'sections': {
              '1': {'startTime': '08:20', 'endTime': '09:05'},
            },
            'campuses': [
              {'id': 'a', 'name': 'A', 'schemes': schemes},
            ],
          }),
          throwsA(isA<FormatException>()),
          reason: '兜底不唯一时应整份不可用',
        );
      }
    });

    test('脏数据只丢自己那一条：同批的其它校区照常可用', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse({
        'version': 1,
        'sections': {
          '1': {'startTime': '08:20', 'endTime': '09:05'},
        },
        'campuses': [
          '不是对象',
          {'id': 'dup', 'name': '重复'},
          {'id': 'dup', 'name': '重复'},
          {
            'id': 'good',
            'name': '好的',
            'schemes': [
              {'name': '好的 · 其他'}
            ],
          },
        ],
      });
      expect(parsed.campuses, hasLength(1));
      expect(parsed.campuses.single.id, 'good');
    });

    test('关键词 mode 未知按 prefix 处理，空白 pattern 丢掉', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse({
        'version': 1,
        'sections': {
          '1': {'startTime': '08:20', 'endTime': '09:05'},
        },
        'campuses': [
          {
            'id': 'a',
            'name': 'A',
            'schemes': [
              {
                'name': 'A · 主楼',
                'keywords': [
                  {'pattern': 'A栋', 'mode': 'unknown-mode'},
                  {'pattern': '  '},
                ],
              },
              {'name': 'A · 其他'},
            ],
          },
        ],
      });
      final withKeywords = parsed.campuses.single.schemes
          .firstWhere((scheme) => !scheme.isFallback);
      expect(withKeywords.keywords, hasLength(1));
      expect(withKeywords.keywords.single.pattern, 'A栋');
      expect(
        withKeywords.keywords.single.mode,
        LocationKeywordMatchMode.fromValue('unknown-mode'),
      );
    });

    test('overrides 为空对象按「无覆盖」处理', () {
      final parsed = QingyuOnlyTimeSchemesLogic.parse({
        'version': 1,
        'sections': {
          '1': {'startTime': '08:20', 'endTime': '09:05'},
          '2': {'startTime': '09:15', 'endTime': '10:00'},
        },
        'campuses': [
          {
            'id': 'a',
            'name': 'A',
            'schemes': [
              {'name': 'A · 其他', 'overrides': <String, dynamic>{}},
            ],
          },
        ],
      });
      expect(sectionsOf(parsed, 0), hasLength(2));
    });
  });
}
