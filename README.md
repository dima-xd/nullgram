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
- Custom (premium) emoji in text, reactions and emoji statuses
- Silent send, "send when online" and scheduled messages
- Bot inline keyboards, including callback buttons
- Per-chat message search, shared-media browser, jump-to-message

**People and groups**
- Contacts, group and channel creation, invite links, join by link
- Member lists with promote, dismiss and remove; group name, photo, about
- Secret (end-to-end encrypted) chats
- Profiles with bio, username, phone, shared actions and blocking
- Global search across chats, public chats and message text

**Calls**
- 1:1 voice and video calls, plus a call log

**Settings**
- Material You theming, light/dark/AMOLED
- Notification defaults per chat scope, blocked users, two-step
  verification, active devices, storage usage and cache clearing

---

## 📝 Not implemented yet
- [ ] Multi-account support
- [ ] Live location sharing
- [ ] Custom chat wallpapers
- [ ] Channel comment threads
- [ ] Inline bot queries (`@bot query`)
- [ ] Stories

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

2. Open the `.env` file and fill in your values

3. Get dependencies
   ```bash
   flutter pub get
   ```

4. Run the app
   ```bash
   flutter run
    ```

---

## ⚡ Status
The core client is usable day to day. Contributions, ideas, and pull
requests are welcome.

---