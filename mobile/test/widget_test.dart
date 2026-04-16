import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('renders app shell', (tester) async {
    await tester.pumpWidget(const NationalRuralSampleApp());

    expect(find.text('Plant Disease Demo'), findsOneWidget);
    expect(find.text('Backend API'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn từ thư viện'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });
}
