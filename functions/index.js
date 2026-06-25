const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const crypto = require("crypto");

admin.initializeApp();

const FCM_TOKENS_COLLECTION = "fcm_tokens";
const FCM_MULTICAST_BATCH_SIZE = 500;
/** Días sin actualizar para tokens de promos (ciudad); tras eso se eliminan. */
const FCM_TOKEN_MAX_AGE_DAYS = 90;
/** Días sin actualizar para tokens de auditoría (superadmin por lugar); más persistentes. */
const FCM_TOKEN_AUDIT_MAX_AGE_DAYS = 180;
// Imagen de notificación: balón de fútbol. Para usar tu logo, súbelo a Firebase Storage y pega aquí la URL.
const NOTIFICATION_IMAGE_URL = "https://img.icons8.com/color/512/soccer-ball.png";

/** Registra o actualiza un token FCM para recibir notificaciones de una ciudad. Sin login. */
exports.registerFcmToken = onCall(async (request) => {
  const { token, ciudadId, platform } = request.data || {};
  if (!token || typeof token !== "string" || token.length === 0) {
    throw new HttpsError("invalid-argument", "token es requerido.");
  }
  if (!ciudadId || typeof ciudadId !== "string" || ciudadId.length === 0) {
    throw new HttpsError("invalid-argument", "ciudadId es requerido.");
  }
  const validPlatforms = ["web", "android", "ios"];
  if (!platform || !validPlatforms.includes(platform)) {
    throw new HttpsError("invalid-argument", "platform debe ser web, android o ios.");
  }
  const docId = crypto.createHash("sha256").update(token).digest("hex");
  try {
    await admin.firestore().collection(FCM_TOKENS_COLLECTION).doc(docId).set({
      token,
      ciudadId,
      platform,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { success: true };
  } catch (err) {
    throw new HttpsError("internal", err.message || "Error registrando token.");
  }
});

/** Registra token FCM para notificaciones de reservas pendientes (admin / encargado / superadmin del mismo lugar). */
exports.registerFcmTokenStaffPendingReservas = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  const { token, lugarId, platform } = request.data || {};
  if (!token || typeof token !== "string" || token.length === 0) {
    throw new HttpsError("invalid-argument", "token es requerido.");
  }
  if (!lugarId || typeof lugarId !== "string" || lugarId.length === 0) {
    throw new HttpsError("invalid-argument", "lugarId es requerido.");
  }
  const validPlatforms = ["web", "android", "ios"];
  const plat = platform && validPlatforms.includes(platform) ? platform : "web";

  const uid = request.auth.uid;
  const userDoc = await admin.firestore().collection("usuarios").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "Usuario no encontrado.");
  }
  const data = userDoc.data();
  const rol = data.rol;
  const allowed = ["admin", "encargado", "superadmin"];
  if (!allowed.includes(rol)) {
    throw new HttpsError(
      "permission-denied",
      "Solo administrador, encargado o superadmin reciben avisos de reservas pendientes."
    );
  }
  const userLugarId = data.lugarId;
  if (!userLugarId || String(userLugarId) !== String(lugarId)) {
    throw new HttpsError(
      "permission-denied",
      "El lugar indicado no coincide con el de tu sesión."
    );
  }

  const docId = crypto.createHash("sha256").update(token).digest("hex");
  try {
    await admin.firestore().collection(FCM_TOKENS_COLLECTION).doc(docId).set({
      token,
      lugarId: String(lugarId),
      platform: plat,
      staffPendingPush: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { success: true };
  } catch (err) {
    throw new HttpsError("internal", err.message || "Error registrando token.");
  }
});

