import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nullgram/l10n/l10n.dart';
import 'package:nullgram/pages/chat/widgets/chat_composer.dart';
import 'package:nullgram/pages/chat/widgets/emoji_panel.dart';
import 'package:nullgram/widgets/safe_insets.dart';

/// The bottom inset a device with on-screen navigation buttons reports.
const double navigationBarInset = 48;

/// The height of the test screen.
const double screenHeight = 800;

/// Makes the test view report a navigation bar, so `MediaQuery` derives the
/// same insets a real edge-to-edge device would.
///
/// Injecting a `MediaQuery` by hand is not enough here: the geometry these
/// tests assert on comes from the real view, so a hand-written size would
/// disagree with where widgets actually land.
void useEdgeToEdgeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, screenHeight);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: navigationBarInset);
  tester.view.viewPadding = const FakeViewPadding(bottom: navigationBarInset);
  addTearDown(tester.view.reset);
}

/// A screen whose bottom edge is where the composer sits.
///
/// The localization delegates are not optional: the composer reads its
/// labels through `AppLocalizations`, which is absent from a bare
/// `MaterialApp`.
Widget edgeToEdgeApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        children: [const Expanded(child: SizedBox()), child],
      ),
    ),
  );
}

/// A screen with a hand-written `MediaQuery`, for checks that only read inset
/// values rather than laid-out geometry.
Widget insetProbe(MediaQueryData data, ValueChanged<BuildContext> onBuild) {
  return MaterialApp(
    home: MediaQuery(
      data: data,
      child: Builder(
        builder: (context) {
          onBuild(context);
          return const SizedBox();
        },
      ),
    ),
  );
}

Widget composer({
  required TextEditingController controller,
  required FocusNode focusNode,
}) {
  return ChatComposer(
    controller: controller,
    focusNode: focusNode,
    replyTo: ValueNotifier(null),
    editing: ValueNotifier(null),
    onSend: () {},
    onSendOptions: () {},
    onVoice: (_) {},
    onSticker: (_) {},
    onGif: (_) {},
    onAttach: () {},
    onFormat: (_, _) {},
    onInsertLink: () {},
  );
}

void main() {
  group('withBottomSafeArea', () {
    testWidgets('adds the navigation bar inset to a base padding', (
      tester,
    ) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        insetProbe(
          const MediaQueryData(
            padding: EdgeInsets.only(bottom: navigationBarInset),
          ),
          (context) => padding = withBottomSafeArea(
            context,
            const EdgeInsets.fromLTRB(1, 2, 3, 4),
          ),
        ),
      );

      expect(padding.bottom, 4 + navigationBarInset);
      // The other edges are left exactly as the caller wrote them.
      expect(padding.left, 1);
      expect(padding.top, 2);
      expect(padding.right, 3);
    });

    testWidgets('ignores the navigation bar while the keyboard covers it', (
      tester,
    ) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        insetProbe(
          // What a device reports with the keyboard open: the bar's inset has
          // moved into viewInsets, so `padding` drops to zero.
          const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(bottom: navigationBarInset),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          (context) => padding = withBottomSafeArea(context),
        ),
      );

      // Adding the bar here would leave a phantom gap above the keyboard.
      expect(padding.bottom, 0);
    });
  });

  group('sheetBottomPadding', () {
    testWidgets('clears the navigation bar with no keyboard', (tester) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        insetProbe(
          const MediaQueryData(
            padding: EdgeInsets.only(bottom: navigationBarInset),
          ),
          (context) => padding = sheetBottomPadding(context),
        ),
      );

      expect(padding.bottom, navigationBarInset);
    });

    testWidgets('clears the keyboard once it is up', (tester) async {
      late EdgeInsets padding;
      await tester.pumpWidget(
        insetProbe(
          const MediaQueryData(
            padding: EdgeInsets.zero,
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          (context) => padding = sheetBottomPadding(context),
        ),
      );

      expect(padding.bottom, 300);
    });
  });

  group('ChatComposer', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('keeps the text field clear of the navigation bar', (
      tester,
    ) async {
      useEdgeToEdgeScreen(tester);
      await tester.pumpWidget(
        edgeToEdgeApp(composer(controller: controller, focusNode: focusNode)),
      );

      final field = tester.getRect(find.byType(TextField));

      expect(
        field.bottom,
        lessThanOrEqualTo(screenHeight - navigationBarInset),
        reason: 'the composer must not sit under the navigation bar',
      );
    });

    testWidgets('keeps the emoji panel clear of the navigation bar', (
      tester,
    ) async {
      // The panel replaced the composer's own inset in an earlier version, so
      // opening it pushed its bottom row under the navigation bar.
      useEdgeToEdgeScreen(tester);
      await tester.pumpWidget(
        edgeToEdgeApp(composer(controller: controller, focusNode: focusNode)),
      );

      await tester.tap(find.byTooltip('Emoji and stickers'));
      // One frame starts the panel's reveal, the next lets it finish; the
      // rect is only meaningful once AnimatedSize has settled.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final panel = tester.getRect(find.byType(EmojiPanel));

      expect(
        panel.bottom,
        lessThanOrEqualTo(screenHeight - navigationBarInset),
        reason: 'the emoji panel must not sit under the navigation bar',
      );
    });
  });
}
