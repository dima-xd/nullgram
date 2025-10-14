class UpdateNewChat {
  final Chat chat;

  UpdateNewChat({required this.chat});

  factory UpdateNewChat.fromJson(Map<String, dynamic> json) {
    return UpdateNewChat(
      chat: Chat.fromJson(json['chat']),
    );
  }
}

class Chat {
  final int? accentColorId;
  final ChatAvailableReactions? availableReactions;
  final int? backgroundCustomEmojiId;
  final bool canBeDeletedForAllUsers;
  final bool canBeDeletedOnlyForSelf;
  final bool canBeReported;
  final List<dynamic> chatLists;
  final String? clientData;
  final bool defaultDisableNotification;
  final bool hasProtectedContent;
  final bool hasScheduledMessages;
  final int? id;
  final bool isMarkedAsUnread;
  final bool isTranslatable;
  final int? lastReadInboxMessageId;
  final int? lastReadOutboxMessageId;
  final int? messageAutoDeleteTime;
  final ChatNotificationSettings notificationSettings;
  final ChatPermissions permissions;
  final ChatPhotoInfo? photo;
  final List<ChatPosition> positions;
  final int? profileAccentColorId;
  final int? profileBackgroundCustomEmojiId;
  final int? replyMarkupMessageId;
  final String? title;
  final dynamic type;
  final int? unreadCount;
  final int? unreadMentionCount;
  final int? unreadReactionCount;
  final VideoChat videoChat;
  final bool viewAsTopics;

  final List<int> folderIds;
  final Message? lastMessage;

