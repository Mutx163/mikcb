import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_adapter_upgrade.dart';
import 'package:university_timetable/models/warehouse_repository_models.dart';

/// 轻屿专属条目 → 标准条目的自动增强。
///
/// 这里守的是**用户视角**：同一所学校的「标准版 / 专属版」在用户眼里是同一件事，
/// 让他二选一等于逼他先知道学校有没有做增强，挑了没增强那条还会白丢「按教学楼分流
/// 作息」。所以同脚本的专属条目必须并进标准条目、列表里只留一条；而真的是另一条
/// 适配的专属条目（不同脚本）必须留着，不能被吃掉。
const _standard = WarehouseAdapterEntry(
  adapterId: 'CQCST_01',
  adapterName: '重庆城市科技学院强智适配',
  category: 'BACHELOR_AND_ASSOCIATE',
  assetJsPath: 'cqcst_01.js',
  importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
  maintainer: 'Mutx163',
  description: '标准版',
);

const _upgrade = WarehouseAdapterEntry(
  adapterId: 'CQCST_02',
  adapterName: '重庆城市科技学院强智适配（按教学楼自动分流作息）',
  category: 'BACHELOR_AND_ASSOCIATE',
  assetJsPath: 'cqcst_01.js',
  importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
  maintainer: 'Mutx163',
  description: '专属版',
  timeSchemesFile: 'time_schemes.json',
  isQingyuOnly: true,
);

void main() {
  group('mergeQingyuOnlyUpgrades', () {
    test('同一份脚本的专属条目并进标准条目，列表里只剩一条', () {
      final merged = mergeQingyuOnlyUpgrades(
        standard: const [_standard],
        extras: const [_upgrade],
      );

      expect(merged, hasLength(1), reason: '用户不该在同一所学校里做二选一');
      final entry = merged.single;
      expect(entry.adapterId, 'CQCST_01', reason: '身份仍是标准条目（宏、索引都按它记）');
      expect(entry.adapterName, _standard.adapterName);
      expect(entry.description, _standard.description);
      // 导入侧「要不要套用专属作息」判断读的就是这两个字段：置真之后那里一字不改
      // 就生效，所以它们是这次合并的全部意义所在。
      expect(entry.timeSchemesFile, 'time_schemes.json');
      expect(entry.isQingyuOnly, isTrue);
    });

    test('没有专属条目时原样返回标准列表', () {
      final merged = mergeQingyuOnlyUpgrades(
        standard: const [_standard],
        extras: const [],
      );
      expect(merged, const [_standard]);
    });

    test('专属条目声明的是另一份脚本时照旧追加，不吃掉它', () {
      const otherScript = WarehouseAdapterEntry(
        adapterId: 'CQCST_03',
        adapterName: '城科（另一个导入方式）',
        category: 'BACHELOR_AND_ASSOCIATE',
        assetJsPath: 'cqcst_other.js',
        importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
        maintainer: 'Mutx163',
        description: '另一条',
        timeSchemesFile: 'time_schemes.json',
        isQingyuOnly: true,
      );

      final merged = mergeQingyuOnlyUpgrades(
        standard: const [_standard],
        extras: const [otherScript],
      );

      expect(merged, hasLength(2));
      expect(merged.first, _standard, reason: '标准条目未被改动');
      expect(merged.last, otherScript, reason: '真的是另一条适配，必须还在');
    });

    test('专属条目与标准条目 id 相同时跳过，不让同一个适配出现两次', () {
      final merged = mergeQingyuOnlyUpgrades(
        standard: const [_standard],
        extras: const [
          WarehouseAdapterEntry(
            adapterId: 'CQCST_01',
            adapterName: '重复 id',
            category: 'BACHELOR_AND_ASSOCIATE',
            assetJsPath: 'cqcst_01.js',
            importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
            maintainer: 'Mutx163',
            description: '重复',
            timeSchemesFile: 'time_schemes.json',
            isQingyuOnly: true,
          ),
        ],
      );

      expect(merged, const [_standard], reason: 'id 重复时保持原样，不合并也不追加');
    });

    test('专属条目没带专属字段时不合并（合了只是多绕一跳脚本查找）', () {
      const noFields = WarehouseAdapterEntry(
        adapterId: 'CQCST_04',
        adapterName: '没有专属字段的专属条目',
        category: 'BACHELOR_AND_ASSOCIATE',
        assetJsPath: 'cqcst_01.js',
        importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
        maintainer: 'Mutx163',
        description: '无',
        isQingyuOnly: true,
      );

      final merged = mergeQingyuOnlyUpgrades(
        standard: const [_standard],
        extras: const [noFields],
      );

      expect(merged, hasLength(2));
      expect(merged.first, _standard);
      expect(merged.first.isQingyuOnly, isFalse);
    });

    test('同一份脚本被多条标准条目引用时，每条都增强', () {
      const twin = WarehouseAdapterEntry(
        adapterId: 'CQCST_01_LIVE',
        adapterName: '城科（直播班）',
        category: 'BACHELOR_AND_ASSOCIATE',
        assetJsPath: 'cqcst_01.js',
        importUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/',
        maintainer: 'Mutx163',
        description: '直播班',
      );

      final merged = mergeQingyuOnlyUpgrades(
        standard: const [_standard, twin],
        extras: const [_upgrade],
      );

      expect(merged, hasLength(2));
      // 只增强其中一条的话，用户会拿到「有时分流有时不分流」的随机行为。
      for (final entry in merged) {
        expect(entry.timeSchemesFile, 'time_schemes.json');
        expect(entry.isQingyuOnly, isTrue);
      }
    });
  });
}