/** Deja de enviar notificaciones de reservas pendientes a este dispositivo (p. ej. al cerrar sesión). */
exports.unregisterFcmTokenStaffPendingReservas = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  const { token } = request.data || {};
  if (!token || typeof token !== "string" || token.length === 0) {
    throw new HttpsError("invalid-argument", "token es requerido.");
  }
  const docId = crypto.createHash("sha256").update(token).digest("hex");
  const ref = admin.firestore().collection(FCM_TOKENS_COLLECTION).doc(docId);
  const snap = await ref.get();
  if (!snap.exists) {
    return { success: true };
  }
  try {
    await ref.set({
      staffPendingPush: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { success: true };
  } catch (err) {
    throw new HttpsError("internal", err.message || "Error actualizando token.");
  }
});

/** Registra o actualiza token FCM para notificaciones de auditoría (riesgo alto/crítico) de SU lugar. Solo superadmin. */
exports.registerFcmTokenAudit = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  const { token, lugarId, platform } = request.data || {};
  if (!token || typeof token !== "string" || token.length === 0) {
    throw new HttpsError("invalid-argument", "token es requerido.");
  }
  if (!lugarId || typeof lugarId !== "string" || lugarId.length === 0) {
    throw new HttpsError("invalid-argument", "lugarId es requerido.");
  }
  const validPlatforms = ["web", "android", "ios"];
  const plat = platform && validPlatforms.includes(platform) ? platform : "web";

  const uid = request.auth.uid;
  const userDoc = await admin.firestore().collection("usuarios").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "Usuario no encontrado.");
  }
  const rol = userDoc.data().rol;
  if (rol !== "superadmin") {
    throw new HttpsError(
      "permission-denied",
      "Solo el superadmin puede registrar notificaciones de auditoría de su lugar."
    );
  }

  const docId = crypto.createHash("sha256").update(token).digest("hex");
  try {
    await admin.firestore().collection(FCM_TOKENS_COLLECTION).doc(docId).set({
      token,
      lugarId,
      rol: "superadmin",
      platform: plat,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { success: true };
  } catch (err) {
    throw new HttpsError("internal", err.message || "Error registrando token de auditoría.");
  }
});

/** Limpia tokens FCM obsoletos: 90 días para promos (ciudad), 180 días para auditoría (superadmin). */
exports.cleanupStaleFcmTokens = onSchedule("0 3 * * *", async () => {
  const db = admin.firestore();
  const now = new Date();
  const cutoff90 = new Date(now);
  cutoff90.setDate(cutoff90.getDate() - FCM_TOKEN_MAX_AGE_DAYS);
  const cutoff180 = new Date(now);
  cutoff180.setDate(cutoff180.getDate() - FCM_TOKEN_AUDIT_MAX_AGE_DAYS);

  const ts90 = admin.firestore.Timestamp.fromDate(cutoff90);
  const ts180 = admin.firestore.Timestamp.fromDate(cutoff180);

  let totalRemoved = 0;

  // Tokens de promos (sin rol): eliminar si no se actualizaron en 90 días (máx 500 por batch)
  const stale90 = await db.collection(FCM_TOKENS_COLLECTION)
    .where("updatedAt", "<", ts90)
    .limit(500)
    .get();

  const batchPromo = db.batch();
  stale90.docs.forEach((d) => {
    const data = d.data();
    if (data.rol === "superadmin") return;
    batchPromo.delete(d.ref);
    totalRemoved++;
  });
  if (totalRemoved > 0) await batchPromo.commit();

  // Tokens de auditoría (superadmin): eliminar solo si no se actualizaron en 180 días (máx 500 por batch)
  const staleAudit = await db.collection(FCM_TOKENS_COLLECTION)
    .where("rol", "==", "superadmin")
    .where("updatedAt", "<", ts180)
    .limit(500)
    .get();

  const batchAudit = db.batch();
  staleAudit.docs.forEach((d) => {
    batchAudit.delete(d.ref);
    totalRemoved++;
  });
  if (staleAudit.size > 0) await batchAudit.commit();

  if (totalRemoved > 0) {
    console.log("cleanupStaleFcmTokens: removed", totalRemoved, "stale tokens");
  } else {
    console.log("cleanupStaleFcmTokens: no stale tokens");
  }
});

