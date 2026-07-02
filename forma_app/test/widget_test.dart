import 'package:flutter_test/flutter_test.dart';

import 'package:forma/main.dart';

void main() {
  testWidgets('renders Forma shell', (WidgetTester tester) async {
    await tester.pumpWidget(const FormaApp());

    expect(find.text('Forma'), findsOneWidget);
  });
}
