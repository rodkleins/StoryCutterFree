import 'package:flutter_test/flutter_test.dart';
import 'package:story_cutter_free/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const StoryCutterApp());

    expect(find.text('Story Cutter'), findsOneWidget);
    expect(find.text('Cut videos for\nInstagram Stories'), findsOneWidget);
    expect(find.text('Tap to select a video'), findsOneWidget);
  });
}
