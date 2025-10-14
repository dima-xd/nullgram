import 'chat.dart';

class Messages {
  final int totalCount;
  final List<Message> messages;

  Messages({
    required this.totalCount,
    required this.messages,
  });

  factory Messages.fromJson(Map<String, dynamic> json) {
    return Messages(
      totalCount: json['totalCount'] ?? json['total_count'] ?? 0,
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCount': totalCount,
      'messages': messages,
    };
  }
}

/*
class Message {
  final int? id;
  final MessageSender? senderId;
  final int? chatId;
  final bool? isOutgoing;
  final bool? isPinned;
  final bool? isFromOffline;
  final bool? canBeSaved;
  final bool? hasTimestampedMedia;
  final bool? isChannelPost;
  final int? date;
  final int? editDate;
  final MessageContent? content;

  Message({
    this.id,
    this.senderId,
    this.chatId,
    this.isOutgoing,
    this.isPinned,
    this.isFromOffline,
    this.canBeSaved,
    this.hasTimestampedMedia,
    this.isChannelPost,
    this.date,
    this.editDate,
    this.content,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'] != null
          ? MessageSender.fromJson(json['senderId'] as Map<String, dynamic>)
          : null,
      chatId: json['chatId'],
      isOutgoing: json['isOutgoing'],
      isPinned: json['isPinned'],
      isFromOffline: json['isFromOffline'],
      canBeSaved: json['canBeSaved'],
      hasTimestampedMedia: json['hasTimestampedMedia'],
      isChannelPost: json['isChannelPost'],
      date: json['date'],
      editDate: json['editDate'],
      content: json['content'] != null
          ? MessageContent.fromJson(json['content'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId?.toJson(),
      'chatId': chatId,
      'isOutgoing': isOutgoing,
      'isPinned': isPinned,
      'isFromOffline': isFromOffline,
      'canBeSaved': canBeSaved,
      'hasTimestampedMedia': hasTimestampedMedia,
      'isChannelPost': isChannelPost,
      'date': date,
      'editDate': editDate,
      'content': content?.toJson(),
    };
  }
}

class MessageSender {
  final int? userId;

  MessageSender({this.userId});

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      userId: json['userId'] ?? json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId};
  }
}

class MessageContent {
  final String? type;
  final FormattedText? text;

  MessageContent({
    this.type,
    this.text,
  });

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      type: json['@type'],
      text: json['text'] != null
          ? FormattedText.fromJson(json['text'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '@type': type,
      'text': text?.toJson(),
    };
  }
}

class FormattedText {
  final String? text;
  final List<TextEntity> entities;

  FormattedText({
    this.text,
    this.entities = const [],
  });

  factory FormattedText.fromJson(Map<String, dynamic> json) {
    return FormattedText(
      text: json['text'],
      entities: (json['entities'] as List<dynamic>? ?? [])
          .map((e) => TextEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'entities': entities.map((e) => e.toJson()).toList(),
    };
  }
}

class TextEntity {
  final int? offset;
  final int? length;
  final Map<String, dynamic>? type;

  TextEntity({
    this.offset,
    this.length,
    this.type,
  });

  factory TextEntity.fromJson(Map<String, dynamic> json) {
    return TextEntity(
      offset: json['offset'],
      length: json['length'],
      type: json['type'] is Map<String, dynamic>
          ? json['type'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offset': offset,
      'length': length,
      'type': type,
    };
  }
}

*/
