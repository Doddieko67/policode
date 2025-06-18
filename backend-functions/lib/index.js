"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendTestNotification = exports.cleanupOldNotifications = exports.sendDirectNotification = exports.sendNotificationOnCreate = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
// Inicializar Firebase Admin
admin.initializeApp();
/**
 * Cloud Function que se ejecuta cuando se crea una nueva notificación
 * Envía automáticamente notificación push al usuario
 */
exports.sendNotificationOnCreate = (0, firestore_1.onDocumentCreated)("notifications/{notificationId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    try {
        const notification = snapshot.data();
        const userId = notification.userId;
        if (!userId) {
            console.log("No userId encontrado en la notificación");
            return;
        }
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
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: await getUnreadCount(userId),
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
    }
    catch (error) {
        console.error("❌ Error enviando notificación:", error);
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
        console.log(`🧹 Limpiando ${invalidTokens.length} tokens inválidos`);
        await admin.firestore()
            .collection("users")
            .doc(userId)
            .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
    }
}
/**
 * Cloud Function para enviar notificaciones directas
 * Uso: llamar desde la app cuando necesites enviar notificación inmediata
 */
exports.sendDirectNotification = (0, https_1.onCall)(async (request) => {
    const data = request.data;
    // Verificar autenticación
    if (!request.auth) {
        throw new Error("El usuario debe estar autenticado");
    }
    try {
        const { title, body, type, postId, fromUserId, fromUserName, actionUrl, priority, targetUserId } = data;
        if (!targetUserId) {
            throw new Error("targetUserId es requerido");
        }
        // Obtener tokens del usuario destino
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(targetUserId)
            .get();
        if (!userDoc.exists) {
            throw new Error("Usuario no encontrado");
        }
        const fcmTokens = userDoc.data()?.fcmTokens || [];
        if (fcmTokens.length === 0) {
            console.log(`Usuario ${targetUserId} no tiene tokens FCM`);
            return { success: true, message: "Usuario sin tokens FCM" };
        }
        // Enviar notificación
        const message = {
            notification: { title, body },
            data: {
                type: type || "system_message",
                postId: postId || "",
                fromUserId: fromUserId || "",
                fromUserName: fromUserName || "",
                actionUrl: actionUrl || "",
                priority: priority || "medium",
            },
            tokens: fcmTokens,
        };
        const response = await admin.messaging().sendEachForMulticast(message);
        return {
            success: true,
            successCount: response.successCount,
            failureCount: response.failureCount,
        };
    }
    catch (error) {
        console.error("Error en sendDirectNotification:", error);
        throw new Error("Error interno del servidor");
    }
});
/**
 * Cloud Function para limpiar notificaciones antiguas (ejecutar semanalmente)
 */
exports.cleanupOldNotifications = (0, scheduler_1.onSchedule)("0 2 * * 0", async () => {
    try {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        const oldNotifications = await admin.firestore()
            .collection("notifications")
            .where("createdAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
            .get();
        const batch = admin.firestore().batch();
        oldNotifications.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(`🧹 Eliminadas ${oldNotifications.size} notificaciones antiguas`);
    }
    catch (error) {
        console.error("Error limpiando notificaciones:", error);
    }
});
/**
 * Cloud Function para testing - envía notificación de prueba
 */
exports.sendTestNotification = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new Error("El usuario debe estar autenticado");
    }
    const userId = request.auth.uid;
    try {
        // Crear notificación de prueba en Firestore
        await admin.firestore().collection("notifications").add({
            userId: userId,
            type: "system_message",
            title: "🧪 Notificación de Prueba",
            message: "¡Las notificaciones push funcionan correctamente!",
            priority: "medium",
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            fromUserName: "Sistema PoliCode",
        });
        return { success: true, message: "Notificación de prueba enviada" };
    }
    catch (error) {
        console.error("Error enviando notificación de prueba:", error);
        throw new Error("Error enviando notificación de prueba");
    }
});
//# sourceMappingURL=index.js.map