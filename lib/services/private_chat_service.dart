import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:policode/models/private_chat_model.dart';
import 'package:policode/services/auth_service.dart';

class PrivateChatService {
  static final PrivateChatService _instance = PrivateChatService._internal();
  factory PrivateChatService() => _instance;
  PrivateChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Obtener chats del usuario actual
  Stream<List<PrivateChat>> getUserChats() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('private_chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastActivity', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PrivateChat.fromFirestore(doc.data()))
            .toList());
  }

  /// Crear o obtener chat entre dos usuarios
  Future<String> createOrGetChat(String otherUserId, String otherUserName) async {
    final userId = _authService.currentUser?.uid;
    final userName = _authService.currentUser?.nombre;
    
    if (userId == null || userName == null) {
      throw Exception('Usuario no autenticado');
    }

    if (userId == otherUserId) {
      throw Exception('No puedes crear un chat contigo mismo');
    }

    // Buscar chat existente
    final participantIds = [userId, otherUserId]..sort();
    final existingChatQuery = await _db
        .collection('private_chats')
        .where('participantIds', isEqualTo: participantIds)
        .where('isGroup', isEqualTo: false)
        .limit(1)
        .get();

    if (existingChatQuery.docs.isNotEmpty) {
      return existingChatQuery.docs.first.id;
    }

    // Crear nuevo chat
    final chatRef = _db.collection('private_chats').doc();
    final now = DateTime.now();
    
    final newChat = PrivateChat(
      id: chatRef.id,
      participantIds: participantIds,
      participantNames: {
        userId: userName,
        otherUserId: otherUserName,
      },
      lastActivity: now,
      createdAt: now,
      unreadCount: {userId: 0, otherUserId: 0},
    );

    await chatRef.set(newChat.toFirestore());
    return chatRef.id;
  }

  /// Obtener mensajes de un chat
  Stream<List<PrivateChatMessage>> getChatMessages(String chatId) {
    return _db
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PrivateChatMessage.fromFirestore(doc.data()))
            .toList());
  }

  /// Enviar mensaje
  Future<void> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    String? replyToId,
  }) async {
    final userId = _authService.currentUser?.uid;
    final userName = _authService.currentUser?.nombre;
    
    if (userId == null || userName == null) {
      throw Exception('Usuario no autenticado');
    }

    final now = DateTime.now();
    final messageRef = _db
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = PrivateChatMessage(
      id: messageRef.id,
      chatId: chatId,
      senderId: userId,
      senderName: userName,
      content: content,
      timestamp: now,
      type: type,
      replyToId: replyToId,
      readByIds: [userId], // El remitente ya lo ha "leído"
    );

    // Usar transacción para actualizar mensaje y chat
    await _db.runTransaction((transaction) async {
      // Crear mensaje
      transaction.set(messageRef, message.toFirestore());
      
      // Actualizar chat
      final chatRef = _db.collection('private_chats').doc(chatId);
      transaction.update(chatRef, {
        'lastMessage': content,
        'lastMessageSenderId': userId,
        'lastActivity': Timestamp.fromDate(now),
        'unreadCount.$userId': 0, // Reset para el remitente
      });
      
      // Incrementar contador de no leídos para otros participantes
      final chatDoc = await transaction.get(chatRef);
      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final participantIds = List<String>.from(chatData['participantIds'] ?? []);
        
        for (final participantId in participantIds) {
          if (participantId != userId) {
            final currentUnread = chatData['unreadCount']?[participantId] ?? 0;
            transaction.update(chatRef, {
              'unreadCount.$participantId': currentUnread + 1,
            });
          }
        }
      }
    });
  }

  /// Marcar mensajes como leídos
  Future<void> markMessagesAsRead(String chatId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final batch = _db.batch();
    
    // Resetear contador de no leídos
    final chatRef = _db.collection('private_chats').doc(chatId);
    batch.update(chatRef, {'unreadCount.$userId': 0});
    
    // Obtener mensajes no leídos del usuario
    final unreadMessages = await _db
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .where('readByIds', whereNotIn: [userId])
        .where('senderId', isNotEqualTo: userId)
        .get();
    
    // Marcar como leídos
    for (final doc in unreadMessages.docs) {
      final readByIds = List<String>.from(doc.data()['readByIds'] ?? []);
      if (!readByIds.contains(userId)) {
        readByIds.add(userId);
        batch.update(doc.reference, {'readByIds': readByIds});
      }
    }
    
    await batch.commit();
  }

  /// Editar mensaje
  Future<void> editMessage(String chatId, String messageId, String newContent) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    final messageRef = _db
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await messageRef.update({
      'content': newContent,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });

    // Si es el último mensaje, actualizar el chat también
    final chatDoc = await _db.collection('private_chats').doc(chatId).get();
    if (chatDoc.exists) {
      final chatData = chatDoc.data() as Map<String, dynamic>;
      if (chatData['lastMessageSenderId'] == userId) {
        await _db.collection('private_chats').doc(chatId).update({
          'lastMessage': newContent,
        });
      }
    }
  }

  /// Eliminar mensaje
  Future<void> deleteMessage(String chatId, String messageId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    await _db
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'content': 'Mensaje eliminado',
      'type': 'system',
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Eliminar chat completo
  Future<void> deleteChat(String chatId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Usuario no autenticado');

    // Eliminar todos los mensajes
    final messagesQuery = await _db
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _db.batch();
    for (final doc in messagesQuery.docs) {
      batch.delete(doc.reference);
    }

    // Eliminar el chat
    batch.delete(_db.collection('private_chats').doc(chatId));
    
    await batch.commit();
  }

  /// Buscar usuarios para iniciar chat
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final snapshot = await _db
        .collection('users')
        .where('nombre', isGreaterThanOrEqualTo: query)
        .where('nombre', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'nombre': doc.data()['nombre'] ?? '',
              'email': doc.data()['email'] ?? '',
              'photoUrl': doc.data()['photoUrl'],
            })
        .where((user) => user['id'] != _authService.currentUser?.uid)
        .toList();
  }

  /// Obtener información de un chat específico
  Future<PrivateChat?> getChat(String chatId) async {
    final doc = await _db.collection('private_chats').doc(chatId).get();
    if (!doc.exists) return null;
    return PrivateChat.fromFirestore(doc.data() as Map<String, dynamic>);
  }

  /// Obtener total de mensajes no leídos
  Future<int> getTotalUnreadCount() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return 0;

    final snapshot = await _db
        .collection('private_chats')
        .where('participantIds', arrayContains: userId)
        .get();

    int totalUnread = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
      totalUnread += (unreadCount?[userId] ?? 0) as int;
    }

    return totalUnread;
  }
}