import 'dart:async';
import 'dart:collection';

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
    final normalizedMessage = message.trim();
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
        buffer.writeln('  $key=${value ?? 'null'}');
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
