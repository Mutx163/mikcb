import 'dart:io';
import 'dart:typed_data';

/// Thrown when a file chosen for import is larger than the caller allows.
///
/// Callers are expected to catch this and show a localised message; it exists so
/// that "too big" never degrades into a generic read failure.
class ImportFileTooLarge implements Exception {
  const ImportFileTooLarge(this.actualBytes, this.maxBytes);

  final int actualBytes;
  final int maxBytes;

  @override
  String toString() =>
      'ImportFileTooLarge: $actualBytes bytes exceeds the $maxBytes byte limit';
}

/// Reads [path] for import, refusing anything over [maxBytes] *before* the bytes
/// are pulled into memory.
///
/// Why the two steps instead of just reading: `FilePicker` with
/// `withData: true` hands the whole file over as a byte list, so by the time a
/// caller could inspect `bytes.length` the memory was already spent. On Android
/// an out-of-memory condition kills the process outright rather than raising
/// something catchable, so the only place a limit can be enforced is before the
/// read. An xlsx is additionally a zip container whose on-disk size badly
/// understates how much it expands when parsed.
Future<Uint8List> readImportFileBytes(
  String path, {
  required int maxBytes,
}) async {
  final length = await File(path).length();
  if (length > maxBytes) {
    throw ImportFileTooLarge(length, maxBytes);
  }
  return File(path).readAsBytes();
}

/// Formats a byte budget for display, e.g. `20 MB`.
String formatByteBudget(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).round()} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).round()} KB';
  }
  return '$bytes B';
}
