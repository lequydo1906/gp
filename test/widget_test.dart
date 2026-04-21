import 'package:flutter_test/flutter_test.dart';

import 'package:giapha/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GiaPhaApp());

    // Verify app title is displayed
    expect(find.text('GIA PHẢ DÒNG HỌ'), findsOneWidget);
  });
}
