"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendDirectNotification = exports.sendNotificationOnCreate = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
// Inicializar Firebase Admin
admin.initializeApp();
/**
 * Cloud Function que se ejecuta cuando se crea una nueva notificación
 * Envía automáticamente notificación push al usuario
 */
exports.sendNotificationOnCreate = (0, firestore_1.onDocumentCreated)("notifications/{notificationId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
        console.log("No hay datos en el snapshot");
        return;
    }
    try {
        const notification = snapshot.data();
        const userId = notification.userId;
        if (!userId) {
            console.log("No userId encontrado en la notificación");
            return;
        }
        console.log(`📱 Procesando notificación para usuario: ${userId}`);
        // Obtener tokens FCM del usuario
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(userId)
            .get();
        if (!userDoc.exists) {
            console.log(`Usuario ${userId} no encontrado`);
            return;
        }
        const userData = userDoc.data();
        const fcmTokens = userData?.fcmTokens || [];
        if (fcmTokens.length === 0) {
            console.log(`Usuario ${userId} no tiene tokens FCM`);
            return;
        }
        console.log(`📤 Enviando notificación a ${fcmTokens.length} dispositivos`);
        // Preparar mensaje de notificación
        const message = {
            notification: {
                title: notification.title,
                body: notification.message,
            },
            data: {
                type: notification.type || "system_message",
                postId: notification.postId || "",
                fromUserId: notification.fromUserId || "",
                fromUserName: notification.fromUserName || "",
                actionUrl: notification.actionUrl || "",
                priority: notification.priority || "medium",
                notificationId: event.params.notificationId,
            },
            android: {
                notification: {
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    priority: "high",
                    sound: "default",
                    color: "#2196F3",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: await getUnreadCount(userId),
                        alert: {
                            title: notification.title,
                            body: notification.message,
                        },
                    },
                },
            },
            tokens: fcmTokens,
        };
        // Enviar notificación
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`✅ Notificación enviada a ${userId}:`, {
            title: notification.title,
            successCount: response.successCount,
            failureCount: response.failureCount,
        });
        // Limpiar tokens inválidos si los hay
        if (response.failureCount > 0) {
            await cleanupInvalidTokens(userId, fcmTokens, response.responses);
        }
        // Actualizar la notificación como enviada
        await snapshot.ref.update({
            sent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            successCount: response.successCount,
            failureCount: response.failureCount,
        });
    }
    catch (error) {
        console.error("❌ Error enviando notificación:", error);
        // Marcar la notificación como fallida
        if (snapshot) {
            await snapshot.ref.update({
                sent: false,
                error: error instanceof Error ? error.message : String(error),
                errorAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    }
});
/**
 * Cloud Function para enviar notificaciones directas
 * Llamar desde la app cuando necesites enviar notificación inmediata
 */
exports.sendDirectNotification = (0, https_1.onCall)(async (request) => {
    // Verificar autenticación
    if (!request.auth) {
        throw new Error("El usuario debe estar autenticado");
    }
    const data = request.data;
    console.log(`📱 Enviando notificación directa:`, data);
    try {
        const { title, body, targetUserId, type, postId, fromUserId, fromUserName, actionUrl, priority } = data;
        if (!targetUserId) {
            throw new Error("targetUserId es requerido");
        }
        if (!title || !body) {
            throw new Error("title y body son requeridos");
        }
        // Obtener tokens del usuario destino
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(targetUserId)
            .get();
        if (!userDoc.exists) {
            throw new Error("Usuario de destino no encontrado");
        }
        const fcmTokens = userDoc.data()?.fcmTokens || [];
        if (fcmTokens.length === 0) {
            console.log(`Usuario ${targetUserId} no tiene tokens FCM`);
            return {
                success: true,
                message: "Usuario sin tokens FCM",
                successCount: 0,
                failureCount: 0
            };
        }
        // Preparar mensaje
        const message = {
            notification: { title, body },
            data: {
                type: type || "direct_message",
                postId: postId || "",
                fromUserId: fromUserId || request.auth.uid,
                fromUserName: fromUserName || "",
                actionUrl: actionUrl || "",
                priority: priority || "medium",
            },
            android: {
                notification: {
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    priority: "high",
                    sound: "default",
                    color: "#2196F3",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: await getUnreadCount(targetUserId),
                    },
                },
            },
            tokens: fcmTokens,
        };
        // Enviar notificación
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`✅ Notificación directa enviada:`, {
            successCount: response.successCount,
            failureCount: response.failureCount,
        });
        // Limpiar tokens inválidos
        if (response.failureCount > 0) {
            await cleanupInvalidTokens(targetUserId, fcmTokens, response.responses);
        }
        return {
            success: true,
            successCount: response.successCount,
            failureCount: response.failureCount,
        };
    }
    catch (error) {
        console.error("Error en sendDirectNotification:", error);
        throw new Error(`Error interno del servidor: ${error instanceof Error ? error.message : String(error)}`);
    }
});
/**
 * Obtener el número de notificaciones no leídas
 */
async function getUnreadCount(userId) {
    try {
        const unreadSnapshot = await admin.firestore()
            .collection("notifications")
            .where("userId", "==", userId)
            .where("isRead", "==", false)
            .get();
        return unreadSnapshot.size;
    }
    catch (error) {
        console.error("Error obteniendo contador no leídas:", error);
        return 0;
    }
}
/**
 * Limpiar tokens FCM inválidos
 */
async function cleanupInvalidTokens(userId, tokens, responses) {
    const invalidTokens = [];
    responses.forEach((response, index) => {
        if (!response.success) {
            const error = response.error;
            if (error.code === "messaging/invalid-registration-token" ||
                error.code === "messaging/registration-token-not-registered") {
                invalidTokens.push(tokens[index]);
            }
        }
    });
    if (invalidTokens.length > 0) {
        console.log(`🧹 Limpiando ${invalidTokens.length} tokens inválidos para usuario ${userId}`);
        try {
            await admin.firestore()
                .collection("users")
                .doc(userId)
                .update({
                fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
            });
            console.log(`✅ Tokens inválidos eliminados correctamente`);
        }
        catch (error) {
            console.error("Error limpiando tokens inválidos:", error);
        }
    }
}
//# sourceMappingURL=index.js.map