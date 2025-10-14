class ChatFolderName {
  final String? text;
  final bool animateCustomEmoji;

  ChatFolderName({required this.text, required this.animateCustomEmoji});

  factory ChatFolderName.fromJson(Map<String, dynamic> json) {
    return ChatFolderName(
      text: json['text']['text'] as String,
      animateCustomEmoji: json['animateCustomEmoji'] as bool? ?? false,
    );
  }
}

class ChatFolderIcon {
  final String? name;

  ChatFolderIcon({required this.name});

  factory ChatFolderIcon.fromJson(Map<String, dynamic> json) {
    return ChatFolderIcon(name: json['name'] as String);
  }
}

class ChatFolderInfo {
  final int? id;
  final int? colorId;
  final bool hasMyInviteLinks;
  final bool isShareable;
  final ChatFolderName name;
  final ChatFolderIcon icon;

  ChatFolderInfo({
    required this.id,
    required this.colorId,
    required this.hasMyInviteLinks,
    required this.isShareable,
    required this.name,
    required this.icon,
  });

  factory ChatFolderInfo.fromJson(Map<String, dynamic> json) {
    return ChatFolderInfo(
      id: json['id'] as int,
      colorId: json['colorId'] as int,
      hasMyInviteLinks: json['hasMyInviteLinks'] as bool? ?? false,
      isShareable: json['isShareable'] as bool? ?? false,
      name: ChatFolderName.fromJson(json['name']),
      icon: ChatFolderIcon.fromJson(json['icon']),
    );
  }
}

class UpdateChatFolders {
  final bool areTagsEnabled;
  final List<ChatFolderInfo> chatFolders;
  final int? mainChatListPosition;

  UpdateChatFolders({
    required this.areTagsEnabled,
    required this.chatFolders,
    required this.mainChatListPosition,
  });

  factory UpdateChatFolders.fromJson(Map<String, dynamic> json) {
    return UpdateChatFolders(
      areTagsEnabled: json['areTagsEnabled'] as bool? ?? false,
      chatFolders: (json['chatFolders'] as List<dynamic>)
          .map((e) => ChatFolderInfo.fromJson(e))
          .toList(),
      mainChatListPosition: json['mainChatListPosition'] as int? ?? 0,
    );
  }
}
