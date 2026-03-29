import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lockmylaptop_mobile_android/main.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const LockMyLaptopApp());
    await tester.pumpAndSettle();

    expect(find.text('Enter 4-digit laptop code'), findsOneWidget);
  });
}
