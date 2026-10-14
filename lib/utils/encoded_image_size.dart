import 'dart:ui' as ui;

/// 读一张**已落盘**图片的编码尺寸（宽 × 高），不整图解码。
///
/// 用引擎的 `ui.ImageDescriptor.encoded`（fromFilePath 按需读头部）：相机原图 20–30 MB
/// 也不会进 Dart 堆，与 `wallpaper_position_picker_sheet.dart` 的正解同源。失败（文件
/// 不在 / 不是图片 / 引擎解码器不可用）返回 null —— 调用方据此跳过校验，不影响主流程。
Future<(int, int)?> readEncodedImageSize(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (descriptor.width, descriptor.height);
  } on Object {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
