import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/l10n/app_localizations.dart';
import 'package:nullgram/pages/chat/widgets/thread_button.dart';

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

Map<String, dynamic> replyInfo({
  int replyCount = 3,
  int lastMessageId = 20,
  int lastReadInboxMessageId = 20,
}) =>
    {
      'replyCount': replyCount,
      'lastMessageId': lastMessageId,
      'lastReadInboxMessageId': lastReadInboxMessageId,
    };

void main() {
  testWidgets('shows a comment count for a channel post', (tester) async {
    await tester.pumpWidget(host(
      ThreadButton(replyInfo: replyInfo(), isChannelPost: true, onTap: () {}),
    ));

    expect(find.text('3 comments'), findsOneWidget);
  });

  testWidgets('shows a reply count in a group', (tester) async {
    await tester.pumpWidget(host(
      ThreadButton(replyInfo: replyInfo(), isChannelPost: false, onTap: () {}),
    ));

    expect(find.text('3 replies'), findsOneWidget);
  });

  testWidgets('marks unread replies with a dot', (tester) async {
    await tester.pumpWidget(host(
      ThreadButton(
        replyInfo: replyInfo(lastMessageId: 30, lastReadInboxMessageId: 20),
        isChannelPost: true,
        onTap: () {},
      ),
    ));

    expect(find.byKey(const Key('threadUnreadDot')), findsOneWidget);
  });

  testWidgets('hides the dot when everything is read', (tester) async {
    await tester.pumpWidget(host(
      ThreadButton(replyInfo: replyInfo(), isChannelPost: true, onTap: () {}),
    ));

    expect(find.byKey(const Key('threadUnreadDot')), findsNothing);
  });

  testWidgets('reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      ThreadButton(
        replyInfo: replyInfo(),
        isChannelPost: true,
        onTap: () => taps++,
      ),
    ));

    await tester.tap(find.byType(ThreadButton));

    expect(taps, 1);
  });
}
