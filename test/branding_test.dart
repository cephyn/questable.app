import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_cards/src/widgets/branding.dart';

void main() {
  testWidgets('BrandingTitle shows logo and text', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(title: BrandingTitle())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(QuestableMark), findsOneWidget);

    final QuestableMark mark = tester.widget<QuestableMark>(
      find.byType(QuestableMark),
    );
    expect(mark.size, 28);
    expect(mark.assetName, 'samples/questable_ico_256.png');

    // And the text label should appear
    expect(find.text('Questable'), findsOneWidget);
  });
}
