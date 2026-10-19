import 'package:flutter_test/flutter_test.dart';
import 'package:tourist_safety_app/main.dart';

void main() {
  testWidgets('Tourist Safety App renders Home dashboard and navigation tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TouristSafetyApp());

    expect(find.text('Tourist Safety Monitor'), findsOneWidget);
    expect(find.text('Safety & Hazard Assessment'), findsOneWidget);
    expect(find.text('Quick Emergency Access'), findsOneWidget);
    expect(find.text('Nearby Police'), findsOneWidget);
    expect(find.text('Nearby Hospitals'), findsOneWidget);
  });
}
