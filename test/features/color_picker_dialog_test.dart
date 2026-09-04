import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/features/inspector/color_picker_dialog.dart';

void main() {
  testWidgets('offers both a full picker and suggested colors', (tester) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showKaraColorPicker(
                  context,
                  initialColor: 0xFFFFFFFF,
                  suggestions: const [0xFFFFFFFF, 0xFFFFC107],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Hue'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
    expect(find.text('MÀU GỢI Ý'), findsOneWidget);

    final suggestedColor = find.descendant(
      of: find.byTooltip('#FFFFC107'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(suggestedColor);
    await tester.tap(suggestedColor);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chọn màu'));
    await tester.pumpAndSettle();

    expect(result, 0xFFFFC107);
  });
}
