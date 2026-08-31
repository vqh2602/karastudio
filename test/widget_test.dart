import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/app/theme/editor_theme.dart';

void main() {
  testWidgets('desktop theme defaults to a compact dark editor surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EditorTheme.dark(),
        home: const Scaffold(body: Text('KaraStudio')),
      ),
    );

    expect(find.text('KaraStudio'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('KaraStudio'))).brightness,
      Brightness.dark,
    );
  });
}
