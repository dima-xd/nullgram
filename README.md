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
- Live typing indicators and connection status

**Messages**
- Text with MarkdownV2 formatting, spoilers, tappable links and mentions
- Replies with quoted preview, forwarding, editing, pinning, reactions
- Multi-select for bulk copy / forward / delete (for me or for everyone)
- Sending photos, albums, videos, documents and polls
- Rendering GIFs, contacts, locations, venues and dice
- Voice messages: hold to record, slide to cancel, real waveforms
- Stickers, including animated (TGS) playback
- Per-chat message search and jump-to-message

**People and groups**
- Contacts, group and channel creation, invite links, join by link
- Profiles with bio, username, phone, shared actions and blocking
- Global search across chats, public chats and message text

**Calls**
- 1:1 voice and video calls, plus a call log

**Settings**
- Material You theming, light/dark/AMOLED
- Notification defaults per chat scope, blocked users, active devices,
  storage usage and cache clearing

---

## 📝 Not implemented yet
- [ ] Multi-account support
- [ ] Video messages (round notes)
- [ ] Secret chat UI
- [ ] Shared media gallery in profiles
- [ ] Group member and admin management
- [ ] Scheduled and silent messages
- [ ] Live location sharing
- [ ] Custom chat wallpapers
- [ ] Two-step verification setup

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