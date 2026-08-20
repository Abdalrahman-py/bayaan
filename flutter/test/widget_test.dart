import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/main.dart';

void main() {
  testWidgets('App launches on the Settings screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BayaanApp());

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Yusuf Ahmed'), findsOneWidget);
    expect(find.text('App Language'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
  });
}
