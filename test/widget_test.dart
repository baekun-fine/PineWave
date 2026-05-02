import 'package:flutter_test/flutter_test.dart';
import 'package:music_daw_player/app.dart';

void main() {
  testWidgets('renders the multitrack player shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MusicDawApp());

    expect(find.text('PineWave'), findsWidgets);
    expect(find.text('Open Files'), findsOneWidget);
    expect(find.text('Add Track'), findsOneWidget);
  });
}
