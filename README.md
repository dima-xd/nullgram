# Nullgram

**Nullgram** is a fully custom Telegram client built **from scratch in Flutter**, without any of the messy original Telegram code.  
The goal is to create a clean, modern, and performant alternative to the official app.

Currently, Nullgram is being developed **only for Android**.  
If the author ever gets an iPhone - iOS support *might* become a thing too.

---

## ❌ Why

The author doesn’t like what Telegram has become -  
bloated with **ads**, **Telegram Premium**, and all the **NFT-style scam nonsense**.

So instead of complaining, Nullgram is being built as a **clean and free alternative**,  
where the focus is on **simplicity, and functionality** - not monetization.

---

## 🚀 Features

**Chats**
- Chat list with folders, archive, pinning, muting, mark as read/unread
- Creating, editing, reordering and deleting chat folders
- Unread counters, mention badges, draft previews, delivery/read ticks
- Live typing indicators, connection status, unread divider in history

**Messages**
- Text with MarkdownV2 formatting, spoilers, tappable links and mentions
- Replies with quoted preview, forwarding, editing, pinning, reactions
- Multi-select for bulk copy / forward / delete (for me or for everyone)
- Sending photos, albums, videos, documents, polls and contacts
- Voice messages: hold to record, slide to cancel, real waveforms
- Round video messages, and fullscreen playback for every video
- Stickers, including animated (TGS), plus saved GIFs
- Sticker packs: installed, trending and search, with one-tap install
- Sticker search by emoji and GIF search through Telegram's inline bot
- Custom (premium) emoji in text, reactions and emoji statuses
- Silent send, "send when online" and scheduled messages
- Bot inline keyboards, callback buttons and the bot's command menu
- Per-chat message search, shared-media browser, jump-to-message
- Link previews, with the site name, title, description and image
- Message translation, reaction and read-receipt lists
- Per-chat auto-delete timer
- Channel comment threads and forum topics

**People and groups**
- Sign-up for a new phone number, including the Terms of Service
- Contacts, group and channel creation, invite links, join by link
- Member lists with promote, dismiss and remove; group name, photo, about
- Secret (end-to-end encrypted) chats
- Profiles with bio, username, phone, shared actions and blocking
- Global search across chats, public chats and message text
- Opens `t.me` and `tg://` links from other apps, and accepts text, photos,
  videos and files shared into it

**Calls**
- 1:1 voice and video calls, plus a call log

**Accounts**
- Unlimited accounts, all online at once: an account that is not on screen
  still delivers notifications and unread badges
- Switching from the drawer header, with no re-login and nothing re-downloaded

**Settings**
- Material You theming, light/dark/AMOLED
- Interface language (English and Russian), which also moves TDLib's own
  language pack
- Privacy rules for last seen, profile photo, bio, phone number, forwards,
  calls, group invites and voice messages
- Passcode lock with biometric unlock and an auto-lock delay
- MTProto/SOCKS5/HTTP proxies, with ping and `t.me/proxy` link import
- Automatic media download limits per connection, mobile data and Wi-Fi
- Notification defaults per chat scope, blocked users, two-step
  verification, active devices, storage usage and cache clearing

---

## 📝 Not implemented yet
- [ ] Group voice and video chats
- [ ] Live location sharing and maps in location messages
- [ ] Custom chat wallpapers
- [ ] Inline bot queries in the composer (`@bot query`); GIF search already
      uses them
- [ ] Stories
- [ ] Group and channel administration beyond members: permissions, slow mode,
      the event log, join requests, statistics, reporting
- [ ] Editing a caption or replacing the media of a sent message
- [ ] Invoices, games, paid media and gifts, which show as unsupported

Roaming is not a separate automatic-download profile: nothing in the plugin
layer distinguishes it from ordinary mobile data.

Signing in needs an `api_id` of your own from my.telegram.org. With official
Telegram application credentials the server demands a Play Integrity or
reCAPTCHA token (`updateApplicationRecaptchaVerificationRequired`) and only
accepts one issued to the official app, so no other package can ever complete
a new sign-in. The app aborts that verification and says so on the login
screen rather than waiting silently.

An incoming call reaches only the account on screen. TDLib file ids belong to
the client that issued them, so an account that has never been on screen shows
an initial rather than an avatar in the switcher until its photo is on disk.

---

## 📱 Platforms
- ✅ Android (in development)
- ❌ iOS (maybe someday…)

---

## 🧩 Installation

1. Clone the repository
   ```bash
   git clone https://github.com/dima-xd/nullgram.git
   cd nullgram
   ```   

2. Copy `assets/config/env.example` to `assets/config/env` and fill in your
   `API_ID`, `API_HASH` and `DB_ENCRYPTION_KEY`. That file is git-ignored and
   read only when a build passes no credentials of its own.

3. Get dependencies
   ```bash
   flutter pub get
   ```

4. Run the app
   ```bash
   flutter run
    ```

### Credentials in CI

A release build takes the same three values as compile-time defines, so they
never have to be committed:

```bash
flutter build apk --release --split-per-abi \
    --dart-define=API_ID="$API_ID" \
    --dart-define=API_HASH="$API_HASH" \
    --dart-define=DB_ENCRYPTION_KEY="$DB_ENCRYPTION_KEY"
```

The workflow in `.github/workflows/build.yml` reads them from the repository
secrets of the same names and fails before building when one is missing. A
define always wins over `assets/config/env`.

`DB_ENCRYPTION_KEY` is not interchangeable: an installed app cannot read a
database written with a different key, so changing it signs every account out.

---

## ⚡ Status
The core client is usable day to day. Contributions, ideas, and pull
requests are welcome.

---