// Callable: actualiza email y/o contraseña de un usuario en Auth (solo admin/programador).
exports.updateUserAuth = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  const callerUid = request.auth.uid;
  const callerDoc = await admin.firestore().collection("usuarios").doc(callerUid).get();
  const callerRol = callerDoc.exists && callerDoc.data() ? callerDoc.data().rol : null;
  if (callerRol !== "programador" && callerRol !== "superadmin") {
    throw new HttpsError(
      "permission-denied",
      "Solo programador o superadmin pueden actualizar email/contraseña."
    );
  }
  const { uid, newEmail, newPassword } = request.data || {};
  if (!uid || typeof uid !== "string") {
    throw new HttpsError("invalid-argument", "uid es requerido.");
  }
  const email = newEmail || null;
  const password = newPassword || null;
  if (!email && !password) {
    throw new HttpsError("invalid-argument", "Indica newEmail o newPassword.");
  }
  const update = {};
  if (email) update.email = email;
  if (password) update.password = password;
  try {
    await admin.auth().updateUser(uid, update);
    return { success: true };
  } catch (err) {
    throw new HttpsError("internal", err.message || "Error al actualizar usuario.");
  }
});

// DESACTIVADO temporalmente: no ejecutar hasta que se vuelva a usar (evitar invocaciones y costos)
// exports.cleanupPendingReservations = onSchedule("every 10 minutes", async () => {
//   const now = admin.firestore.Timestamp.now();
//   const oneHourAgo = new Date(now.toDate().getTime() - 60 * 60 * 1000);
//
//   const pendingReservations = await admin.firestore()
//     .collection("reservas_pendientes")
//     .where("estado", "==", "pendiente")
//     .where("expira_en", "<=", oneHourAgo.getTime())
//     .get();
//
//   const batch = admin.firestore().batch();
//
//   for (const doc of pendingReservations.docs) {
//     const data = doc.data();
//     batch.set(
//       admin.firestore().collection("reservas_historial").doc(doc.id),
//       {
//         ...data,
//         estado: "expirada",
//         procesado_en: admin.firestore.FieldValue.serverTimestamp(),
//       }
//     );
//     batch.delete(doc.ref);
//   }
//
//   await batch.commit();
//   console.log(`Processed ${pendingReservations.docs.length} expired reservations`);
// });

/** Elimina promociones cuya fecha ya pasó (fecha < hoy). Se ejecuta cada domingo a las 4:00. */
const PROMOCIONES_COLLECTION = "promociones";

function getTodayYYYYMMDD() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

exports.cleanupOldPromociones = onSchedule("0 4 * * 0", async () => {
  const db = admin.firestore();
  const todayStr = getTodayYYYYMMDD();

  const old = await db.collection(PROMOCIONES_COLLECTION)
    .where("fecha", "<", todayStr)
    .limit(500)
    .get();

  if (old.empty) {
    console.log("cleanupOldPromociones: no hay promociones con fecha anterior a", todayStr);
    return;
  }

  const batch = db.batch();
  old.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  console.log("cleanupOldPromociones: eliminadas", old.size, "promociones con fecha <", todayStr);
});