  Chat({
    required this.accentColorId,
    required this.availableReactions,
    required this.backgroundCustomEmojiId,
    required this.canBeDeletedForAllUsers,
    required this.canBeDeletedOnlyForSelf,
    required this.canBeReported,
    required this.chatLists,
    required this.clientData,
    required this.defaultDisableNotification,
    required this.hasProtectedContent,
    required this.hasScheduledMessages,
    required this.id,
    required this.isMarkedAsUnread,
    required this.isTranslatable,
    required this.lastReadInboxMessageId,
    required this.lastReadOutboxMessageId,
    required this.messageAutoDeleteTime,
    required this.notificationSettings,
    required this.permissions,
    required this.photo,
    required this.positions,
    required this.profileAccentColorId,
    required this.profileBackgroundCustomEmojiId,
    required this.replyMarkupMessageId,
    required this.title,
    required this.type,
    required this.unreadCount,
    required this.unreadMentionCount,
    required this.unreadReactionCount,
    required this.videoChat,
    required this.viewAsTopics,

    this.folderIds = const [],
    this.lastMessage,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      accentColorId: json['accentColorId'],
      availableReactions: json['availableReactions'] != null
          ? ChatAvailableReactions.fromJson(json['availableReactions'])
          : null,
      backgroundCustomEmojiId: json['backgroundCustomEmojiId'],
      canBeDeletedForAllUsers: json['canBeDeletedForAllUsers'],
      canBeDeletedOnlyForSelf: json['canBeDeletedOnlyForSelf'],
      canBeReported: json['canBeReported'],
      chatLists: json['chatLists'] ?? [],
      clientData: json['clientData'] ?? '',
      defaultDisableNotification: json['defaultDisableNotification'],
      hasProtectedContent: json['hasProtectedContent'],
      hasScheduledMessages: json['hasScheduledMessages'],
      id: json['id'],
      isMarkedAsUnread: json['isMarkedAsUnread'],
      isTranslatable: json['isTranslatable'],
      lastReadInboxMessageId: json['lastReadInboxMessageId'],
      lastReadOutboxMessageId: json['lastReadOutboxMessageId'],
      messageAutoDeleteTime: json['messageAutoDeleteTime'],
      notificationSettings:
      ChatNotificationSettings.fromJson(json['notificationSettings']),
      permissions: ChatPermissions.fromJson(json['permissions']),
      photo:
      json['photo'] != null ? ChatPhotoInfo.fromJson(json['photo']) : null,
      positions: (json['positions'] as List<dynamic>?)
          ?.map((e) => ChatPosition.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      profileAccentColorId: json['profileAccentColorId'],
      profileBackgroundCustomEmojiId: json['profileBackgroundCustomEmojiId'],
      replyMarkupMessageId: json['replyMarkupMessageId'],
      title: json['title'],
      type: json['type'],
      unreadCount: json['unreadCount'],
      unreadMentionCount: json['unreadMentionCount'],
      unreadReactionCount: json['unreadReactionCount'],
      videoChat: VideoChat.fromJson(json['videoChat']),
      viewAsTopics: json['viewAsTopics'],

      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
    );
  }

  Chat copyWith({
    List<int>? folderIds,
    Message? lastMessage,
    int? unreadCount,
    List<ChatPosition>? positions,
  }) {
    return Chat(
      accentColorId: this.accentColorId,
      availableReactions: this.availableReactions,
      backgroundCustomEmojiId: this.backgroundCustomEmojiId,
      canBeDeletedForAllUsers: this.canBeDeletedForAllUsers,
      canBeDeletedOnlyForSelf: this.canBeDeletedOnlyForSelf,
      canBeReported: this.canBeReported,
      chatLists: this.chatLists,
      clientData: this.clientData,
      defaultDisableNotification: this.defaultDisableNotification,
      hasProtectedContent: this.hasProtectedContent,
      hasScheduledMessages: this.hasScheduledMessages,
      id: this.id,
      isMarkedAsUnread: this.isMarkedAsUnread,
      isTranslatable: this.isTranslatable,
      lastReadInboxMessageId: this.lastReadInboxMessageId,
      lastReadOutboxMessageId: this.lastReadOutboxMessageId,
      messageAutoDeleteTime: this.messageAutoDeleteTime,
      notificationSettings: this.notificationSettings,
      permissions: this.permissions,
      photo: this.photo,
      positions: positions ?? this.positions,
      profileAccentColorId: this.profileAccentColorId,
      profileBackgroundCustomEmojiId: this.profileBackgroundCustomEmojiId,
      replyMarkupMessageId: this.replyMarkupMessageId,
      title: this.title,
      type: this.type,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadMentionCount: this.unreadMentionCount,
      unreadReactionCount: this.unreadReactionCount,
      videoChat: this.videoChat,
      viewAsTopics: this.viewAsTopics,

      folderIds: folderIds ?? this.folderIds,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}

class UpdateChatPosition {
  final int chatId;
  final ChatPosition position;

  UpdateChatPosition({
    required this.chatId,
    required this.position,
  });

  factory UpdateChatPosition.fromJson(Map<String, dynamic> json) {
    return UpdateChatPosition(
      chatId: json['chatId'],
      position: ChatPosition.fromJson(json['position']),
    );
  }

  Map<String, dynamic> toJson() => {
    'chatId': chatId,
    'position': position.toJson(),
  };
}

class ChatAvailableReactions {
  final int? maxReactionCount;
  final List<dynamic> reactions;

  ChatAvailableReactions({
    required this.maxReactionCount,
    required this.reactions,
  });

  factory ChatAvailableReactions.fromJson(Map<String, dynamic> json) {
    return ChatAvailableReactions(
      maxReactionCount: json['maxReactionCount'],
      reactions: json['reactions'] ?? [],
    );
  }
}

class ChatNotificationSettings {
  final bool disableMentionNotifications;
  final bool disablePinnedMessageNotifications;
  final int? muteFor;
  final bool muteStories;
  final bool showPreview;
  final bool showStoryPoster;
  final int? soundId;
  final int? storySoundId;

  ChatNotificationSettings({
    required this.disableMentionNotifications,
    required this.disablePinnedMessageNotifications,
    required this.muteFor,
    required this.muteStories,
    required this.showPreview,
    required this.showStoryPoster,
    required this.soundId,
    required this.storySoundId,
  });

  factory ChatNotificationSettings.fromJson(Map<String, dynamic> json) {
    return ChatNotificationSettings(
      disableMentionNotifications: json['disableMentionNotifications'],
      disablePinnedMessageNotifications:
      json['disablePinnedMessageNotifications'],
      muteFor: json['muteFor'],
      muteStories: json['muteStories'],
      showPreview: json['showPreview'],
      showStoryPoster: json['showStoryPoster'],
      soundId: json['soundId'],
      storySoundId: json['storySoundId'],
    );
  }
}

class ChatPermissions {
  final bool canAddLinkPreviews;
  final bool canChangeInfo;
  final bool canCreateTopics;
  final bool canInviteUsers;
  final bool canPinMessages;
  final bool canSendAudios;
  final bool canSendBasicMessages;
  final bool canSendDocuments;
  final bool canSendOtherMessages;
  final bool canSendPhotos;
  final bool canSendPolls;
  final bool canSendVideoNotes;
  final bool canSendVideos;
  final bool canSendVoiceNotes;

  ChatPermissions({
    required this.canAddLinkPreviews,
    required this.canChangeInfo,
    required this.canCreateTopics,
    required this.canInviteUsers,
    required this.canPinMessages,
    required this.canSendAudios,
    required this.canSendBasicMessages,
    required this.canSendDocuments,
    required this.canSendOtherMessages,
    required this.canSendPhotos,
    required this.canSendPolls,
    required this.canSendVideoNotes,
    required this.canSendVideos,
    required this.canSendVoiceNotes,
  });

  factory ChatPermissions.fromJson(Map<String, dynamic> json) {
    return ChatPermissions(
      canAddLinkPreviews: json['canAddLinkPreviews'],
      canChangeInfo: json['canChangeInfo'],
      canCreateTopics: json['canCreateTopics'],
      canInviteUsers: json['canInviteUsers'],
      canPinMessages: json['canPinMessages'],
      canSendAudios: json['canSendAudios'],
      canSendBasicMessages: json['canSendBasicMessages'],
      canSendDocuments: json['canSendDocuments'],
      canSendOtherMessages: json['canSendOtherMessages'],
      canSendPhotos: json['canSendPhotos'],
      canSendPolls: json['canSendPolls'],
      canSendVideoNotes: json['canSendVideoNotes'],
      canSendVideos: json['canSendVideos'],
      canSendVoiceNotes: json['canSendVoiceNotes'],
    );
  }
}

class ChatPhotoInfo {
  final FileData big;
  final bool hasAnimation;
  final bool isPersonal;
  final Minithumbnail? minithumbnail;
  final FileData small;

  ChatPhotoInfo({
    required this.big,
    required this.hasAnimation,
    required this.isPersonal,
    required this.minithumbnail,
    required this.small,
  });

  factory ChatPhotoInfo.fromJson(Map<String, dynamic> json) {
    return ChatPhotoInfo(
      big: FileData.fromJson(json['big']),
      hasAnimation: json['hasAnimation'],
      isPersonal: json['isPersonal'],
      minithumbnail: json['minithumbnail'] != null
          ? Minithumbnail.fromJson(json['minithumbnail'])
          : null,
      small: FileData.fromJson(json['small']),
    );
  }
}

class FileData {
  final int? expectedSize;
  final int? id;
  final LocalFile local;
  final RemoteFile remote;
  final int? size;

  FileData({
    required this.expectedSize,
    required this.id,
    required this.local,
    required this.remote,
    required this.size,
  });

  factory FileData.fromJson(Map<String, dynamic> json) {
    return FileData(
      expectedSize: json['expectedSize'],
      id: json['id'],
      local: LocalFile.fromJson(json['local']),
      remote: RemoteFile.fromJson(json['remote']),
      size: json['size'],
    );
  }
}

class LocalFile {
  final bool canBeDeleted;
  final bool canBeDownloaded;
  final int? downloadOffset;
  final int? downloadedPrefixSize;
  final int? downloadedSize;
  final bool isDownloadingActive;
  final bool isDownloadingCompleted;
  final String? path;

  LocalFile({
    required this.canBeDeleted,
    required this.canBeDownloaded,
    required this.downloadOffset,
    required this.downloadedPrefixSize,
    required this.downloadedSize,
    required this.isDownloadingActive,
    required this.isDownloadingCompleted,
    required this.path,
  });

  factory LocalFile.fromJson(Map<String, dynamic> json) {
    return LocalFile(
      canBeDeleted: json['canBeDeleted'],
      canBeDownloaded: json['canBeDownloaded'],
      downloadOffset: json['downloadOffset'],
      downloadedPrefixSize: json['downloadedPrefixSize'],
      downloadedSize: json['downloadedSize'],
      isDownloadingActive: json['isDownloadingActive'],
      isDownloadingCompleted: json['isDownloadingCompleted'],
      path: json['path'],
    );
  }
}

class RemoteFile {
  final String? id;
  final bool isUploadingActive;
  final bool isUploadingCompleted;
  final String? uniqueId;
  final int? uploadedSize;

  RemoteFile({
    required this.id,
    required this.isUploadingActive,
    required this.isUploadingCompleted,
    required this.uniqueId,
    required this.uploadedSize,
  });

  factory RemoteFile.fromJson(Map<String, dynamic> json) {
    return RemoteFile(
      id: json['id'],
      isUploadingActive: json['isUploadingActive'],
      isUploadingCompleted: json['isUploadingCompleted'],
      uniqueId: json['uniqueId'],
      uploadedSize: json['uploadedSize'],
    );
  }
}

class Minithumbnail {
  final List<dynamic>? data;
  final int? height;
  final int? width;

  Minithumbnail({
    required this.data,
    required this.height,
    required this.width,
  });

  factory Minithumbnail.fromJson(Map<String, dynamic> json) {
    return Minithumbnail(
      data: json['data'],
      height: json['height'],
      width: json['width'],
    );
  }
}

class ChatType {
  final bool? isChannel;
  final int? supergroupId;
  final int? userId;
  final int? basicGroupId;
  final String? type;

  ChatType({
    this.isChannel,
    this.supergroupId,
    this.userId,
    this.basicGroupId,
    this.type,
  });

  factory ChatType.fromJson(Map<String, dynamic> json) {
    final chatType = json['@type'] as String?;

    return ChatType(
      type: chatType,
      isChannel: json['is_channel'] as bool?,
      supergroupId: json['supergroup_id'] as int?,
      userId: json['user_id'] as int?,
      basicGroupId: json['basic_group_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (type != null) result['@type'] = type;
    if (isChannel != null) result['is_channel'] = isChannel;
    if (supergroupId != null) result['supergroup_id'] = supergroupId;
    if (userId != null) result['user_id'] = userId;
    if (basicGroupId != null) result['basic_group_id'] = basicGroupId;

    return result;
  }
}

class VideoChat {
  final int? groupCallId;
  final bool hasParticipants;

  VideoChat({
    required this.groupCallId,
    required this.hasParticipants,
  });

  factory VideoChat.fromJson(Map<String, dynamic> json) {
    return VideoChat(
      groupCallId: json['groupCallId'],
      hasParticipants: json['hasParticipants'],
    );
  }
}

class ChatPosition {
  final bool? isPinned;
  final ChatList? list;
  final int? order;

  ChatPosition({
    required this.isPinned,
    required this.list,
    required this.order,
  });

  factory ChatPosition.fromJson(Map<String, dynamic> json) {
    return ChatPosition(
      isPinned: json['isPinned'],
      list: ChatList.fromJson(json['list']),
      order: json['order'],
    );
  }

  Map<String, dynamic> toJson() => {
    'isPinned': isPinned,
    'list': list?.toJson(),
    'order': order,
  };
}

class UpdateChatLastMessage {
  final int? chatId;
  final Message? lastMessage;
  final List<ChatPosition> positions;

  UpdateChatLastMessage({
    required this.chatId,
    required this.lastMessage,
    required this.positions,
  });

  factory UpdateChatLastMessage.fromJson(Map<String, dynamic> json) {
    return UpdateChatLastMessage(
      chatId: json['chatId'],
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      positions: (json['positions'] as List<dynamic>?)
          ?.map((e) => ChatPosition.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class Message {
  final int? id;
  final int? chatId;
  final int? date;
  final MessageContent content;
  final MessageForwardInfo? forwardInfo;
  final MessageInteractionInfo? interactionInfo;
  final bool isPinned;
  final String? authorSignature;
  final bool? canBeSaved;
  final bool? containsUnreadMention;
  final int? editDate;
  final int? effectId;
  final bool? hasTimestampedMedia;
  final bool? isChannelPost;
  final bool? isFromOffline;
  final bool? isOutgoing;
  final bool? isPaidStarSuggestedPost;
  final bool? isPaidTonSuggestedPost;
  final int? mediaAlbumId;
  final int? messageThreadId;
  final int? paidMessageStarCount;
  final int? selfDestructIn;
  final int? senderBoostCount;
  final int? senderBusinessBotUserId;
  final MessageSender? senderId;
  final MessageTopicForum? topicId;
  final List<dynamic>? unreadReactions;
  final int? viaBotUserId;

  Message({
    required this.id,
    required this.chatId,
    required this.date,
    required this.content,
    this.forwardInfo,
    this.interactionInfo,
    required this.isPinned,
    this.authorSignature,
    this.canBeSaved,
    this.containsUnreadMention,
    this.editDate,
    this.effectId,
    this.hasTimestampedMedia,
    this.isChannelPost,
    this.isFromOffline,
    this.isOutgoing,
    this.isPaidStarSuggestedPost,
    this.isPaidTonSuggestedPost,
    this.mediaAlbumId,
    this.messageThreadId,
    this.paidMessageStarCount,
    this.selfDestructIn,
    this.senderBoostCount,
    this.senderBusinessBotUserId,
    this.senderId,
    this.topicId,
    this.unreadReactions,
    this.viaBotUserId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      chatId: json['chatId'],
      date: json['date'],
      content: MessageContent.fromJson(json['content']),
      forwardInfo: json['forwardInfo'] != null
          ? MessageForwardInfo.fromJson(json['forwardInfo'])
          : null,
      interactionInfo: json['interactionInfo'] != null
          ? MessageInteractionInfo.fromJson(json['interactionInfo'])
          : null,
      isPinned: json['isPinned'] ?? false,
      authorSignature: json['authorSignature'],
      canBeSaved: json['canBeSaved'],
      containsUnreadMention: json['containsUnreadMention'],
      editDate: json['editDate'],
      effectId: json['effectId'],
      hasTimestampedMedia: json['hasTimestampedMedia'],
      isChannelPost: json['isChannelPost'],
      isFromOffline: json['isFromOffline'],
      isOutgoing: json['isOutgoing'],
      isPaidStarSuggestedPost: json['isPaidStarSuggestedPost'],
      isPaidTonSuggestedPost: json['isPaidTonSuggestedPost'],
      mediaAlbumId: json['mediaAlbumId'],
      messageThreadId: json['messageThreadId'],
      paidMessageStarCount: json['paidMessageStarCount'],
      selfDestructIn: json['selfDestructIn'],
      senderBoostCount: json['senderBoostCount'],
      senderBusinessBotUserId: json['senderBusinessBotUserId'],
      senderId: json['senderId'] != null
          ? MessageSender.fromJson(json['senderId'])
          : null,
      topicId: json['topicId'] != null
          ? MessageTopicForum.fromJson(json['topicId'])
          : null,
      unreadReactions: json['unreadReactions'],
      viaBotUserId: json['viaBotUserId'],
    );
  }
}

class MessageContent {
  final String? type;
  final FormattedText? text;

  MessageContent({
    required this.type,
    this.text,
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      type: json['@type'] ?? 'messageText',
      text: json['text'] != null
          ? FormattedText.fromJson(json['text'] as Map<String, dynamic>)
          : null,
    );
  }

  String getPreview() {
    switch (type) {
      case 'MessageText':
        return text?.text ?? '';
      case 'MessagePhoto':
        return '📷 Photo';
      case 'MessageVideo':
        return '🎥 Video';
      case 'MessageVoiceNote':
        return '🎤 Voice message';
      case 'MessageDocument':
        return '📎 Document';
      case 'MessageSticker':
        return '🎨 Sticker';
      case 'MessageAnimation':
        return '🎬 GIF';
      default:
        return 'Message';
    }
  }
}

class FormattedText {
  final String? text;
  final List<dynamic> entities;

  FormattedText({
    required this.text,
    required this.entities,
  });

  factory FormattedText.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return FormattedText(text: '', entities: []);
    }
    return FormattedText(
      text: json['text'] ?? '',
      entities: json['entities'] ?? [],
    );
  }
}

class MessageForwardInfo {
  final int? date;
  final MessageOrigin? origin;
  final String? publicServiceAnnouncementType;
  final ForwardSource? source;

  MessageForwardInfo({
    required this.date,
    this.origin,
    this.publicServiceAnnouncementType,
    this.source,
  });

  factory MessageForwardInfo.fromJson(Map<String, dynamic> json) {
    return MessageForwardInfo(
      date: json['date'],
      origin: json['origin'] != null
          ? MessageOrigin.fromJson(json['origin'])
          : null,
      publicServiceAnnouncementType: json['publicServiceAnnouncementType'],
      source: json['source'] != null
          ? ForwardSource.fromJson(json['source'])
          : null,
    );
  }
}

class MessageOrigin {
  final int? chatId;
  final int? messageId;
  final String? authorSignature;

  MessageOrigin({
    required this.chatId,
    required this.messageId,
    required this.authorSignature,
  });

  factory MessageOrigin.fromJson(Map<String, dynamic> json) {
    return MessageOrigin(
      chatId: json['chatId'],
      messageId: json['messageId'],
      authorSignature: json['authorSignature'] ?? '',
    );
  }
}

class ForwardSource {
  final int? chatId;
  final int? date;
  final bool isOutgoing;
  final int? messageId;
  final String? senderName;

  ForwardSource({
    required this.chatId,
    required this.date,
    required this.isOutgoing,
    required this.messageId,
    required this.senderName,
  });

  factory ForwardSource.fromJson(Map<String, dynamic> json) {
    return ForwardSource(
      chatId: json['chatId'],
      date: json['date'],
      isOutgoing: json['isOutgoing'],
      messageId: json['messageId'],
      senderName: json['senderName'],
    );
  }
}

class MessageInteractionInfo {
  final int? viewCount;
  final int? forwardCount;
  final MessageReplyInfo? replyInfo;

  MessageInteractionInfo({
    required this.viewCount,
    this.forwardCount,
    this.replyInfo,
  });

  factory MessageInteractionInfo.fromJson(Map<String, dynamic> json) {
    return MessageInteractionInfo(
      viewCount: json['viewCount'] ?? 0,
      forwardCount: json['forwardCount'],
      replyInfo: json['replyInfo'] != null
          ? MessageReplyInfo.fromJson(json['replyInfo'])
          : null,
    );
  }
}

class MessageReplyInfo {
  final int? lastMessageId;
  final int? lastReadInboxMessageId;
  final int? lastReadOutboxMessageId;
  final List<dynamic> recentReplierIds;
  final int? replyCount;

  MessageReplyInfo({
    required this.lastMessageId,
    required this.lastReadInboxMessageId,
    required this.lastReadOutboxMessageId,
    required this.recentReplierIds,
    required this.replyCount,
  });

  factory MessageReplyInfo.fromJson(Map<String, dynamic> json) {
    return MessageReplyInfo(
      lastMessageId: json['lastMessageId'],
      lastReadInboxMessageId: json['lastReadInboxMessageId'],
      lastReadOutboxMessageId: json['lastReadOutboxMessageId'],
      recentReplierIds: json['recentReplierIds'] ?? [],
      replyCount: json['replyCount'],
    );
  }
}

class MessageSender {
  final int? chatId;

  MessageSender({required this.chatId});

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      chatId: json['chatId'],
    );
  }
}

class MessageTopicForum {
  final int? forumTopicId;

  MessageTopicForum({required this.forumTopicId});

  factory MessageTopicForum.fromJson(Map<String, dynamic> json) {
    return MessageTopicForum(
      forumTopicId: json['forumTopicId'],
    );
  }
}

class UpdateChatAddedToList {
  final int chatId;
  final ChatList chatList;

  UpdateChatAddedToList({
    required this.chatId,
    required this.chatList,
  });

  factory UpdateChatAddedToList.fromJson(Map<String, dynamic> json) {
    return UpdateChatAddedToList(
      chatId: json['chatId'],
      chatList: ChatList.fromJson(json['chatList']),
    );
  }

  Map<String, dynamic> toJson() => {
    'chatId': chatId,
    'chatList': chatList.toJson(),
  };
}

class ChatList {
  final int? chatFolderId;

  ChatList({required this.chatFolderId});

  factory ChatList.fromJson(Map<String, dynamic> json) {
    return ChatList(
      chatFolderId: json['chatFolderId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'chatFolderId': chatFolderId,
  };
}

