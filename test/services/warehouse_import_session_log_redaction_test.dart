import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/warehouse_import_session_log.dart';

/// 教务导入执行日志会被用户**导出发给他人**
/// （`log_viewer_entry.dart` 的 onExport 落 `qingyu-warehouse-import-log-*.txt`
/// 再 SharePlus 分享），所以它不能把带着会话凭据的教务系统地址原样收进去。
///
/// 保存宏时仓库里早就有 `sanitizeWarehouseScriptPageUrl`
/// （`warehouse_macro_models.dart:342`）剥 JSESSIONID/ticket/token/sid 与路径里的
/// `;jsessionid=`，`course_import_screen.dart` 的 :4967/:6528/:6635 都在用它；
/// 但同一个页面往这份日志里写的是 `_currentUrl` 裸值
/// （:3909/:3984/:3989/:4010/:4092）——同一份数据两套口径。
/// 这里把脱敏收到日志本身，五个现在的写入点和以后新增的点一起覆盖。
void main() {
  late WarehouseImportSessionLog log;

  setUp(() {
    log = WarehouseImportSessionLog.instance;
    log.clear();
  });

  tearDown(() {
    log.clear();
  });

  test('消息里的 URL 掉查询串与路径里的 jsessionid', () {
    log.append(
      message:
          'open web login school=示例(10) adapter=默认(1) '
          'url=https://jw.example.edu.cn/index;jsessionid=ABCDEF1234?ticket=T-9981 macro=false',
    );

    final text = log.readText();
    expect(text, isNot(contains('ABCDEF1234')));
    expect(text, isNot(contains('T-9981')));
    // 站点与路径仍要留着，否则日志没法定位是哪个教务系统。
    expect(text, contains('jw.example.edu.cn'));
  });

  test('extras 里 url 类字段同样脱敏，其它字段不动', () {
    log.append(
      message: 'navigate',
      extras: const <String, Object?>{
        'url': 'https://jw.example.edu.cn/x?sid=SESSID&xh=20230001',
        'schoolId': '10',
        'adapterName': '默认脚本',
      },
    );

    final text = log.readText();
    expect(text, isNot(contains('SESSID')));
    expect(text, isNot(contains('20230001')));
    expect(text, contains('schoolId=10'));
    expect(text, contains('adapterName=默认脚本'));
  });

  test('解析不出绝对地址时整条 URL 不收', () {
    log.append(
      message: 'bad url=https://&*&%&/x?token=LEAK',
      extras: const {'entryUrl': 'not a url at all'},
    );

    final text = log.readText();
    expect(text, isNot(contains('LEAK')));
    expect(text, isNot(contains('not a url at all')));
  });

  test('非 URL 文本与空值保持原样', () {
    log.append(
      message: 'console.error: adapter returned empty list',
      extras: const {'macroReplay': true, 'url': null, 'count': 3},
    );

    final text = log.readText();
    expect(text, contains('console.error: adapter returned empty list'));
    expect(text, contains('macroReplay=true'));
    expect(text, contains('count=3'));
    expect(text, contains('url=null'));
  });

  test('sanitizeWarehouseLogUrl 只留 scheme+host+path（比宏存储更严）', () {
    expect(
      sanitizeWarehouseLogUrl(
        'https://jw.example.edu.cn/cas/login?service=https%3A%2F%2Fjw%2Fx&ticket=T1',
      ),
      'https://jw.example.edu.cn/cas/login',
    );
    expect(
      sanitizeWarehouseLogUrl(
        'https://jw.example.edu.cn/xh.jsp?xh=20230001',
      ),
      'https://jw.example.edu.cn/xh.jsp',
    );
    expect(sanitizeWarehouseLogUrl('file:///etc/passwd'), '');
    expect(sanitizeWarehouseLogUrl(null), '');
    expect(sanitizeWarehouseLogUrl('   '), '');
  });
}
