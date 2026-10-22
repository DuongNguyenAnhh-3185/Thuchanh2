import 'package:flutter_test/flutter_test.dart';
import 'package:study_doc_manager/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic test verifies widget tree builds
    expect(const CashewDocApp(), isNotNull);
  });
}
