import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/warehouse_repository_models.dart';

void main() {
  const globalTools = WarehouseSearchSchoolEntry(
    id: 'GLOBAL_TOOLS',
    adapters: [
      WarehouseSearchAdapterEntry(
        adapterId: 'WakeUp',
        adapterName: 'WakeUp课程表分享口令导入(支持新版)',
      ),
      WarehouseSearchAdapterEntry(
        adapterId: 'StarLink',
        adapterName: '星链课表分享码导入',
      ),
    ],
  );
  const cqu = WarehouseSearchSchoolEntry(
    id: 'CQU',
    adapters: [WarehouseSearchAdapterEntry(adapterId: 'CQU', adapterName: '重庆大学教务')],
  );
  const index = WarehouseSearchIndex(
    versionId: 'IDX_test',
    schools: [globalTools, cqu],
  );

  const cquSchool = WarehouseSchoolEntry(
    id: 'CQU',
    name: '重庆大学',
    initial: 'C',
    resourceFolder: 'CQU',
  );
  const globalSchool = WarehouseSchoolEntry(
    id: 'GLOBAL_TOOLS',
    name: '通用工具与服务',
    initial: 'T',
    resourceFolder: 'GLOBAL_TOOLS',
  );

  group('WarehouseSearchSchoolEntry.matchedAdapterNames', () {
    test('适配器名称大小写不敏感命中', () {
      expect(
        globalTools.matchedAdapterNames('wakeup'),
        ['WakeUp课程表分享口令导入(支持新版)'],
      );
      expect(
        globalTools.matchedAdapterNames('WAKEUP'),
        ['WakeUp课程表分享口令导入(支持新版)'],
      );
    });

    test('适配器 ID 也能命中（名称不含关键词时）', () {
      expect(globalTools.matchedAdapterNames('StarLink'), ['星链课表分享码导入']);
    });

    test('名称为空的适配器回退用 ID 展示', () {
      const school = WarehouseSearchSchoolEntry(
        id: 'X',
        adapters: [WarehouseSearchAdapterEntry(adapterId: 'Legacy', adapterName: '')],
      );
      expect(school.matchedAdapterNames('legacy'), ['Legacy']);
    });

    test('空关键词与未命中返回空列表', () {
      expect(globalTools.matchedAdapterNames(''), isEmpty);
      expect(globalTools.matchedAdapterNames('  '), isEmpty);
      expect(globalTools.matchedAdapterNames('正方'), isEmpty);
    });
  });

  group('WarehouseSearchIndex.matchedAdapterNamesBySchool', () {
    test('按学校 id 分组且只含非空命中', () {
      final matches = index.matchedAdapterNamesBySchool('口令');
      expect(matches.keys, ['GLOBAL_TOOLS']);
      expect(matches['GLOBAL_TOOLS'], ['WakeUp课程表分享口令导入(支持新版)']);
    });

    test('多个学校命中时全部返回', () {
      // “教务”同时命中「重庆大学教务」与各通用教务脚本名
      final matches = index.matchedAdapterNamesBySchool('教务');
      expect(matches.keys, containsAll(['CQU']));
    });

    test('空关键词返回空映射', () {
      expect(index.matchedAdapterNamesBySchool(''), isEmpty);
    });
  });

  group('filterWarehouseSchools', () {
    test('空关键词原样返回全部学校', () {
      expect(
        filterWarehouseSchools([cquSchool, globalSchool], '  '),
        [cquSchool, globalSchool],
      );
    });

    test('学校字段命中行为与旧版一致', () {
      expect(filterWarehouseSchools([cquSchool, globalSchool], '重庆大学'), [
        cquSchool,
      ]);
      // 资源目录/ID/首字母参与匹配
      expect(filterWarehouseSchools([cquSchool, globalSchool], 'GLOBAL_TOOLS'), [
        globalSchool,
      ]);
    });

    test('脚本名命中把学校带出来（适配索引外搜不到 WakeUp）', () {
      final matches = index.matchedAdapterNamesBySchool('wakeup');
      final filtered = filterWarehouseSchools(
        [cquSchool, globalSchool],
        'wakeup',
        adapterMatches: matches,
      );
      expect(filtered, [globalSchool]);
    });

    test('命中映射为空时等价于仅按学校字段搜索（旧版适配仓降级）', () {
      final filtered = filterWarehouseSchools(
        [cquSchool, globalSchool],
        'wakeup',
      );
      expect(filtered, isEmpty);
    });
  });
}
