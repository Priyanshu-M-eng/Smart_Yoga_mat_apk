// Basic smoke test for app boot.
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_yoga_mat_app/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const SmartYogaMatApp());
    expect(find.text('Smart Yoga Mat'), findsOneWidget);
  });
}
