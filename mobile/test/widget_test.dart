import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('renders japanese app shell', (tester) async {
    await tester.pumpWidget(const NationalRuralSampleApp());

    expect(find.text('植物病害診断デモ'), findsOneWidget);
    expect(find.text('バックエンド API'), findsOneWidget);
    expect(find.text('写真を撮る'), findsOneWidget);
    expect(find.text('ギャラリーから選ぶ'), findsOneWidget);
    expect(find.text('診断する'), findsOneWidget);
    expect(find.text('まだ画像が選択されていません'), findsOneWidget);
    expect(find.text('2. Batch test trên app mobile'), findsNothing);
  });
}
