/// The app version reported to Telegram, shown in the account's session list.
///
/// Kept in sync with `version` in `pubspec.yaml` by hand: reading the real
/// value needs `package_info_plus`, and TDLib wants it before the first frame.
const String appVersion = '1.0.0';
