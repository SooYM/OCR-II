import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_app/main.dart';

void main() {
  testWidgets('App renders CaptureScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MedScanApp());
    expect(find.text('MedScan'), findsOneWidget);
  });
}
