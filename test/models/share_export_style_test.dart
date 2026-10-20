import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/share_export_style.dart';

/// 分享图底色是**用户可见产物**的一部分：改它等于改分享出去的每一张图。
///
/// 它原先在 `services/*_share_service.dart` 里取自 `HyperosTokens.background`
/// （屏内设置页的灰底令牌）。task-10 把它下沉成业务常量 `ShareExportStyle.background`
/// ——理由是「分享图恒用亮色底」是**业务约束**（透明孔洞在被分享出去后不会变成
/// 黑块），不是屏内 UI 令牌，将来主题或屏内灰度改版时两者没有理由一起动。
///
/// 这条钉两件事：值逐位不变；不透明。
void main() {
  test('分享图底色：逐位等于历史取值', () {
    // 历史上 = HyperosTokens.background = HyperosMiuixSpec.settingsBackground
    // = 0xFFF2F2F2。下沉只是搬家，像素不许动。
    expect(ShareExportStyle.background, const Color(0xFFF2F2F2));
  });

  test('分享图底色必须不透明', () {
    expect(
      ShareExportStyle.background.a,
      1.0,
      reason:
          '不透明是它存在的全部理由 —— 离屏捕获采不到背后内容，'
          '半透明底色会让文档里的孔洞在分享出去的 PNG 上变成黑块',
    );
  });
}
