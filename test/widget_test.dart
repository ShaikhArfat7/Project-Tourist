import 'package:flutter_test/flutter_test.dart';
import 'package:tourist_safety_app/main.dart';

void main() {
  testWidgets('Tourist Safety App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TouristSafetyApp());

    // Verify that Dashboard title renders.
    expect(find.text('Tourist Safety Monitor'), findsWidgets);
    expect(find.text('Safety Status'), findsOneWidget);
  });
}
