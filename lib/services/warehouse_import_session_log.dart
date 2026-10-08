import 'dart:async';
import 'dart:collection';

import '../logging/app_debug_log.dart';
import '../models/warehouse_macro_models.dart';

/// 写进导入执行日志的 URL：走仓库里**已有**的那套会话参数剥离。
///
/// 这份日志是给用户导出发给维护者的明文文本
/// （`log_viewer_entry.dart` 的 `onExport` 落 `qingyu-warehouse-import-log-*.txt`
/// 再 SharePlus 分享），而教务系统登录后的地址常带
/// `JSESSIONID` / `ticket` / `token` / `sid` / `xh=学号` 这类查询参数或
/// 路径里的 `;jsessionid=`。保存宏时已经用
/// [sanitizeWarehouseScriptPageUrl] 剥过一遍（`warehouse_macro_models.dart:342`，
/// 调用点 :286/:427/:428 与 `course_import_screen.dart:4967/6528/6635`），
/// 日志这一路原先是把 `_currentUrl` 原样写进去，同一份数据两种口径。
///
/// 日志比宏存储再严一档：宏要能重放就得留下业务查询参数（`?xh=…`、`?type=kcb`），
/// 而定位"是哪个教务系统的哪个页面"只需要 scheme + host + port + path，
/// 所以这里在剥掉会话参数之后，把剩下的查询串与 fragment 也一并去掉。
/// 解析不出可用的 http(s) 绝对地址时返回空串（畸形地址本身可能就是被塞进来的可疑内容）。
String sanitizeWarehouseLogUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  final withoutSession = sanitizeWarehouseScriptPageUrl(trimmed) ?? trimmed;
  final uri = Uri.tryParse(withoutSession);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return '';
  }
  // 重建而不是 replace(query: '')：后者会留下光杆的 `?`。
  // 重建同时也丢掉了 authority 里的 userinfo（`https://user:pass@host` 这种
  // 把凭据写进地址的形态本来就不该出现在可分享的日志里）。
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path.isEmpty ? '/' : uri.path,
  ).toString();
}

/// 日志文本里出现的每个 http(s) 地址都按上面的口径脱敏。
final RegExp _warehouseLogUrlPattern = RegExp(r'''https?://[^\s"'<>]+''');

String _scrubUrlsInLogText(String text) {
  return text.replaceAllMapped(
    _warehouseLogUrlPattern,
    (Match match) => sanitizeWarehouseLogUrl(match.group(0)),
  );
}

/// extras 里 key 含 "url" 的值一律按 URL 处理；其余值原样保留
/// （日志还要能看出 schoolId / adapterId / macroReplay 这些定位信息）。
Object? _scrubLogExtra(String key, Object? value) {
  if (key.toLowerCase().contains('url')) {
    if (value is! String) {
      return value == null ? null : '';
    }
    return sanitizeWarehouseLogUrl(value);
  }
  // ⚠️ 其余值并不是"原样保留"就安全：WebView console 消息、脚本状态串里
  // 常夹着课程名 / 教师 / 教室。这份日志是用户导出发给维护者的明文文本
  // （`log_viewer_entry.dart` 的 onExport → SharePlus），而它是仓库里第三个
  // 可分享出口 —— 之前只做了 URL 清洗，个人字段一个都没盖，与
  // `app_debug_log.dart` 那份被声明为「唯一来源」的字段表完全脱钩。
  // 所以接上同一份表（key 命中即整值盖住，嵌套值按结构脱敏）。
  return redactPersonalFieldValue(key, value);
}

/// In-memory ring buffer for warehouse course-import execution traces.
///
/// Entries are formatted like [AppLogService] diagnostics blocks so they can be
/// opened in [LiveDiagnosticsLogViewerScreen] and shared with maintainers.
class WarehouseImportSessionLog {
  WarehouseImportSessionLog._internal();

  static final WarehouseImportSessionLog instance =
      WarehouseImportSessionLog._internal();

  static const int maxEntries = 800;
  static const String category = 'WarehouseImport';

  final Queue<String> _blocks = Queue<String>();
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  Stream<void> get changes => _changeController.stream;

  int get entryCount => _blocks.length;

  bool get isEmpty => _blocks.isEmpty;

  void clear() {
    if (_blocks.isEmpty) {
      return;
    }
    _blocks.clear();
    _notifyChanged();
  }

  void append({
    required String message,
    String level = 'info',
    Map<String, Object?> extras = const {},
  }) {
    // 两层：先剥 URL 会话参数（这份日志比宏存储更严，见上），再过个人字段表。
    // 顺序不能反 —— `key=value` 正则对已剥过的文本一样有效，但反过来会让
    // URL 里的 `name=` 之类片段被当成个人字段先抹掉，破坏取证信息。
    final normalizedMessage = redactPersonalFields(
      _scrubUrlsInLogText(message.trim()),
    );
    if (normalizedMessage.isEmpty) {
      return;
    }
    final buffer = StringBuffer()
      ..writeln('time=${DateTime.now().millisecondsSinceEpoch}')
      ..writeln('level=${_normalizeLevel(level)}')
      ..writeln('source=app')
      ..writeln('category=$category')
      ..writeln('message=$normalizedMessage');
    if (extras.isNotEmpty) {
      buffer.writeln('extras=');
      extras.forEach((key, value) {
        buffer.writeln('  $key=${_scrubLogExtra(key, value) ?? 'null'}');
      });
    }
    buffer.writeln();
    _blocks.addLast(buffer.toString());
    while (_blocks.length > maxEntries) {
      _blocks.removeFirst();
    }
    _notifyChanged();
  }

  String readText({String title = 'Warehouse import execution log'}) {
    final body = _blocks.join().trimRight();
    final header = [
      title,
      'exportedAt=${DateTime.now().millisecondsSinceEpoch}',
      'entryCount=${_blocks.length}',
      '----',
    ].join('\n');
    if (body.isEmpty) {
      return header;
    }
    return '$header\n$body';
  }

  Stream<String> watchText({String title = 'Warehouse import execution log'}) {
    late StreamController<String> controller;
    StreamSubscription<void>? subscription;

    void emit() {
      if (!controller.isClosed) {
        controller.add(readText(title: title));
      }
    }

    controller = StreamController<String>(
      onListen: () {
        emit();
        subscription = _changeController.stream.listen((_) => emit());
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
        await controller.close();
      },
    );
    return controller.stream;
  }

  String _normalizeLevel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'error':
      case 'err':
        return 'error';
      case 'warn':
      case 'warning':
        return 'warn';
      case 'debug':
        return 'debug';
      case 'verbose':
      case 'trace':
        return 'verbose';
      default:
        return 'info';
    }
  }

  void _notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
}
