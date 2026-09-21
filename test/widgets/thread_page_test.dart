import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/l10n/app_localizations.dart';
import 'package:nullgram/pages/chat/thread_page.dart';
import 'package:nullgram/services/message_history.dart';
import 'package:nullgram/theme/app_theme.dart';

/// A source that never talks to TDLib, so the page can be pumped in a test.
class SilentSource implements HistorySource {
  @override
  int get chatId => 10;

  @override
  Future<List<Map<String, dynamic>>> load({
    required int fromMessageId,
    required int offset,
    required int limit,
    required bool onlyLocal,
  }) async =>
      const [];

  @override
  bool owns(Map<String, dynamic> message) => false;
}

Map<String, dynamic> rootMessage() => {
      'id': 4,
      'chatId': 10,
      'date': 1700000000,
      'isOutgoing': false,
      'content': {
        '@type': 'MessageText',
        'text': {'text': 'The post'},
      },
    };

Map<String, dynamic> threadInfo() => {
      'chatId': 10,
      'messageThreadId': 4,
      'messages': [rootMessage()],
    };

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      // MessageBubble reads the ChatColors theme extension, so the real theme
      // has to be in play.
      theme: buildLightTheme(null),
      home: child,
    );

/// Pumps [page] on a surface tall enough for the root post, the list and the
/// composer; the default 800px one overflows the empty state.
Future<void> pumpPage(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host(page));
  await tester.pump();
}

void main() {
  testWidgets('heads the comment list with the root post', (tester) async {
    await pumpPage(tester, ThreadPage(
      chat: const {'id': 10, 'title': 'Discussion'},
      threadInfo: threadInfo(),
      history: MessageHistoryController(source: SilentSource()),
    ));

    // The post scrolls with the comments rather than sitting in a panel of
    // its own, so it has to be inside the list. Matched by substring: the
    // bubble appends its timestamp to the text as a widget span.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.textContaining('The post'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('marks where the comments start', (tester) async {
    await pumpPage(tester, ThreadPage(
      chat: const {'id': 10, 'title': 'Discussion'},
      threadInfo: threadInfo(),
      history: MessageHistoryController(source: SilentSource()),
    ));

    expect(find.text('No comments yet'), findsOneWidget);
  });

  testWidgets('offers the composer when the user can post', (tester) async {
    await pumpPage(tester, ThreadPage(
      chat: const {'id': 10, 'title': 'Discussion'},
      threadInfo: threadInfo(),
      history: MessageHistoryController(source: SilentSource()),
    ));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Join discussion'), findsNothing);
  });

  testWidgets('offers a join button instead of the composer when blocked',
      (tester) async {
    await pumpPage(tester, ThreadPage(
      chat: const {'id': 10, 'title': 'Discussion'},
      threadInfo: threadInfo(),
      history: MessageHistoryController(source: SilentSource()),
      canPostInitially: false,
    ));

    expect(find.text('Join discussion'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
