import 'package:flutter_test/flutter_test.dart';
import 'package:wasteland_warriors/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WastelandWarriorsApp());
    expect(find.byType(WastelandWarriorsApp), findsOneWidget);
  });
}
