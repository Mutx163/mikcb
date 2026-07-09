import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';
import 'package:university_timetable/utils/home_page_background.dart';

void main() {
  group('homePageHeaderBlurBandRect', () {
    test('includes status bar from top when scope enabled', () {
      const safeTop = 48.0;
      const extend = homePageFrostedRegionSeamOverlap;

      final layout = homePageHeaderBlurBandRect(
        safeAreaTop: safeTop,
        includeStatusBar: true,
        extendBottom: extend,
      );

      expect(layout.top, 0);
      expect(layout.height, safeTop + homePageHeaderContentHeight + extend);
    });

    test('starts below status bar when scope disabled', () {
      const safeTop = 48.0;
      const extend = homePageFrostedRegionSeamOverlap;

      final layout = homePageHeaderBlurBandRect(
        safeAreaTop: safeTop,
        includeStatusBar: false,
        extendBottom: extend,
      );

      expect(layout.top, safeTop);
      expect(layout.height, homePageHeaderContentHeight + extend);
    });
  });
}
