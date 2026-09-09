import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/pages/chat/widgets/image_details.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('shows counter for multiple photos', (tester) async {
    await tester.pumpWidget(wrap(const ImageDetails(
      photoPaths: ['/tmp/a.jpg', '/tmp/b.jpg'],
      heroTag: 'h',
    )));

    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('hides counter for a single photo', (tester) async {
    await tester.pumpWidget(wrap(const ImageDetails(
      photoPaths: ['/tmp/a.jpg'],
      heroTag: 'h',
    )));

    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('renders the caption for the current photo', (tester) async {
    await tester.pumpWidget(wrap(const ImageDetails(
      photoPaths: ['/tmp/a.jpg'],
      captions: ['hello world'],
      heroTag: 'h',
    )));

    expect(find.text('hello world'), findsOneWidget);
  });
}
