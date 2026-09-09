import 'package:flutter/material.dart';

/// Grows [base] at the bottom so content can clear the OS navigation bar.
///
/// The app draws edge to edge — Android 15 makes that mandatory — so a
/// `Scaffold` body extends underneath the navigation bar. For a scrolling list
/// that is the right look: content passes under the bar. But without this
/// padding the *last* row stays stuck beneath it and can never be read.
///
/// Reads `padding` rather than `viewPadding` deliberately. `viewPadding`
/// ignores the keyboard, so using it would leave a phantom gap above an open
/// keyboard, which the `Scaffold` has already made room for; `padding` falls to
/// zero exactly when the keyboard covers the navigation bar.
EdgeInsets withBottomSafeArea(
  BuildContext context, [
  EdgeInsets base = EdgeInsets.zero,
]) =>
    base.copyWith(bottom: base.bottom + MediaQuery.paddingOf(context).bottom);

/// The padding a bottom sheet needs below its content.
///
/// A modal sheet reaches the bottom of the screen, so it has to clear the
/// navigation bar itself — or the keyboard, once that covers the bar. The two
/// insets are summed because `padding` already excludes whatever `viewInsets`
/// takes, so only one of them is ever non-zero at the bottom edge.
EdgeInsets sheetBottomPadding(BuildContext context) {
  final media = MediaQuery.of(context);
  return EdgeInsets.only(
    bottom: media.viewInsets.bottom + media.padding.bottom,
  );
}
