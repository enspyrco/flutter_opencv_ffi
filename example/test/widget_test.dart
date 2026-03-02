import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('App shows OpenCV version in app bar', (tester) async {
    await tester.pumpWidget(const OpenCvExampleApp());
    // The app bar should contain the OpenCV version.
    expect(find.textContaining('OpenCV'), findsOneWidget);
  });
}
