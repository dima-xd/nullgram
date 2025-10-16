import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/home/widgets/chat_list_view.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
import '../../tdlib/models/chat.dart';
import '../../tdlib/models/chat_folder.dart';
import '../chat/chat_page.dart';
import 'menu.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<Map<int, Map<String, dynamic>>> chatsNotifier = ValueNotifier({});
  final ValueNotifier<List<ChatFolderInfo>> folders = ValueNotifier([]);
  int selectedFolderIndex = 0;

  TabController? _tabController;

  final Map<int, int> linkedChats = {};
  final Map<int, bool> memberStatus = {};

  final Map<int, dynamic> users = {};
  final Map<int, dynamic> supergroups = {};

  final Map<String, bool> _fileExistsCache = {};
  final Map<String, Uint8List?> _miniThumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadChats();

    TDLibClient.chatUpdates.listen((update) async {
      final type = update['@type'];
      switch (type) {
        case updateNewChatConst:
          final chatData = update['chat'] as Map<String, dynamic>;
          final chatId = chatData['id'] as int;

          final user = users[chatId];
          if (user != null) {
            chatData["user"] = user;
          }

          final supergroup = supergroups[chatId];
          if (supergroup != null) {
            chatData["supergroup"] = supergroup;
          }

          var status = memberStatus[chatData['type']?["supergroupId"]] ?? true;
          if (!status) return;

          final photo = chatData['photo'];
          if (photo != null &&
              photo['small']?['local']?['path'] == "" &&
              photo['small']?['remote']?['id'] != null) {
            TDLibClient.downloadFile(fileId: photo['small']['id']).catchError((_) {});
          }

          final updatedChats = Map<int, Map<String, dynamic>>.from(chatsNotifier.value);
          updatedChats[chatId] = chatData;
          chatsNotifier.value = updatedChats;

        case updateChatFoldersConst:
          final updateFolders = UpdateChatFolders.fromJson(update);

          final allChatsFolder = ChatFolderInfo(
            id: -1,
            colorId: 0,
            hasMyInviteLinks: false,
            isShareable: false,
            name: ChatFolderName(text: "All chats", animateCustomEmoji: false),
            icon: ChatFolderIcon(name: ""),
          );

          final newFolders = [allChatsFolder, ...updateFolders.chatFolders];
          if (_tabController == null || _tabController!.length != newFolders.length) {
            _tabController?.dispose();
            _tabController = TabController(length: newFolders.length, vsync: this)
              ..addListener(() {
                selectedFolderIndex = _tabController!.index;
              });
          }
          folders.value = newFolders;

          setState(() {});

        case updateChatPositionConst:
          final chatId = update['chatId'] as int;
          final position = update['position'] as Map<String, dynamic>;
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null) {
            final positions = List<Map<String, dynamic>>.from(existingChat['positions'] ?? []);
            final posIndex = positions.indexWhere(
                    (p) => p['list']?['chatFolderId'] == position['list']?['chatFolderId']
            );

            if (posIndex != -1) {
              positions[posIndex] = position;
            } else {
              positions.add(position);
            }

            final updatedChats = Map<int, Map<String, dynamic>>.from(chatsNotifier.value);
            updatedChats[chatId] = {...existingChat, 'positions': positions};
            chatsNotifier.value = updatedChats;
          }

        case updateChatLastMessageConst:
          final chatId = update['chatId'] as int;
          final lastMessage = update['lastMessage'];
          final newPositions = update['positions'] as List<dynamic>?;
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null) {
            final mergedPositions = List<Map<String, dynamic>>.from(
                newPositions?.map((e) => e as Map<String, dynamic>) ?? []
            );

            final existingPositions = existingChat['positions'] as List<dynamic>?;
            if (existingPositions != null) {
              for (final existingPos in existingPositions) {
                final existingPosMap = existingPos as Map<String, dynamic>;
                if (!mergedPositions.any((p) =>
                p['list']?['chatFolderId'] == existingPosMap['list']?['chatFolderId'])) {
                  mergedPositions.add(existingPosMap);
                }
              }
            }

            final updatedChats = Map<int, Map<String, dynamic>>.from(chatsNotifier.value);
            updatedChats[chatId] = {
              ...existingChat,
              'lastMessage': lastMessage,
              'positions': mergedPositions,
            };
            chatsNotifier.value = updatedChats;
          }

        case updateChatAddedToListConst:
          final chatId = update['chatId'] as int;
          final folderId = update['chatList']?['chatFolderId'] as int?;
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null && folderId != null) {
            final folderIds = List<int>.from(existingChat['folderIds'] ?? []);

            if (!folderIds.contains(folderId)) {
              folderIds.add(folderId);
              final updatedChats = Map<int, Map<String, dynamic>>.from(chatsNotifier.value);
              updatedChats[chatId] = {...existingChat, 'folderIds': folderIds};
              chatsNotifier.value = updatedChats;
            }
          }

        case updateSupergroupConst:
          var isMember = true;
          var type = update["supergroup"]["status"]["@type"];
          if (type == "ChatMemberStatusLeft" ||
              type == "ChatMemberStatusBanned") {
            isMember = false;
          }

          final id = "-100${update["supergroup"]["id"]}";
          supergroups[int.parse(id)] = update["supergroup"];
          memberStatus[update["supergroup"]["id"]] = isMember;

        case updateChatReadInboxConst:
          final chatId = update["chatId"] as int;
          final unreadCount = update["unreadCount"] as int;
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null) {
            final updatedChats = Map<int, Map<String, dynamic>>.from(chatsNotifier.value);
            updatedChats[chatId] = {...existingChat, 'unreadCount': unreadCount};
            chatsNotifier.value = updatedChats;
          }
        case updateUserConst:
          users[update["user"]["id"]] = update["user"];
      }
    });

    TDLibClient.filesUpdates.listen((update) async {
      final type = update['@type'];
      switch (type) {
        case updateFileConst:
          final fileId = update['file']?['id'] as int?;
          final path = update['file']?['local']?['path'] as String?;

          if (path != null && fileId != null) {
            final exists = await File(path).exists();
            if (_fileExistsCache[path] != exists) {
              _fileExistsCache[path] = exists;
              final updatedChats = Map<int, Map<String, dynamic>>.from(chatsNotifier.value);
              chatsNotifier.value = updatedChats;
            }
          }
      }
    });
  }

  Future<void> _loadChats() async {
    try {
      while (true) {
        var type = await TDLibClient.loadChats();
        if (type != "Ok") break;

        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      logger.e('Failed to load chats: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Nullgram'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
        bottom: folders.value.isNotEmpty && _tabController != null
            ? PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
              tabs: folders.value.map((folder) => Tab(text: folder.name.text)).toList(),
            ),
          ),
        )
            : null,
      ),
      drawer: const HomeMenu(),
      body: folders.value.isEmpty || _tabController == null
          ? ChatListView(
        chatsNotifier: chatsNotifier,
        folderId: null,
        fileExistsCache: _fileExistsCache,
        miniThumbnailCache: _miniThumbnailCache,
        onChatTap: _openChat,
      )
          : TabBarView(
        controller: _tabController,
        children: folders.value.map((folder) {
          return ChatListView(
            chatsNotifier: chatsNotifier,
            folderId: folder.id == -1 ? null : folder.id,
            fileExistsCache: _fileExistsCache,
            miniThumbnailCache: _miniThumbnailCache,
            onChatTap: _openChat,
          );
        }).toList(),
      ),
    );
  }

  void _openChat(int chatID) {
    final chatData = chatsNotifier.value[chatID];
    if (chatData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(chat: chatData),
        ),
      );
    }
  }
}
