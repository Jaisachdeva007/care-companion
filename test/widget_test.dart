import 'package:flutter_test/flutter_test.dart';
import 'package:care_companion/app.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CareCompanionApp());

    expect(find.text('Care Companion'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}