// Envía notificación push solo a dispositivos de la ciudad de la promoción (web + móvil)
exports.notifyPromocionCreated = onDocumentCreated("promociones/{promoId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("notifyPromocionCreated: no data");
    return;
  }
  const data = snapshot.data();
  const lugarId = data.lugarId;
  const canchaNombre = data.cancha_nombre || "Cancha";
  const fecha = data.fecha || "";
  const horario = data.horario || "";
  const precioPromocional = data.precio_promocional;
  const nota = data.nota || "";
  const promoId = event.params.promoId;

  let lugarNombre = "TuCanchaFácil";
  let ciudadId = "";
  if (lugarId) {
    try {
      const lugarDoc = await admin.firestore().collection("lugares").doc(lugarId).get();
      if (lugarDoc.exists) {
        const lugarData = lugarDoc.data();
        if (lugarData.nombre) lugarNombre = lugarData.nombre;
        if (lugarData.ciudadId) ciudadId = String(lugarData.ciudadId);
      }
    } catch (e) {
      console.warn("notifyPromocionCreated: no se pudo leer lugar", e.message);
    }
  }

  if (!ciudadId) {
    console.log("notifyPromocionCreated: sin ciudadId, no se envían notificaciones");
    return;
  }

  const precioStr = precioPromocional != null ?
    `$${Number(precioPromocional).toLocaleString("es-CO")}` :
    "";
  const horaInfo = [fecha, horario].filter(Boolean).join(" · ");
  const title = `⚽ Nueva promoción – ${lugarNombre}`;
  let body = `${precioStr}`;
  if (horaInfo) body += ` · ${horaInfo}`;
  if (canchaNombre) body += ` · ${canchaNombre}`;
  if (nota) body += ` – ${nota.substring(0, 80)}${nota.length > 80 ? "…" : ""}`;
  if (!body.trim()) body = "¡Revisa las promociones en TuCanchaFácil!";

  const payload = {
    notification: {
      title,
      body,
      imageUrl: NOTIFICATION_IMAGE_URL,
    },
    data: {
      type: "promocion",
      promocionId: promoId,
      lugarId: String(lugarId || ""),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "promociones",
        imageUrl: NOTIFICATION_IMAGE_URL,
      },
    },
    apns: {
      payload: { aps: { "mutable-content": 1 } },
      fcmOptions: { imageUrl: NOTIFICATION_IMAGE_URL },
    },
    webpush: {
      notification: {
        title,
        body,
        icon: NOTIFICATION_IMAGE_URL,
        image: NOTIFICATION_IMAGE_URL,
        requireInteraction: false,
      },
      fcmOptions: {
        link: "/",
      },
    },
  };

  try {
    const tokensSnap = await admin.firestore()
      .collection(FCM_TOKENS_COLLECTION)
      .where("ciudadId", "==", ciudadId)
      .get();

    const docIds = [];
    const tokens = [];
    tokensSnap.docs.forEach((d) => {
      const t = d.data().token;
      if (t) {
        docIds.push(d.id);
        tokens.push(t);
      }
    });

    if (tokens.length === 0) {
      console.log("notifyPromocionCreated: no tokens for ciudadId", ciudadId);
      return;
    }

    const toDelete = new Set(); // docIds de tokens que FCM rechaza (inválidos o desregistrados)

    for (let i = 0; i < tokens.length; i += FCM_MULTICAST_BATCH_SIZE) {
      const batchTokens = tokens.slice(i, i + FCM_MULTICAST_BATCH_SIZE);
      const batchDocIds = docIds.slice(i, i + FCM_MULTICAST_BATCH_SIZE);
      const multicast = { ...payload, tokens: batchTokens };
      const response = await admin.messaging().sendEachForMulticast(multicast);
      const failed = response.responses.filter((r) => !r.success).length;
      if (failed > 0) {
        response.responses.forEach((r, idx) => {
          if (!r.success && r.error && isPermanentFcmError(r.error.code)) {
            toDelete.add(batchDocIds[idx]);
          }
        });
        console.warn("notifyPromocionCreated: batch", i / FCM_MULTICAST_BATCH_SIZE,
          "success:", response.successCount, "failed:", failed);
      }
    }

    if (toDelete.size > 0) {
      const batch = admin.firestore().batch();
      toDelete.forEach((id) => {
        batch.delete(admin.firestore().collection(FCM_TOKENS_COLLECTION).doc(id));
      });
      await batch.commit();
      console.log("notifyPromocionCreated: removed", toDelete.size, "invalid FCM tokens");
    }

    console.log("notifyPromocionCreated: sent to", tokens.length, "tokens, ciudadId:", ciudadId);
  } catch (err) {
    console.error("notifyPromocionCreated: FCM error", err.message, "promoId:", promoId);
  }
});

