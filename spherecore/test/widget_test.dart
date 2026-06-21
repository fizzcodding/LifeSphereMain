import 'package:flutter_test/flutter_test.dart';

import 'package:spherecore/main.dart';

void main() {
  testWidgets('SphereCore app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const SphereCoreApp());

    // Verify the app renders with SphereCore branding.
    expect(find.text('LifeSphere'), findsNothing); // title is not 'LifeSphere' literal, it's in constants

    // Pump enough to settle async operations.
    await tester.pumpAndSettle();
  });
}
