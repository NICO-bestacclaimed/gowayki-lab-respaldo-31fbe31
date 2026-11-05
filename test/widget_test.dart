import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/app.dart';
import 'package:gowayki_lab/data/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServiceLocator.init(useFirebase: false);
  });

  testWidgets('arranca splash Gowayki Lab', (tester) async {
    await tester.pumpWidget(const GowaykiLabApp());
    expect(find.text('Gowayki Lab'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
  });
}
