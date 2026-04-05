import 'package:flutter_test/flutter_test.dart';

import 'package:open_code_lumina/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());

    expect(find.text('Lumina'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
  });
}
