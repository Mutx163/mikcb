import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:qr/qr.dart';

import 'qr_transfer_codec.dart';
import 'qr_transfer_session.dart';

/// A QR module matrix that can cross an isolate boundary without retaining
/// the package's mutable QrCode/QrImage objects.
class QrTransferMatrix {
  const QrTransferMatrix({
    required this.seed,
    required this.frameText,
    required this.moduleCount,
    required this.modules,
  });

  final int seed;
  final String frameText;
  final int moduleCount;
  final Uint8List modules;

  bool isDark(int row, int column) {
    if (row < 0 || row >= moduleCount || column < 0 || column >= moduleCount) {
      throw RangeError('QR module out of range: $row, $column');
    }
    return modules[row * moduleCount + column] != 0;
  }
}

/// Creates a portable QR matrix from a frame text.
///
/// This is also used by the worker isolate. Keeping the package-specific
/// construction here means the UI only receives bytes and never constructs a
/// QrCode or QrImage during a frame transition.
QrTransferMatrix qrTransferMatrixForText(String frameText, {int seed = 0}) {
  final qrCode = QrCode.fromData(
    data: frameText,
    errorCorrectLevel: QrErrorCorrectLevel.L,
  );
  final qrImage = QrImage(qrCode);
  final modules = Uint8List(qrImage.moduleCount * qrImage.moduleCount);
  for (var row = 0; row < qrImage.moduleCount; row++) {
    for (var column = 0; column < qrImage.moduleCount; column++) {
      modules[row * qrImage.moduleCount + column] = qrImage.isDark(row, column)
          ? 1
          : 0;
    }
  }
  return QrTransferMatrix(
    seed: seed,
    frameText: frameText,
    moduleCount: qrImage.moduleCount,
    modules: modules,
  );
}

/// Owns the QR encoder in a cancellable background isolate.
class QrTransferFrameWorker {
  QrTransferFrameWorker._(this._receivePort) {
    _subscription = _receivePort.listen(_handleMessage);
  }

  final ReceivePort _receivePort;
  late final StreamSubscription<dynamic> _subscription;
  final Completer<SendPort> _workerPortCompleter = Completer<SendPort>();
  final Completer<QrTransferSessionInfo> _infoCompleter =
      Completer<QrTransferSessionInfo>();
  final Map<int, Completer<List<QrTransferMatrix>>> _pending = {};

  Isolate? _isolate;
  SendPort? _workerPort;
  QrTransferSessionInfo? _info;
  int _nextRequestId = 0;
  bool _disposed = false;

  static Future<QrTransferFrameWorker> start(Uint8List payload) async {
    final worker = QrTransferFrameWorker._(ReceivePort());
    try {
      worker._isolate = await Isolate.spawn(
        _qrTransferWorkerMain,
        worker._receivePort.sendPort,
      );
      final workerPort = await worker._workerPortCompleter.future.timeout(
        const Duration(seconds: 10),
      );
      workerPort.send(<Object?>[
        'init',
        TransferableTypedData.fromList(<Uint8List>[payload]),
      ]);
      await worker._infoCompleter.future.timeout(const Duration(seconds: 30));
      return worker;
    } catch (_) {
      await worker.dispose();
      rethrow;
    }
  }

  QrTransferSessionInfo get info => _info!;

  Future<List<QrTransferMatrix>> generate({
    required int startSeed,
    required int count,
  }) {
    if (_disposed) {
      return Future<List<QrTransferMatrix>>.error(
        StateError('qr_transfer_worker_disposed'),
      );
    }
    if (startSeed < 0) {
      return Future<List<QrTransferMatrix>>.error(
        ArgumentError.value(startSeed, 'startSeed'),
      );
    }
    if (count <= 0 || count > 16) {
      return Future<List<QrTransferMatrix>>.error(
        ArgumentError.value(count, 'count', 'must be between 1 and 16'),
      );
    }
    final port = _workerPort;
    if (port == null) {
      return Future<List<QrTransferMatrix>>.error(
        StateError('qr_transfer_worker_not_ready'),
      );
    }

    final requestId = _nextRequestId++;
    final completer = Completer<List<QrTransferMatrix>>();
    _pending[requestId] = completer;
    port.send(<Object?>['generate', requestId, startSeed, count]);
    return completer.future;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final error = StateError('qr_transfer_worker_disposed');
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
    await _subscription.cancel();
  }