/** Notifica solo al superadmin del lugar cuando se crea una auditoría de riesgo alto o crítico de ESE lugar. */
exports.notifyAuditoriaAltaRiesgo = onDocumentCreated("auditoria/{auditId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const data = snapshot.data();
  const nivelRiesgo = (data.nivel_riesgo || "").toLowerCase();
  if (nivelRiesgo !== "alto" && nivelRiesgo !== "critico") {
    return;
  }
  const lugarId = data.lugarId;
  if (!lugarId || typeof lugarId !== "string") {
    console.log("notifyAuditoriaAltaRiesgo: sin lugarId, skip");
    return;
  }
  const descripcion = (data.descripcion || "Nueva auditoría de riesgo " + nivelRiesgo).substring(0, 120);
  const title = nivelRiesgo === "critico" ? "🚨 Auditoría riesgo CRÍTICO" : "🔴 Auditoría riesgo ALTO";
  const auditId = event.params.auditId;

  const payload = {
    notification: {
      title,
      body: descripcion,
      imageUrl: NOTIFICATION_IMAGE_URL,
    },
    data: {
      type: "auditoria",
      auditId: String(auditId),
      lugarId: String(lugarId),
      nivel_riesgo: String(nivelRiesgo),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: { channelId: "promociones", imageUrl: NOTIFICATION_IMAGE_URL },
    },
    apns: {
      payload: { aps: { "mutable-content": 1 } },
      fcmOptions: { imageUrl: NOTIFICATION_IMAGE_URL },
    },
    webpush: {
      notification: {
        title,
        body: descripcion,
        icon: NOTIFICATION_IMAGE_URL,
        imageUrl: NOTIFICATION_IMAGE_URL,
        requireInteraction: true,
      },
      fcmOptions: { link: "/" },
    },
  };

  try {
    const tokensSnap = await admin.firestore()
      .collection(FCM_TOKENS_COLLECTION)
      .where("lugarId", "==", lugarId)
      .where("rol", "==", "superadmin")
      .get();

    const tokens = [];
    tokensSnap.docs.forEach((d) => {
      const t = d.data().token;
      if (t) tokens.push(t);
    });

    if (tokens.length === 0) {
      console.log("notifyAuditoriaAltaRiesgo: no tokens superadmin for lugarId", lugarId);
      return;
    }

    for (let i = 0; i < tokens.length; i += FCM_MULTICAST_BATCH_SIZE) {
      const batch = tokens.slice(i, i + FCM_MULTICAST_BATCH_SIZE);
      const multicast = { ...payload, tokens: batch };
      await admin.messaging().sendEachForMulticast(multicast);
    }
    console.log("notifyAuditoriaAltaRiesgo: sent to", tokens.length, "superadmin tokens, lugarId:", lugarId, "auditId:", auditId);
  } catch (err) {
    console.error("notifyAuditoriaAltaRiesgo: FCM error", err.message, "auditId:", auditId);
  }
});

