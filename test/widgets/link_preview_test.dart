import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/pages/chat/widgets/message_link_preview.dart';
import 'package:nullgram/theme/app_theme.dart';

Widget host(Widget child) => MaterialApp(
      theme: buildLightTheme(null),
      home: Scaffold(body: child),
    );

Map<String, dynamic> preview({
  String? siteName = 'Example',
  String? title = 'A headline',
  String? description = 'What the page is about',
}) =>
    {
      '@type': 'LinkPreview',
      'url': 'https://example.com/story',
      'displayUrl': 'example.com/story',
      'siteName': siteName,
      'title': title,
      'description': {'@type': 'FormattedText', 'text': description},
      'type': {'@type': 'LinkPreviewTypeArticle'},
      'showLargeMedia': false,
    };

void main() {
  testWidgets('shows the site name, title and description', (tester) async {
    await tester.pumpWidget(
      host(MessageLinkPreview(linkPreview: preview())),
    );

    expect(find.text('Example'), findsOneWidget);
    expect(find.text('A headline'), findsOneWidget);
    expect(find.text('What the page is about'), findsOneWidget);
  });

  testWidgets('drops the empty fields instead of drawing blank rows',
      (tester) async {
    await tester.pumpWidget(
      host(MessageLinkPreview(
        linkPreview: preview(siteName: '', description: null),
      )),
    );

    expect(find.text('A headline'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('renders nothing when the preview carries no content',
      (tester) async {
    await tester.pumpWidget(
      host(MessageLinkPreview(
        linkPreview: preview(siteName: null, title: null, description: null),
      )),
    );

    expect(find.byType(Text), findsNothing);
  });
}
