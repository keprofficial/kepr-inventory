import 'package:flutter_test/flutter_test.dart';

import 'package:kepr_inventory/main.dart';

void main() {
  testWidgets('shows Supabase setup guidance without configuration',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KeprApp());

    expect(find.text('Connect KEPR Inventory'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