/** Notifica a staff (admin/encargado/superadmin) registrado para el mismo lugar: nueva reserva pendiente de confirmación. */
exports.notifyReservaPendienteCreated = onDocumentCreated("reservas/{reservaId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    return;
  }
  const data = snapshot.data();
  if (data.confirmada !== false) {
    return;
  }
  const rawLugar = data.lugarId;
  if (rawLugar == null || String(rawLugar).trim() === "") {
    console.log("notifyReservaPendienteCreated: sin lugarId, skip");
    return;
  }
  const lugarId = String(rawLugar);

  const nombre = data.nombre || "Cliente";
  const fecha = data.fecha || "";
  const horario = data.horario || "";
  const canchaNombre = data.cancha_nombre || data.canchaNombre || "";
  const reservaId = event.params.reservaId;

  let lugarNombre = "Tu lugar";
  try {
    const lugarDoc = await admin.firestore().collection("lugares").doc(String(lugarId)).get();
    if (lugarDoc.exists && lugarDoc.data().nombre) {
      lugarNombre = lugarDoc.data().nombre;
    }
  } catch (e) {
    console.warn("notifyReservaPendienteCreated: lugar read", e.message);
  }

  const title = `📋 Reserva pendiente — ${lugarNombre}`;
  const parts = [nombre, fecha, horario].filter(Boolean);
  if (canchaNombre) parts.push(canchaNombre);
  let body = parts.join(" · ");
  if (!body.trim()) body = "Nueva reserva por confirmar.";

  const payload = {
    notification: {
      title,
      body,
      imageUrl: NOTIFICATION_IMAGE_URL,
    },
    data: {
      type: "reserva_pendiente",
      reservaId: String(reservaId),
      lugarId: String(lugarId),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "reservas_staff_pendientes",
        imageUrl: NOTIFICATION_IMAGE_URL,
      },
    },
    apns: {
      payload: { aps: { "mutable-content": 1 } },
      fcmOptions: { imageUrl: NOTIFICATION_IMAGE_URL },
    },
    webpush: {
      notification: {
        title,
        body,
        icon: NOTIFICATION_IMAGE_URL,
        imageUrl: NOTIFICATION_IMAGE_URL,
        requireInteraction: false,
      },
      fcmOptions: { link: "/" },
    },
  };

  try {
    const tokensSnap = await admin.firestore()
      .collection(FCM_TOKENS_COLLECTION)
      .where("lugarId", "==", lugarId)
      .where("staffPendingPush", "==", true)
      .get();

    const docIds = [];
    const tokens = [];
    tokensSnap.docs.forEach((d) => {
      const t = d.data().token;
      if (t) {
        docIds.push(d.id);
        tokens.push(t);
      }
    });

    if (tokens.length === 0) {
      console.log("notifyReservaPendienteCreated: no staff tokens for lugarId", lugarId);
      return;
    }

    const toDelete = new Set();
    for (let i = 0; i < tokens.length; i += FCM_MULTICAST_BATCH_SIZE) {
      const batchTokens = tokens.slice(i, i + FCM_MULTICAST_BATCH_SIZE);
      const batchDocIds = docIds.slice(i, i + FCM_MULTICAST_BATCH_SIZE);
      const multicast = { ...payload, tokens: batchTokens };
      const response = await admin.messaging().sendEachForMulticast(multicast);
      if (response.failureCount > 0) {
        response.responses.forEach((r, idx) => {
          if (!r.success && r.error && isPermanentFcmError(r.error.code)) {
            toDelete.add(batchDocIds[idx]);
          }
        });
      }
    }

    if (toDelete.size > 0) {
      const batch = admin.firestore().batch();
      toDelete.forEach((id) => {
        batch.delete(admin.firestore().collection(FCM_TOKENS_COLLECTION).doc(id));
      });
      await batch.commit();
    }
    console.log("notifyReservaPendienteCreated: sent to", tokens.length, "tokens reservaId:", reservaId);
  } catch (err) {
    console.error("notifyReservaPendienteCreated: FCM error", err.message, "reservaId:", reservaId);
  }
});

/**
 * Códigos de error FCM que indican token inválido/desregistrado; se puede borrar de Firestore.
 * @param {string} code - Código de error devuelto por FCM
 * @return {boolean} true si el error es permanente y el token debe eliminarse
 */
function isPermanentFcmError(code) {
  if (!code) return false;
  const permanent = [
    "invalid-registration",
    "registration-token-not-registered",
    "invalid-argument",
    "mismatch-sender-id",
  ];
  return permanent.some((c) => code.includes(c) || code === c);
}
