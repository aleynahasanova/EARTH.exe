import 'package:flutter_test/flutter_test.dart';
import 'package:earth_exe/main.dart';

void main() {
  testWidgets('EARTH.exe launches successfully', (tester) async {
    await tester.pumpWidget(const EarthExeApp());

    expect(find.text('We have a situation.'), findsOneWidget);
  });
}
