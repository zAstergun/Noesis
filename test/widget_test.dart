import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(NoesisApp.new, isNotNull);
  });
}