  void _handleMessage(Object? rawMessage) {
    if (rawMessage is SendPort) {
      _workerPort = rawMessage;
      if (!_workerPortCompleter.isCompleted) {
        _workerPortCompleter.complete(rawMessage);
      }
      return;
    }
    if (rawMessage is! List || rawMessage.isEmpty) {
      return;
    }
    final operation = rawMessage[0];
    if (operation == 'ready') {
      final info = QrTransferSessionInfo(
        sourceSymbolCount: rawMessage[1] as int,
        symbolSize: rawMessage[2] as int,
        payloadLength: rawMessage[3] as int,
        rawLength: rawMessage[4] as int,
        payloadSha256: rawMessage[5] as String,
      );
      _info = info;
      if (!_infoCompleter.isCompleted) {
        _infoCompleter.complete(info);
      }
      return;
    }
    if (operation == 'error') {
      final requestId = rawMessage[1] as int;
      final error = StateError(rawMessage[2] as String);
      final stackTrace = StackTrace.fromString(rawMessage[3] as String);
      if (requestId < 0) {
        if (!_infoCompleter.isCompleted) {
          _infoCompleter.completeError(error, stackTrace);
        }
      } else {
        final completer = _pending.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
      return;
    }
    if (operation != 'batch') {
      return;
    }

    final requestId = rawMessage[1] as int;
    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }
    try {
      final rawFrames = rawMessage[2] as List;
      final frames = rawFrames
          .map((rawFrame) {
            final frame = rawFrame as List;
            final rawModules = frame[3];
            final modules = rawModules is Uint8List
                ? rawModules
                : Uint8List.fromList(List<int>.from(rawModules as List));
            return QrTransferMatrix(
              seed: frame[0] as int,
              frameText: frame[1] as String,
              moduleCount: frame[2] as int,
              modules: modules,
            );
          })
          .toList(growable: false);
      completer.complete(frames);
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }
}

@pragma('vm:entry-point')
void _qrTransferWorkerMain(SendPort mainPort) {
  final commandPort = ReceivePort();
  mainPort.send(commandPort.sendPort);
  QrTransferEncoder? encoder;

  commandPort.listen((rawMessage) {
    if (rawMessage is! List || rawMessage.isEmpty) {
      return;
    }
    final operation = rawMessage[0];
    var requestId = -1;
    try {
      if (operation == 'init') {
        final transfer = rawMessage[1] as TransferableTypedData;
        final payload = transfer.materialize().asUint8List();
        encoder = QrTransferEncoder.prepare(payload);
        final info = encoder!.info;
        mainPort.send(<Object?>[
          'ready',
          info.sourceSymbolCount,
          info.symbolSize,
          info.payloadLength,
          info.rawLength,
          info.payloadSha256,
        ]);
        return;
      }
      if (operation != 'generate') {
        return;
      }

      requestId = rawMessage[1] as int;
      final activeEncoder = encoder;
      if (activeEncoder == null) {
        throw StateError('qr_transfer_worker_not_initialized');
      }
      final startSeed = rawMessage[2] as int;
      final count = rawMessage[3] as int;
      if (startSeed < 0 || count <= 0 || count > 16) {
        throw ArgumentError('invalid QR frame batch');
      }

      final frames = <List<Object>>[];
      for (var offset = 0; offset < count; offset++) {
        final seed = startSeed + offset;
        final matrix = qrTransferMatrixForText(
          activeEncoder.frameTextFor(seed),
          seed: seed,
        );
        frames.add(<Object>[
          matrix.seed,
          matrix.frameText,
          matrix.moduleCount,
          matrix.modules,
        ]);
      }
      mainPort.send(<Object?>['batch', requestId, frames]);
    } on Object catch (error, stackTrace) {
      mainPort.send(<Object?>[
        'error',
        requestId,
        error.toString(),
        stackTrace.toString(),
      ]);
    }
  });
}
