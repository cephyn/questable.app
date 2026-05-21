import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_cards/src/quest_card/public_quest_card_list_view.dart';
import 'package:quest_cards/src/widgets/branding.dart';

void main() {
  testWidgets('PublicBrowseHero shows discovery copy, actions, and concept art', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicBrowseHero(onSignIn: () {}, onCreateAccount: () {}),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Questable'), findsOneWidget);
    expect(find.text('Discover your next adventure'), findsOneWidget);
    expect(
      find.text(
        'Browse quest cards for tabletop role-playing games. Sign in to create, edit or contribute to the collection.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    final Finder marks = find.byType(QuestableMark);
    expect(marks, findsOneWidget);

    final QuestableMark mark = tester.widget<QuestableMark>(marks);
    expect(mark.size, 28);
    expect(mark.assetName, 'samples/questable_ico_256.png');

    final Image conceptImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'samples/questable_concept.png',
      ),
    );
    expect(conceptImage.fit, BoxFit.cover);
  });
}
