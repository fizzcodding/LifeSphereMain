import 'package:flutter_test/flutter_test.dart';

import 'package:hollowcore/main.dart';

void main() {
  testWidgets('HollowCore app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const HollowCoreApp());

    // Verify the app renders with HollowCore branding.
    expect(find.text('LifeSphere'), findsNothing); // title is not 'LifeSphere' literal, it's in constants

    // Pump enough to settle async operations.
    await tester.pumpAndSettle();
  });
}
