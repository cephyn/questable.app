import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_cards/src/widgets/branding.dart';

void main() {
  testWidgets('BrandingTitle shows logo and text', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: AppBar(title: BrandingTitle())),
    ));

    await tester.pumpAndSettle();

    // Should show an Image widget using the samples asset
    expect(find.byType(Image), findsOneWidget);

    final Image img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<AssetImage>());
    final provider = img.image as AssetImage;
    expect(provider.assetName, 'samples/questable_logo.png');

    // And the text label should appear
    expect(find.text('Questable'), findsOneWidget);
  });
}
