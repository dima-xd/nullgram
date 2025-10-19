import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nullgram/pages/home/widgets/chat_list_view.dart';
import 'package:nullgram/tdlib/constants.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';
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
  final ValueNotifier<List<Map<String, dynamic>>> folders = ValueNotifier([]);
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
          final chatData = update['chat'];
          final chatId = chatData['id'];

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
          
          _updateFolderUnreadCounts();

        case updateChatFoldersConst:
          final chatFolders = update['chatFolders'] ?? [];

          final allChatsFolder = {
            'id': -1,
            'name': {'text': 'All chats'},
            'unreadCount': 0,
          };

          final newFolders = <Map<String, dynamic>>[allChatsFolder, ...chatFolders.map((folder) => {
            'id': folder['id'],
            'name': {'text': folder['name']['text']['text']},
            'unreadCount': 0,
          })];
          
          if (_tabController == null || _tabController!.length != newFolders.length) {
            _tabController?.dispose();
            _tabController = TabController(length: newFolders.length, vsync: this)
              ..addListener(() {
                selectedFolderIndex = _tabController!.index;
              });
          }
          folders.value = newFolders;
          _updateFolderUnreadCounts();

          setState(() {});

        case updateChatPositionConst:
          final chatId = update['chatId'];
          final position = update['position'];
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null) {
            final positions = existingChat['positions'] ?? [];
            final posIndex = positions.indexWhere(
                    (p) => p['list']?['chatFolderId'] == position['list']?['chatFolderId']
            );

            if (posIndex != -1) {
              positions[posIndex] = position;
            } else {
              positions.add(position);
            }

            final updatedChats = chatsNotifier.value;
            updatedChats[chatId] = {...existingChat, 'positions': positions};
            chatsNotifier.value = updatedChats;
          }

        case updateChatLastMessageConst:
          final chatId = update['chatId'];
          final lastMessage = update['lastMessage'];
          final newPositions = update['positions'];
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null) {
            final mergedPositions = List<Map<String, dynamic>>.from(
                newPositions?.map((e) => e) ?? []
            );

            final existingPositions = existingChat['positions'];
            if (existingPositions != null) {
              for (final existingPos in existingPositions) {
                final existingPosMap = existingPos;
                if (!mergedPositions.any((p) =>
                p['list']?['chatFolderId'] == existingPosMap['list']?['chatFolderId'])) {
                  mergedPositions.add(existingPosMap);
                }
              }
            }

            final updatedChats = chatsNotifier.value;
            updatedChats[chatId] = {
              ...existingChat,
              'lastMessage': lastMessage,
              'positions': mergedPositions,
            };
            chatsNotifier.value = updatedChats;
          }

        case updateChatAddedToListConst:
          final chatId = update['chatId'];
          final folderId = update['chatList']?['chatFolderId'];
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null && folderId != null) {
            final folderIds = existingChat['folderIds'] ?? [];

            if (!folderIds.contains(folderId)) {
              folderIds.add(folderId);
              final updatedChats = chatsNotifier.value;
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
          final chatId = update["chatId"];
          final unreadCount = update["unreadCount"];
          final existingChat = chatsNotifier.value[chatId];

          if (existingChat != null) {
            final updatedChats = chatsNotifier.value;
            updatedChats[chatId] = {...existingChat, 'unreadCount': unreadCount};
            chatsNotifier.value = updatedChats;
            
            _updateFolderUnreadCounts();
          }
        case updateUserConst:
          users[update["user"]["id"]] = update["user"];
        case updateUserStatusConst:
          final userId = update['userId'];
          var user = users[userId];
          if (user != null) {
            user['status'] = update['status'];
            
            final updatedChats = chatsNotifier.value;
            for (final chatId in updatedChats.keys) {
              final chat = updatedChats[chatId];
              if (chat?['user']?['id'] == userId) {
                updatedChats[chatId] = {
                  ...?chat,
                  'user': {
                    ...chat?['user'],
                    'status': update['status'],
                  },
                };
              }
            }
            chatsNotifier.value = updatedChats;
          }
      }
    });

    TDLibClient.filesUpdates.listen((update) async {
      final type = update['@type'];
      switch (type) {
        case updateFileConst:
          final fileId = update['file']?['id'];
          final path = update['file']?['local']?['path'];

          if (path != null && fileId != null) {
            final exists = await File(path).exists();
            if (_fileExistsCache[path] != exists) {
              _fileExistsCache[path] = exists;
              final updatedChats = chatsNotifier.value;
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

  void _updateFolderUnreadCounts() {
    final updatedFolders = folders.value;
    
    for (int i = 0; i < updatedFolders.length; i++) {
      final folder = updatedFolders[i];
      final folderId = folder['id'];
      int unreadChatsCount = 0;
      
      for (final chat in chatsNotifier.value.values) {
        final chatUnreadCount = chat['unreadCount'] ?? 0;
        if (chatUnreadCount > 0) {
          if (folderId == -1) {
            unreadChatsCount++;
          } else {
            final chatFolderIds = chat['folderIds'] ?? [];
            if (chatFolderIds.contains(folderId)) {
              unreadChatsCount++;
            }
          }
        }
      }
      
      updatedFolders[i] = {...folder, 'unreadCount': unreadChatsCount};
    }
    
    folders.value = updatedFolders;
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
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: folders,
              builder: (context, foldersList, child) {
                return TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
                  tabs: foldersList.map((folder) {
                    final unreadCount = folder['unreadCount'] ?? 0;
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(folder['name']['text']),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
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
            folderId: folder['id'] == -1 ? null : folder['id'],
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
