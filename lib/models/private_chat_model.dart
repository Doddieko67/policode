import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Modelo para un chat privado entre usuarios
class PrivateChat extends Equatable {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime lastActivity;
  final DateTime createdAt;
  final Map<String, int> unreadCount;
  final bool isGroup;
  final String? groupName;
  final String? groupImageUrl;

  const PrivateChat({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    this.lastMessage,
    this.lastMessageSenderId,
    required this.lastActivity,
    required this.createdAt,
    this.unreadCount = const {},
    this.isGroup = false,
    this.groupName,
    this.groupImageUrl,
  });

  factory PrivateChat.fromFirestore(Map<String, dynamic> data) {
    return PrivateChat(
      id: data['id'] ?? '',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      lastMessage: data['lastMessage'],
      lastMessageSenderId: data['lastMessageSenderId'],
      lastActivity: (data['lastActivity'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      groupImageUrl: data['groupImageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastActivity': Timestamp.fromDate(lastActivity),
      'createdAt': Timestamp.fromDate(createdAt),
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupImageUrl': groupImageUrl,
    };
  }

  PrivateChat copyWith({
    String? id,
    List<String>? participantIds,
    Map<String, String>? participantNames,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastActivity,
    DateTime? createdAt,
    Map<String, int>? unreadCount,
    bool? isGroup,
    String? groupName,
    String? groupImageUrl,
  }) {
    return PrivateChat(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupImageUrl: groupImageUrl ?? this.groupImageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        participantIds,
        participantNames,
        lastMessage,
        lastMessageSenderId,
        lastActivity,
        createdAt,
        unreadCount,
        isGroup,
        groupName,
        groupImageUrl,
      ];
}

/// Modelo para un mensaje en chat privado
class PrivateChatMessage extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? replyToId;
  final bool isEdited;
  final DateTime? editedAt;
  final List<String> readByIds;

  const PrivateChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.replyToId,
    this.isEdited = false,
    this.editedAt,
    this.readByIds = const [],
  });

  factory PrivateChatMessage.fromFirestore(Map<String, dynamic> data) {
    return PrivateChatMessage(
      id: data['id'] ?? '',
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: MessageType.fromString(data['type']) ?? MessageType.text,
      replyToId: data['replyToId'],
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null ? (data['editedAt'] as Timestamp).toDate() : null,
      readByIds: List<String>.from(data['readByIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.value,
      'replyToId': replyToId,
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'readByIds': readByIds,
    };
  }

  PrivateChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    String? replyToId,
    bool? isEdited,
    DateTime? editedAt,
    List<String>? readByIds,
  }) {
    return PrivateChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      replyToId: replyToId ?? this.replyToId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      readByIds: readByIds ?? this.readByIds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        senderName,
        content,
        timestamp,
        type,
        replyToId,
        isEdited,
        editedAt,
        readByIds,
      ];
}

/// Tipos de mensaje
enum MessageType {
  text('text'),
  image('image'),
  file('file'),
  system('system');

  const MessageType(this.value);
  final String value;

  static MessageType? fromString(String? value) {
    if (value == null) return null;
    return MessageType.values
        .where((type) => type.value == value)
        .firstOrNull;
  }
}