import 'package:flutter_test/flutter_test.dart';

import 'package:spherecore/main.dart';

void main() {
  testWidgets('SphereCore app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const HollowCoreApp());
    await tester.pumpAndSettle();
  });
}
