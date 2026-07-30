import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// Locates the MiuixSwitch thumb: the only circle-shaped [Container]
/// inside [HyperosSwitch] (the track is a rounded-rect AnimatedContainer).
Finder _thumbFinder() {
  return find.descendant(
    of: find.byType(HyperosSwitch),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  );
}

void main() {
  group('HyperosSwitch layout', () {
    testWidgets('off thumb is 20dp wide at 4dp inset', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: HyperosSwitch(value: false, onChanged: _noop)),
          ),
        ),
      );

      final switchBox = tester.getRect(find.byType(HyperosSwitch));
      final thumbBox = tester.getRect(_thumbFinder());

      expect(thumbBox.width, HyperosMiuixSwitch.thumbSize);
      expect(thumbBox.height, HyperosMiuixSwitch.thumbSize);
      expect(
        thumbBox.left - switchBox.left,
        closeTo(HyperosMiuixSwitch.thumbOffInset, 0.5),
      );
      expect(thumbBox.center.dx, lessThan(switchBox.center.dx));
    });

    testWidgets('on thumb is 20dp wide at 25dp inset', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: HyperosSwitch(value: true, onChanged: _noop)),
          ),
        ),
      );

      final switchBox = tester.getRect(find.byType(HyperosSwitch));
      final thumbBox = tester.getRect(_thumbFinder());

      expect(thumbBox.width, HyperosMiuixSwitch.thumbSize);
      expect(
        thumbBox.left - switchBox.left,
        closeTo(HyperosMiuixSwitch.thumbOnInset, 0.5),
      );
      expect(thumbBox.center.dx, greaterThan(switchBox.center.dx));
    });
  });
}

void _noop(bool _) {}
