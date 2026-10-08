// 系统备份规则守卫：`AndroidManifest.xml` 必须挂上备份规则，且规则本身不能被
// 改成「白名单」或把凭据放回去。
//
// 为什么要有这条：本项目此前**一个备份属性都没声明**。`android:allowBackup`
// 缺省即 true，Auto Backup 默认打包 shared preferences、内部文件、SQLite 库，
// 于是三组凭据（WebDAV / 情侣同步 / 教务导入会话，全在 flutter_secure_storage
// 的 `FlutterSecureStorage.xml` 里）连同全部课表一起进系统云备份——与项目
// 「本地优先、隐私」的定位相悖。属性和规则文件本身是静默失效的：不声明不会有
// 任何报错或告警，只有真的去翻系统备份设置才看得见，所以落成扫描测试。
//
// 这条测试要挡住三种回退：
//   1. 有人把 `fullBackupContent` / `dataExtractionRules` 删掉（= 静默回到全量备份）；
//   2. 有人在规则里加 `<include>` —— Auto Backup 的语义是「出现任意 `<include>`
//      就整体翻成白名单」，手滑加一条会让备份范围整个变质，且不报错；
//   3. 有人把 `FlutterSecureStorage.xml` 的排除删掉（凭据回到备份范围）；
//   4. `cloud-backup` 段被"简化"回只有 `domain="root"` 一条 —— 看着像关掉了，
//      实际上一棵树都没排掉（这条是 2026-10-07 才发现的静默失效）。
//
// 策略本身（云端全关 / 换机带走数据但不带凭据）写在两个规则文件的注释里，
// 改动前先读那里的理由。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _legacyRulesPath = 'android/app/src/main/res/xml/backup_rules.xml';
const _modernRulesPath =
    'android/app/src/main/res/xml/data_extraction_rules.xml';

/// flutter_secure_storage 的默认 SharedPreferences 文件名。
///
/// 来源：`FlutterSecureStorageConfig.DEFAULT_PREF_NAME = "FlutterSecureStorage"`
/// （插件 android 端源码）。三组凭据共用这一个文件，所以排掉它就等于排掉全部。
/// 插件若改名，这里会红——那时三组凭据就换了文件，必须同步改两个规则文件。
const _secureStoragePrefs = 'FlutterSecureStorage.xml';

/// 读文件并剥掉 `<!-- -->` 注释——本文件所有断言扫的都是「真实元素」。
///
/// include/exclude 的白名单语义只对元素成立，注释里提到这两个词不算数。不剥的话，
/// 两个规则文件里「为什么不写 include」的那段说明本身就会把守卫顶红，而守卫存在
/// 的意义恰恰是拦住真元素——被自己的说明文字绊倒的守卫，迟早被人加白名单绕过。
String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '缺少文件：$path');
  return file.readAsStringSync().replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
}

void main() {
  group('AndroidManifest 备份属性', () {
    late final String manifest;

    setUpAll(() => manifest = _read(_manifestPath));

    test('API 31+ 与 API 30- 两套规则都挂上了', () {
      // minSdk = 26，所以两套格式都得在：缺一套，那批系统上就退回全量备份。
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
        reason: 'Android 12+ 没有备份规则 = 该系统上默认全量备份',
      );
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
        reason: 'Android 11 及以下没有备份规则 = 该系统上默认全量备份',
      );
    });

    test('没有把 allowBackup 写成 false 来「一刀切」', () {
      // 一刀切的代价写在 backup_rules.xml 注释里：会让换机的用户丢全部课表。
      // 真要改策略，先改那两个文件的注释，再改这里。
      expect(
        manifest,
        isNot(contains('android:allowBackup="false"')),
        reason: 'allowBackup=false 会连换机直传一起关掉，'
            '课表就没了；若这是有意的，请先更新 backup_rules.xml 的注释',
      );
    });
  });

  group('备份规则文件', () {
    test('两套规则都不含 <include>（否则语义翻成白名单）', () {
      for (final path in [_legacyRulesPath, _modernRulesPath]) {
        final xml = _read(path);
        expect(
          xml,
          isNot(contains('<include')),
          reason: '$path 出现了 <include>：Auto Backup 会从「默认全备、排除列出」'
              '整体翻成白名单，备份范围静默变质',
        );
      }
    });

    test('API 31+ 规则：换机直传只排凭据', () {
      final xml = _read(_modernRulesPath);
      expect(xml, contains('<data-extraction-rules>'));
      expect(xml, contains('<cloud-backup>'));
      expect(xml, contains('<device-transfer>'));
      expect(
        xml,
        contains('<exclude domain="sharedpref" path="$_secureStoragePrefs"'),
        reason: '换机直传没排掉凭据文件',
      );
    });

    test('API 31+ 云备份：九个域逐个排掉，漏一条就漏一棵树', () {
      // 只写 `domain="root" path="."` **关不掉云备份**（2026-10-07 实锤）。
      // 框架 `BackupAgent.onFullBackup` 在遍历 root 域之前就把 files / database /
      // sharedpref 塞进 `traversalExcludeSet`，之后三者各自独立遍历、只认自己
      // 域的规则。本 App 的课表 JSON 与三组凭据全在 `shared_prefs`
      // （`storage_service.dart` 走 `SharedPreferences.getInstance()`），
      // 于是只排 root 等于什么都没排，课表与凭据照旧上 Google 云。
      //
      // 这条断言在修复前是红的：当时 `cloud-backup` 段只有 root 一条 exclude。
      final xml = _read(_modernRulesPath);
      final cloudSection = xml.substring(
        xml.indexOf('<cloud-backup>'),
        xml.indexOf('</cloud-backup>'),
      );
      const requiredDomains = [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
        'device_root',
        'device_file',
        'device_database',
        'device_sharedpref',
      ];
      for (final domain in requiredDomains) {
        expect(
          cloudSection,
          contains('<exclude domain="$domain" path="."'),
          reason: 'cloud-backup 段没排掉 $domain 域：这棵树的内容仍会进云备份',
        );
      }
    });

    test('API 30- 规则：排掉凭据文件', () {
      final xml = _read(_legacyRulesPath);
      expect(xml, contains('<full-backup-content>'));
      expect(
        xml,
        contains('<exclude domain="sharedpref" path="$_secureStoragePrefs"'),
        reason: 'Android 8~11 上凭据会进系统备份',
      );
    });
  });
}
